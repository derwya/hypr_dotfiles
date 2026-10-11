use clap::{Parser, ValueEnum};
use serde::Deserialize;
use std::{
    fs,
    io::{BufRead, BufReader, Read, Write},
    os::unix::net::UnixStream,
    sync::mpsc::{self, Sender},
    thread,
    time::Duration,
    path::Path,
};

const PIXEL_THRESHOLD: i32 = 5;
const PIXEL_THRESHOLD_SECONDARY: i32 = 50;
const MOUSE_REFRESH_DELAY_MS: u64 = 150;
const BOTTOM_EDGE_EXTENSION: i32 = 40;
const ACTIVE_MONITOR_TOLERANCE: i32 = 2;
const STATE_FILE: &str = "/tmp/waybar_state";

fn get_bar_state() -> u8 {
    // 0=autohide, 1=always_visible, 2=always_hidden
    if let Ok(content) = fs::read_to_string(STATE_FILE) {
        content.trim().parse::<u8>().unwrap_or(0)
    } else {
        0
    }
}

fn main() {
    let args = Args::parse();
    let (tx, rx) = mpsc::channel::<Event>();

    println!("--- AUTO-HIDE BAR STARTED ---");
    println!(
        "Watching Side: {:?} | Manual Scaling: {} | Monitor: {:?}",
        args.side, args.scaling, args.monitor
    );

    let target_pid = match args.pid {
        Some(p) => Some(p),
        None => find_waybar_pid(),
    };

    if target_pid.is_none() {
        eprintln!("CRITICAL ERROR: Could not find Waybar PID. Is Waybar running?");
        return;
    }
    let waybar_pid = target_pid.unwrap();
    println!("Target Waybar PID: {}", waybar_pid);
    thread::sleep(Duration::from_millis(500));

    let mut cursor_top: bool = false;
    let mut windows_opened: bool = check_windows_on_monitor(&args.monitor);
    let mut last_visibility: bool = !windows_opened;

    spawn_mouse_position_updater(tx.clone(), args.clone());
    spawn_window_event_listener(tx.clone(), args.monitor.clone());

    set_waybar_visible(waybar_pid, last_visibility);

    for event in rx {
        let bar_state = get_bar_state();
        
        match bar_state {
            1 => {
                // Always visible
                if !last_visibility {
                    set_waybar_visible(waybar_pid, true);
                    last_visibility = true;
                }
                continue;
            }
            2 => {
                // Always hidden
                if last_visibility {
                    set_waybar_visible(waybar_pid, false);
                    last_visibility = false;
                }
                continue;
            }
            _ => {
                // Auto-hide (normal behavior)
            }
        }

        match event {
            Event::CursorTop(val) => cursor_top = val,
            Event::WindowsOpened(val) => windows_opened = val,
        }

        let should_be_visible = if args.always_hidden {
            cursor_top
        } else {
            if cursor_top { true } else { !windows_opened }
        };

        if should_be_visible != last_visibility {
            if !set_waybar_visible(waybar_pid, should_be_visible) {
                eprintln!(
                    "ERROR: Failed to signal Waybar (PID {}). Did it crash?",
                    waybar_pid
                );
            }
            last_visibility = should_be_visible;
        }
    }
}

#[derive(Parser, Clone)]
struct Args {
    #[arg(long)]
    always_hidden: bool,

    #[arg(long, value_enum, default_value = "top")]
    side: Side,

    #[arg(long)]
    pid: Option<i32>,

    #[arg(long, default_value_t = 1.0)]
    scaling: f32,

    #[arg(long)]
    monitor: Option<String>,
}

fn mixed_monitor_rect(m: &Monitor, scaling: f32) -> (i32, i32, i32, i32) {
    let s = if scaling.is_finite() && scaling > 0.0 {
        scaling
    } else {
        1.0
    };
    let x = m.x;
    let y = m.y;
    let width = (m.width as f32 / s).round() as i32;
    let height = (m.height as f32 / s).round() as i32;
    (x, y, width.max(1), height.max(1))
}

fn spawn_mouse_position_updater(tx: Sender<Event>, args: Args) {
    thread::spawn(move || {
        let mut previous_state = false;

        loop {
            if let (Some(pos), Some(monitors)) = (get_cursor_pos(), get_monitors()) {
                let target_monitor = if let Some(ref monitor_name) = args.monitor {
                    monitors.iter().find(|m| m.name == *monitor_name)
                } else {
                    monitors.first()
                };

                let Some(target) = target_monitor else {
                    if let Some(ref name) = args.monitor {
                        eprintln!("WARNING: Monitor '{}' not found", name);
                    }
                    thread::sleep(Duration::from_millis(MOUSE_REFRESH_DELAY_MS));
                    continue;
                };

                let (mx, my, mw, mh) = mixed_monitor_rect(target, args.scaling);
                let right = mx + mw - 1;
                let bottom = my + mh - 1;
                let tol = ACTIVE_MONITOR_TOLERANCE;

                let cursor_on_target = pos.x >= (mx - tol)
                    && pos.x <= (right + tol)
                    && pos.y >= (my - tol)
                    && pos.y <= (bottom + tol);

                if !cursor_on_target {
                    if previous_state {
                        tx.send(Event::CursorTop(false)).ok();
                        previous_state = false;
                    }
                    thread::sleep(Duration::from_millis(MOUSE_REFRESH_DELAY_MS));
                    continue;
                }

                let cx = pos.x.clamp(mx, right);
                let cy = pos.y.clamp(my, bottom);

                let distance_from_edge = match args.side {
                    Side::Top => cy - my,
                    Side::Bottom => {
                        let adjusted_distance = bottom - cy;
                        adjusted_distance + BOTTOM_EDGE_EXTENSION
                    }
                    Side::Left => cx - mx,
                    Side::Right => right - cx,
                };

                let threshold = if previous_state {
                    PIXEL_THRESHOLD_SECONDARY
                } else {
                    PIXEL_THRESHOLD
                };

                let effective_threshold = if matches!(args.side, Side::Bottom) {
                    threshold + BOTTOM_EDGE_EXTENSION
                } else {
                    threshold
                };

                let is_cursor_at_edge = distance_from_edge <= effective_threshold;

                if is_cursor_at_edge != previous_state {
                    tx.send(Event::CursorTop(is_cursor_at_edge)).ok();
                    previous_state = is_cursor_at_edge;
                }
            }

            thread::sleep(Duration::from_millis(MOUSE_REFRESH_DELAY_MS));
        }
    });
}

#[derive(Debug)]
enum Event {
    CursorTop(bool),
    WindowsOpened(bool),
}

fn hypr_query(cmd: &str) -> Option<String> {
    let socket_path = format!(
        "{}/hypr/{}/.socket.sock",
        std::env::var("XDG_RUNTIME_DIR").ok()?,
        std::env::var("HYPRLAND_INSTANCE_SIGNATURE").ok()?
    );
    let mut stream = UnixStream::connect(socket_path).ok()?;
    stream.write_all(cmd.as_bytes()).ok()?;
    let mut response = String::new();
    stream.read_to_string(&mut response).ok()?;
    Some(response)
}

fn get_cursor_pos() -> Option<CursorPos> {
    serde_json::from_str(&hypr_query("j/cursorpos")?).ok()
}

fn get_monitors() -> Option<Vec<Monitor>> {
    serde_json::from_str(&hypr_query("j/monitors")?).ok()
}

fn spawn_window_event_listener(tx: mpsc::Sender<Event>, monitor: Option<String>) {
    thread::spawn(move || {
        let socket_path = format!(
            "{}/hypr/{}/.socket2.sock",
            std::env::var("XDG_RUNTIME_DIR").unwrap(),
            std::env::var("HYPRLAND_INSTANCE_SIGNATURE").unwrap()
        );

        let stream = match UnixStream::connect(&socket_path) {
            Ok(s) => s,
            Err(_) => return,
        };

        let reader = BufReader::new(stream);
        for line in reader.lines().flatten() {
            if line.contains("window") || line.contains("workspace") {
                tx.send(Event::WindowsOpened(check_windows_on_monitor(&monitor)))
                    .ok();
            }
        }
    });
}

fn check_windows_on_monitor(monitor_name: &Option<String>) -> bool {
    let monitors_json = hypr_query("j/monitors").unwrap_or_default();
    let monitors: Vec<serde_json::Value> = serde_json::from_str(&monitors_json).unwrap_or_default();

    let target_monitor = if let Some(name) = monitor_name {
        monitors.iter().find(|m| m["name"].as_str() == Some(name))
    } else {
        monitors.first()
    };

    if let Some(monitor) = target_monitor {
        if let Some(workspace_id) = monitor["activeWorkspace"]["id"].as_i64() {
            let workspaces_json = hypr_query("j/workspaces").unwrap_or_default();
            let workspaces: Vec<serde_json::Value> =
                serde_json::from_str(&workspaces_json).unwrap_or_default();

            if let Some(workspace) = workspaces
                .iter()
                .find(|ws| ws["id"].as_i64() == Some(workspace_id))
            {
                return workspace["windows"].as_i64().unwrap_or(0) > 0;
            }
        }
    }

    let res = hypr_query("j/activeworkspace").unwrap_or_default();
    let data: serde_json::Value = serde_json::from_str(&res).unwrap_or_default();
    data["windows"].as_i64().unwrap_or(0) > 0
}

fn set_waybar_visible(pid: i32, visible: bool) -> bool {
    let signal = if visible { 12 } else { 10 };
    unsafe { libc::kill(pid, signal) == 0 }
}

fn find_waybar_pid() -> Option<i32> {
    fs::read_dir("/proc")
        .ok()?
        .filter_map(|entry| {
            let path = entry.ok()?.path();
            if !path.is_dir() {
                return None;
            }
            let comm = fs::read_to_string(path.join("comm")).ok()?;
            if comm.trim() == "waybar" || comm.trim() == ".waybar-wrapped" {
                path.file_name()?.to_str()?.parse::<i32>().ok()
            } else {
                None
            }
        })
        .next()
}

#[derive(Deserialize)]
struct CursorPos {
    x: i32,
    y: i32,
}

#[derive(Deserialize, Debug)]
struct Monitor {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    name: String,
}

#[derive(Debug, Clone, Copy, Deserialize, ValueEnum)]
enum Side {
    Top,
    Left,
    Right,
    Bottom,
}

impl Default for Side {
    fn default() -> Self {
        Side::Top
    }
}

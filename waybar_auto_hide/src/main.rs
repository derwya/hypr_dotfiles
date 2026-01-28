use clap::{Parser, ValueEnum};
use serde::Deserialize;
use std::{
    fs,
    io::{BufRead, BufReader, Read, Write},
    os::unix::net::UnixStream,
    sync::mpsc::{self, Sender},
    thread,
    time::Duration,
};

// --- CONFIGURATION ---
const PIXEL_THRESHOLD: i32 = 5;
const PIXEL_THRESHOLD_SECONDARY: i32 = 50;
const MOUSE_REFRESH_DELAY_MS: u64 = 150;

// Your original idea: allow some extra “bottom area” so the reveal feels easier/smoother.
const BOTTOM_EDGE_EXTENSION: i32 = 40;

// Fix for “cursor disappears at the very bottom”: allow a couple pixels of tolerance when
// determining which monitor the cursor is on (rounding/scaling can push it out by ~1px).
const ACTIVE_MONITOR_TOLERANCE: i32 = 2;

fn main() {
    let args = Args::parse();
    let (tx, rx) = mpsc::channel::<Event>();

    println!("--- AUTO-HIDE BAR STARTED ---");
    println!("Watching Side: {:?} | Manual Scaling: {}", args.side, args.scaling);

    // 1. Determine Target PID
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

    let mut cursor_top: bool = false;
    let mut windows_opened: bool = check_windows();
    let mut last_visibility: bool = !windows_opened;

    spawn_mouse_position_updater(tx.clone(), args.clone());
    spawn_window_event_listener(tx.clone());

    // Initial state set
    set_waybar_visible(waybar_pid, last_visibility);

    for event in rx {
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
                eprintln!("ERROR: Failed to signal Waybar (PID {}). Did it crash?", waybar_pid);
            }
            last_visibility = should_be_visible;
        }
    }
}

// --- ARGS STRUCT ---
#[derive(Parser, Clone)]
struct Args {
    #[arg(long)]
    always_hidden: bool,

    #[arg(long, value_enum, default_value = "top")]
    side: Side,

    #[arg(long)]
    pid: Option<i32>,

    /// Your monitor scaling factor (e.g., 1.67).
    #[arg(long, default_value_t = 1.0)]
    scaling: f32,
}

// --- MOUSE UPDATER ---
fn spawn_mouse_position_updater(tx: Sender<Event>, args: Args) {
    thread::spawn(move || {
        let mut previous_state = false;
        let mut last_active_monitor_idx: Option<usize> = None;

        loop {
            if let (Some(pos), Some(monitors)) = (get_cursor_pos(), get_monitors()) {
                // Find active monitor in LOGICAL space, but with:
                // - inclusive bounds (<=) instead of strict < on right/bottom
                // - a small tolerance to survive rounding/scaling edge cases
                let active_idx = monitors.iter().enumerate().find_map(|(i, m)| {
                    let (lx, ly, lw, lh) = logical_monitor_rect(m, args.scaling);
                    let right = lx + lw - 1;
                    let bottom = ly + lh - 1;

                    let tol = ACTIVE_MONITOR_TOLERANCE;

                    let inside_x = pos.x >= (lx - tol) && pos.x <= (right + tol);
                    let inside_y = pos.y >= (ly - tol) && pos.y <= (bottom + tol);

                    if inside_x && inside_y { Some(i) } else { None }
                });

                let use_idx = match active_idx {
                    Some(i) => {
                        last_active_monitor_idx = Some(i);
                        Some(i)
                    }
                    None => last_active_monitor_idx,
                };

                if let Some(i) = use_idx {
                    let m = &monitors[i];

                    // Keep your original "round()" scaling logic
                    let (logical_x, logical_y, logical_width, logical_height) =
                        logical_monitor_rect(m, args.scaling);

                    let right_edge = logical_x + logical_width - 1;
                    let bottom_edge = logical_y + logical_height - 1;

                    // IMPORTANT: clamp cursor into the monitor rect so that if Hyprland reports
                    // (x,y) slightly outside due to scaling/rounding, we still treat it as on-edge.
                    let cx = pos.x.clamp(logical_x, right_edge);
                    let cy = pos.y.clamp(logical_y, bottom_edge);

                    let distance_from_edge = match args.side {
                        Side::Top => cy - logical_y,
                        Side::Bottom => {
                            // RESTORED: your original bottom logic (smooth feel)
                            let adjusted_distance = bottom_edge - cy;
                            adjusted_distance + BOTTOM_EDGE_EXTENSION
                        }
                        Side::Left => cx - logical_x,
                        Side::Right => right_edge - cx,
                    };

                    let threshold = if previous_state {
                        PIXEL_THRESHOLD_SECONDARY
                    } else {
                        PIXEL_THRESHOLD
                    };

                    // RESTORED: your original effective threshold logic
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
            }

            thread::sleep(Duration::from_millis(MOUSE_REFRESH_DELAY_MS));
        }
    });
}

fn logical_monitor_rect(m: &Monitor, scaling: f32) -> (i32, i32, i32, i32) {
    let s = if scaling.is_finite() && scaling > 0.0 { scaling } else { 1.0 };

    // RESTORED: same rounding approach you had before
    let logical_x = (m.x as f32 / s).round() as i32;
    let logical_y = (m.y as f32 / s).round() as i32;
    let logical_width = (m.width as f32 / s).round() as i32;
    let logical_height = (m.height as f32 / s).round() as i32;

    (logical_x, logical_y, logical_width.max(1), logical_height.max(1))
}

// --- STANDARD HELPERS ---

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

fn spawn_window_event_listener(tx: mpsc::Sender<Event>) {
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
                tx.send(Event::WindowsOpened(check_windows())).ok();
            }
        }
    });
}

fn check_windows() -> bool {
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
            if !path.is_dir() { return None; }
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
}

#[derive(Debug, Clone, Copy, Deserialize, ValueEnum)]
enum Side {
    Top,
    Left,
    Right,
    Bottom,
}

impl Default for Side {
    fn default() -> Self { Side::Top }
}


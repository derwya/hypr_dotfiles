-- Hyprland config (Lua), Tokyo Night.
-- Wiki: https://wiki.hypr.land/Configuring/Start/
-- Check after editing:  Hyprland --verify-config

local mainMod = "SUPER"
-- Quickshell popups (network / bluetooth / audio / calendar), see ~/.config/quickshell/widgets
local widget = "qs -c widgets ipc call widgets toggle "
local scripts = "~/.config/hypr/scripts/"


-----------------------
---- MACHINE (HOST) ----
-----------------------

-- Per-machine settings (monitors, GPU env, laptop extras) live in
-- hosts/<hostname>.lua; machines without a profile use hosts/default.lua
-- (laptop, integrated graphics). Test another profile: HYPR_HOST=name Hyprland --verify-config
local function hostname()
    local f = io.open("/etc/hostname")
    local name = f and f:read("l")
    if f then f:close() end
    return name or "default"
end

local HOSTNAME = os.getenv("HYPR_HOST") or hostname()
local ok, HOST = pcall(require, "hosts." .. HOSTNAME)
if not ok then
    HOST = require("hosts.default")
end


------------------
---- MONITORS ----
------------------

-- The one place monitors are defined (the host profile). Workspaces listed
-- there open on that monitor; bars.sh reads the same mapping back from
-- Hyprland, so the waybar workspace buttons follow it too.
local MONITORS = HOST.monitors

local workspaceMonitor = {}
for _, m in ipairs(MONITORS) do
    hl.monitor({ output = m.output, mode = m.mode, position = m.position, scale = m.scale })
    for i, ws in ipairs(m.workspaces) do
        workspaceMonitor[ws] = m.output
        hl.workspace_rule({ workspace = tostring(ws), monitor = m.output, default = (i == 1) or nil })
    end
end

-- Anything else that gets plugged in (projector, TV, ...): sensible defaults.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- Monitor hotplug: relaunch bars for the new layout, give new screens a wallpaper.
for _, event in ipairs({ "monitor.added", "monitor.removed" }) do
    hl.on(event, function()
        hl.exec_cmd(scripts .. "bars.sh")
        hl.exec_cmd(scripts .. "random-wallpaper.sh --restore")
    end)
end


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd(scripts .. "random-wallpaper.sh")   -- starts swaybg, random wallpaper per monitor
    hl.exec_cmd(scripts .. "bars.sh")               -- waybar on every monitor
    hl.exec_cmd("swaync")
    hl.exec_cmd("qs -c widgets -n -d")
    hl.exec_cmd("hypridle")                         -- lock / screen off when idle
    hl.exec_cmd("pypr")
    hl.exec_cmd('gsettings set org.gnome.desktop.interface gtk-theme "Tokyonight-Dark"')
    hl.exec_cmd('gsettings set org.gnome.desktop.interface icon-theme "Tokyonight-Dark"')
    hl.exec_cmd('gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"')

    -- Always start on the main monitor's first workspace (1), not wherever the
    -- cursor happened to be.
    local main = MONITORS[1]
    if main and hl.get_monitor(main.output) then
        hl.dispatch(hl.dsp.focus({ monitor = main.output }))
    end
    hl.dispatch(hl.dsp.focus({ workspace = main and main.workspaces[1] or 1 }))
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- Machine-specific (e.g. NVIDIA on the desktop), from the host profile
for name, value in pairs(HOST.env or {}) do
    hl.env(name, value)
end

hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("GDK_SCALE", "1")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    input = {
        kb_layout          = "us,ua",
        kb_options         = "grp:alt_shift_toggle",
        numlock_by_default = true,
        follow_mouse       = 1,
        sensitivity        = -0.5,
        touchpad = {
            natural_scroll = true,
            scroll_factor  = 0.4,
        },
    },

    general = {
        gaps_in     = 5,
        gaps_out    = 10,
        border_size = 2,
        col = {
            -- Tokyo Night blue → purple → cyan, slowly rotating (borderangle animation below)
            active_border   = { colors = { "rgba(7aa2f7ff)", "rgba(bb9af7ff)", "rgba(7dcfffff)" }, angle = 45 },
            inactive_border = "rgba(3b426199)",
        },
        resize_on_border = true,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 10,
        rounding_power = 2,
        dim_special    = 0.3,   -- darken the desktop behind scratchpads (Spotify)

        shadow = {
            enabled        = true,
            range          = 18,
            render_power   = 3,
            color          = "rgba(0b0c1499)",
            color_inactive = "rgba(0b0c1455)",
        },

        blur = {
            enabled           = true,
            size              = 6,
            passes            = 3,
            vibrancy          = 0.18,
            new_optimizations = true,
            popups            = true,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    binds = {
        workspace_back_and_forth = true,   -- pressing the current workspace key goes back
    },

    cursor = {
        hide_on_key_press = true,
    },

    -- X11 apps render at native resolution instead of being upscaled (blurry) to
    -- the 5/3 scale. Apps scale themselves: Gazebo/RViz via QT_SCALE_FACTOR in
    -- ~/.bashrc (distrobox), Spotify runs native Wayland (~/.config/spotify-flags.conf).
    xwayland = {
        force_zero_scaling = true,
    },

    misc = {
        force_default_wallpaper  = 0,
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        background_color         = "rgb(1a1b26)",
        animate_manual_resizes   = true,
        focus_on_activate        = true,
    },
})

-- Laptops: swipe three fingers left/right on the touchpad to switch workspaces.
if HOST.laptop then
    hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
end

-- Curves
hl.curve("smooth",  { type = "bezier", points = { { 0.25, 1 },   { 0.5, 1 }  } })
hl.curve("overshot",{ type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve("ease",    { type = "bezier", points = { { 0.4, 0 },    { 0.2, 1 }  } })
hl.curve("linear",  { type = "bezier", points = { { 0, 0 },      { 1, 1 }    } })
hl.curve("snappy",  { type = "spring", mass = 1, stiffness = 260, dampening = 24 })

hl.animation({ leaf = "global",        enabled = true, speed = 8,   bezier = "default" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.5, spring = "snappy" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4,   spring = "snappy",  style = "popin 85%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 2.5, bezier = "ease",    style = "popin 85%" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = 4,   spring = "snappy" })
hl.animation({ leaf = "border",        enabled = true, speed = 6,   bezier = "smooth" })
hl.animation({ leaf = "borderangle",   enabled = true, speed = 90,  bezier = "linear",  style = "loop" })
hl.animation({ leaf = "fade",          enabled = true, speed = 4,   bezier = "smooth" })
hl.animation({ leaf = "fadeDim",       enabled = true, speed = 4,   bezier = "smooth" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 3,   bezier = "smooth",  style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 2,   bezier = "ease",    style = "fade" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 4,   bezier = "overshot", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "overshot", style = "slidevert" })


---------------------
---- LAYER RULES ----
---------------------

-- Frosted glass behind the bars, menus, notifications and popups.
for _, ns in ipairs({ "waybar", "rofi", "swaync-control-center", "swaync-notification-window", "qs-widgets" }) do
    hl.layer_rule({
        name         = "blur-" .. ns,
        match        = { namespace = "^(" .. ns .. ")$" },
        blur         = true,
        ignore_alpha = 0.3,
    })
end


----------------------
---- WINDOW RULES ----
----------------------

hl.window_rule({
    name  = "rofi-left",
    match = { class = "^(rofi-left)$" },
    float = true,
    pin   = true,
})

hl.window_rule({
    name   = "tui-popup",
    match  = { class = "^(tui-popup)$" },
    float  = true,
    size   = "65% 65%",
    center = true,
})

-- Settings / utility apps: floating, centered, sensible size.
hl.window_rule({
    name   = "float-utilities",
    match  = { class = "^(org.pulseaudio.pavucontrol|nm-connection-editor|nwg-displays|nwg-look|qt6ct|qt5ct|blueman-manager|org.kde.kdeconnect.app)$" },
    float  = true,
    size   = "55% 60%",
    center = true,
})

-- File pickers and other dialogs.
hl.window_rule({
    name   = "float-dialogs",
    match  = { title = "^(Open File|Open Files|Open Folder|Save As|Save File|Select a File|Choose Files?|File Upload|Library|Confirm.*)(.*)$" },
    float  = true,
    size   = "60% 65%",
    center = true,
})

hl.window_rule({
    name   = "float-polkit",
    match  = { class = "^(polkit-gnome-authentication-agent-1)$" },
    float  = true,
    center = true,
    pin    = true,
})

-- Browser picture-in-picture: small, pinned, bottom-right.
hl.window_rule({
    name              = "pip",
    match             = { title = "^(Picture-in-Picture|Picture in picture)$" },
    float             = true,
    pin               = true,
    keep_aspect_ratio = true,
    size              = "25% 25%",
    move              = "100%-w-20 100%-w-20",
})

-- Don't lock / blank the screen while something is fullscreen (videos, games).
hl.window_rule({
    name         = "idle-inhibit-fullscreen",
    match        = { class = ".*" },
    idle_inhibit = "fullscreen",
})

-- Apps may not maximize themselves; tiling decides.
hl.window_rule({
    name           = "suppress-maximize",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

-- XWayland drag-and-drop ghost windows must not steal focus.
hl.window_rule({
    name     = "fix-xwayland-drags",
    match    = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})


---------------------
---- KEYBINDINGS ----
---------------------

local function bind(keys, dispatcher, opts)
    hl.bind(mainMod .. (keys ~= "" and " + " .. keys or ""), dispatcher, opts)
end

local function exec(cmd)
    return hl.dsp.exec_cmd(cmd)
end

-- Launchers
bind("SPACE", exec("rofi -show drun"))
bind("R",     exec("rofi -show run"))
bind("F",     exec("rofi -show filebrowser"))
bind("V",     exec("~/.config/rofi/clipboard.sh"))
bind("U",     exec("~/.config/rofi/web-search.sh"))
bind("W",     exec("rofi -show window"))
bind("S",     exec("pypr toggle spotify"))
bind("I",     exec("nwg-displays"))
bind("N",     exec("swaync-client -t -sw"))           -- notification center

-- Popups (same as clicking the bar icons)
bind("SHIFT + W", exec(widget .. "network"))
bind("SHIFT + A", exec(widget .. "audio"))
bind("SHIFT + B", exec(widget .. "bluetooth"))
bind("SHIFT + C", exec(widget .. "calendar"))

bind("ESCAPE", exec("kitty --class tui-popup -e btop"))
bind("E",      exec("kitty --class tui-popup -e yazi"))
bind("Q",      exec("kitty"))

bind("CTRL + W",  exec(scripts .. "random-wallpaper.sh"))
bind("SHIFT + M", exec("~/.local/bin/rofi-power-menu"))
bind("SHIFT + L", exec("hyprlock"))
bind("SHIFT + R", exec(scripts .. "wf-recorder-toggle.sh"))
bind("ALT + B",   exec(scripts .. "toggle-bars.sh"))   -- bars: auto-hide / shown / hidden

-- Screenshots (saved to ~/Pictures/Screenshots and copied)
hl.bind("Print",               exec(scripts .. "screenshot.sh region"))
hl.bind("SHIFT + Print",       exec(scripts .. "screenshot.sh screen"))
hl.bind(mainMod .. " + Print", exec(scripts .. "screenshot.sh window"))

-- Windows
bind("C",         hl.dsp.window.close())
bind("SHIFT + V", hl.dsp.window.float({ action = "toggle" }))
bind("SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
bind("M",         hl.dsp.window.fullscreen({ mode = "maximized" }))
bind("P",         hl.dsp.window.pseudo())
bind("SHIFT + N", hl.dsp.layout("togglesplit"))

-- Focus with vim keys
bind("h", hl.dsp.focus({ direction = "left" }))
bind("l", hl.dsp.focus({ direction = "right" }))
bind("k", hl.dsp.focus({ direction = "up" }))
bind("j", hl.dsp.focus({ direction = "down" }))

-- Resize (hold to repeat) and move with arrows
local resizeSteps = { right = { 10, 0 }, left = { -10, 0 }, up = { 0, -10 }, down = { 0, 10 } }
for key, d in pairs(resizeSteps) do
    bind(key, hl.dsp.window.resize({ x = d[1], y = d[2], relative = true }), { repeating = true })
    bind("SHIFT + " .. key, hl.dsp.window.move({ direction = key }))
end

-- Workspaces: SUPER+1..0 jumps to the workspace on its own monitor; SHIFT moves the
-- window there. If that monitor is unplugged, the workspace simply opens where you are.
local function focusHome(ws)
    local mon = workspaceMonitor[ws]
    if mon and hl.get_monitor(mon) then
        hl.dispatch(hl.dsp.focus({ monitor = mon }))
    end
end

for ws = 1, 10 do
    local key = tostring(ws % 10) -- 10 maps to key 0
    bind(key, function()
        focusHome(ws)
        hl.dispatch(hl.dsp.focus({ workspace = ws }))
    end)
    bind("SHIFT + " .. key, function()
        hl.dispatch(hl.dsp.window.move({ workspace = ws }))
        focusHome(ws)
    end)
end

bind("TAB",        hl.dsp.focus({ workspace = "previous" }))
bind("mouse_down", hl.dsp.focus({ workspace = "e+1" }))
bind("mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Mouse: drag to move, hold Alt to resize
bind("mouse:272", hl.dsp.window.drag(),   { mouse = true })
bind("ALT_L",     hl.dsp.window.resize(), { mouse = true })

-- Media keys (work on the lock screen; volume repeats when held)
local mediaOpts = { locked = true, repeating = true }
hl.bind("XF86AudioRaiseVolume",  exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 1.0"), mediaOpts)
hl.bind("XF86AudioLowerVolume",  exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- --limit 1.0"), mediaOpts)
hl.bind("XF86AudioMute",         exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),   { locked = true })
hl.bind("XF86AudioMicMute",      exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86AudioPlay",         exec("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause",        exec("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",         exec("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",         exec("playerctl previous"),   { locked = true })
hl.bind("XF86MonBrightnessUp",   exec("brightnessctl s 10%+"), mediaOpts)
hl.bind("XF86MonBrightnessDown", exec("brightnessctl s 10%-"), mediaOpts)

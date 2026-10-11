pragma Singleton

import QtQuick
import Quickshell

// Tokyo Night palette and sizes shared by all widgets (matches waybar/rofi).
Singleton {
    readonly property color bg: "#eb1a1b26"   // ~92% opaque; Hyprland blurs behind it
    readonly property color surface: "#24283b"
    readonly property color surfaceHover: "#292e42"
    readonly property color border: "#7aa2f7"
    readonly property color divider: "#3b4261"
    readonly property color fg: "#c0caf5"
    readonly property color fgDim: "#737aa2"
    readonly property color fgMuted: "#565f89"
    readonly property color accent: "#7aa2f7"
    readonly property color accentAlt: "#bb9af7"
    readonly property color accentText: "#15161e"
    readonly property color green: "#9ece6a"
    readonly property color red: "#f7768e"
    readonly property color yellow: "#e0af68"
    readonly property color cyan: "#7dcfff"

    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 13
    readonly property int smallSize: 11
    readonly property int iconSize: 17

    // Placement under the bar: top-right, 12px / 20px (same spot as the old rofi popups).
    readonly property int marginTop: 20
    readonly property int marginRight: 12
    // Bottom bars (secondary monitor): open just above the 50px bar.
    readonly property int marginBottom: 60
    readonly property int width: 360
    readonly property int padding: 14
    readonly property int radius: 12
    readonly property int listMaxHeight: 320
}

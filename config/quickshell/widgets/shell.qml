// Popup widgets for network, bluetooth and audio (replaces the rofi menus).
//
// Run:     qs -c widgets -n -d
// Toggle:  qs -c widgets ipc call widgets toggle network|bluetooth|audio|calendar
//          qs -c widgets ipc call widgets toggleBottom <name>   (from a bottom bar)
// Close:   qs -c widgets ipc call widgets close
//
// One popup at a time, on the focused monitor, under the bar: top-right for
// network/bluetooth/audio, centered (under the clock) for the calendar,
// (same spot as the old rofi popups). From a bottom bar (toggleBottom) popups
// open bottom-right, just above the bar. Click outside or Esc closes it.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Networking

ShellRoot {
    id: root

    property string active: ""        // "network" | "bluetooth" | "audio" | "calendar" | ""
    property string screenName: ""
    property string edge: "top"       // "top" | "bottom": which bar opened it

    // The click that dismisses a popup via the focus grab can be the same click on
    // the bar icon that then asks to toggle it again; ignore that echo.
    property string grabClosed: ""
    property double grabClosedAt: 0

    // Keep the D-Bus backed services loaded so popups open with data ready
    // (Bluetooth/Networking only start once something references them).
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property int netDevices: Networking.devices.values.length

    function open(name, fromEdge) {
        if (!["network", "bluetooth", "audio", "calendar"].includes(name)) return;
        screenName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        edge = fromEdge === "bottom" ? "bottom" : "top";
        active = name;
    }

    function close() {
        active = "";
    }

    function toggle(name, fromEdge) {
        if (active === name) return close();
        if (grabClosed === name && Date.now() - grabClosedAt < 400) return;
        open(name, fromEdge);
    }

    function screenFor(name) {
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++)
            if (screens[i].name === name) return screens[i];
        return screens.length ? screens[0] : null;
    }

    IpcHandler {
        target: "widgets"
        function toggle(name: string): void { root.toggle(name, "top"); }
        function toggleBottom(name: string): void { root.toggle(name, "bottom"); }
        function open(name: string): void { root.open(name, "top"); }
        function close(): void { root.close(); }
    }

    LazyLoader {
        active: root.active !== ""

        PanelWindow {
            id: panel

            screen: root.screenFor(root.screenName)
            // Top bar: top-right, except the calendar which is centered under the clock
            // (only top-anchored = horizontally centered). Bottom bar: bottom-right.
            readonly property bool atBottom: root.edge === "bottom"
            readonly property bool centered: !atBottom && root.active === "calendar"
            anchors.top: !atBottom
            anchors.bottom: atBottom
            anchors.right: !centered
            margins.top: atBottom ? 0 : Theme.marginTop
            margins.bottom: atBottom ? Theme.marginBottom : 0
            margins.right: centered ? 0 : Theme.marginRight
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            implicitWidth: Theme.width
            implicitHeight: frame.height

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-widgets"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            HyprlandFocusGrab {
                active: true
                windows: [panel]
                onCleared: {
                    root.grabClosed = root.active;
                    root.grabClosedAt = Date.now();
                    root.close();
                }
            }

            Rectangle {
                id: frame
                width: parent.width
                height: content.implicitHeight + Theme.padding * 2
                radius: Theme.radius
                color: Theme.bg
                border.width: 2
                border.color: Theme.border

                focus: true
                Keys.onEscapePressed: root.close()

                Loader {
                    id: content
                    x: Theme.padding
                    y: Theme.padding
                    width: parent.width - Theme.padding * 2
                    sourceComponent: root.active === "network" ? networkPanel
                                   : root.active === "bluetooth" ? bluetoothPanel
                                   : root.active === "audio" ? audioPanel
                                   : root.active === "calendar" ? calendarPanel : null
                }
            }
        }
    }

    Component {
        id: networkPanel
        NetworkPanel { onCloseRequested: root.close() }
    }
    Component {
        id: bluetoothPanel
        BluetoothPanel { onCloseRequested: root.close() }
    }
    Component {
        id: audioPanel
        AudioPanel { onCloseRequested: root.close() }
    }
    Component {
        id: calendarPanel
        CalendarPanel { onCloseRequested: root.close() }
    }
}

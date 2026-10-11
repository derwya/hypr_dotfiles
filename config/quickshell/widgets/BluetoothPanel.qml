import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

// Bluetooth popup: power toggle, scan, device list with battery, connect/pair/forget.
ColumnLayout {
    id: root

    signal closeRequested

    spacing: 10

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter !== null && adapter.enabled
    property string error: ""

    // Known devices always; discovered ones only if they have a real name.
    readonly property var devices: {
        if (!adapter) return [];
        return adapter.devices.values
            .filter(d => d.paired || d.trusted || d.connected || (d.name && d.name !== d.address.replace(/:/g, "-")))
            .sort((a, b) => (b.connected - a.connected) || ((b.paired || b.trusted) - (a.paired || a.trusted))
                            || a.name.localeCompare(b.name));
    }
    readonly property var known: devices.filter(d => d.paired || d.trusted || d.connected)
    readonly property var discovered: devices.filter(d => !(d.paired || d.trusted || d.connected))

    // Stop scanning when the popup closes.
    Component.onDestruction: if (adapter && adapter.discovering) adapter.discovering = false

    function deviceIcon(d) {
        const i = d.icon || "";
        if (i.includes("headset") || i.includes("headphone")) return "󰋋";
        if (i.includes("audio") || i.includes("speaker")) return "󰓃";
        if (i.includes("mouse")) return "󰍽";
        if (i.includes("keyboard")) return "󰌌";
        if (i.includes("phone")) return "󰏲";
        if (i.includes("gaming") || i.includes("joystick")) return "󰊴";
        if (i.includes("computer")) return "󰟀";
        return "󰂯";
    }

    function stateText(d) {
        switch (d.state) {
        case BluetoothDeviceState.Connecting: return "Connecting…";
        case BluetoothDeviceState.Disconnecting: return "Disconnecting…";
        }
        if (d.pairing) return "Pairing…";
        if (d.connected) return "Connected";
        return d.paired ? "Paired" : d.trusted ? "Trusted" : "";
    }

    function activate(d) {
        root.error = "";
        if (d.connected) {
            d.disconnect();
        } else if (d.paired || d.bonded) {
            d.connect();
        } else {
            // New (or trusted-but-unpaired) device: pair, trust, then connect once paired.
            d.trusted = true;
            d.pair();
        }
    }

    PanelHeader {
        Layout.fillWidth: true
        icon: !root.powered ? "󰂲" : root.known.some(d => d.connected) ? "󰂱" : "󰂯"
        title: "Bluetooth"
        status: !root.adapter ? "No adapter"
              : !root.powered ? "Off"
              : (() => {
                    const c = root.known.filter(d => d.connected);
                    return c.length ? c.map(d => d.name).join(", ") : (root.adapter.discovering ? "Scanning…" : "On");
                })()

        IconButton {
            visible: root.powered
            icon: "󰑐"
            tooltip: "Scan"
            active: root.adapter && root.adapter.discovering
            onClicked: root.adapter.discovering = !root.adapter.discovering

            RotationAnimation on rotation {
                running: root.adapter !== null && root.adapter.discovering
                from: 0; to: 360; duration: 1200; loops: Animation.Infinite
                onStopped: parent.rotation = 0
            }
        }
        Toggle {
            visible: root.adapter !== null
            checked: root.powered
            busy: root.adapter !== null && (root.adapter.state === BluetoothAdapterState.Enabling
                                            || root.adapter.state === BluetoothAdapterState.Disabling)
            onToggled: root.adapter.enabled = !root.adapter.enabled
        }
    }

    Text {
        visible: !root.powered
        Layout.fillWidth: true
        Layout.leftMargin: 10
        text: !root.adapter ? "No Bluetooth adapter found"
            : root.adapter.state === BluetoothAdapterState.Blocked ? "Bluetooth is blocked (rfkill)" : "Bluetooth is off"
        color: Theme.fgMuted
        font.family: Theme.font
        font.pixelSize: Theme.smallSize
    }

    ScrollList {
        visible: root.powered

        SectionLabel {
            visible: root.known.length > 0
            text: "Devices"
        }

        Repeater {
            model: root.known
            delegate: ListRow {
                required property var modelData
                Layout.fillWidth: true
                icon: root.deviceIcon(modelData)
                title: modelData.name
                subtitle: modelData.batteryAvailable ? `󰁹 ${Math.round(modelData.battery * 100)}%` : ""
                active: modelData.connected
                trailing: root.stateText(modelData)
                trailingColor: modelData.connected ? Theme.green : Theme.fgDim
                busy: modelData.pairing || modelData.state === BluetoothDeviceState.Connecting
                      || modelData.state === BluetoothDeviceState.Disconnecting
                actionIcon: "󰆴"
                actionTooltip: "Forget"
                onClicked: root.activate(modelData)
                onActionClicked: modelData.forget()

                // Finish "pair → connect" for devices paired from this popup.
                Connections {
                    target: modelData
                    function onPairedChanged() { if (modelData.paired && !modelData.connected) modelData.connect(); }
                }
            }
        }

        SectionLabel {
            visible: root.adapter !== null && (root.adapter.discovering || root.discovered.length > 0)
            text: "Available"
        }

        Text {
            visible: root.adapter !== null && root.adapter.discovering && root.discovered.length === 0
            Layout.leftMargin: 10
            text: "Looking for devices…"
            color: Theme.fgMuted
            font.family: Theme.font
            font.pixelSize: Theme.smallSize
        }

        Repeater {
            model: root.discovered
            delegate: ListRow {
                required property var modelData
                Layout.fillWidth: true
                icon: root.deviceIcon(modelData)
                title: modelData.name
                trailing: modelData.pairing ? "Pairing…" : "Pair"
                trailingColor: Theme.accent
                busy: modelData.pairing
                onClicked: root.activate(modelData)

                Connections {
                    target: modelData
                    function onPairedChanged() { if (modelData.paired && !modelData.connected) modelData.connect(); }
                }
            }
        }
    }

    Text {
        visible: root.error !== ""
        Layout.fillWidth: true
        text: "󰀦 " + root.error
        color: Theme.red
        wrapMode: Text.Wrap
        font.family: Theme.font
        font.pixelSize: Theme.smallSize
    }
}

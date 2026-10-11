import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking

// Network popup: wired status, Wi-Fi toggle, network list with password entry.
ColumnLayout {
    id: root

    signal closeRequested

    spacing: 10

    readonly property var devices: Networking.devices.values
    readonly property var wifiDev: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevs: devices.filter(d => d.type === DeviceType.Wired)

    property string pendingPsk: ""   // name of the network whose password field is open
    property string error: ""

    // Scan only while the popup is open.
    onWifiDevChanged: if (wifiDev) wifiDev.scannerEnabled = true
    Component.onCompleted: if (wifiDev) wifiDev.scannerEnabled = true
    Component.onDestruction: if (wifiDev) wifiDev.scannerEnabled = false

    readonly property var networks: {
        if (!wifiDev) return [];
        return wifiDev.networks.values.slice().sort((a, b) =>
            (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength));
    }

    function strength(n) {
        const s = n.signalStrength > 1 ? n.signalStrength / 100 : n.signalStrength;
        return s > 0.75 ? "󰤨" : s > 0.5 ? "󰤥" : s > 0.25 ? "󰤢" : "󰤟";
    }

    function secure(n) {
        return n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe;
    }

    function activate(n) {
        root.error = "";
        if (n.connected) {
            n.disconnect();
        } else if (n.known || !secure(n)) {
            n.connect();
        } else {
            root.pendingPsk = root.pendingPsk === n.name ? "" : n.name;
        }
    }

    function connectivityText() {
        switch (Networking.connectivity) {
        case NetworkConnectivity.Full: return "Online";
        case NetworkConnectivity.Limited: return "Limited connectivity";
        case NetworkConnectivity.Portal: return "Sign-in required";
        case NetworkConnectivity.None: return "Offline";
        default: return "";
        }
    }

    PanelHeader {
        Layout.fillWidth: true
        icon: wiredDevs.some(d => d.connected) ? "󰈀" : (wifiDev && wifiDev.connected ? "󰖩" : "󰖪")
        title: "Network"
        status: {
            const wired = wiredDevs.find(d => d.connected);
            const wifi = networks.find(n => n.connected);
            const name = wired ? "Ethernet" : wifi ? wifi.name : "Disconnected";
            const c = root.connectivityText();
            return c && (wired || wifi) ? `${name} · ${c}` : name;
        }
    }

    // ── Wired ─────────────────────────────────────────────
    SectionLabel {
        visible: wiredDevs.length > 0
        text: "Ethernet"
    }

    Repeater {
        model: root.wiredDevs
        delegate: ListRow {
            required property var modelData
            Layout.fillWidth: true
            icon: modelData.hasLink ? "󰈀" : "󰈂"
            title: modelData.name
            subtitle: !modelData.hasLink ? "Cable unplugged"
                     : modelData.connected ? `${modelData.linkSpeed} Mb/s · ${modelData.address}` : "Not connected"
            active: modelData.connected
            trailing: modelData.connected ? "Connected" : ""
            trailingColor: Theme.green
            busy: modelData.state === ConnectionState.Connecting || modelData.state === ConnectionState.Disconnecting
            onClicked: {
                if (modelData.connected) modelData.disconnect();
                else if (modelData.network) modelData.network.connect();
            }
        }
    }

    // ── Wi-Fi ─────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 8

        SectionLabel {
            text: "Wi-Fi"
            Layout.topMargin: 0
        }
        Toggle {
            visible: root.wifiDev !== null && Networking.wifiHardwareEnabled
            checked: Networking.wifiEnabled
            onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
        }
    }

    Text {
        visible: !root.wifiDev || !Networking.wifiEnabled || root.networks.length === 0
        Layout.fillWidth: true
        Layout.leftMargin: 10
        text: !root.wifiDev ? "No Wi-Fi adapter"
            : !Networking.wifiHardwareEnabled ? "Wi-Fi is blocked by a hardware switch"
            : !Networking.wifiEnabled ? "Wi-Fi is off"
            : "Searching for networks…"
        color: Theme.fgMuted
        font.family: Theme.font
        font.pixelSize: Theme.smallSize
    }

    ScrollList {
        visible: root.wifiDev !== null && Networking.wifiEnabled && root.networks.length > 0

        Repeater {
            model: root.networks
            delegate: ColumnLayout {
                id: entry
                required property var modelData
                Layout.fillWidth: true
                spacing: 4

                Connections {
                    target: entry.modelData
                    function onConnectionFailed(reason) {
                        root.error = `${entry.modelData.name}: ${ConnectionFailReason.toString(reason)}`;
                        if (reason === ConnectionFailReason.NoSecrets) root.pendingPsk = entry.modelData.name;
                    }
                    function onConnectedChanged() {
                        if (entry.modelData.connected && root.pendingPsk === entry.modelData.name) root.pendingPsk = "";
                    }
                }

                ListRow {
                    Layout.fillWidth: true
                    icon: root.strength(entry.modelData)
                    title: entry.modelData.name
                    subtitle: (root.secure(entry.modelData) ? "󰌾 " : "") + (entry.modelData.known ? "Saved" : (root.secure(entry.modelData) ? "Secured" : "Open"))
                    active: entry.modelData.connected
                    trailing: entry.modelData.connected ? "Connected" : ""
                    trailingColor: Theme.green
                    busy: entry.modelData.stateChanging
                    actionIcon: entry.modelData.known ? "󰆴" : ""
                    actionTooltip: "Forget"
                    onClicked: root.activate(entry.modelData)
                    onActionClicked: entry.modelData.forget()
                }

                Rectangle {
                    visible: root.pendingPsk === entry.modelData.name
                    Layout.fillWidth: true
                    Layout.leftMargin: 40
                    implicitHeight: 34
                    radius: 8
                    color: Theme.surface
                    border.width: 1
                    border.color: psk.activeFocus ? Theme.accent : Theme.divider

                    onVisibleChanged: if (visible) psk.forceActiveFocus()

                    TextInput {
                        id: psk
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        clip: true
                        onAccepted: {
                            root.error = "";
                            entry.modelData.connectWithPsk(text);
                            text = "";
                        }
                        Keys.onEscapePressed: root.pendingPsk = ""

                        Text {
                            visible: psk.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Password, then Enter"
                            color: Theme.fgMuted
                            font: psk.font
                        }
                    }
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

    FooterButton {
        icon: "󰒓"
        text: "Network settings"
        onClicked: {
            Quickshell.execDetached(["nm-connection-editor"]);
            root.closeRequested();
        }
    }
}

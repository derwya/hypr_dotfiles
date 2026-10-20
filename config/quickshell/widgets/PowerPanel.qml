import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Battery popup: charge/time/power from UPower, TLP on/off and Lenovo battery
// conservation mode (charging stops at ~60%). Conservation is written with
// `sudo -n tee` (NOPASSWD rule for that sysfs file); TLP via systemctl (polkit).
ColumnLayout {
    id: root

    signal closeRequested

    spacing: 10

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery !== null && battery.ready && battery.isPresent
    // Quickshell reports 0..1; older versions used 0..100.
    readonly property int percent: !hasBattery ? 0
        : Math.round(battery.percentage <= 1 ? battery.percentage * 100 : battery.percentage)

    readonly property string consGlob: "/sys/bus/platform/drivers/ideapad_acpi/*/conservation_mode"
    property string conservation: ""   // "1" | "0" | "" (not available)
    property bool tlpActive: false
    property bool busy: false
    property string error: ""

    function batteryIcon() {
        if (!hasBattery) return "󰂑";
        if (battery.state === UPowerDeviceState.Charging) return "󰂄";
        const icons = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
        return icons[Math.min(10, Math.floor(percent / 10))];
    }

    function duration(seconds) {
        const m = Math.round(seconds / 60);
        return m >= 60 ? `${Math.floor(m / 60)} h ${m % 60} min` : `${m} min`;
    }

    function statusText() {
        if (!hasBattery) return "No battery";
        switch (battery.state) {
        case UPowerDeviceState.Charging:
            return `${percent}% · Charging` + (battery.timeToFull > 0 ? ` · ${duration(battery.timeToFull)} to full` : "");
        case UPowerDeviceState.Discharging:
            return `${percent}%` + (battery.timeToEmpty > 0 ? ` · ${duration(battery.timeToEmpty)} left` : "");
        case UPowerDeviceState.FullyCharged:
            return `${percent}% · Full`;
        case UPowerDeviceState.PendingCharge:
            return `${percent}% · Plugged in, not charging`;
        }
        return `${percent}%`;
    }

    function refresh() {
        poll.running = true;
    }

    function run(cmd) {
        root.error = "";
        root.busy = true;
        action.command = cmd;
        action.running = true;
    }

    Component.onCompleted: refresh()

    // Line 1: conservation_mode (or "na"), line 2: tlp.service state.
    Process {
        id: poll
        command: ["sh", "-c", `f=$(ls ${root.consGlob} 2>/dev/null | head -n1); `
                              + `[ -n "$f" ] && cat "$f" || echo na; systemctl is-active tlp.service`]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                root.conservation = lines[0] === "na" ? "" : lines[0];
                root.tlpActive = lines[1] === "active";
                root.busy = false;
            }
        }
    }

    Process {
        id: action
        stderr: StdioCollector { id: actionErr }
        onExited: (code) => {
            if (code !== 0) root.error = actionErr.text.trim() || `Command failed (${code})`;
            root.refresh();
        }
    }

    // Icon, title/subtitle and a switch; clicking anywhere on the row flips it.
    component SwitchRow: Rectangle {
        id: row
        property string icon: ""
        property string title: ""
        property string subtitle: ""
        property bool checked: false
        signal toggled

        Layout.fillWidth: true
        implicitHeight: Math.max(44, rowContent.implicitHeight + 14)
        radius: 8
        color: hover.hovered ? Theme.surfaceHover : "transparent"

        HoverHandler { id: hover }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            enabled: !root.busy
            onClicked: row.toggled()
        }

        RowLayout {
            id: rowContent
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            spacing: 10

            Text {
                text: row.icon
                color: row.checked ? Theme.accent : Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.iconSize
                Layout.preferredWidth: 20
                horizontalAlignment: Text.AlignHCenter
            }
            ColumnLayout {
                spacing: 1
                Layout.fillWidth: true
                Text {
                    text: row.title
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Text {
                    visible: text !== ""
                    text: row.subtitle
                    color: Theme.fgDim
                    font.family: Theme.font
                    font.pixelSize: Theme.smallSize
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }
            Toggle {
                checked: row.checked
                busy: root.busy
                onToggled: if (!root.busy) row.toggled()
            }
        }
    }

    PanelHeader {
        Layout.fillWidth: true
        icon: root.batteryIcon()
        title: "Battery"
        status: root.statusText()
    }

    // Charge bar
    Rectangle {
        visible: root.hasBattery
        Layout.fillWidth: true
        implicitHeight: 6
        radius: 3
        color: Theme.divider
        Rectangle {
            width: parent.width * root.percent / 100
            height: parent.height
            radius: parent.radius
            color: root.percent <= 12 ? Theme.red : root.percent <= 25 ? Theme.yellow : Theme.green
            Behavior on width { NumberAnimation { duration: 200 } }
        }
    }

    Text {
        visible: root.hasBattery
        Layout.fillWidth: true
        Layout.leftMargin: 2
        text: [battery && battery.changeRate > 0 ? `${battery.changeRate.toFixed(1)} W` : "",
               battery && battery.healthSupported ? `Health ${Math.round(battery.healthPercentage)}%` : ""]
              .filter(s => s !== "").join("  ·  ")
        color: Theme.fgMuted
        font.family: Theme.font
        font.pixelSize: Theme.smallSize
    }

    SectionLabel { text: "Power management" }

    SwitchRow {
        visible: root.conservation !== ""
        icon: "󱐋"
        title: "Conservation mode"
        subtitle: root.conservation === "1" ? "Charging stops at 60%" : "Charges to 100%"
        checked: root.conservation === "1"
        onToggled: root.run(["sh", "-c",
            `f=$(ls ${root.consGlob} | head -n1) && echo ${root.conservation === "1" ? 0 : 1} | sudo -n tee "$f" >/dev/null`])
    }

    SwitchRow {
        icon: "󰌪"
        title: "TLP"
        subtitle: root.tlpActive ? "Power saving active" : "Off"
        checked: root.tlpActive
        onToggled: root.run(["systemctl", root.tlpActive ? "stop" : "start", "tlp.service"])
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
        icon: "󰑓"
        text: "TLP status"
        onClicked: {
            Quickshell.execDetached(["kitty", "--class", "tui-popup", "-e", "sh", "-c",
                "tlp-stat -s 2>/dev/null || echo 'TLP not available'; printf '\\nPress Enter to close'; read _"]);
            root.closeRequested();
        }
    }
}

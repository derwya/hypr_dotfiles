import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

// Audio popup: output/input volume + mute, device pickers, per-app volume.
ColumnLayout {
    id: root

    signal closeRequested

    spacing: 10

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var nodes: Pipewire.nodes.values
    readonly property var sinks: nodes.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var sources: nodes.filter(n => n.audio && !n.isSink && !n.isStream)
    readonly property var apps: nodes.filter(n => n.audio && n.type === PwNodeType.AudioOutStream)

    property bool showOutputs: false
    property bool showInputs: false

    // Volume/mute of a node are only live while it is tracked.
    PwObjectTracker {
        objects: [root.sink, root.source].concat(root.apps).filter(n => n)
    }

    function label(n) {
        return n ? (n.nickname || n.description || n.name) : "None";
    }

    function appName(n) {
        return n.properties["application.name"] || n.description || n.name;
    }

    // MPRIS player behind an app stream, if it has its own volume. Players like
    // Spotify re-apply their internal volume to the stream on every track change,
    // so changing the stream volume alone would be undone at the next song.
    function playerFor(n) {
        const name = String(appName(n)).toLowerCase();
        return Mpris.players.values.find(p => p.volumeSupported && (
            p.identity.toLowerCase() === name
            || (p.desktopEntry || "").toLowerCase() === name
            || p.dbusName.toLowerCase().endsWith("." + name))) ?? null;
    }

    function volIcon(n, input) {
        if (!n || !n.audio) return input ? "󰍭" : "󰖁";
        if (input) return n.audio.muted ? "󰍭" : "󰍬";
        const v = n.audio.volume;
        return n.audio.muted ? "󰖁" : v > 0.66 ? "󰕾" : v > 0.33 ? "󰖀" : "󰕿";
    }

    // One device block: [mute button] slider percentage [▾ device picker]
    component DeviceControl: ColumnLayout {
        id: dc
        property var node
        property bool input: false
        property var choices: []
        property bool expanded: false
        signal toggleExpanded

        Layout.fillWidth: true
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            IconButton {
                icon: root.volIcon(dc.node, dc.input)
                iconColor: dc.node && dc.node.audio && dc.node.audio.muted ? Theme.red : Theme.accent
                tooltip: "Mute"
                onClicked: if (dc.node && dc.node.audio) dc.node.audio.muted = !dc.node.audio.muted
            }
            VolumeSlider {
                Layout.fillWidth: true
                value: dc.node && dc.node.audio ? dc.node.audio.volume : 0
                muted: dc.node && dc.node.audio ? dc.node.audio.muted : true
                onMoved: v => {
                    if (!dc.node || !dc.node.audio) return;
                    dc.node.audio.volume = v;
                    if (dc.node.audio.muted && v > 0) dc.node.audio.muted = false;
                }
            }
            Text {
                text: dc.node && dc.node.audio ? `${Math.round(dc.node.audio.volume * 100)}%` : "—"
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.smallSize
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 36
            }
        }

        // Current device; click to pick another.
        ListRow {
            Layout.fillWidth: true
            icon: dc.input ? "󰍬" : "󰓃"
            title: root.label(dc.node)
            subtitle: dc.choices.length > 1 ? `${dc.choices.length} devices` : ""
            trailing: dc.choices.length > 1 ? (dc.expanded ? "󰅃" : "󰅀") : ""
            onClicked: if (dc.choices.length > 1) dc.toggleExpanded()
        }

        Repeater {
            model: dc.expanded ? dc.choices.filter(n => n !== dc.node) : []
            delegate: ListRow {
                required property var modelData
                Layout.fillWidth: true
                Layout.leftMargin: 24
                icon: "󰐊"
                title: root.label(modelData)
                subtitle: modelData.description !== root.label(modelData) ? modelData.description : ""
                onClicked: {
                    if (dc.input) Pipewire.preferredDefaultAudioSource = modelData;
                    else Pipewire.preferredDefaultAudioSink = modelData;
                    dc.toggleExpanded();
                }
            }
        }
    }

    PanelHeader {
        Layout.fillWidth: true
        icon: root.volIcon(root.sink, false)
        title: "Audio"
        status: root.sink && root.sink.audio
                ? `${root.label(root.sink)} · ${root.sink.audio.muted ? "Muted" : Math.round(root.sink.audio.volume * 100) + "%"}`
                : ""
    }

    ScrollList {
        maxHeight: 460

        SectionLabel { text: "Output" }
        DeviceControl {
            node: root.sink
            choices: root.sinks
            expanded: root.showOutputs
            onToggleExpanded: root.showOutputs = !root.showOutputs
        }

        SectionLabel { text: "Input" }
        DeviceControl {
            node: root.source
            input: true
            choices: root.sources
            expanded: root.showInputs
            onToggleExpanded: root.showInputs = !root.showInputs
        }

        SectionLabel {
            visible: root.apps.length > 0
            text: "Apps"
        }

        Repeater {
            model: root.apps
            delegate: RowLayout {
                id: app
                required property var modelData
                readonly property var player: root.playerFor(modelData)
                readonly property real level: player ? player.volume : (modelData.audio ? modelData.audio.volume : 0)
                Layout.fillWidth: true
                Layout.leftMargin: 4
                spacing: 8

                IconButton {
                    icon: modelData.audio && modelData.audio.muted ? "󰝟" : "󰝚"
                    iconColor: modelData.audio && modelData.audio.muted ? Theme.red : Theme.cyan
                    onClicked: if (modelData.audio) modelData.audio.muted = !modelData.audio.muted
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: root.appName(app.modelData)
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.smallSize
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    VolumeSlider {
                        Layout.fillWidth: true
                        value: app.level
                        muted: app.modelData.audio ? app.modelData.audio.muted : true
                        onMoved: v => {
                            if (app.player) app.player.volume = v;
                            else if (app.modelData.audio) app.modelData.audio.volume = v;
                        }
                    }
                }
                Text {
                    text: `${Math.round(app.level * 100)}%`
                    color: Theme.fgDim
                    font.family: Theme.font
                    font.pixelSize: Theme.smallSize
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 36
                }
            }
        }
    }

    FooterButton {
        icon: "󰒓"
        text: "Advanced (pavucontrol)"
        onClicked: {
            Quickshell.execDetached(["pavucontrol"]);
            root.closeRequested();
        }
    }
}

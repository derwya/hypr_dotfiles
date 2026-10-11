import QtQuick

// Horizontal 0..1 slider: drag, click or scroll (5% steps). Emits moved(value).
Item {
    id: root

    property real value: 0
    property bool muted: false
    signal moved(real value)

    implicitHeight: 20
    implicitWidth: 200

    function setFrom(x) {
        root.moved(Math.max(0, Math.min(1, x / width)));
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Theme.divider

        Rectangle {
            width: Math.max(height, track.width * Math.min(1, root.value))
            height: parent.height
            radius: 3
            color: root.muted ? Theme.fgMuted : Theme.accent
        }
    }

    Rectangle {
        width: 14
        height: 14
        radius: 7
        anchors.verticalCenter: parent.verticalCenter
        x: (root.width - width) * Math.min(1, root.value)
        color: root.muted ? Theme.fgDim : Theme.fg
        border.width: 2
        border.color: root.muted ? Theme.fgMuted : Theme.accent
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.setFrom(mouse.x)
        onPositionChanged: mouse => { if (pressed) root.setFrom(mouse.x); }
        onWheel: wheel => {
            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
            root.moved(Math.max(0, Math.min(1, Math.round((root.value + step) * 20) / 20)));
        }
    }
}

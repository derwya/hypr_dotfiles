import QtQuick

// On/off switch. Emits toggled(); the owner flips the real state.
Rectangle {
    id: root

    property bool checked: false
    property bool busy: false
    signal toggled

    implicitWidth: 40
    implicitHeight: 22
    radius: height / 2
    color: checked ? Theme.accent : Theme.divider
    opacity: busy ? 0.6 : 1

    Behavior on color { ColorAnimation { duration: 150 } }

    Rectangle {
        width: parent.height - 6
        height: width
        radius: width / 2
        y: 3
        x: root.checked ? parent.width - width - 3 : 3
        color: root.checked ? Theme.accentText : Theme.fg
        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}

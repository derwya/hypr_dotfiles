import QtQuick

// Small round icon button.
Rectangle {
    id: root

    property string icon: ""
    property string tooltip: ""
    property bool active: false
    property color iconColor: active ? Theme.accent : Theme.fgDim
    signal clicked

    implicitWidth: 28
    implicitHeight: 28
    radius: 14
    color: hover.hovered ? Theme.surfaceHover : "transparent"

    HoverHandler { id: hover }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: hover.hovered ? Theme.fg : root.iconColor
        font.family: Theme.font
        font.pixelSize: Theme.iconSize - 1
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

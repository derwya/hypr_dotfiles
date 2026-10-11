import QtQuick
import QtQuick.Layouts

// Full-width secondary action at the bottom of a panel (e.g. open settings app).
Rectangle {
    id: root

    property string icon: ""
    property string text: ""
    signal clicked

    Layout.fillWidth: true
    Layout.topMargin: 2
    implicitHeight: 34
    radius: 8
    color: hover.hovered ? Theme.surfaceHover : Theme.surface

    HoverHandler { id: hover }

    Row {
        anchors.centerIn: parent
        spacing: 8
        Text {
            text: root.icon
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.iconSize - 2
        }
        Text {
            text: root.text
            color: hover.hovered ? Theme.fg : Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

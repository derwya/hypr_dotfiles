import QtQuick
import QtQuick.Layouts

// Clickable list entry: icon, title, optional subtitle, optional trailing text/button.
Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string trailing: ""
    property color trailingColor: Theme.fgDim
    property bool active: false
    property bool busy: false
    property string actionIcon: ""     // small button on the right, e.g. forget
    property string actionTooltip: ""

    signal clicked
    signal actionClicked

    implicitHeight: Math.max(40, content.implicitHeight + 14)
    radius: 8
    color: active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                  : (hover.hovered ? Theme.surfaceHover : "transparent")

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    RowLayout {
        id: content
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 8
        spacing: 10

        Text {
            text: root.icon
            color: root.active ? Theme.accent : Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.iconSize
            Layout.preferredWidth: 20
            horizontalAlignment: Text.AlignHCenter
        }

        ColumnLayout {
            spacing: 1
            Layout.fillWidth: true

            Text {
                text: root.title
                color: root.active ? Theme.accent : Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: root.active
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                visible: text !== ""
                text: root.subtitle
                color: Theme.fgDim
                font.family: Theme.font
                font.pixelSize: Theme.smallSize
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Text {
            visible: text !== ""
            text: root.busy ? "…" : root.trailing
            color: root.trailingColor
            font.family: Theme.font
            font.pixelSize: Theme.smallSize
        }

        IconButton {
            visible: root.actionIcon !== ""
            icon: root.actionIcon
            tooltip: root.actionTooltip
            onClicked: root.actionClicked()
        }
    }
}

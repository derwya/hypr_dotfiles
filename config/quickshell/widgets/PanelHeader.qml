import QtQuick
import QtQuick.Layouts

// Panel title row: icon, title, status line, and slot for controls on the right.
RowLayout {
    id: root

    property string icon: ""
    property string title: ""
    property string status: ""
    default property alias controls: controlsRow.data

    spacing: 10

    Text {
        text: root.icon
        color: Theme.accent
        font.family: Theme.font
        font.pixelSize: 22
    }

    ColumnLayout {
        spacing: 0
        Layout.fillWidth: true

        Text {
            text: root.title
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize + 2
            font.bold: true
        }
        Text {
            visible: text !== ""
            text: root.status
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.smallSize
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    RowLayout {
        id: controlsRow
        spacing: 6
    }
}

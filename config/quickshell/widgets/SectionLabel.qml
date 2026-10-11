import QtQuick
import QtQuick.Layouts

// Small uppercase section caption with a divider line.
RowLayout {
    property string text: ""

    spacing: 8
    Layout.fillWidth: true
    Layout.topMargin: 4

    Text {
        text: parent.text.toUpperCase()
        color: Theme.fgMuted
        font.family: Theme.font
        font.pixelSize: Theme.smallSize - 1
        font.bold: true
        font.letterSpacing: 1
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.divider
    }
}

import QtQuick
import QtQuick.Layouts

// Vertical list that grows with its content up to Theme.listMaxHeight, then scrolls.
Flickable {
    id: root

    default property alias content: column.data
    property int maxHeight: Theme.listMaxHeight

    Layout.fillWidth: true
    implicitHeight: Math.min(column.implicitHeight, maxHeight)
    contentHeight: column.implicitHeight
    contentWidth: width
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: column.implicitHeight > maxHeight

    ColumnLayout {
        id: column
        width: root.width
        spacing: 2
    }
}

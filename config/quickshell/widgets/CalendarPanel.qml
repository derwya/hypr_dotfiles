import QtQuick
import QtQuick.Layouts

// Calendar popup: live clock, month grid (Mon-first, ISO week numbers),
// month navigation by arrows or scroll, "Today" to jump back.
ColumnLayout {
    id: root

    signal closeRequested

    spacing: 12

    property date now: new Date()
    property int viewYear: now.getFullYear()
    property int viewMonth: now.getMonth()   // 0-11
    readonly property bool onCurrentMonth: viewYear === now.getFullYear() && viewMonth === now.getMonth()
    readonly property var locale: Qt.locale("en_GB")

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    function shiftMonth(delta) {
        const d = new Date(viewYear, viewMonth + delta, 1);
        viewYear = d.getFullYear();
        viewMonth = d.getMonth();
    }

    function goToday() {
        viewYear = now.getFullYear();
        viewMonth = now.getMonth();
    }

    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const day = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - day);
        const yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - yearStart) / 86400000 + 1) / 7);
    }

    // 6 weeks x 7 days starting on the Monday on/before the 1st of the month.
    readonly property var weeks: {
        const first = new Date(viewYear, viewMonth, 1);
        const offset = (first.getDay() + 6) % 7;
        const start = new Date(viewYear, viewMonth, 1 - offset);
        const rows = [];
        for (let w = 0; w < 6; w++) {
            const days = [];
            for (let i = 0; i < 7; i++) {
                const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + w * 7 + i);
                days.push({
                    day: d.getDate(),
                    inMonth: d.getMonth() === viewMonth,
                    weekend: i >= 5,
                    today: d.toDateString() === now.toDateString()
                });
            }
            rows.push({ week: isoWeek(new Date(start.getFullYear(), start.getMonth(), start.getDate() + w * 7)), days: days });
        }
        return rows;
    }

    // ── Header: time and full date ────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
            text: Qt.formatTime(root.now, "HH:mm")
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: 38
            font.bold: true
        }
        Text {
            text: root.locale.toString(root.now, "dddd, d MMMM yyyy") + ` · week ${root.isoWeek(root.now)}`
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.divider
    }

    // ── Month navigation ──────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
            text: root.locale.standaloneMonthName(root.viewMonth, Locale.LongFormat) + " " + root.viewYear
            color: Theme.accent
            font.family: Theme.font
            font.pixelSize: Theme.fontSize + 1
            font.bold: true
            Layout.fillWidth: true
            Layout.leftMargin: 4
        }

        Rectangle {
            visible: !root.onCurrentMonth
            implicitWidth: todayLabel.implicitWidth + 16
            implicitHeight: 24
            radius: 12
            color: todayHover.hovered ? Theme.surfaceHover : Theme.surface
            HoverHandler { id: todayHover }
            Text {
                id: todayLabel
                anchors.centerIn: parent
                text: "Today"
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.smallSize
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.goToday()
            }
        }

        IconButton { icon: "󰅁"; onClicked: root.shiftMonth(-1) }
        IconButton { icon: "󰅂"; onClicked: root.shiftMonth(1) }
    }

    // ── Month grid ────────────────────────────────────────
    GridLayout {
        id: grid
        Layout.fillWidth: true
        columns: 8
        rowSpacing: 2
        columnSpacing: 2

        // Sized from the panel width (not the grid's own width, which would be circular).
        readonly property real cell: Math.floor((root.width - columnSpacing * 7) / 8)

        Repeater {
            model: ["Wk", "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            delegate: Text {
                required property string modelData
                required property int index
                Layout.preferredWidth: grid.cell
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: index === 0 ? Theme.fgMuted : index >= 6 ? Theme.accentAlt : Theme.fgDim
                font.family: Theme.font
                font.pixelSize: Theme.smallSize
                font.bold: true
            }
        }

        Repeater {
            model: root.weeks.length * 8
            delegate: Item {
                required property int index
                readonly property var week: root.weeks[Math.floor(index / 8)]
                readonly property int col: index % 8
                readonly property var info: col > 0 ? week.days[col - 1] : null

                Layout.preferredWidth: grid.cell
                Layout.preferredHeight: 34

                Rectangle {
                    visible: info !== null && info.today
                    anchors.centerIn: parent
                    width: 30
                    height: 30
                    radius: 15
                    color: Theme.accent
                }

                Text {
                    anchors.centerIn: parent
                    text: col === 0 ? week.week : info.day
                    color: col === 0 ? Theme.fgMuted
                         : info.today ? Theme.accentText
                         : !info.inMonth ? Theme.fgMuted
                         : info.weekend ? Theme.accentAlt : Theme.fg
                    opacity: col > 0 && !info.inMonth ? 0.55 : 1
                    font.family: Theme.font
                    font.pixelSize: col === 0 ? Theme.smallSize - 1 : Theme.fontSize
                    font.bold: info !== null && info.today
                }
            }
        }
    }

    // Scroll anywhere over the panel to change month.
    WheelHandler {
        onWheel: event => root.shiftMonth(event.angleDelta.y > 0 ? -1 : 1)
    }
}

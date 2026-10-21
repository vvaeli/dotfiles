import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    property bool compact: false
    // Inside the control centre the clock lives in the header.
    property bool showClock: true
    property int month: Desktop.now.getMonth()
    property int year: Desktop.now.getFullYear()
    readonly property date first: new Date(year, month, 1)
    readonly property int offset: (first.getDay() + 6) % 7
    spacing: 14
    RowLayout {
        visible: root.showClock
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true
            Label { text: Qt.formatDateTime(Desktop.now, "HH:mm"); font.pixelSize: root.compact ? 42 : 48; font.weight: Font.Normal; color: Theme.primary }
            Label { text: Desktop.now.toLocaleDateString(Qt.locale("ru_RU"), "dddd, d MMMM"); color: Theme.muted }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Chip { icon: "left"; flat: !root.showClock; implicitWidth: 36; onClicked: root.changeMonth(-1) }
        Label {
            text: { const name = Qt.locale("ru_RU").standaloneMonthName(root.month, Locale.LongFormat); return name.charAt(0).toUpperCase() + name.slice(1) + " " + root.year; }
            horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true; font.weight: Font.DemiBold
            // Clicking the month returns to today.
            TapHandler { onTapped: { root.month = Desktop.now.getMonth(); root.year = Desktop.now.getFullYear(); } }
        }
        Chip { icon: "right"; flat: !root.showClock; implicitWidth: 36; onClicked: root.changeMonth(1) }
    }
    GridLayout {
        id: daysGrid
        columns: 7
        uniformCellWidths: true
        columnSpacing: 4; rowSpacing: 4
        Layout.fillWidth: true
        Repeater {
            model: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
            Label {
                required property string modelData
                text: modelData; color: Theme.muted; font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true; Layout.preferredHeight: 24
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
            }
        }
        Repeater {
            model: 42
            Item {
                required property int index
                readonly property date day: new Date(root.year, root.month, index - root.offset + 1)
                readonly property bool today: day.toDateString() === Desktop.now.toDateString()
                Layout.fillWidth: true; Layout.preferredHeight: root.showClock ? 36 : 32
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.height, parent.width); height: width; radius: width / 2
                    color: parent.today ? Theme.primary : Theme.textSurface
                    opacity: parent.today ? 1 : dayHover.hovered ? 0.08 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.duration } }
                }
                HoverHandler { id: dayHover }
                Label {
                    anchors.centerIn: parent; text: parent.day.getDate()
                    color: parent.today ? Theme.textPrimary : parent.day.getMonth() === root.month ? Theme.textSurface : Theme.outline
                    font.pixelSize: 13
                }
            }
        }
    }
    function changeMonth(delta) {
        const date = new Date(year, month + delta, 1);
        year = date.getFullYear(); month = date.getMonth();
    }
}

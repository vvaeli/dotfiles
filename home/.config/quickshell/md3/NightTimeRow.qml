import QtQuick
import QtQuick.Layouts

// Schedule time with half-hour steps, for the night light page.
RowLayout {
    id: row
    property string title
    property string icon
    property int minutes
    property bool interactive: true
    signal change(int step)
    Layout.fillWidth: true
    spacing: 8
    Icon { name: row.icon; tint: Theme.muted; implicitWidth: 18; implicitHeight: 18 }
    Label { text: row.title; Layout.fillWidth: true; font.pixelSize: 13 }
    Chip { icon: "minus"; implicitWidth: 32; implicitHeight: 32; enabled: row.interactive; onClicked: row.change(-30) }
    Label {
        text: Desktop.formatMinutes(row.minutes)
        Layout.preferredWidth: 52; horizontalAlignment: Text.AlignHCenter
        font.pixelSize: 16; font.weight: Font.DemiBold; font.features: {"tnum": 1}
    }
    Chip { icon: "plus"; implicitWidth: 32; implicitHeight: 32; enabled: row.interactive; onClicked: row.change(30) }
}

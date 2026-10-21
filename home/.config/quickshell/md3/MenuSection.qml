import QtQuick
import QtQuick.Layouts

// Small caption above a group, with optional controls on the right.
RowLayout {
    id: root
    property string text: ""
    default property alias trailing: tail.data
    Layout.fillWidth: true
    Layout.topMargin: 2
    spacing: 6
    Label { text: root.text; color: Theme.muted; font.pixelSize: 12; font.weight: Font.Medium; Layout.leftMargin: 6; Layout.fillWidth: true; elide: Text.ElideRight }
    RowLayout { id: tail; spacing: 6 }
}

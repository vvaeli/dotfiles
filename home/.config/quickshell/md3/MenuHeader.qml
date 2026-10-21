import QtQuick
import QtQuick.Layouts

// Page header shared by the menus: tonal icon tile, title with a status line, trailing controls.
RowLayout {
    id: root
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property color subtitleColor: Theme.muted
    property bool active: true
    default property alias trailing: tail.data
    Layout.fillWidth: true
    spacing: 12
    Rectangle {
        visible: root.icon !== ""
        implicitWidth: 40; implicitHeight: 40; radius: 14
        color: root.active ? Theme.primaryContainer : Theme.buttonSurface
        Behavior on color { ColorAnimation { duration: Theme.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.effectsCurve } }
        Icon {
            anchors.centerIn: parent
            name: root.icon
            tint: root.active ? Theme.textPrimaryContainer : Theme.muted
            implicitWidth: 22; implicitHeight: 22
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 1
        Label { text: root.title; font.pixelSize: 18; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
        Label { visible: text !== ""; text: root.subtitle; color: root.subtitleColor; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
    }
    RowLayout { id: tail; spacing: 6 }
}

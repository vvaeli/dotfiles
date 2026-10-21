import QtQuick
import QtQuick.Layouts

// MD3 split quick tile: the icon toggles the feature, the rest opens its page
// (or toggles too when there is no page). Tonal fill while the feature is on.
Rectangle {
    id: root
    property string icon: ""
    property string title: ""
    property string detail: ""
    property bool active: false
    property bool busy: false
    property bool hasPage: false
    signal toggled()
    signal opened()
    implicitHeight: 68
    radius: active ? 22 : 34
    color: active ? Theme.primaryContainer : Theme.cardSurface
    Behavior on color { ColorAnimation { duration: Theme.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.effectsCurve } }
    Behavior on radius { NumberAnimation { duration: Theme.fastSpatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.fastSpatialCurve } }
    readonly property color foreground: active ? Theme.textPrimaryContainer : Theme.textSurface
    Accessible.role: Accessible.Button
    Accessible.name: title
    Rectangle {
        anchors.fill: parent; radius: parent.radius
        color: root.foreground
        opacity: bodyTap.pressed ? 0.12 : bodyHover.hovered ? 0.06 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.duration } }
    }
    Rectangle {
        id: toggle
        x: 10; anchors.verticalCenter: parent.verticalCenter
        width: 42; height: 42
        radius: root.active ? 14 : 22
        color: root.active ? Theme.primary : Theme.buttonSurface
        scale: toggleTap.pressed ? 0.9 : 1
        Behavior on radius { NumberAnimation { duration: Theme.fastSpatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.fastSpatialCurve } }
        Behavior on color { ColorAnimation { duration: Theme.duration } }
        Behavior on scale { NumberAnimation { duration: Theme.fastSpatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.fastSpatialCurve } }
        Rectangle {
            anchors.fill: parent; radius: parent.radius
            color: root.active ? Theme.textPrimary : Theme.textSurface
            opacity: toggleTap.pressed ? 0.16 : toggleHover.hovered ? 0.1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.duration } }
        }
        Icon {
            anchors.centerIn: parent
            name: root.icon
            tint: root.active ? Theme.textPrimary : Theme.textSurface
            implicitWidth: 20; implicitHeight: 20
            opacity: root.busy ? 0.5 : 1
        }
        HoverHandler { id: toggleHover; enabled: !root.busy; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: toggleTap; enabled: !root.busy; onTapped: Qt.callLater(() => root.toggled()) }
    }
    Item {
        anchors.left: toggle.right; anchors.right: parent.right
        anchors.top: parent.top; anchors.bottom: parent.bottom
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 9; anchors.rightMargin: 10
            spacing: 2
            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                Label { text: root.title; color: root.foreground; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                Label { text: root.detail; color: root.foreground; opacity: 0.72; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
            }
            Icon { visible: root.hasPage; name: "right"; tint: root.foreground; opacity: 0.6; implicitWidth: 14; implicitHeight: 14 }
        }
        HoverHandler { id: bodyHover; enabled: !root.busy || root.hasPage; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            id: bodyTap
            enabled: !root.busy || root.hasPage
            onTapped: Qt.callLater(() => { if (root.hasPage) root.opened(); else root.toggled(); })
        }
    }
}

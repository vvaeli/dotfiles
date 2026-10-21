import QtQuick
import QtQuick.Layouts

// List entry: leading icon in a tonal circle, title and status, trailing indicators.
// The whole row is the click target, with hover and press state layers.
Item {
    id: root
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property color subtitleColor: Theme.muted
    property bool selected: false
    property bool interactive: true
    property bool danger: false
    default property alias trailing: tail.data
    signal clicked()
    Layout.fillWidth: true
    implicitHeight: subtitle !== "" ? 56 : 48
    Accessible.role: Accessible.Button
    Accessible.name: title
    readonly property color accent: danger ? Theme.error : Theme.primary
    Rectangle {
        anchors.fill: parent
        radius: 16
        color: root.selected ? Theme.secondaryContainer : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.effectsCurve } }
    }
    Rectangle {
        anchors.fill: parent
        radius: 16
        color: Theme.textSurface
        opacity: !root.interactive ? 0 : tap.pressed ? 0.12 : hover.hovered || root.activeFocus ? 0.06 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.effectsCurve } }
    }
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 12
        spacing: 12
        opacity: root.enabled ? 1 : 0.45
        scale: tap.pressed ? 0.98 : 1
        Behavior on scale { NumberAnimation { duration: Theme.fastSpatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.fastSpatialCurve } }
        Rectangle {
            visible: root.icon !== ""
            implicitWidth: 36; implicitHeight: 36; radius: 18
            color: root.selected || root.danger ? root.accent : Theme.buttonSurface
            Behavior on color { ColorAnimation { duration: Theme.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.effectsCurve } }
            Icon {
                anchors.centerIn: parent
                name: root.icon
                tint: root.selected || root.danger ? (root.danger ? Theme.surface : Theme.textPrimary) : Theme.textSurface
                implicitWidth: 18; implicitHeight: 18
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Label { text: root.title; font.pixelSize: 13; font.weight: Font.Medium; elide: Text.ElideRight; Layout.fillWidth: true }
            Label { visible: text !== ""; text: root.subtitle; color: root.subtitleColor; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
        }
        RowLayout { id: tail; spacing: 6 }
    }
    HoverHandler { id: hover; enabled: root.interactive; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; enabled: root.interactive; onTapped: Qt.callLater(() => root.clicked()) }
    activeFocusOnTab: interactive
    Keys.onReturnPressed: if (interactive) clicked()
    Keys.onSpacePressed: if (interactive) clicked()
}

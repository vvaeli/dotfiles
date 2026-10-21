import QtQuick

// MD3 switch. With interactive: false it only shows the state of a clickable row around it.
Item {
    id: root
    property bool checked: false
    property bool interactive: true
    signal toggled()
    implicitWidth: 52; implicitHeight: 32
    opacity: enabled ? 1 : 0.4
    Accessible.role: Accessible.CheckBox
    Accessible.checked: checked
    readonly property real thumbSize: tap.pressed ? 28 : checked ? 24 : 16
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.primary : Theme.buttonSurface
        border.width: root.checked ? 0 : 2
        border.color: Theme.muted
        Behavior on color { ColorAnimation { duration: Theme.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.effectsCurve } }
    }
    Rectangle {
        // Hover halo around the thumb.
        width: 40; height: 40; radius: 20
        x: thumb.x + thumb.width / 2 - 20; y: (root.height - 40) / 2
        color: root.checked ? Theme.primary : Theme.textSurface
        opacity: !root.interactive ? 0 : tap.pressed ? 0.14 : hover.hovered ? 0.08 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.duration } }
    }
    Rectangle {
        id: thumb
        width: root.thumbSize; height: width; radius: width / 2
        x: (root.checked ? root.width - 16 : 16) - width / 2
        y: (root.height - height) / 2
        color: root.checked ? Theme.textPrimary : Theme.muted
        Behavior on x { NumberAnimation { duration: Theme.fastSpatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.fastSpatialCurve } }
        Behavior on width { NumberAnimation { duration: Theme.fastSpatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.fastSpatialCurve } }
        Behavior on color { ColorAnimation { duration: Theme.duration } }
        Icon {
            anchors.centerIn: parent
            name: "check"; tint: Theme.primary
            implicitWidth: 14; implicitHeight: 14
            opacity: root.checked ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.duration } }
        }
    }
    HoverHandler { id: hover; enabled: root.interactive; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; enabled: root.interactive; onTapped: Qt.callLater(() => root.toggled()) }
}

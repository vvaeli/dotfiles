import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property string icon: ""
    property int iconSize: 18
    property string text: ""
    property int textSize: 12
    property string tooltip: ""
    property int maximumTextWidth: 10000
    property bool selected: false
    property bool filled: false
    property bool flat: false
    Accessible.role: Accessible.Button
    Accessible.name: tooltip || text || icon
    property color foreground: selected ? Theme.textPrimary : Theme.textSurface
    signal clicked(var mouse)
    signal scrolled(real delta)
    readonly property real naturalWidth: content.implicitWidth + 24
    implicitWidth: naturalWidth
    implicitHeight: 36
    radius: height / 2
    color: selected ? Theme.primary : filled ? Theme.buttonFilled : flat ? "transparent" : Theme.buttonSurface
    opacity: enabled ? 1 : 0.4
    scale: tap.pressed ? 0.96 : 1
    Behavior on scale { NumberAnimation { duration: Theme.fastSpatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.fastSpatialCurve } }
    Behavior on foreground { ColorAnimation { duration: Theme.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.effectsCurve } }
    Behavior on color { ColorAnimation { duration: Theme.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.effectsCurve } }
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: root.foreground
        opacity: tap.pressed ? 0.16 : hover.hovered || root.activeFocus ? 0.08 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.effectsCurve } }
    }
    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 7
        Icon { visible: root.icon !== ""; name: root.icon; tint: root.foreground; implicitWidth: root.iconSize; implicitHeight: root.iconSize }
        Text { visible: root.text !== ""; text: root.text; color: root.foreground; font.family: Theme.font; font.pixelSize: root.textSize; font.weight: Font.Medium; Layout.maximumWidth: root.maximumTextWidth; elide: Text.ElideRight }
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler {
        id: tap
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        // Let Qt finish the release before mapping or unmapping a menu surface.
        onTapped: (point, button) => Qt.callLater(() => root.clicked({button: button}))
    }
    WheelHandler {
        onWheel: wheel => { root.scrolled(wheel.angleDelta.y); wheel.accepted = true; }
    }
    activeFocusOnTab: true
    Keys.onReturnPressed: root.clicked({button: Qt.LeftButton})
    Keys.onSpacePressed: root.clicked({button: Qt.LeftButton})
}

import QtQuick
import QtQuick.Controls

Slider {
    id: control
    from: 0
    to: 1
    implicitHeight: 36
    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.availableWidth
        height: 12
        radius: 6
        color: Theme.secondaryContainer
        Rectangle {
            width: control.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: Theme.primary
        }
    }
    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: 5
        height: control.pressed ? 32 : 28
        Behavior on height { NumberAnimation { duration: Theme.fastSpatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.fastSpatialCurve } }
        radius: 2
        color: Theme.primary
        border.width: 0
        border.color: Theme.surface
    }
}

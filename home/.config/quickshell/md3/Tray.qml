import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

// Tray icons styled like the bar's other buttons: state layer on hover and press,
// a springy press, a filled state while the item's menu is open, animated arrival.
Row {
    id: root
    required property var panelWindow
    spacing: 2
    Repeater {
        model: SystemTray.items
        delegate: Item {
            id: trayItem
            required property var modelData
            readonly property bool open: root.panelWindow.menuOpen && root.panelWindow.page === "tray" && root.panelWindow.trayItem === modelData
            Accessible.role: Accessible.Button
            Accessible.name: modelData.title || modelData.id
            width: 36; height: 36
            // New icons grow in; the Row slides its neighbours along with the width.
            property real arrival: 0
            Component.onCompleted: arrival = 1
            Behavior on arrival { NumberAnimation { duration: Theme.spatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.spatialCurve } }
            opacity: Math.min(1, arrival)
            Rectangle {
                id: body
                anchors.fill: parent
                radius: height / 2
                color: trayItem.open ? Theme.primaryContainer : "transparent"
                scale: (tap.pressed ? 0.9 : 1) * trayItem.arrival
                Behavior on color { ColorAnimation { duration: Theme.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.effectsCurve } }
                Behavior on scale { NumberAnimation { duration: Theme.fastSpatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.fastSpatialCurve } }
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: trayItem.open ? Theme.textPrimaryContainer : Theme.textSurface
                    opacity: tap.pressed ? 0.16 : hover.hovered ? 0.08 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.effectsCurve } }
                }
                Image {
                    anchors.centerIn: parent
                    width: 20; height: 20
                    source: trayItem.modelData.icon
                    sourceSize.width: 40
                    sourceSize.height: 40
                    fillMode: Image.PreserveAspectFit
                    scale: hover.hovered && !tap.pressed ? 1.12 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.fastSpatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.fastSpatialCurve } }
                }
                // Apps asking for attention get a small dot, like an unread badge.
                Rectangle {
                    visible: trayItem.modelData.status === Status.NeedsAttention
                    width: 7; height: 7; radius: 4
                    color: Theme.error
                    anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 6
                }
            }
            HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                id: tap
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onTapped: (point, button) => Qt.callLater(() => {
                    if (button === Qt.MiddleButton) trayItem.modelData.secondaryActivate();
                    else if (trayItem.modelData.hasMenu) root.panelWindow.openTrayMenu(trayItem.modelData, trayItem);
                    else trayItem.modelData.activate();
                })
            }
            WheelHandler { onWheel: wheel => { trayItem.modelData.scroll(wheel.angleDelta.y, false); wheel.accepted = true; } }
        }
    }
}

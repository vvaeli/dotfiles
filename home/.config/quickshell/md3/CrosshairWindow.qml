import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    visible: Desktop.crosshairVisible && modelData.name === "DP-1"
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "md3-crosshair"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}
    Item {
    width: 28; height: 28
    anchors.centerIn: parent
    Repeater {
        model: [
            {x: 2, y: 12, w: 8, h: 4},
            {x: 18, y: 12, w: 8, h: 4},
            {x: 12, y: 2, w: 4, h: 8},
            {x: 12, y: 18, w: 4, h: 8}
        ]
        Rectangle {
            required property var modelData
            x: modelData.x; y: modelData.y
            width: modelData.w; height: modelData.h
            radius: 1
            color: Theme.primary
            border.width: 1
            border.color: "#b0000000"
        }
    }
    }
}

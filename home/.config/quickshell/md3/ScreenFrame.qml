import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root
    required property var modelData
    PanelWindow {
        screen: root.modelData
        visible: Desktop.barVisible
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "md3-frame"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        mask: Region {}
        FrameSurface { anchors.fill: parent }
    }
}

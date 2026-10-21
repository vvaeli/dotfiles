import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    anchors.bottom: true
    margins.bottom: 92
    implicitWidth: 320
    implicitHeight: 90
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "md3-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}
    visible: surface.progress > 0 || surface.expanded
    OsdSurface {
        id: surface
        anchors.fill: parent
        expanded: Desktop.osdVisible && Desktop.osdMonitor === root.modelData.name
        kind: Desktop.osdKind
        level: Desktop.osdLevel
        muted: Desktop.osdMuted
    }
}

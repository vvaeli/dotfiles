import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property bool opened: Desktop.launcherVisible && Desktop.launcherMonitor === modelData.name
    anchors { top: true; bottom: true; left: true; right: true }
    visible: opened || progress > 0
    property real progress: opened ? 1 : 0
    Behavior on progress { NumberAnimation { duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
    color: 'transparent'
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: 'md3-menu'
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { x: pane.x; y: pane.y; width: pane.width; height: pane.height }
    Reveal {
        id: pane
        width: Math.min(648, root.width - 64)
        x: (root.width - width) / 2
        y: (root.height - 88) / 2 + (1 - root.progress) * 10
        height: menu.implicitHeight + 32
        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        expanded: true; progress: 1; detached: true
        opacity: root.progress
        enabled: root.opened
        LauncherMenu {
            id: menu
            x: 16; y: 16; width: parent.width - 32
            maximumListHeight: Math.min(420, Math.max(80, root.modelData.height / 2 - 120))
            opened: root.opened
            onCloseRequested: Desktop.launcherVisible = false
        }
    }
    HyprlandFocusGrab { windows: [root]; active: root.opened && root.visible; onCleared: Desktop.launcherVisible = false }
}

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property var monitor: Hyprland.monitorFor(modelData)
    readonly property bool fullscreen: Desktop.dockFullscreen(Hyprland.toplevels.values, monitor)
    readonly property bool detached: fullscreen || !Desktop.barVisible
    readonly property bool opened: Desktop.clipboardVisible && Desktop.clipboardMonitor === modelData.name
    anchors { top: true; left: true; right: true }
    margins.top: detached ? 0 : Theme.barHeight
    implicitHeight: pane.y + pane.height + Theme.menuShadow
    visible: opened || pane.progress > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "md3-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region {
        x: root.detached ? pane.x : pane.x - Theme.menuJoinRadius
        y: pane.y
        width: pane.width + (root.detached ? 0 : Theme.menuJoinRadius * 2)
        height: pane.revealedHeight
    }
    Reveal {
        id: pane
        detached: root.detached
        y: root.detached ? Theme.menuShadow + 12 : 0
        width: Math.min(560, root.width - Theme.frameWidth * 2)
        height: Math.min(menu.implicitHeight + 40, root.modelData.height - root.margins.top - y - Theme.menuShadow - 20)
        x: (root.width - width) / 2
        expanded: root.opened
        ClipboardMenu {
            id: menu
            x: 20; y: 20; width: parent.width - 40
            opened: root.opened
            onCloseRequested: Desktop.clipboardVisible = false
        }
    }
    HyprlandFocusGrab {
        windows: [root]
        active: root.opened && root.visible
        onCleared: Desktop.clipboardVisible = false
    }
}

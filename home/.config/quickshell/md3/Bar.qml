import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: panel
    required property var modelData
    screen: modelData
    visible: Desktop.barVisible
    onVisibleChanged: { if (!visible) menuOpen = false; }
    readonly property var monitor: Hyprland.monitorFor(screen)
    property string page: "settings"
    property bool menuOpen: false
    property var trayItem: null
    property real menuCenterX: width - 212
    readonly property bool compact: width < 1100
    readonly property string windowTitle: {
        const workspace = monitor?.activeWorkspace;
        const windows = workspace?.toplevels.values ?? [];
        return windows.find(w => w.activated)?.title ?? windows[0]?.title ?? "Рабочий стол";
    }
    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    exclusiveZone: Theme.barHeight + Theme.windowGap
    color: "transparent"
    WlrLayershell.namespace: "md3-bar"

    function togglePage(name, source) {
        if (menuOpen && page === name) menuOpen = false;
        else {
            menuPane.beginMorph();
            if (source) menuCenterX = source.mapToItem(panel.contentItem, source.width / 2, 0).x;
            else menuCenterX = name === "calendar" ? width / 2 : width - 212;
            page = name;
            menuOpen = true;
            Desktop.actionError = "";
        }
    }
    function openTrayMenu(item, source) {
        if (menuOpen && page === "tray" && trayItem === item) { menuOpen = false; return; }
        menuPane.beginMorph();
        trayItem = item;
        menuCenterX = source.mapToItem(panel.contentItem, source.width / 2, 0).x;
        page = "tray";
        menuOpen = true;
        Desktop.actionError = "";
    }
    BarSurface { panel: panel }
    Connections {
        target: Desktop
        function onMenuRequested(name, monitorName) {
            if (panel.modelData.name !== monitorName) { panel.menuOpen = false; return; }
            panel.togglePage(name);
            panel.menuCenterX = panel.width / 2;
        }
        function onMenuCloseRequested() { panel.menuOpen = false; }
    }
    PanelWindow {
        id: popup
        screen: panel.screen
        anchors { top: true; left: true; right: true }
        margins.top: panel.height
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "md3-menu"
        WlrLayershell.layer: WlrLayer.Overlay
        // Constant on purpose: changing keyboard interactivity on a mapped surface makes Quickshell
        // recreate it (the menu vanished when going from the main menu to the wallpapers), and an
        // Exclusive layer makes Hyprland drop clicks on the bar, so its buttons could not close the menu.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        Timer {
            interval: 100
            running: popup.visible && panel.menuOpen && panel.page === "wallpaper"
            onTriggered: menuPane.loadedPage?.focusGallery()
        }
        // Always the full height below the bar: resizing the layer surface whenever a page grows
        // or a morph ends made the menu jump for a frame. The mask keeps clicks outside passing through.
        implicitHeight: panel.screen.height - panel.height
        color: "transparent"
        visible: panel.visible && (panel.menuOpen || menuPane.progress > 0)
        mask: Region {
            x: Math.max(Theme.frameWidth, menuPane.x - Theme.menuJoinRadius)
            y: 0
            width: Math.min(panel.width - Theme.frameWidth, menuPane.x + menuPane.width + Theme.menuJoinRadius) - x
            height: Math.ceil(menuPane.revealedHeight) + ((menuPane.leftAttached || menuPane.rightAttached) ? Theme.menuJoinRadius : 0)
        }
        MenuPane {
            id: menuPane
            contentWidth: Math.min(implicitWidth, panel.width - Theme.frameWidth * 2)
            targetX: Math.max(Theme.frameWidth, Math.min(panel.width - Theme.frameWidth - contentWidth, panel.menuCenterX - contentWidth / 2))
            leftAttached: x <= Theme.frameWidth
            rightAttached: x + width >= panel.width - Theme.frameWidth
            trayItem: panel.trayItem
            expanded: panel.menuOpen
            page: panel.page
            maximumHeight: panel.screen.height - panel.height - Theme.menuJoinRadius - Theme.menuShadow - Theme.frameWidth
            onCloseRequested: panel.menuOpen = false
            onNavigateRequested: name => { beginMorph(); panel.page = name; Desktop.actionError = ""; }
        }
        HyprlandFocusGrab {
            windows: [panel, popup]
            active: panel.menuOpen && popup.visible
            onCleared: panel.menuOpen = false
        }
    }
    PanelWindow {
        id: toastWindow
        // With the frame on screen the toast grows out of the bar and joins the right frame edge
        // like a menu; over a fullscreen window or with the bar hidden it floats as its own card.
        readonly property bool fullscreen: Desktop.dockFullscreen(Hyprland.toplevels.values, panel.monitor)
        readonly property bool detached: fullscreen || !Desktop.barVisible
        readonly property bool shown: !!Desktop.toast && !popup.visible && panel.modelData.name === "DP-1"
        readonly property int edge: detached ? 12 : Theme.frameWidth
        // Kept while the surface collapses, so the text does not vanish before the motion ends.
        property var notification: null
        Connections {
            target: Desktop
            function onToastChanged() { if (Desktop.toast) toastWindow.notification = Desktop.toast; }
        }
        screen: panel.modelData
        anchors { top: true; right: true }
        margins.top: detached ? 0 : Theme.barHeight
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "md3-toast"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        implicitWidth: toastPane.width + edge + Theme.menuJoinRadius + Theme.menuShadow
        implicitHeight: toastPane.y + toastPane.height + Theme.menuJoinRadius + Theme.menuShadow * 2
        color: "transparent"
        visible: shown || toastPane.progress > 0
        mask: Region {
            x: toastPane.x - (toastWindow.detached ? 0 : Theme.menuJoinRadius)
            y: toastPane.y
            width: toastPane.width + (toastWindow.detached ? 0 : Theme.menuJoinRadius)
            height: Math.ceil(toastPane.revealedHeight) + (toastPane.rightAttached ? Theme.menuJoinRadius : 0)
        }
        Reveal {
            id: toastPane
            detached: toastWindow.detached
            rightAttached: !toastWindow.detached
            expanded: toastWindow.shown
            width: Math.min(400, panel.width - Theme.frameWidth * 2)
            height: toastCard.implicitHeight + 16
            x: toastWindow.width - toastWindow.edge - width
            y: toastWindow.detached ? Theme.menuShadow + 12 : 0
            NotificationCard {
                id: toastCard
                popupMode: true
                x: 8; y: 8; width: parent.width - 16
                notification: toastWindow.notification
            }
        }
    }
}

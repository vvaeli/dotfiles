import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property var running: Desktop.dockAppsForMonitor(Hyprland.toplevels.values, monitor?.name ?? "")
    // Pinned apps count windows on every monitor, so clicking one focuses it instead of starting another.
    readonly property var runningEverywhere: Desktop.dockAppsForMonitor(Hyprland.toplevels.values, "")
    // Pinned desktop ids, kept in ~/.local/state/md3/dock.json.
    readonly property var defaultPins: ["com.mitchellh.ghostty", "google-chrome", "thunar", "telegram-app", "spotify", "discord", "steam"]
    property var pins: defaultPins
    FileView {
        id: pinFile
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/md3/dock.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (Array.isArray(data.pinned)) root.pins = data.pinned;
                if (Array.isArray(data.order)) root.order = data.order;
            } catch (_) {}
        }
        onLoadFailed: root.pins = root.defaultPins
    }
    // Preferred order of running, unpinned apps (window class keys), also from dock.json.
    property var order: []
    function save() {
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s\\n' \"$2\" > \"$1\"", "md3",
            pinFile.path, JSON.stringify({pinned: pins, order: order}, null, 2)]);
    }
    function togglePin(app) {
        if (!app.id) return;
        pins = pins.includes(app.id) ? pins.filter(id => id !== app.id) : pins.concat([app.id]);
        save();
    }
    // Applies a drag in the dock: keys in their new visual order. Left of the separator is the
    // pinned group, so dragging across it pins or unpins the app.
    function arrange(keys) {
        const sep = keys.indexOf("separator");
        const byKey = {};
        for (const app of apps) byKey[app.key] = app;
        const nextPins = [], runKeys = [];
        keys.forEach((key, i) => {
            const app = byKey[key];
            if (!app || app.separator) return;
            const pinnedZone = sep >= 0 ? i < sep : app.pinned;
            if (pinnedZone && app.id) { if (!nextPins.includes(app.id)) nextPins.push(app.id); }
            else if (!app.pinned) runKeys.push(key.slice(4));
        });
        // Pins without a desktop entry right now are not shown; keep them at the end.
        const shown = new Set(apps.filter(a => a.pinned).map(a => a.id));
        pins = nextPins.concat(pins.filter(id => !shown.has(DesktopEntries.byId(id)?.id ?? id) && !nextPins.includes(id)));
        order = runKeys.concat(order.filter(k => !runKeys.includes(k)));
        save();
    }
    // Pinned apps first (with their windows when running), a separator, then the rest.
    readonly property var apps: {
        const used = new Set();
        const list = [];
        for (const id of pins) {
            const entry = DesktopEntries.byId(id);
            if (!entry) continue;
            const keys = [id, entry.startupClass, id.split(".").pop()].filter(k => k).map(k => k.toLowerCase().replace(/\.desktop$/, ""));
            const app = runningEverywhere.find(a => keys.includes(a.key) || a.id === entry.id);
            if (app) used.add(app.key);
            list.push({key: "pin:" + id, id: entry.id, pinned: true, name: entry.name, icon: entry.icon,
                active: app?.active ?? false, windows: app?.windows ?? []});
        }
        const rank = key => { const i = order.indexOf(key); return i < 0 ? order.length : i; };
        const rest = running.filter(a => !used.has(a.key))
            .map((a, i) => ({a, i})).sort((p, q) => rank(p.a.key) - rank(q.a.key) || p.i - q.i)
            .map(({a}) => Object.assign({}, a, {key: "run:" + a.key, pinned: false}));
        if (list.length && rest.length) list.push({key: "separator", separator: true, windows: []});
        return list.concat(rest);
    }
    readonly property real dockWidth: Math.min(dock.implicitWidth, width - Theme.frameWidth * 2 - 16)
    readonly property real dockX: (width - dockWidth) / 2
    readonly property bool fullscreen: Desktop.dockFullscreen(Hyprland.toplevels.values, monitor)
    readonly property int bottomGap: fullscreen ? 12 : Theme.frameWidth
    readonly property bool overlapped: Desktop.dockOverlaps(Hyprland.toplevels.values, monitor,
        {x: (monitor?.x ?? 0) + dockX, y: (monitor?.y ?? 0) + screen.height - bottomGap - dock.height,
            width: dockWidth, height: dock.height})
    property bool peek: false
    readonly property bool pointerInside: edgeHover.containsMouse || triggerHover.containsMouse || (dock.hovered && progress > 0.1)
    onPointerInsideChanged: {
        if (pointerInside) { hideDelay.stop(); showDelay.restart(); }
        else { showDelay.stop(); hideDelay.restart(); }
    }
    readonly property bool expanded: apps.length > 0 && Desktop.barVisible && (!overlapped || peek)
    readonly property real progress: dock.progress
    readonly property real visibleTop: dock.y + dock.height - dock.revealedHeight
    anchors { bottom: true; left: true; right: true }
    implicitHeight: 140
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: apps.length > 0 && Desktop.barVisible
    WlrLayershell.namespace: "md3-dock"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {
        x: root.dockX
        y: Math.min(root.height - 3, root.visibleTop)
        width: root.dockWidth
        height: root.height - y
    }
    Item {
        x: root.dockX
        y: Math.min(root.height - 3, root.visibleTop)
        width: root.dockWidth
        height: root.height - y
        MouseArea {
            id: edgeHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
    }
    // A separate always-mapped edge surface can receive enter events even when
    // the animated dock is entirely outside its window's visible area.
    PanelWindow {
        id: trigger
        screen: root.screen
        anchors { bottom: true; left: true; right: true }
        implicitHeight: 6
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: root.apps.length > 0 && Desktop.barVisible
        WlrLayershell.namespace: "md3-dock-trigger"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        readonly property real activationWidth: Math.min(width, Math.max(320, root.dockWidth + 80))
        mask: Region { x: (trigger.width - trigger.activationWidth) / 2; y: 0; width: trigger.activationWidth; height: trigger.height }
        MouseArea {
            id: triggerHover
            x: (trigger.width - trigger.activationWidth) / 2
            width: trigger.activationWidth; height: parent.height
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
    }
    Timer { id: showDelay; interval: 100; onTriggered: root.peek = true }
    Timer { id: hideDelay; interval: 450; onTriggered: root.peek = false }
    DockSurface {
        id: dock
        apps: root.apps
        x: root.dockX
        width: root.dockWidth
        height: 64
        y: root.height - root.bottomGap - height
        expanded: root.expanded
        detached: root.fullscreen
        onActivateRequested: (app, direction) => Desktop.focusDockApp(app, direction)
        onLaunchRequested: app => { if (!Desktop.preview) DesktopEntries.byId(app.id)?.execute(); }
        onPinRequested: app => root.togglePin(app)
        onArrangeRequested: keys => root.arrange(keys)
        onLauncherRequested: Desktop.toggleLauncher()
    }
}

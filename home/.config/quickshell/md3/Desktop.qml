pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import Quickshell.Services.Notifications

Scope {
    id: root
    readonly property bool preview: Quickshell.env("MD3_PREVIEW") === "1"
    property var stats: ({cpu: 0, ram: 0, ramUsed: 0, ramTotal: 0, disk: 0, diskFree: 0,
        networkAvailable: false, network: "Нет подключения", networkType: "offline",
        wifiEnabled: false, brightnessAvailable: false, brightness: 0})
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property real volume: sink?.audio?.volume ?? 0
    function volumeIconFor(level, isMuted) {
        return isMuted || level <= 0 ? "mute" : level < 0.34 ? "volumeLow" : level < 0.67 ? "volumeMedium" : "volume";
    }
    function wifiIconFor(signal) { return signal < 35 ? "wifiLow" : signal < 70 ? "wifiMedium" : "wifi"; }
    function bluetoothColorFor(adapterEnabled, connected) { return !adapterEnabled ? Theme.outline : connected ? Theme.primary : Theme.textSurface; }
    readonly property string volumeIcon: volumeIconFor(volume, muted)
    readonly property string networkIcon: stats.networkType === "ethernet" ? "ethernet" : stats.networkType === "wifi" ? wifiIconFor(stats.wifiSignal ?? 0) : "offline"
    readonly property color bluetoothColor: bluetoothColorFor(adapter?.enabled ?? false, (adapter?.devices.values ?? []).some(device => device.connected))
    readonly property bool muted: sink?.audio?.muted ?? true
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery?.isLaptopBattery ?? false
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var notifications: notificationServer.trackedNotifications.values
    property bool dnd: false
    property bool barVisible: true
    property bool crosshairVisible: false
    property bool clipboardVisible: false
    signal menuRequested(string page, string monitorName)
    // Escape anywhere (Hyprland global shortcut md3:menuClose) closes the bar menus.
    signal menuCloseRequested()
    function toggleWallpaperMenu() {
        clipboardVisible = false;
        launcherVisible = false;
        barVisible = true;
        menuRequested("wallpaper", Hyprland.focusedMonitor?.name || "DP-1");
    }
    property bool launcherVisible: false
    property string launcherMonitor: "DP-1"
    function toggleLauncher() {
        if (launcherVisible) launcherVisible = false;
        else {
            clipboardVisible = false;
            launcherMonitor = Hyprland.focusedMonitor?.name || "DP-1";
            launcherVisible = true;
        }
    }
    property string clipboardMonitor: "DP-1"
    function toggleClipboard() {
        if (clipboardVisible) clipboardVisible = false;
        else {
            clipboardMonitor = Hyprland.focusedMonitor?.name || "DP-1";
            clipboardVisible = true;
        }
    }
    property var toast: null
    property string actionError: ""
    property string keyboardLayout: ""
    property bool osdVisible: false
    property string osdKind: "volume"
    property real osdLevel: 0
    property bool osdMuted: false
    property string osdMonitor: "DP-1"
    function showOsd(kind, level, isMuted, monitorName) {
        if (!["volume", "microphone", "brightness", "layout"].includes(kind)) return;
        osdKind = kind;
        osdLevel = Math.max(0, Math.min(1, level));
        osdMuted = isMuted;
        osdMonitor = monitorName;
        osdVisible = true;
        osdTimer.restart();
    }
    function updateKeyboardLayout(layout, monitorName) {
        if (!layout || layout === keyboardLayout) return;
        keyboardLayout = layout;
        showOsd("layout", 0, false, monitorName || Hyprland.focusedMonitor?.name || "DP-1");
    }
    Timer { id: osdTimer; interval: 1600; onTriggered: root.osdVisible = false }
    readonly property var now: clock.date

    SystemClock { id: clock; precision: SystemClock.Seconds }
    PwObjectTracker { objects: [root.sink, root.source].filter(x => x !== null) }
    Process {
        id: metrics
        command: ["python3", Quickshell.shellPath("metrics.py")]
        running: !root.preview
        stdout: SplitParser {
            onRead: data => {
                try { root.stats = JSON.parse(data); } catch (error) { console.warn("Metrics:", error); }
            }
        }
    }
    Process {
        id: action
        stdout: StdioCollector {}
        stderr: StdioCollector { id: actionStderr }
        onExited: (code, status) => {
            if (code !== 0) root.actionError = actionStderr.text.trim() || "Не удалось выполнить действие";
        }
    }
    function run(args) {
        if (preview || action.running) return;
        actionError = "";
        action.command = args;
        action.running = true;
    }
    // Тёмная/светлая палитра: matugen пересобирает цвета оболочки и приложений по текущим обоям.
    readonly property bool colorModeBusy: colorMode.running
    property string pendingColorMode: ""
    function setColorMode(mode) {
        if (preview || colorMode.running || (mode === "light") === Theme.light) return;
        actionError = "";
        pendingColorMode = mode;
        colorMode.command = ["python3", Quickshell.shellPath("wallpaper.py"), "mode", mode];
        colorMode.running = true;
    }
    function toggleColorMode() { setColorMode(Theme.light ? "dark" : "light"); }
    Process {
        id: colorMode
        stdout: StdioCollector {}
        stderr: StdioCollector { id: colorModeError }
        onExited: (code, status) => {
            root.pendingColorMode = "";
            if (code !== 0) root.actionError = colorModeError.text.trim().split("\n").pop() || "Не удалось сменить тему";
        }
    }
    // Wallpaper gallery state lives here so reopening the menu shows it at once and
    // closing the menu mid-change never kills the palette/theme sync half way.
    property var wallpaperEntries: []
    property string wallpaperCurrent: ""
    property string wallpaperPending: ""
    property string wallpaperMessage: ""
    property bool wallpaperMatugen: true
    property string wallpaperListing: ""
    readonly property bool wallpaperBusy: wallpaperApply.running
    readonly property bool wallpaperLoading: wallpaperList.running
    function refreshWallpapers() { if (!preview && !wallpaperList.running && !wallpaperApply.running) wallpaperList.running = true; }
    function applyWallpaper(path) {
        if (preview || wallpaperApply.running || colorMode.running || path === wallpaperCurrent) return;
        wallpaperMessage = "";
        wallpaperPending = path;
        wallpaperApply.command = ["python3", Quickshell.shellPath("wallpaper.py"), "apply", path];
        wallpaperApply.running = true;
    }
    Process {
        id: wallpaperList
        command: ["python3", Quickshell.shellPath("wallpaper.py"), "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.wallpaperCurrent = data.current;
                    root.wallpaperMatugen = data.matugen;
                    // Same listing keeps the model, so tiles are not rebuilt and do not flash.
                    const listing = JSON.stringify(data.entries);
                    if (listing !== root.wallpaperListing) { root.wallpaperListing = listing; root.wallpaperEntries = data.entries; }
                } catch (_) {}
            }
        }
        stderr: StdioCollector { id: wallpaperListError }
        onExited: (code, status) => { if (code) root.wallpaperMessage = wallpaperListError.text.trim(); }
    }
    Process {
        id: wallpaperApply
        stdout: StdioCollector { onStreamFinished: { try { const result = JSON.parse(text); root.wallpaperCurrent = result.path; root.wallpaperMessage = result.message.startsWith("Обои и цвета") ? "" : result.message; } catch (_) {} } }
        stderr: StdioCollector { id: wallpaperApplyError }
        onExited: (code, status) => {
            root.wallpaperPending = "";
            if (code) root.wallpaperMessage = wallpaperApplyError.text.trim().split("\n").pop() || "Не удалось сменить обои";
        }
    }
    function launch(args) { if (!preview) Quickshell.execDetached(args); }
    function setVolume(value) {
        if (sink?.audio) { sink.audio.muted = false; sink.audio.volume = Math.max(0, Math.min(1, value)); }
    }
    function toggleMute() { if (sink?.audio) sink.audio.muted = !sink.audio.muted; }
    function focusMonitor(monitor) {
        if (!monitor || preview) return;
        Hyprland.dispatch(Hyprland.usingLua
            ? "hl.dsp.focus({ monitor = " + JSON.stringify(monitor.name) + " })"
            : "focusmonitor " + monitor.name);
    }
    function workspacesForMonitor(workspaces, monitorName) {
        return workspaces.filter(w => w.monitor?.name === monitorName && !w.name.startsWith("special:"))
            .sort((a, b) => a.id - b.id);
    }
    function focusWorkspace(monitor, workspace) {
        if (preview) return;
        focusMonitor(monitor);
        Hyprland.dispatch(Hyprland.usingLua
            ? "hl.dsp.focus({ workspace = " + (workspace.id > 0 ? workspace.id : JSON.stringify(workspace.name)) + " })"
            : "workspace " + workspace.name);
    }
    function nextWorkspace(monitor, direction) {
        if (!monitor || preview) return;
        focusMonitor(monitor);
        Hyprland.dispatch(Hyprland.usingLua
            ? 'hl.dsp.focus({ workspace = "m' + (direction > 0 ? '+' : '-') + '1" })'
            : 'workspace m' + (direction > 0 ? '+' : '-') + '1');
    }
    function createWorkspace(monitor) {
        if (!monitor || preview) return;
        const used = Hyprland.workspaces.values.filter(w => w.id > 0).map(w => w.id);
        let id = 1;
        while (used.includes(id)) ++id;
        focusMonitor(monitor);
        Hyprland.dispatch(Hyprland.usingLua ? 'hl.dsp.focus({ workspace = ' + id + ' })' : 'workspace ' + id);
    }
    function dockAppsForMonitor(windows, monitorName) {
        const groups = new Map();
        for (const window of windows) {
            // No monitor name: windows from every monitor.
            if ((monitorName && window.monitor?.name !== monitorName) || window.lastIpcObject?.mapped === false) continue;
            const ipc = window.lastIpcObject ?? {};
            const appId = ipc.class || window.waylandHandle?.appId || ipc.initialClass || "application";
            const key = appId.toLowerCase().replace(/\.desktop$/, "");
            if (!groups.has(key)) {
                const entry = DesktopEntries.byId(appId) || DesktopEntries.applications.values.find(e =>
                    e.startupClass?.toLowerCase() === key || e.id.toLowerCase().replace(/\.desktop$/, "") === key);
                groups.set(key, {key: key, id: entry?.id ?? "", name: entry?.name || appId, icon: entry?.icon || appId,
                    active: false, windows: []});
            }
            const app = groups.get(key);
            app.active = app.active || window.activated;
            app.windows.push({address: window.address, active: window.activated, title: window.title});
        }
        return Array.from(groups.values());
    }
    function dockFullscreen(windows, monitor) {
        if (!monitor) return false;
        const activeId = monitor.activeWorkspace?.id;
        const specialId = monitor.lastIpcObject?.specialWorkspace?.id;
        return windows.some(window => {
            const ipc = window.lastIpcObject ?? {};
            return window.monitor?.name === monitor.name && ipc.mapped !== false && ipc.hidden !== true
                && (ipc.pinned || window.workspace?.id === activeId || (specialId && window.workspace?.id === specialId))
                && ipc.fullscreen === 2;
        });
    }
    function dockOverlaps(windows, monitor, rect) {
        if (!monitor) return false;
        const activeId = monitor.activeWorkspace?.id;
        const specialId = monitor.lastIpcObject?.specialWorkspace?.id;
        return windows.some(window => {
            const ipc = window.lastIpcObject ?? {};
            if (window.monitor?.name !== monitor.name || ipc.mapped === false || ipc.hidden === true) return false;
            if (!ipc.pinned && window.workspace?.id !== activeId && !(specialId && window.workspace?.id === specialId)) return false;
            if ((ipc.fullscreen ?? 0) === 2) return true;
            const at = ipc.at, size = ipc.size;
            return at && size && at[0] < rect.x + rect.width && at[0] + size[0] > rect.x
                && at[1] < rect.y + rect.height && at[1] + size[1] > rect.y;
        });
    }
    function focusDockApp(app, direction) {
        if (preview || !app.windows.length) return;
        const active = app.windows.findIndex(window => window.active);
        const index = active < 0 ? 0 : (active + (direction ?? 1) + app.windows.length) % app.windows.length;
        const address = app.windows[index].address;
        const selector = "address:" + (address.startsWith("0x") ? address : "0x" + address);
        Hyprland.dispatch(Hyprland.usingLua ? "hl.dsp.focus({ window = " + JSON.stringify(selector) + " })" : "focuswindow " + selector);
    }
    // Geometry also changes during drag/resize without a window lifecycle event.
    Timer {
        interval: 300; repeat: true; running: !root.preview && root.barVisible
        onTriggered: Hyprland.refreshToplevels()
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") layoutRefresh.restart();
        }
    }
    Timer {
        id: layoutRefresh
        interval: 50
        onTriggered: {
            if (keyboardState.running) restart();
            else keyboardState.running = true;
        }
    }
    Process {
        id: keyboardState
        command: ["hyprctl", "-j", "devices"]
        running: !root.preview
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const keyboards = JSON.parse(text).keyboards || [];
                    const layout = (keyboards.find(k => k.main) || keyboards[0])?.active_keymap ?? "";
                    if (!root.keyboardLayout) root.keyboardLayout = layout;
                    else root.updateKeyboardLayout(layout);
                } catch (_) {}
            }
        }
    }
    function clearNotifications() {
        const copy = notifications.slice();
        for (const n of copy) n.dismiss();
        toast = null;
    }
    NotificationServer {
        id: notificationServer
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: notification => {
            notification.tracked = true;
            if (root.notifications.length > 50) root.notifications[0].dismiss();
            if (!root.dnd) {
                root.toast = notification;
                toastTimer.interval = notification.expireTimeout > 0 ? Math.min(notification.expireTimeout, 15000) : 6000;
                toastTimer.restart();
            }
        }
    }
    Timer { id: toastTimer; onTriggered: root.toast = null }

    // Night light: a colour matrix that Hyprland applies after rendering (hyprland-ctm-control-v1,
    // through tools/nightlight). Screenshots and the screenshot tool's frozen frame stay untinted,
    // and the cursor is tinted too. "auto" follows a schedule with a gradual ramp at both ends;
    // every change fades here, since Hyprland skips its own CTM fade on NVIDIA.
    readonly property string nightHelper: Quickshell.shellPath("tools/nightlight/md3-nightlight")
    readonly property string nightStateFile: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/md3/nightlight.json"
    property string nightMode: "off"      // off | on | auto
    property int nightTemperature: 4000   // kelvin
    property int nightStart: 20 * 60      // minutes after midnight
    property int nightEnd: 7 * 60
    readonly property int nightRamp: 40
    property real nightClock: 0
    property string nightError: ""
    readonly property real nightLevel: nightMode === "on" ? 1 : nightMode === "auto" ? nightScheduleLevel(nightClock) : 0
    readonly property bool nightLight: nightLevel > 0
    function nightScheduleLevel(minutes) {
        const length = (nightEnd - nightStart + 1440) % 1440 || 1440;
        const into = (minutes - nightStart + 1440) % 1440;
        if (into >= length) return 0;
        return Math.max(0, Math.min(1, into / nightRamp, (length - into) / nightRamp));
    }
    function formatMinutes(minutes) {
        minutes = (Math.round(minutes) % 1440 + 1440) % 1440;
        return String(Math.floor(minutes / 60)).padStart(2, "0") + ":" + String(minutes % 60).padStart(2, "0");
    }
    readonly property string nightStatus: nightMode === "on" ? "Включён · " + nightTemperature + " K"
        : nightMode === "off" ? "Выключен"
        : nightLight ? "Авто · до " + formatMinutes(nightEnd) : "Авто · с " + formatMinutes(nightStart)
    function setNightMode(mode) {
        if (preview || mode === nightMode) return;
        nightMode = mode;
        saveNight();
    }
    // Old menus toggle between off and on.
    function setNightLight(on) { setNightMode(on ? "on" : "off"); }
    function setNightTemperature(kelvin) { nightTemperature = Math.round(kelvin / 100) * 100; nightSave.restart(); }
    function setNightSchedule(start, end) {
        nightStart = (start % 1440 + 1440) % 1440;
        nightEnd = (end % 1440 + 1440) % 1440;
        saveNight();
    }
    function saveNight() {
        nightFile.setText(JSON.stringify({mode: nightMode, temperature: nightTemperature, start: nightStart, end: nightEnd}) + "\n");
    }
    Timer { id: nightSave; interval: 600; onTriggered: root.saveNight() }
    FileView {
        id: nightFile
        path: root.nightStateFile
        printErrors: false
        onLoaded: {
            try {
                const state = JSON.parse(text());
                if (["off", "on", "auto"].includes(state.mode)) root.nightMode = state.mode;
                if (state.temperature >= 1500 && state.temperature <= 6500) root.nightTemperature = state.temperature;
                if (Number.isInteger(state.start)) root.nightStart = state.start;
                if (Number.isInteger(state.end)) root.nightEnd = state.end;
            } catch (_) {}
        }
    }
    Timer {
        interval: 20000; repeat: true; triggeredOnStart: true
        running: !root.preview
        onTriggered: { const now = new Date(); root.nightClock = now.getHours() * 60 + now.getMinutes() + now.getSeconds() / 60; }
    }
    // White point of a black body (Tanner Helland's fit), scaled so the brightest channel is 1.
    function kelvinColor(kelvin) {
        const t = kelvin / 100;
        const r = t <= 66 ? 255 : 329.698727446 * Math.pow(t - 60, -0.1332047592);
        const g = t <= 66 ? 99.4708025861 * Math.log(t) - 161.1195681661 : 288.1221695283 * Math.pow(t - 60, -0.0755148492);
        const b = t >= 66 ? 255 : t <= 19 ? 0 : 138.5177312231 * Math.log(t - 10) - 305.0447927307;
        const c = [r, g, b].map(v => Math.max(0, Math.min(255, v)) / 255);
        const top = Math.max(...c);
        return c.map(v => v / top);
    }
    // Strength actually on screen; animates toward the target so switching never jumps.
    property real nightShown: nightLevel
    Behavior on nightShown { NumberAnimation { duration: 1400; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
    property real nightShownKelvin: nightTemperature
    Behavior on nightShownKelvin { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
    readonly property var nightMatrix: {
        const warm = kelvinColor(nightShownKelvin);
        return warm.map(v => 1 + (v - 1) * nightShown);
    }
    onNightMatrixChanged: pushNight()
    function pushNight() {
        if (nightProcess.running) nightProcess.write(nightMatrix.map(v => v.toFixed(4)).join(" ") + "\n");
    }
    Process {
        id: nightProcess
        command: [root.nightHelper]
        running: !root.preview
        stdinEnabled: true
        onRunningChanged: if (running) { root.nightError = ""; root.pushNight(); }
        onExited: (code, status) => {
            root.nightError = code === 2 ? "Цветом экрана управляет другая программа" : "Ночной свет недоступен";
            nightRetry.restart();
        }
    }
    Timer { id: nightRetry; interval: 10000; onTriggered: if (!root.preview) nightProcess.running = true }
    // The screen shader of the previous night light version is dropped once.
    Process {
        command: ["sh", "-c", "hyprctl -j getoption decoration:screen_shader | grep -q nightlight && hyprctl eval 'hl.config({decoration={screen_shader=\"\"}})'"]
        running: !root.preview
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) { if (event.name === "configreloaded") root.pushNight(); }
    }
    // Caffeine: an idle inhibitor lock that hypridle honours, held while the process lives.
    property bool caffeine: false
    Process {
        running: root.caffeine && !root.preview
        command: ["systemd-inhibit", "--what=idle", "--who=md3", "--why=Не засыпать", "sleep", "infinity"]
    }
    property real uptime: 0
    Process {
        id: uptimeReader
        command: ["cat", "/proc/uptime"]
        running: !root.preview
        stdout: StdioCollector { onStreamFinished: root.uptime = parseFloat(text) || 0 }
    }
    Timer { interval: 60000; repeat: true; running: !root.preview; onTriggered: uptimeReader.running = true }
    function formatUptime(seconds) {
        const minutes = Math.floor(seconds / 60), hours = Math.floor(minutes / 60), days = Math.floor(hours / 24);
        if (days) return days + " д " + hours % 24 + " ч";
        if (hours) return hours + " ч " + minutes % 60 + " мин";
        return minutes + " мин";
    }
    // Icon file for a window class or desktop id, "" when the theme has none.
    function iconForApp(appId) {
        if (!appId) return "";
        const entry = DesktopEntries.byId(appId) || DesktopEntries.heuristicLookup(appId);
        return iconSource(entry?.icon || appId);
    }
    // Theme icon by name; icons installed only under ~/.local/share/icons/hicolor are
    // missed by the theme lookup, so fall back to that folder.
    function iconSource(name) {
        if (!name || name === "application") return "";
        if (name.startsWith("/")) return "file://" + name;
        return Quickshell.iconPath(name, true)
            || "file://" + Quickshell.env("HOME") + "/.local/share/icons/hicolor/scalable/apps/" + name + ".svg";
    }
    function setWifiEnabled(on) { run(["nmcli", "radio", "wifi", on ? "on" : "off"]); }
    function toggleMic() { if (source?.audio) source.audio.muted = !source.audio.muted; }
}

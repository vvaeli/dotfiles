pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Beryllium (beryl) — живое состояние демона и действия меню VPN.
Scope {
    id: root
    readonly property string binary: "/usr/local/bin/beryl"
    property var status: ({})
    property var servers: []
    property var subscriptions: []
    property var pings: ({})
    property bool daemonAvailable: false
    property string error: ""
    property string pendingServer: ""
    // Subscription being re-downloaded: its id, or "*" for all of them.
    property string pendingSubscription: ""
    readonly property bool busy: action.running
    readonly property bool pinging: ping.running
    readonly property string connectionState: (status.state ?? "CONNECTION_STATE_DISCONNECTED").replace("CONNECTION_STATE_", "")
    readonly property bool connected: connectionState === "CONNECTED" || connectionState === "DEGRADED"
    readonly property bool transitioning: busy || ["CONNECTING", "DISCONNECTING", "RECOVERING"].includes(connectionState)
    readonly property string mode: ({MODE_TUN: "tun", MODE_TUNNEL: "tun", MODE_SYSTEM_PROXY: "proxy", MODE_LOCAL_PROXY: "local"})[status.mode] ?? settingsMode
    property string settingsMode: "tun"
    readonly property var server: status.server ?? null
    // Строки не пересчитывают зависимые списки на каждом тике статуса.
    readonly property string currentId: connected ? (server?.id ?? "") : ""
    readonly property string subscriptionId: server?.subscription_id ?? ""
    readonly property string icon: !daemonAvailable || connectionState === "FAILED" ? "shieldOff" : connected ? "shieldCheck" : "shield"
    readonly property color color: !daemonAvailable || connectionState === "FAILED" ? Theme.error
        : connectionState === "DEGRADED" ? Theme.error
        : connected ? Theme.primary : transitioning ? Theme.textSurface : Theme.outline
    readonly property string stateText: !daemonAvailable ? "Демон недоступен" : ({
        CONNECTED: "Подключено", DEGRADED: "Соединение нестабильно", CONNECTING: "Подключение…",
        DISCONNECTING: "Отключение…", RECOVERING: "Восстановление…", FAILED: "Ошибка подключения"
    })[connectionState] ?? "Отключено"

    function modeTitle(name) { return ({tun: "TUN", proxy: "Системный прокси", local: "Локальный прокси"})[name] ?? name; }
    function seconds(value) { return value ? parseFloat(value) : NaN; }
    function latencyFor(item) {
        const pinged = pings[item.id];
        if (pinged !== undefined) return pinged;
        return Math.round(seconds(item.latency) * 1000);
    }
    function formatBytes(value) {
        let bytes = Number(value ?? 0);
        const units = ["Б", "КБ", "МБ", "ГБ", "ТБ"];
        let unit = 0;
        while (bytes >= 1024 && unit < units.length - 1) { bytes /= 1024; ++unit; }
        return (unit === 0 || bytes >= 100 ? Math.round(bytes) : bytes.toFixed(1)) + " " + units[unit];
    }
    function formatRate(value) { return formatBytes(value) + "/с"; }
    function formatUptime(since, now) {
        if (!since) return "";
        let total = Math.max(0, Math.floor((now - new Date(since)) / 1000));
        const h = Math.floor(total / 3600), m = Math.floor(total % 3600 / 60), s = total % 60;
        return (h > 0 ? h + ":" + String(m).padStart(2, "0") : m) + ":" + String(s).padStart(2, "0");
    }
    function describe(item) {
        if (!item) return "";
        const strip = (value, prefix) => (value ?? "").replace(prefix, "");
        const raw = strip(item.protocol, "PROTOCOL_");
        const protocol = ({VMESS: "VMess", TROJAN: "Trojan", SHADOWSOCKS: "Shadowsocks", HYSTERIA: "Hysteria",
            HYSTERIA2: "Hysteria2", WIREGUARD: "WireGuard", SOCKS: "SOCKS", HTTP: "HTTP"})[raw] ?? raw;
        const parts = [protocol, strip(item.transport, "TRANSPORT_"), strip(item.security, "SECURITY_")]
            .filter(p => p && p !== "NONE" && p !== "UNSPECIFIED");
        return parts.join(" · ");
    }

    function run(args, serverId, subscriptionId) {
        if (Desktop.preview || action.running) return;
        error = "";
        pendingServer = serverId ?? "";
        pendingSubscription = subscriptionId ?? "";
        action.command = [binary, "--json", "--timeout", "40s"].concat(args);
        action.running = true;
    }
    function connectTo(item) { run(["connect", item.id], item.id); }
    function connectAuto() { run(["connect", "--auto"], ""); }
    function disconnect() { run(["disconnect"]); }
    function toggle() {
        if (transitioning) return;
        if (connected) disconnect();
        else if (status.server?.id) run(["connect", status.server.id], status.server.id);
        else connectAuto();
    }
    function setMode(name) { if (name !== mode) run(["mode", name]); }
    function updateSubscriptions() { run(["sub", "update", "--all"], "", "*"); }
    function updateSubscription(item) { run(["sub", "update", item.id], "", item.id); }
    function isUpdating(item) { return busy && (pendingSubscription === "*" || pendingSubscription === item?.id); }
    function ago(iso, now) {
        if (!iso) return "ещё не обновлялась";
        const minutes = Math.max(0, Math.floor((now - new Date(iso)) / 60000));
        if (minutes < 1) return "обновлена только что";
        if (minutes < 60) return "обновлена " + minutes + " мин назад";
        const hours = Math.floor(minutes / 60);
        if (hours < 24) return "обновлена " + hours + " ч назад";
        return "обновлена " + Math.floor(hours / 24) + " дн назад";
    }
    function pingAll() {
        if (Desktop.preview || ping.running) return;
        error = "";
        ping.running = true;
    }
    function refresh() {
        if (Desktop.preview) return;
        if (!serverList.running) serverList.running = true;
        if (!subList.running) subList.running = true;
        if (!modeQuery.running) modeQuery.running = true;
    }

    Component.onCompleted: refresh()

    // `status -w` печатает отформатированные JSON-объекты; верхний уровень
    // закрывается строкой "}" без отступа.
    Process {
        id: watcher
        property string buffer: ""
        command: [root.binary, "--json", "status", "--watch"]
        running: !Desktop.preview
        stdout: SplitParser {
            onRead: line => {
                watcher.buffer += line + "\n";
                if (line !== "}") return;
                try {
                    root.status = JSON.parse(watcher.buffer);
                    root.daemonAvailable = true;
                } catch (e) { console.warn("Beryl:", e); }
                watcher.buffer = "";
            }
        }
        onExited: (code, exitStatus) => {
            watcher.buffer = "";
            root.daemonAvailable = false;
            root.status = ({});
            restartWatcher.restart();
        }
    }
    Timer {
        id: restartWatcher
        interval: 3000
        onTriggered: { if (!Desktop.preview) { watcher.running = true; root.refresh(); } }
    }
    Process {
        id: action
        stdout: StdioCollector {}
        stderr: StdioCollector { id: actionError }
        onExited: (code, exitStatus) => {
            if (code !== 0) root.error = actionError.text.trim().split("\n")[0].replace(/^beryl:\s*/, "").replace(/^Error:\s*/, "") || "Beryllium не выполнил команду";
            if (code !== 0 && root.pendingSubscription) root.error = "Не удалось обновить подписку: " + root.error;
            root.pendingServer = "";
            root.pendingSubscription = "";
            root.refresh();
        }
    }
    Process {
        id: serverList
        command: [root.binary, "--json", "servers"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.servers = JSON.parse(text) ?? []; } catch (_) {} }
        }
    }
    Process {
        id: subList
        command: [root.binary, "--json", "sub", "ls"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.subscriptions = JSON.parse(text) ?? []; } catch (_) {} }
        }
    }
    Process {
        id: modeQuery
        command: [root.binary, "--json", "mode"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.settingsMode = JSON.parse(text).mode || "tun"; } catch (_) {} }
        }
    }
    Process {
        id: ping
        command: [root.binary, "--json", "--timeout", "60s", "ping"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = {};
                    for (const entry of JSON.parse(text) ?? [])
                        result[entry.server_id] = entry.error ? -1 : Math.round(root.seconds(entry.latency) * 1000);
                    root.pings = result;
                } catch (_) { root.error = "Не удалось измерить задержку"; }
                root.refresh();
            }
        }
    }
}

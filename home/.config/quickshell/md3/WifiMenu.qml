import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: root
    property var snapshot: ({available: false, enabled: false, device: "", networks: [], error: ""})
    property var selectedNetwork: null
    property string errorText: ""
    property bool connecting: connection.running
    readonly property var radioControl: radioToggle
    spacing: 12
    readonly property var activeNetwork: snapshot.networks.find(n => n.active) ?? null
    MenuHeader {
        icon: root.snapshot.enabled ? "wifi" : "offline"
        title: "Wi-Fi"
        active: root.snapshot.enabled
        subtitle: !root.snapshot.available ? "Адаптер недоступен" : !root.snapshot.enabled ? "Выключен"
            : root.connecting ? "Подключаю…" : root.activeNetwork ? "Подключено · " + root.activeNetwork.ssid : "Не подключено"
        MdSwitch {
            id: radioToggle
            checked: root.snapshot.enabled
            enabled: root.snapshot.available && !radio.running && !root.connecting
            onToggled: {
                radio.command = ["nmcli", "radio", "wifi", root.snapshot.enabled ? "off" : "on"];
                if (!Desktop.preview) radio.running = true;
            }
        }
    }
    MenuSection {
        visible: root.snapshot.enabled
        text: scan.running ? "Ищу сети…" : "Доступные сети"
        Chip { icon: "refresh"; flat: true; implicitWidth: 30; implicitHeight: 30; tooltip: "Обновить"; enabled: !scan.running && !root.connecting; onClicked: root.refresh(true) }
    }
    MenuGroup {
        visible: root.snapshot.enabled
        AnimatedCardList {
            Layout.fillWidth: true
            animateInsertionHeight: false
            updateDelay: 80
            cardSpacing: 2
            rowColor: Theme.cardSurface
            keyField: "bssid"
            source: root.snapshot.networks
            delegate: Component { MenuRow {
                property var modelData: parent.modelData
                readonly property bool secured: modelData.security !== "--" && modelData.security !== ""
                icon: Desktop.wifiIconFor(modelData.signal)
                title: modelData.ssid
                subtitle: (modelData.active ? "Подключено · " : "") + modelData.signal + "% · " + (secured ? modelData.security : "Открытая сеть")
                selected: modelData.active || root.selectedNetwork?.bssid === modelData.bssid
                interactive: !root.connecting
                onClicked: {
                    if (modelData.active) root.disconnectNetwork();
                    else if (!secured) root.connectNetwork(modelData, "");
                    else { root.selectedNetwork = modelData; password.text = ""; password.forceActiveFocus(); }
                }
                Icon { name: modelData.active ? "close" : "lock"; visible: modelData.active || secured; tint: Theme.muted; implicitWidth: 16; implicitHeight: 16 }
            } }
        }
        Label {
            visible: root.snapshot.networks.length === 0
            Layout.margins: 12
            text: scan.running ? "Ищу сети…" : "Сетей не найдено"; color: Theme.muted; font.pixelSize: 12
        }
    }
    MenuGroup {
        visible: opacity > 0
        opacity: root.selectedNetwork !== null ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.slowEffectsDuration } }
        padding: 14
        spacing: 10
        Label { text: root.selectedNetwork?.ssid ?? ""; elide: Text.ElideRight; Layout.fillWidth: true; font.weight: Font.DemiBold }
        Controls.TextField {
            id: password
            Layout.fillWidth: true
            implicitHeight: 44
            echoMode: TextInput.Password
            placeholderText: "Пароль"
            color: Theme.textSurface
            placeholderTextColor: Theme.muted
            font.family: Theme.font
            leftPadding: 14
            background: Rectangle { radius: 14; color: Theme.container; border.width: 2; border.color: password.activeFocus ? Theme.primary : "transparent" }
            onAccepted: root.connectNetwork(root.selectedNetwork, text)
        }
        Label { text: "Для сохранённой сети пароль можно не вводить."; color: Theme.muted; font.pixelSize: 11; wrapMode: Text.Wrap; Layout.fillWidth: true }
        RowLayout {
            Layout.alignment: Qt.AlignRight
            Chip { text: "Отмена"; flat: true; enabled: !root.connecting; onClicked: { root.selectedNetwork = null; password.text = ""; } }
            Chip { text: root.connecting ? "Подключаю…" : "Подключить"; selected: true; enabled: !root.connecting; onClicked: root.connectNetwork(root.selectedNetwork, password.text) }
        }
    }
    Label { visible: root.errorText !== ""; text: root.errorText; color: Theme.error; font.pixelSize: 12; wrapMode: Text.Wrap; Layout.fillWidth: true }
    Chip { text: "Все подключения"; icon: "settings"; onClicked: Desktop.launch(["ghostty", "-e", "nmtui"]) }
    function refresh(rescan) {
        if (Desktop.preview || scan.running) return;
        scan.command = ["python3", Quickshell.shellPath("wifi_scan.py")];
        if (rescan) scan.command = scan.command.concat(["--rescan"]);
        scan.running = true;
    }
    function connectNetwork(network, secret) {
        if (!network || Desktop.preview || connection.running) return;
        root.errorText = "";
        let args = ["nmcli", "--wait", "20", "device", "wifi", "connect", network.bssid, "ifname", snapshot.device];
        if (secret !== "") args = args.concat(["password", secret]);
        connection.command = args;
        connection.running = true;
    }
    function disconnectNetwork() {
        if (Desktop.preview || connection.running) return;
        connection.command = ["nmcli", "device", "disconnect", snapshot.device];
        connection.running = true;
    }
    Component.onCompleted: refresh(false)
    Process {
        id: scan
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.snapshot = JSON.parse(text); if (root.snapshot.error) root.errorText = root.snapshot.error; }
                catch (_) { root.errorText = "Не удалось получить список сетей"; }
            }
        }
    }
    Process {
        id: radio
        stderr: StdioCollector { id: radioError }
        onExited: (code, status) => { if (code !== 0) root.errorText = radioError.text.trim(); root.refresh(false); }
    }
    Process {
        id: connection
        stderr: StdioCollector { id: connectionError }
        onExited: (code, status) => {
            connection.command = [];
            password.text = "";
            if (code !== 0) root.errorText = connectionError.text.trim() || "Не удалось подключиться";
            else { root.selectedNetwork = null; root.refresh(false); }
        }
    }
}

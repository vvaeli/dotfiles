import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: root
    property var adapter: Desktop.adapter
    readonly property var searchControl: searchButton
    property bool startedScan: false
    property string pendingAddress: ""
    function connectDevice(device) {
        if (connection.running || Desktop.preview) return;
        stopScan();
        Desktop.actionError = "";
        pendingAddress = device.address;
        connection.command = ["python3", Quickshell.shellPath("bluetooth_connect.py"), device.connected ? "disconnect" : device.paired ? "connect" : "pair", device.address];
        connection.running = true;
    }
    Process {
        id: connection
        stderr: StdioCollector { id: connectionError }
        onExited: (code, status) => {
            if (code !== 0) Desktop.actionError = connectionError.text.trim() || "Не удалось подключить Bluetooth-устройство";
            root.pendingAddress = "";
        }
    }
    readonly property var devices: (root.adapter?.devices.values ?? []).slice().sort((a, b) =>
        Number(b.connected) - Number(a.connected) || Number(b.paired) - Number(a.paired) || a.name.localeCompare(b.name))
    readonly property var connectedNames: devices.filter(d => d.connected).map(d => d.name || d.address)
    spacing: 12
    MenuHeader {
        icon: "bluetooth"
        title: "Bluetooth"
        active: root.adapter?.enabled ?? false
        subtitle: !root.adapter ? "Адаптер недоступен" : !root.adapter.enabled ? "Выключен"
            : root.connectedNames.length ? "Подключено · " + root.connectedNames.join(", ") : "Нет подключённых устройств"
        MdSwitch {
            checked: root.adapter?.enabled ?? false
            enabled: !!root.adapter
            onToggled: root.adapter.enabled = !root.adapter.enabled
        }
    }
    MenuSection {
        visible: root.adapter?.enabled ?? false
        text: root.adapter?.discovering ? "Ищу устройства…" : "Устройства"
        Chip {
            id: searchButton
            text: root.adapter?.discovering ? "Стоп" : "Найти"
            icon: "refresh"; implicitHeight: 30
            selected: root.adapter?.discovering ?? false
            enabled: root.adapter?.enabled ?? false
            onClicked: {
                if (root.adapter.discovering) root.stopScan();
                else { root.startedScan = true; root.adapter.discovering = true; scanTimeout.restart(); }
            }
        }
    }
    MenuGroup {
        visible: root.adapter?.enabled ?? false
        AnimatedCardList {
            Layout.fillWidth: true
            animateInsertionHeight: false
            updateDelay: 80
            cardSpacing: 2
            rowColor: Theme.cardSurface
            keyField: "address"
            source: root.adapter?.enabled ? root.devices.map(device => ({
                address: device.address, name: device.name, connected: device.connected,
                paired: device.paired, pairing: device.pairing, state: device.state,
                batteryAvailable: device.batteryAvailable, battery: device.battery
            })) : []
            delegate: Component { MenuRow {
                property var modelData: parent.modelData
                readonly property bool busy: root.pendingAddress === modelData.address || modelData.pairing
                    || modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
                icon: "bluetooth"
                title: modelData.name || modelData.address
                subtitle: root.pendingAddress === modelData.address ? "Подключаю…" : modelData.pairing ? "Сопряжение…"
                    : modelData.state === BluetoothDeviceState.Connecting ? "Подключаю…"
                    : modelData.state === BluetoothDeviceState.Disconnecting ? "Отключаю…"
                    : modelData.connected ? "Подключено" + (modelData.batteryAvailable ? " · " + Math.round(modelData.battery * 100) + "%" : "")
                    : modelData.paired ? "Сохранено" : "Новое устройство"
                selected: modelData.connected
                interactive: !connection.running && !busy
                onClicked: root.connectDevice(modelData)
                Icon { name: modelData.connected ? "close" : modelData.paired ? "link" : "plus"; tint: Theme.muted; implicitWidth: 16; implicitHeight: 16 }
            } }
        }
        Label {
            visible: root.devices.length === 0
            Layout.margins: 12
            text: root.adapter?.discovering ? "Ищу устройства…" : "Пока нет устройств. Нажми «Найти»."; color: Theme.muted; font.pixelSize: 12
        }
    }
    Chip { text: "Сопряжение с PIN-кодом"; icon: "keyboard"; enabled: root.adapter?.enabled ?? false; onClicked: Desktop.launch(["ghostty", "-e", "bluetoothctl"]) }
    function stopScan() { if (root.adapter) root.adapter.discovering = false; startedScan = false; scanTimeout.stop(); }
    Timer { id: scanTimeout; interval: 30000; onTriggered: root.stopScan() }
    Component.onDestruction: { if (startedScan && root.adapter) root.adapter.discovering = false; }
}

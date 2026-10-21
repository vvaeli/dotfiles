import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

ColumnLayout {
    id: root
    property var snapshot: ({outputs: [], bluetoothCards: [], error: ""})
    readonly property bool busy: routing.running
    property string pendingOutput: ""
    signal navigateRequested(string page)
    function refresh() {
        if (!Desktop.preview && !devices.running && !routing.running) devices.running = true;
    }
    function route(mode, name) {
        if (busy || Desktop.preview) return;
        pendingOutput = name;
        Desktop.actionError = "";
        routing.command = ["python3", Quickshell.shellPath("audio_devices.py"), mode, name];
        routing.running = true;
    }
    Process {
        id: devices
        command: ["python3", Quickshell.shellPath("audio_devices.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.snapshot = JSON.parse(text); }
                catch (_) { root.snapshot = {outputs: [], bluetoothCards: [], error: "Не удалось получить список выходов"}; }
            }
        }
    }
    Process {
        id: routing
        stderr: StdioCollector { id: routeError }
        onExited: (code, status) => {
            if (code !== 0) Desktop.actionError = routeError.text.trim() || "Не удалось переключить звук";
            root.pendingOutput = "";
            root.refresh();
        }
    }
    Timer { interval: 2000; running: !Desktop.preview; repeat: true; onTriggered: root.refresh() }
    Component.onCompleted: refresh()
    spacing: 12
    MenuHeader {
        icon: Desktop.volumeIcon
        title: "Звук"
        active: !Desktop.muted
        subtitle: Desktop.sink?.description || "Устройство вывода недоступно"
        MdSwitch { checked: !Desktop.muted; onToggled: Desktop.toggleMute() }
    }
    MenuGroup {
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 10; Layout.rightMargin: 12
            implicitHeight: 52
            spacing: 12
            Rectangle {
                implicitWidth: 36; implicitHeight: 36; radius: 18
                color: Desktop.muted ? Theme.buttonSurface : Theme.primary
                Icon { anchors.centerIn: parent; name: Desktop.volumeIcon; tint: Desktop.muted ? Theme.textSurface : Theme.textPrimary; implicitWidth: 18; implicitHeight: 18 }
                TapHandler { onTapped: Desktop.toggleMute() }
            }
            MdSlider { Layout.fillWidth: true; enabled: !!Desktop.sink?.audio; value: Desktop.volume; onMoved: Desktop.setVolume(value) }
            Label { text: Math.round(Desktop.volume * 100) + "%"; font.pixelSize: 12; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 36 }
        }
        MenuRow {
            id: micRow
            visible: !!Desktop.source?.audio
            readonly property bool live: !(Desktop.source?.audio?.muted ?? true)
            icon: live ? "mic" : "micOff"
            title: "Микрофон"
            subtitle: Desktop.source?.description ?? ""
            onClicked: { if (Desktop.source?.audio) Desktop.source.audio.muted = !Desktop.source.audio.muted; }
            MdSwitch { checked: micRow.live; interactive: false }
        }
    }
    MenuSection {
        text: root.busy ? "Переключаю…" : "Устройство вывода"
        Chip { icon: "refresh"; flat: true; implicitWidth: 30; implicitHeight: 30; tooltip: "Обновить"; enabled: !root.busy; onClicked: root.refresh() }
    }
    MenuGroup {
        AnimatedCardList {
            Layout.fillWidth: true
            animateInsertionHeight: false
            updateDelay: 80
            cardSpacing: 2
            rowColor: Theme.cardSurface
            keyField: "name"
            source: root.snapshot.outputs
            delegate: Component { MenuRow {
                property var modelData: parent.modelData
                icon: modelData.bluetooth ? "bluetooth" : "volume"
                title: modelData.description
                subtitle: root.pendingOutput === modelData.name ? "Переключаю…" : modelData.active ? "Используется" : modelData.bluetooth ? "Bluetooth-наушники" : "Аудиовыход"
                selected: modelData.active
                interactive: !root.busy && !modelData.active
                onClicked: root.route("--select", modelData.name)
                Icon { visible: modelData.active; name: "check"; tint: Theme.primary; implicitWidth: 16; implicitHeight: 16 }
            } }
        }
        AnimatedCardList {
            Layout.fillWidth: true
            animateInsertionHeight: false
            updateDelay: 80
            cardSpacing: 2
            rowColor: Theme.cardSurface
            keyField: "name"
            source: root.snapshot.bluetoothCards
            delegate: Component { MenuRow {
                property var modelData: parent.modelData
                icon: "bluetooth"
                title: modelData.description
                subtitle: "Включить музыку · A2DP"
                interactive: !root.busy
                onClicked: root.route("--bluetooth", modelData.name)
                Icon { name: "plus"; tint: Theme.muted; implicitWidth: 16; implicitHeight: 16 }
            } }
        }
        Label {
            visible: root.snapshot.error !== "" || root.snapshot.outputs.length === 0
            Layout.margins: 12; Layout.fillWidth: true
            text: root.snapshot.error || "Нет аудиовыходов. Подключи устройство."
            color: root.snapshot.error ? Theme.error : Theme.muted
            wrapMode: Text.Wrap; font.pixelSize: 12
        }
    }
    // Input devices: any microphone can be the default, not only the headset's.
    readonly property var inputs: Pipewire.nodes.values.filter(n => n.audio && !n.isStream && !n.isSink)
        .sort((a, b) => (a.description || a.name).localeCompare(b.description || b.name))
    MenuSection { text: "Микрофон"; visible: root.inputs.length > 0 }
    MenuGroup {
        visible: root.inputs.length > 0
        Repeater {
            model: root.inputs
            MenuRow {
                id: inputRow
                required property var modelData
                readonly property bool current: Desktop.source === modelData
                icon: /bluez/i.test(modelData.name) ? "bluetooth" : "mic"
                title: modelData.description || modelData.nickname || modelData.name
                subtitle: current ? "Используется" + (Desktop.source?.audio?.muted ? " · выключен" : "") : /bluez/i.test(modelData.name) ? "Гарнитура" : "Нажми, чтобы выбрать"
                selected: current
                interactive: !current
                onClicked: Pipewire.preferredDefaultAudioSource = modelData
                Icon { visible: inputRow.current; name: "check"; tint: Theme.primary; implicitWidth: 16; implicitHeight: 16 }
            }
        }
    }
    Chip { text: "Подключить Bluetooth-наушники"; icon: "bluetooth"; onClicked: root.navigateRequested("bluetooth") }
}

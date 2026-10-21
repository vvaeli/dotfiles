import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    signal navigateRequested(string page)
    spacing: 12
    MenuHeader {
        icon: "settings"
        title: "Быстрые настройки"
        subtitle: Desktop.now.toLocaleDateString(Qt.locale("ru_RU"), "dddd, d MMMM")
    }
    GridLayout {
        columns: 2; columnSpacing: 10; rowSpacing: 10
        Layout.fillWidth: true
        Repeater {
            model: [
                {page: "wifi", icon: Desktop.networkIcon, title: "Wi-Fi", detail: Desktop.stats.wifiEnabled ? Desktop.stats.network : "Выключен", active: Desktop.stats.wifiEnabled},
                {page: "bluetooth", icon: "bluetooth", title: "Bluetooth", detail: Desktop.adapter?.enabled ? "Включён" : "Выключен", active: Desktop.adapter?.enabled ?? false},
                {page: "vpn", icon: Vpn.icon, title: "VPN", detail: Vpn.connected ? (Vpn.server?.name ?? Vpn.stateText) : Vpn.stateText, active: Vpn.connected},
                {action: "theme", icon: Theme.light ? "sun" : "sleep", title: "Тема", detail: Desktop.colorModeBusy ? "Перекрашиваю…" : Theme.light ? "Светлая" : "Тёмная", active: !Theme.light},
                {page: "notifications", icon: Desktop.dnd ? "dnd" : "bell", title: "Уведомления", detail: Desktop.dnd ? "Не беспокоить" : "Со звуком", active: !Desktop.dnd},
                {page: "power", icon: "power", title: "Сеанс", detail: "Выход и питание", active: false}
            ]
            // MD3 quick tile: tonal fill while the feature is on, chevron when it opens a page.
            Rectangle {
                id: tile
                required property var modelData
                readonly property bool busy: modelData.action === "theme" && Desktop.colorModeBusy
                Layout.fillWidth: true; Layout.preferredWidth: 140
                implicitHeight: 64; radius: 22
                color: modelData.active ? Theme.primaryContainer : Theme.cardInteractive
                Behavior on color { ColorAnimation { duration: Theme.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.effectsCurve } }
                scale: tileTap.pressed ? 0.96 : 1
                Behavior on scale { NumberAnimation { duration: Theme.fastSpatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.fastSpatialCurve } }
                readonly property color foreground: modelData.active ? Theme.textPrimaryContainer : Theme.textSurface
                Rectangle {
                    anchors.fill: parent; radius: parent.radius
                    color: tile.foreground
                    opacity: tileTap.pressed ? 0.12 : tileHover.hovered ? 0.07 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.duration } }
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 10
                    Rectangle {
                        implicitWidth: 36; implicitHeight: 36; radius: 18
                        color: tile.modelData.active ? Theme.primary : Theme.buttonSurface
                        Icon { anchors.centerIn: parent; name: tile.modelData.icon; tint: tile.modelData.active ? Theme.textPrimary : Theme.muted; implicitWidth: 18; implicitHeight: 18 }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        Label { text: tile.modelData.title; color: tile.foreground; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                        Label { text: tile.modelData.detail; color: tile.foreground; opacity: 0.75; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
                    }
                }
                HoverHandler { id: tileHover; enabled: !tile.busy; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    id: tileTap
                    enabled: !tile.busy
                    onTapped: Qt.callLater(() => {
                        if (tile.modelData.action === "theme") Desktop.toggleColorMode();
                        else root.navigateRequested(tile.modelData.page);
                    })
                }
            }
        }
    }
    MenuGroup {
        padding: 10
        ColumnLayout {
            id: sound
            Layout.fillWidth: true
            spacing: 4
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Chip { flat: true; icon: Desktop.volumeIcon; implicitWidth: 30; implicitHeight: 30; tooltip: "Выключить звук"; onClicked: Desktop.toggleMute() }
                MdSlider { Layout.fillWidth: true; implicitHeight: 30; value: Desktop.volume; onMoved: Desktop.setVolume(value) }
                Chip { flat: true; icon: "right"; implicitWidth: 30; implicitHeight: 30; tooltip: "Устройства вывода"; onClicked: root.navigateRequested("audio") }
            }
            RowLayout {
                visible: Desktop.stats.brightnessAvailable
                Layout.fillWidth: true
                Icon { name: "sun"; tint: Theme.primary }
                MdSlider {
                    Layout.fillWidth: true; from: 0.05; value: Desktop.stats.brightness
                    onMoved: brightnessDebounce.restart()
                    Timer { id: brightnessDebounce; interval: 120; onTriggered: Desktop.run(["brightnessctl", "-d", Desktop.stats.brightnessDevice, "set", Math.round(parent.value * 100) + "%"]) }
                }
            }
        }
    }
    Media { Layout.fillWidth: true; elevated: false }
}

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

ColumnLayout {
    id: root
    property bool showHeader: true
    property string pending: ""
    spacing: 12
    // A second press confirms; the request expires if it is left alone.
    onPendingChanged: if (pending) expire.restart()
    Timer { id: expire; interval: 4000; onTriggered: root.pending = "" }
    MenuHeader {
        visible: root.showHeader
        icon: "power"
        title: "Сеанс"
        subtitle: (Quickshell.env("USER") || "") + " · выход и питание"
    }
    MenuGroup {
        Repeater {
            model: [{name: "Заблокировать", detail: "Экран блокировки", icon: "lock", command: [Quickshell.env("HOME") + "/.config/hypr/scripts/lock"]},
                {name: "Сон", detail: "Приостановить работу", icon: "sleep", command: ["systemctl", "suspend"]},
                {name: "Выйти из сеанса", detail: "Закрыть Hyprland", icon: "logout", command: ["hyprctl", "dispatch", Hyprland.usingLua ? "hl.dsp.exit()" : "exit"]},
                {name: "Перезагрузить", detail: "Перезапустить компьютер", icon: "reboot", command: [Quickshell.env("HOME") + "/.config/hypr/scripts/power-action", "reboot"]},
                {name: "Выключить", detail: "Завершить работу", icon: "power", command: [Quickshell.env("HOME") + "/.config/hypr/scripts/power-action", "poweroff"]}]
            delegate: MenuRow {
                required property var modelData
                readonly property bool confirming: root.pending === modelData.name
                icon: modelData.icon
                title: confirming ? "Подтвердить: " + modelData.name.toLowerCase() : modelData.name
                subtitle: confirming ? "Нажми ещё раз" : modelData.detail
                subtitleColor: confirming ? Theme.error : Theme.muted
                danger: confirming
                onClicked: {
                    if (modelData.icon === "lock" || confirming) {
                        if (modelData.icon === "lock") Desktop.launch(modelData.command);
                        else Desktop.run(modelData.command);
                        root.pending = "";
                    } else root.pending = modelData.name;
                }
            }
        }
    }
}

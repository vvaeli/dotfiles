import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: root
    signal navigateRequested(string page)
    signal closeRequested()
    spacing: 12
    MenuHeader {
        icon: "arch"
        title: Quickshell.env("USER") || Quickshell.env("LOGNAME") || Quickshell.env("HOME").split("/").pop()
        subtitle: "Системное меню"
    }
    MenuGroup {
        Repeater {
            model: [{icon: "settings", title: "Основные настройки", detail: "Сеть, звук, календарь", page: "main"},
                {icon: "wallpaper", title: "Обои и цвета", detail: "Палитра и светлая тема", page: "wallpaper"},
                {icon: "launcher", title: "Приложения", detail: "Запуск и поиск", command: Theme.launcher},
                {icon: "folder", title: "Файлы", detail: "Thunar", command: ["thunar"]}]
            delegate: MenuRow {
                required property var modelData
                icon: modelData.icon; title: modelData.title; subtitle: modelData.detail
                onClicked: {
                    if (modelData.page) root.navigateRequested(modelData.page);
                    else { Desktop.launch(modelData.command); root.closeRequested(); }
                }
                Icon { name: "right"; tint: Theme.muted; implicitWidth: 16; implicitHeight: 16 }
            }
        }
    }
    MenuSection { text: "Сеанс" }
    Power { Layout.fillWidth: true; showHeader: false }
}

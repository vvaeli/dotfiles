import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

Card {
    id: root
    required property var notification
    property bool popupMode: false
    readonly property string applicationName: {
        const name = (notification?.appName ?? "").trim();
        if (name && name.toLowerCase() !== "уведомление") return name;
        const desktopId = notification?.desktopEntry ?? "";
        const entry = desktopId ? DesktopEntries.byId(desktopId.replace(/\.desktop$/, "")) : null;
        return entry?.name || desktopId || "Система";
    }
    // A toast sits directly on its revealed surface; only hover marks a clickable one.
    elevated: !popupMode
    color: popupMode ? (interactive && hovered ? Theme.cardHover : "transparent")
        : interactive ? hovered ? Theme.cardHover : Theme.cardInteractive : Theme.cardSurface
    readonly property bool urgent: notification?.urgency === NotificationUrgency.Critical
    readonly property color accent: urgent ? Theme.error : Theme.primary
    readonly property var actions: notification?.actions ?? []
    readonly property var defaultAction: actions.find(action => action.identifier === "default") ?? null
    readonly property var buttons: actions.filter(action => action.identifier !== "default")
    interactive: !!defaultAction
    onClicked: invoke(defaultAction)
    implicitHeight: column.implicitHeight + 32
    radius: 24
    function dismiss() {
        if (Desktop.toast === notification) Desktop.toast = null;
        notification?.dismiss();
    }
    function invoke(action) {
        action.invoke();
        if (Desktop.toast === notification) Desktop.toast = null;
    }
    ColumnLayout {
        id: column
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: parent.top; anchors.margins: 16
        spacing: 12
        RowLayout {
            Layout.fillWidth: true; spacing: 10
            Rectangle {
                implicitWidth: 32; implicitHeight: 32; radius: 12
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.12)
                Image {
                    id: appIcon
                    anchors.centerIn: parent; width: 20; height: 20
                    source: {
                        const icon = root.notification?.appIcon ?? "";
                        if (!icon) return "";
                        return icon.startsWith("/") ? "file://" + icon : icon.includes(":") ? icon : Quickshell.iconPath(icon, true);
                    }
                    fillMode: Image.PreserveAspectFit
                    visible: status === Image.Ready
                }
                Icon { anchors.centerIn: parent; name: "bell"; tint: root.accent; width: 18; height: 18; visible: !appIcon.visible }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                Label { text: root.applicationName; font.pixelSize: 15; font.weight: Font.DemiBold; color: Theme.textSurface; elide: Text.ElideRight; Layout.fillWidth: true }
                Label { visible: root.urgent; text: "Важное уведомление"; color: Theme.error; font.pixelSize: 10 }
            }
            Chip { icon: "close"; implicitWidth: 28; implicitHeight: 28; foreground: Theme.muted; tooltip: "Закрыть уведомление"; onClicked: root.dismiss() }
        }
        Item {
            Layout.fillWidth: true
            implicitHeight: messageColumn.implicitHeight
            ColumnLayout {
                id: messageColumn
                anchors.left: parent.left; anchors.right: parent.right
                spacing: 6
            Label {
                visible: text !== "" && text.trim() !== root.applicationName && text.trim().toLowerCase() !== "уведомление"; text: root.notification?.summary ?? ""
                font.pixelSize: 15; font.weight: Font.DemiBold
                wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight; Layout.fillWidth: true
            }
            Label {
                visible: text !== "" && text.trim() !== root.applicationName; text: (root.notification?.body ?? "").replace(/<br\s*\/?\s*>/gi, "\n").replace(/<\/?(?:b|i|u|a|span)(?:\s[^>]*)?>/gi, "")
                color: Theme.muted; font.pixelSize: 12; lineHeight: 1.25
                wrapMode: Text.Wrap; maximumLineCount: 6; elide: Text.ElideRight; Layout.fillWidth: true
            }
            }

        }
        Flow {
            Layout.fillWidth: true
            visible: root.buttons.length > 0
            spacing: 8
            Repeater {
                model: root.buttons
                Chip {
                    required property var modelData
                    required property int index
                    text: modelData.text
                    selected: index === 0
                    maximumTextWidth: Math.max(40, column.width - 24)
                    onClicked: root.invoke(modelData)
                }
            }
        }
    }
}

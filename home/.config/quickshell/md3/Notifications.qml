import QtQuick
import QtQuick.Layouts

ColumnLayout {
    spacing: 12
    MenuHeader {
        icon: Desktop.dnd ? "dnd" : "bell"
        title: "Уведомления"
        active: !Desktop.dnd
        subtitle: notificationList.count ? notificationList.count + " в журнале" : "Нет новых"
        Chip { icon: "close"; text: "Очистить"; implicitHeight: 32; enabled: Desktop.notifications.length > 0; onClicked: Desktop.clearNotifications() }
    }
    MenuGroup {
        MenuRow {
            icon: "dnd"
            title: "Не беспокоить"
            subtitle: Desktop.dnd ? "Баннеры скрыты, журнал пополняется" : "Баннеры и звук включены"
            selected: Desktop.dnd
            onClicked: { Desktop.dnd = !Desktop.dnd; Desktop.toast = null; }
            MdSwitch { checked: Desktop.dnd; interactive: false }
        }
    }
    Item {
        Layout.fillWidth: true
        implicitHeight: notificationList.count === 0 ? 120 : 0
        visible: implicitHeight > 0
        clip: true
        Behavior on implicitHeight { NumberAnimation { duration: Theme.slowEffectsDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slowEffectsCurve } }
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8
            opacity: notificationList.count === 0 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.duration } }
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 56; implicitHeight: 56; radius: 28; color: Theme.cardSurface
                Icon { anchors.centerIn: parent; name: "bell"; tint: Theme.muted; implicitWidth: 24; implicitHeight: 24 }
            }
            Label { Layout.alignment: Qt.AlignHCenter; text: "Пока всё спокойно"; color: Theme.muted; font.pixelSize: 12 }
        }
    }
    AnimatedCardList {
        id: notificationList
        Layout.fillWidth: true
        keyField: "id"
        // Native notifications are destroyed on dismissal. Keep their visual
        // data alive until the outgoing card has finished collapsing.
        source: Desktop.notifications.slice().reverse().map(n => ({
            id: n.id, appName: n.appName, desktopEntry: n.desktopEntry,
            appIcon: n.appIcon, summary: n.summary, body: n.body,
            urgency: n.urgency, actions: n.actions,
            dismiss: function() {
                if (Desktop.toast === n) Desktop.toast = null;
                n.dismiss();
            }
        }))
        delegate: Component { NotificationCard {
            property var modelData: parent.modelData
            notification: modelData
            elevated: false
            Layout.fillWidth: true
        }
        }
    }
}

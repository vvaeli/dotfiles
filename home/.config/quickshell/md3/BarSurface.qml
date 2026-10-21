import QtQuick
import QtQuick.Layouts
import Quickshell

// The bar: system button, workspaces and the focused window on the left; the clock with
// what is playing in the middle; the tray, a status capsule and notifications on the right.
// Groups sit in tonal capsules on the frame colour.
Rectangle {
    id: bar
    required property var panel
    anchors.fill: parent
    color: Theme.surface

    // ── Left ────────────────────────────────────────────────────────────────────
    RowLayout {
        id: left
        anchors.left: parent.left; anchors.leftMargin: Theme.frameWidth + 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Chip {
            id: sessionButton
            flat: !(panel.menuOpen && panel.page === "system")
            selected: panel.menuOpen && panel.page === "system"
            icon: "arch"; iconSize: 18
            implicitWidth: 40; implicitHeight: 34
            foreground: selected ? Theme.textPrimary : Theme.primary
            tooltip: "Системное меню"
            onClicked: panel.togglePage("system", sessionButton)
        }
        Flickable {
            Layout.preferredWidth: Math.min(workspaces.implicitWidth, panel.width * 0.3)
            Layout.preferredHeight: 34
            contentWidth: workspaces.implicitWidth
            clip: true; boundsBehavior: Flickable.StopAtBounds
            Workspaces { id: workspaces; monitor: panel.monitor }
        }
        // Focused window: its icon and title, crossfading when focus moves.
        RowLayout {
            id: focused
            visible: !panel.compact
            Layout.leftMargin: 4
            Layout.maximumWidth: Math.max(0, (nowPlaying.visible ? nowPlaying.x : clock.x) - left.x - x - 24)
            spacing: 8
            readonly property var window: {
                const windows = panel.monitor?.activeWorkspace?.toplevels.values ?? [];
                return windows.find(w => w.activated) ?? null;
            }
            readonly property string appId: window?.lastIpcObject?.class ?? window?.wayland?.appId ?? ""
            opacity: window ? 1 : 0.6
            Behavior on opacity { NumberAnimation { duration: Theme.duration } }
            Image {
                visible: focused.window && status === Image.Ready
                source: Desktop.iconForApp(focused.appId)
                sourceSize: Qt.size(36, 36)
                Layout.preferredWidth: 18; Layout.preferredHeight: 18
            }
            Text {
                Layout.fillWidth: true
                text: focused.window?.title || "Рабочий стол"
                elide: Text.ElideRight
                font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium
                color: Theme.muted
            }
        }
    }

    // ── Centre: the clock stays in the exact middle (the control centre opens under it);
    // what is playing hangs off its left side.
    Item {
        anchors.fill: parent
        Rectangle {
            id: nowPlaying
            anchors.right: clock.left; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: implicitWidth; height: implicitHeight
            readonly property var player: Desktop.player
            readonly property bool playing: !!player && player.isPlaying
            visible: !panel.compact && implicitWidth > 1
            implicitWidth: playing ? playingRow.implicitWidth + 24 : 0
            implicitHeight: 34
            radius: height / 2
            readonly property bool open: panel.menuOpen && panel.page === "player"
            color: open ? Theme.primaryContainer : Theme.cardSurface
            Behavior on color { ColorAnimation { duration: Theme.duration } }
            clip: true
            Behavior on implicitWidth { NumberAnimation { duration: Theme.spatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.spatialCurve } }
            Rectangle {
                anchors.fill: parent; radius: parent.radius; color: Theme.textSurface
                opacity: mediaTap.pressed ? 0.14 : mediaHover.hovered ? 0.07 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.duration } }
            }
            RowLayout {
                id: playingRow
                x: 12; anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                // Three bars bouncing while music plays.
                Row {
                    spacing: 2
                    Layout.preferredHeight: 14
                    Repeater {
                        model: 3
                        Rectangle {
                            required property int index
                            width: 3; radius: 1.5
                            anchors.bottom: parent.bottom
                            color: Theme.primary
                            property real level: 0.4
                            height: 4 + 10 * level
                            SequentialAnimation on level {
                                running: nowPlaying.playing && bar.visible
                                loops: Animation.Infinite
                                NumberAnimation { to: 1; duration: 260 + index * 90; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0.2; duration: 300 + index * 70; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                }
                Text {
                    Layout.maximumWidth: 260
                    text: [nowPlaying.player?.trackTitle, nowPlaying.player?.trackArtist].filter(t => t).join(" — ")
                    elide: Text.ElideRight
                    font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium
                    color: nowPlaying.open ? Theme.textPrimaryContainer : Theme.textSurface
                }
            }
            HoverHandler { id: mediaHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                id: mediaTap
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                onTapped: (point, button) => Qt.callLater(() => {
                    if (button === Qt.MiddleButton) nowPlaying.player?.togglePlaying();
                    else panel.togglePage("player", nowPlaying);
                })
            }
            WheelHandler {
                onWheel: wheel => { if (wheel.angleDelta.y < 0) nowPlaying.player?.next(); else nowPlaying.player?.previous(); wheel.accepted = true; }
            }
        }
        Rectangle {
            id: clock
            anchors.centerIn: parent
            width: implicitWidth; height: implicitHeight
            readonly property bool open: panel.menuOpen && (panel.page === "main" || panel.page === "settings")
            implicitWidth: clockRow.implicitWidth + 28
            implicitHeight: 34
            radius: height / 2
            color: open ? Theme.primaryContainer : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.duration } }
            readonly property color foreground: open ? Theme.textPrimaryContainer : Theme.textSurface
            Rectangle {
                anchors.fill: parent; radius: parent.radius; color: clock.foreground
                opacity: clockTap.pressed ? 0.14 : clockHover.hovered ? 0.07 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.duration } }
            }
            Row {
                id: clockRow
                anchors.centerIn: parent
                spacing: 8
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(Desktop.now, "HH:mm")
                    font.family: Theme.font; font.pixelSize: 15; font.weight: Font.Bold
                    color: clock.foreground
                }
                Text {
                    visible: !panel.compact
                    anchors.verticalCenter: parent.verticalCenter
                    text: Desktop.now.toLocaleDateString(Qt.locale("ru_RU"), "ddd, d MMMM")
                    font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium
                    color: clock.open ? clock.foreground : Theme.muted
                }
            }
            Accessible.role: Accessible.Button
            Accessible.name: "Центр управления"
            HoverHandler { id: clockHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { id: clockTap; onTapped: Qt.callLater(() => panel.togglePage("main", clock)) }
        }
    }

    // ── Right ───────────────────────────────────────────────────────────────────
    RowLayout {
        id: right
        anchors.right: parent.right; anchors.rightMargin: Theme.frameWidth + 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Rectangle {
            visible: tray.implicitWidth > 0
            implicitWidth: trayView.width + 8
            implicitHeight: 38
            radius: height / 2
            color: Theme.cardSurface
            Flickable {
                id: trayView
                x: 4; anchors.verticalCenter: parent.verticalCenter
                width: Math.min(tray.implicitWidth, panel.width * 0.18)
                height: 36
                contentWidth: tray.implicitWidth
                clip: true; boundsBehavior: Flickable.StopAtBounds
                Tray { id: tray; panelWindow: panel }
            }
        }
        // Status capsule: each icon opens its own menu.
        Rectangle {
            implicitWidth: status.implicitWidth + 8
            implicitHeight: 38
            radius: height / 2
            color: Theme.cardSurface
            RowLayout {
                id: status
                x: 4; anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                StatusButton {
                    panel: bar.panel
                    visible: Desktop.keyboardLayout !== ""
                    text: /Russian|Русский/i.test(Desktop.keyboardLayout) ? "RU" : /English|Английский/i.test(Desktop.keyboardLayout) ? "EN" : Desktop.keyboardLayout.slice(0, 2).toUpperCase()
                    tooltip: "Раскладка · Caps Lock"
                    onClicked: Desktop.run(["hyprctl", "switchxkblayout", "all", "next"])
                }
                StatusButton {
                    panel: bar.panel
                    id: networkButton
                    icon: Desktop.networkIcon; page: "wifi"
                    tooltip: Desktop.stats.network
                    onClicked: panel.togglePage("wifi", networkButton)
                }
                StatusButton {
                    panel: bar.panel
                    id: vpnButton
                    icon: Vpn.icon; page: "vpn"
                    foreground: open ? Theme.textPrimary : Vpn.connected ? Theme.primary : Vpn.color
                    property real pulse: 1
                    opacity: Vpn.transitioning ? 0.45 + 0.55 * pulse : 1
                    tooltip: "VPN · ПКМ: подключить/отключить"
                    onClicked: mouse => { if (mouse.button === Qt.RightButton) Vpn.toggle(); else panel.togglePage("vpn", vpnButton); }
                    SequentialAnimation on pulse {
                        running: Vpn.transitioning; loops: Animation.Infinite
                        onRunningChanged: { if (!running) vpnButton.pulse = 1; }
                        NumberAnimation { to: 0; duration: 600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
                    }
                }
                StatusButton {
                    panel: bar.panel
                    id: bluetoothButton
                    visible: panel.width >= 800
                    icon: "bluetooth"; page: "bluetooth"
                    foreground: open ? Theme.textPrimary : Desktop.bluetoothColor
                    tooltip: "Bluetooth"
                    onClicked: panel.togglePage("bluetooth", bluetoothButton)
                }
                StatusButton {
                    panel: bar.panel
                    id: audioButton
                    icon: Desktop.volumeIcon; page: "audio"
                    tooltip: "Звук · прокрутка: громкость · ПКМ: выключить"
                    onClicked: mouse => { if (mouse.button === Qt.RightButton) Desktop.toggleMute(); else panel.togglePage("audio", audioButton); }
                    onScrolled: delta => Desktop.setVolume(Desktop.volume + (delta > 0 ? 0.05 : -0.05))
                }
                StatusButton {
                    panel: bar.panel
                    visible: Desktop.hasBattery
                    icon: Desktop.battery?.state === 1 ? "charging" : "battery"
                    text: Math.round((Desktop.battery?.percentage ?? 0) * 100) + "%"
                    foreground: (Desktop.battery?.percentage ?? 1) < 0.2 ? Theme.error : Theme.textSurface
                    tooltip: "Батарея"
                    onClicked: panel.togglePage("main", clock)
                }
            }
        }
        // Notifications with an unread badge.
        Item {
            implicitWidth: 38; implicitHeight: 38
            StatusButton {
                    panel: bar.panel
                id: notificationsButton
                anchors.fill: parent
                icon: Desktop.dnd ? "dnd" : "bell"; page: "notifications"
                color: open ? Theme.primary : Theme.cardSurface
                tooltip: "Уведомления"
                onClicked: { Desktop.toast = null; panel.togglePage("notifications", notificationsButton); }
            }
            Rectangle {
                readonly property int count: Desktop.notifications.length
                visible: count > 0 && !Desktop.dnd
                x: parent.width - width + 2; y: -1
                width: Math.max(16, badgeText.implicitWidth + 8); height: 16; radius: 8
                color: Theme.primary
                border.width: 2; border.color: Theme.surface
                scale: visible ? 1 : 0
                Behavior on scale { NumberAnimation { duration: Theme.fastSpatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.fastSpatialCurve } }
                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: parent.count > 99 ? "99+" : parent.count
                    font.family: Theme.font; font.pixelSize: 9; font.weight: Font.Bold
                    color: Theme.textPrimary
                }
            }
        }
    }
}

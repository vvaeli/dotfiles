import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

// Control centre. Left: quick tiles that toggle in place (their label opens the full page),
// sound with a per-app mixer, the player. Right: calendar, system load, recent notifications.
ColumnLayout {
    id: root
    signal navigateRequested(string page)
    signal closeRequested()
    spacing: 14
    readonly property real columnWidth: (width - 12) / 2
    readonly property string user: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "user"
    readonly property string greeting: {
        const hour = Desktop.now.getHours();
        return hour < 5 ? "Доброй ночи" : hour < 12 ? "Доброе утро" : hour < 18 ? "Добрый день" : "Добрый вечер";
    }
    // Actions that capture or cover the screen run once this menu has closed.
    function afterClose(args) {
        root.closeRequested();
        Desktop.launch(["sh", "-c", "sleep 0.45; exec \"$@\"", "md3"].concat(args));
    }

    // ── Header: greeting, clock and session shortcuts ────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Rectangle {
            implicitWidth: 44; implicitHeight: 44; radius: 22
            color: Theme.primaryContainer
            Label { anchors.centerIn: parent; text: root.user.charAt(0).toUpperCase(); color: Theme.textPrimaryContainer; font.pixelSize: 18; font.weight: Font.DemiBold }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Label { text: root.greeting + ", " + root.user; font.pixelSize: 18; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
            Label {
                text: Desktop.now.toLocaleDateString(Qt.locale("ru_RU"), "dddd, d MMMM") + (Desktop.uptime > 0 ? " · работает " + Desktop.formatUptime(Desktop.uptime) : "")
                color: Theme.muted; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true
            }
        }
        Label { text: Qt.formatDateTime(Desktop.now, "HH:mm"); font.pixelSize: 30; color: Theme.primary; Layout.rightMargin: 6 }
        Repeater {
            model: [{icon: "selectRegion", tip: "Скриншот области", run: () => root.afterClose(["qs", "-c", "md3", "ipc", "call", "screenshot", "region"])},
                {icon: "clipboard", tip: "Буфер обмена", run: () => { root.closeRequested(); Desktop.toggleClipboard(); }},
                {icon: "lock", tip: "Заблокировать", run: () => root.afterClose([Quickshell.env("HOME") + "/.config/hypr/scripts/lock"])},
                {icon: "power", tip: "Сеанс", run: () => root.navigateRequested("power")}]
            Chip {
                required property var modelData
                icon: modelData.icon; tooltip: modelData.tip
                implicitWidth: 40; implicitHeight: 40
                onClicked: modelData.run()
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 4; columnSpacing: 8; rowSpacing: 8
        QuickTile {
            Layout.fillWidth: true; Layout.preferredWidth: 1
            readonly property bool wired: Desktop.stats.networkType === "ethernet"
            icon: Desktop.stats.wifiEnabled ? (Desktop.stats.networkType === "wifi" ? Desktop.networkIcon : "wifi") : "offline"
            title: "Wi-Fi"
            detail: !Desktop.stats.wifiEnabled ? "Выключен" : Desktop.stats.networkType === "wifi" ? Desktop.stats.network : "Не подключён"
            active: Desktop.stats.wifiEnabled
            hasPage: true
            onToggled: Desktop.setWifiEnabled(!Desktop.stats.wifiEnabled)
            onOpened: root.navigateRequested("wifi")
        }
        QuickTile {
            Layout.fillWidth: true; Layout.preferredWidth: 1
            readonly property var connected: (Desktop.adapter?.devices.values ?? []).filter(d => d.connected)
            icon: "bluetooth"
            title: "Bluetooth"
            detail: !Desktop.adapter ? "Недоступен" : !Desktop.adapter.enabled ? "Выключен"
                : connected.length ? (connected[0].name || connected[0].address) + (connected.length > 1 ? " +" + (connected.length - 1) : "") : "Включён"
            active: Desktop.adapter?.enabled ?? false
            busy: !Desktop.adapter
            hasPage: true
            onToggled: Desktop.adapter.enabled = !Desktop.adapter.enabled
            onOpened: root.navigateRequested("bluetooth")
        }
        QuickTile {
            Layout.fillWidth: true; Layout.preferredWidth: 1
            icon: Vpn.icon
            title: "VPN"
            detail: Vpn.connected ? (Vpn.server?.name ?? Vpn.stateText) : Vpn.stateText
            active: Vpn.connected
            busy: !Vpn.daemonAvailable || Vpn.transitioning
            hasPage: true
            onToggled: Vpn.toggle()
            onOpened: root.navigateRequested("vpn")
        }
        QuickTile {
            Layout.fillWidth: true; Layout.preferredWidth: 1
            readonly property bool live: !(Desktop.source?.audio?.muted ?? true)
            icon: live ? "mic" : "micOff"
            title: "Микрофон"
            detail: !Desktop.source?.audio ? "Нет устройства" : live ? Math.round((Desktop.source.audio.volume ?? 0) * 100) + "%" : "Выключен"
            active: live
            busy: !Desktop.source?.audio
            hasPage: true
            onToggled: Desktop.toggleMic()
            onOpened: root.navigateRequested("audio")
        }
        QuickTile {
            Layout.fillWidth: true; Layout.preferredWidth: 1
            icon: "dnd"
            title: "Тишина"
            detail: Desktop.dnd ? "Баннеры скрыты" : Desktop.notifications.length ? Desktop.notifications.length + " в журнале" : "Выключено"
            active: Desktop.dnd
            hasPage: true
            onToggled: { Desktop.dnd = !Desktop.dnd; if (Desktop.dnd) Desktop.toast = null; }
            onOpened: root.navigateRequested("notifications")
        }
        QuickTile {
            Layout.fillWidth: true; Layout.preferredWidth: 1
            icon: "palette"
            title: "Тема"
            detail: Desktop.colorModeBusy ? "Перекрашиваю…" : Theme.light ? "Светлая" : "Тёмная"
            active: !Theme.light
            busy: Desktop.colorModeBusy
            hasPage: true
            onToggled: Desktop.toggleColorMode()
            onOpened: root.navigateRequested("wallpaper")
        }
        QuickTile {
            Layout.fillWidth: true; Layout.preferredWidth: 1
            icon: "nightLight"
            title: "Ночной свет"
            detail: Desktop.nightMode === "auto" ? (Desktop.nightLight ? "Авто · включён" : "Авто · с " + Desktop.formatMinutes(Desktop.nightStart))
                : Desktop.nightLight ? Desktop.nightTemperature + " K" : "Выключен"
            active: Desktop.nightLight
            hasPage: true
            onToggled: Desktop.setNightMode(Desktop.nightMode === "off" ? "on" : "off")
            onOpened: root.navigateRequested("nightlight")
        }
        QuickTile {
            Layout.fillWidth: true; Layout.preferredWidth: 1
            icon: "coffee"
            title: "Не засыпать"
            detail: Desktop.caffeine ? "Экран не погаснет" : "Выключено"
            active: Desktop.caffeine
            onToggled: Desktop.caffeine = !Desktop.caffeine
        }
    }

    // ── Player: a wide banner tinted by its cover ────────────────────────────────
    Rectangle {
        id: media
        Layout.fillWidth: true
        readonly property var players: Mpris.players.values
        property int chosen: -1
        // A playing player first, then one with a track loaded; idle browser tabs come last.
        readonly property var player: chosen >= 0 && chosen < players.length ? players[chosen]
            : players.find(p => p.isPlaying) ?? players.find(p => p.trackTitle) ?? null
        visible: !!player
        implicitHeight: 116
        radius: 28
        color: Theme.cardSurface
        function time(s) { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }
        Timer {
            interval: 1000; repeat: true
            running: !!media.player && media.player.isPlaying && media.visible
            onTriggered: media.player.positionChanged()
        }
        // Blurred cover across the whole banner, clipped exactly to the banner's rounded shape.
        // The cover is drawn larger than the banner so the blur has no faded edges inside it.
        ClippingRectangle {
            anchors.fill: parent; radius: parent.radius
            color: "transparent"
            Image {
                id: backdrop
                anchors.fill: parent; anchors.margins: -48
                source: media.player?.trackArtUrl || ""
                fillMode: Image.PreserveAspectCrop
                visible: false
                asynchronous: true
                sourceSize.width: 256
            }
            MultiEffect {
                anchors.fill: backdrop
                source: backdrop
                autoPaddingEnabled: false
                visible: backdrop.status === Image.Ready
                blurEnabled: true; blur: 1; blurMax: 64
                saturation: 0.3
                opacity: Theme.light ? 0.4 : 0.45
            }
        }
        RowLayout {
            anchors.fill: parent; anchors.margins: 14
            spacing: 16
            Item {
                implicitWidth: 88; implicitHeight: 88
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: Qt.callLater(() => root.navigateRequested("player")) }
                Rectangle { id: coverMask; anchors.fill: parent; radius: 20; visible: false; layer.enabled: true }
                Rectangle {
                    anchors.fill: parent; radius: 20; color: Theme.secondaryContainer
                    Icon { anchors.centerIn: parent; name: "music"; tint: Theme.primary; implicitWidth: 30; implicitHeight: 30 }
                }
                Image {
                    anchors.fill: parent
                    source: media.player?.trackArtUrl || ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                    asynchronous: true
                    sourceSize.width: 176
                    layer.enabled: true
                    layer.effect: MultiEffect { maskEnabled: true; maskSource: coverMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1 }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: Qt.callLater(() => root.navigateRequested("player")) }
                        Label { Layout.fillWidth: true; text: media.player?.trackTitle || "Без названия"; elide: Text.ElideRight; font.weight: Font.DemiBold; font.pixelSize: 16 }
                        Label { Layout.fillWidth: true; text: [media.player?.trackArtist, media.player?.trackAlbum].filter(t => t).join(" · "); visible: text !== ""; elide: Text.ElideRight; color: Theme.muted; font.pixelSize: 12 }
                    }
                    // With several players the source name switches between them.
                    Chip {
                        Layout.alignment: Qt.AlignTop
                        text: media.player?.identity ?? ""
                        textSize: 11; implicitHeight: 26; maximumTextWidth: 110
                        icon: media.players.length > 1 ? "refresh" : ""; iconSize: 12
                        flat: media.players.length < 2
                        enabled: media.players.length > 1
                        opacity: 1
                        onClicked: media.chosen = (Math.max(0, media.players.indexOf(media.player)) + 1) % media.players.length
                    }
                }
                Item { Layout.fillHeight: true }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    readonly property bool timed: (media.player?.lengthSupported ?? false) && (media.player?.length ?? 0) > 0
                    Label { visible: parent.timed; text: media.time(media.player?.position ?? 0); font.pixelSize: 11; color: Theme.muted; Layout.preferredWidth: 32 }
                    MdSlider {
                        visible: parent.timed
                        Layout.fillWidth: true
                        implicitHeight: 28
                        to: Math.max(1, media.player?.length ?? 1)
                        value: media.player?.position ?? 0
                        enabled: media.player?.canSeek ?? false
                        onMoved: media.player.position = value
                    }
                    Label { visible: parent.timed; text: media.time(media.player?.length ?? 0); font.pixelSize: 11; color: Theme.muted }
                    Item { visible: !parent.timed; Layout.fillWidth: true }
                    Chip { icon: "previous"; flat: true; implicitWidth: 38; implicitHeight: 38; enabled: media.player?.canGoPrevious ?? false; onClicked: media.player.previous() }
                    Chip { icon: media.player?.isPlaying ? "pause" : "play"; iconSize: 20; selected: true; implicitWidth: 50; implicitHeight: 50; enabled: media.player?.canTogglePlaying ?? false; onClicked: media.player.togglePlaying() }
                    Chip { icon: "next"; flat: true; implicitWidth: 38; implicitHeight: 38; enabled: media.player?.canGoNext ?? false; onClicked: media.player.next() }
                }
            }
        }
    }

    // Sound and load on the left, the calendar on the right; both columns end on the same line.
    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        ColumnLayout {
            Layout.preferredWidth: root.columnWidth
            Layout.maximumWidth: root.columnWidth
            Layout.fillHeight: true
            spacing: 12
        // ── Sound: output, microphone, and every app that is playing ─────────
        MenuGroup {
            id: sound
            padding: 8
            spacing: 0
            readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.isSink && n.audio)
            PwObjectTracker { objects: sound.streams }
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8; Layout.rightMargin: 2
                implicitHeight: 28
                Label {
                    text: Desktop.sink?.description || "Нет устройства вывода"
                    color: Theme.muted; font.pixelSize: 11; font.weight: Font.Medium
                    elide: Text.ElideRight; Layout.fillWidth: true
                }
                Chip { icon: "right"; flat: true; implicitWidth: 28; implicitHeight: 28; iconSize: 14; tooltip: "Устройства"; onClicked: root.navigateRequested("audio") }
            }
            VolumeRow {
                icon: Desktop.volumeIcon
                active: !Desktop.muted
                value: Desktop.volume
                enabled: !!Desktop.sink?.audio
                onIconTapped: Desktop.toggleMute()
                onMoved: v => Desktop.setVolume(v)
            }
            VolumeRow {
                visible: !!Desktop.source?.audio
                icon: Desktop.source?.audio?.muted ? "micOff" : "mic"
                active: !(Desktop.source?.audio?.muted ?? true)
                value: Desktop.source?.audio?.volume ?? 0
                onIconTapped: Desktop.toggleMic()
                onMoved: v => { Desktop.source.audio.muted = false; Desktop.source.audio.volume = v; }
            }
            Label {
                visible: sound.streams.length > 0
                text: "Приложения"
                color: Theme.muted; font.pixelSize: 11; font.weight: Font.Medium
                Layout.leftMargin: 8; Layout.topMargin: 6; Layout.bottomMargin: 2
            }
            Repeater {
                model: sound.streams.slice(0, 4)
                VolumeRow {
                    required property var modelData
                    readonly property var props: modelData.properties ?? {}
                    readonly property string iconName: props["application.icon-name"]
                        || DesktopEntries.heuristicLookup(props["application.name"] || props["application.process.binary"] || "")?.icon
                        || props["application.process.binary"] || ""
                    appIcon: iconName ? Quickshell.iconPath(iconName, true) : ""
                    icon: "music"
                    caption: props["application.name"] || modelData.description || modelData.name
                    active: !modelData.audio.muted
                    value: modelData.audio.volume
                    onIconTapped: modelData.audio.muted = !modelData.audio.muted
                    onMoved: v => { modelData.audio.muted = false; modelData.audio.volume = v; }
                }
            }
        }

        MenuGroup {
            padding: 12
            Layout.fillHeight: true
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Gauge { value: Desktop.stats.cpu / 100; title: "Процессор"; detail: Desktop.stats.cpu + "%" }
                Gauge { value: Desktop.stats.ram / 100; title: "Память"; detail: Desktop.stats.ramUsed + " / " + Math.round(Desktop.stats.ramTotal) + " ГБ" }
                Gauge { value: Desktop.stats.disk / 100; title: "Диск"; detail: Math.round(Desktop.stats.diskFree) + " ГБ своб." }
            }
            Item { Layout.fillHeight: true }
            // Opens btop for the details.
            TapHandler { onTapped: root.afterClose(["ghostty", "-e", "btop"]) }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
        }
        ColumnLayout {
            Layout.preferredWidth: root.columnWidth
            Layout.maximumWidth: root.columnWidth
            Layout.fillHeight: true
            spacing: 12
        MenuGroup {
            padding: 12
            Layout.fillHeight: true
            Calendar { Layout.fillWidth: true; compact: true; showClock: false; spacing: 8 }
            Item { Layout.fillHeight: true }
        }
        }
    }
    MenuSection {
        visible: Desktop.notifications.length > 0
        text: "Последние уведомления"
        Chip { text: "Все · " + Desktop.notifications.length; implicitHeight: 28; onClicked: root.navigateRequested("notifications") }
    }
    MenuGroup {
        visible: Desktop.notifications.length > 0
        Repeater {
            model: Desktop.notifications.slice(-2).reverse()
            MenuRow {
                required property var modelData
                icon: modelData.urgency === 2 ? "bolt" : "bell"
                title: modelData.summary || modelData.appName
                subtitle: [modelData.appName, (modelData.body ?? "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ")].filter(t => t).join(" · ")
                onClicked: {
                    const action = (modelData.actions ?? []).find(a => a.identifier === "default");
                    if (action) { action.invoke(); root.closeRequested(); }
                    else root.navigateRequested("notifications");
                }
            }
        }
    }
    // Slider row used for the output, the microphone and each app in the mixer.
    component VolumeRow: RowLayout {
        id: volumeRow
        property string icon: ""
        property string appIcon: ""
        property string caption: ""
        property bool active: true
        property real value: 0
        signal iconTapped()
        signal moved(real value)
        Layout.fillWidth: true
        Layout.leftMargin: 4; Layout.rightMargin: 6
        implicitHeight: 40
        spacing: 10
        Rectangle {
            implicitWidth: 32; implicitHeight: 32; radius: 16
            color: volumeRow.appIcon ? "transparent" : volumeRow.caption ? Theme.buttonSurface : volumeRow.active ? Theme.primary : Theme.buttonSurface
            Behavior on color { ColorAnimation { duration: Theme.duration } }
            Icon { visible: !volumeRow.appIcon; anchors.centerIn: parent; name: volumeRow.icon; tint: volumeRow.caption ? Theme.muted : volumeRow.active ? Theme.textPrimary : Theme.textSurface; implicitWidth: 16; implicitHeight: 16 }
            Image { visible: !!volumeRow.appIcon; anchors.centerIn: parent; width: 24; height: 24; source: volumeRow.appIcon; sourceSize: Qt.size(48, 48); opacity: volumeRow.active ? 1 : 0.4 }
            TapHandler { onTapped: volumeRow.iconTapped() }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: -4
            Label { visible: volumeRow.caption !== ""; text: volumeRow.caption; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true; Layout.topMargin: 2 }
            MdSlider { Layout.fillWidth: true; implicitHeight: volumeRow.caption ? 26 : 32; value: volumeRow.value; onMoved: volumeRow.moved(value) }
        }
        Label { text: Math.round(volumeRow.value * 100) + "%"; font.pixelSize: 11; color: Theme.muted; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 32 }
    }

    // Load ring with the value inside and a caption under it.
    component Gauge: ColumnLayout {
        id: gauge
        property real value: 0
        property string title: ""
        property string detail: ""
        Layout.fillWidth: true; Layout.preferredWidth: 1
        spacing: 4
        property real shown: value
        Behavior on shown { NumberAnimation { duration: 600; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
        onShownChanged: ring.requestPaint()
        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 56; implicitHeight: 56
            Canvas {
                id: ring
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const c = width / 2, r = c - 4, start = Math.PI * 0.75, sweep = Math.PI * 1.5;
                    ctx.lineWidth = 6; ctx.lineCap = "round";
                    ctx.strokeStyle = Theme.secondaryContainer;
                    ctx.beginPath(); ctx.arc(c, c, r, start, start + sweep); ctx.stroke();
                    const v = Math.max(0, Math.min(1, gauge.shown));
                    if (v > 0.005) {
                        ctx.strokeStyle = v > 0.85 ? Theme.error : Theme.primary;
                        ctx.beginPath(); ctx.arc(c, c, r, start, start + sweep * v); ctx.stroke();
                    }
                }
                Connections { target: Theme; function onPaletteChanged() { ring.requestPaint(); } }
            }
            Label { anchors.centerIn: parent; text: Math.round(gauge.value * 100); font.pixelSize: 15; font.weight: Font.DemiBold }
        }
        Label { text: gauge.title; font.pixelSize: 11; font.weight: Font.Medium; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true; elide: Text.ElideRight }
        Label { text: gauge.detail; font.pixelSize: 10; color: Theme.muted; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true; elide: Text.ElideRight }
    }
}

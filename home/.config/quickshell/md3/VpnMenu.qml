import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    readonly property var subscription: Vpn.subscriptions.find(s => s.id === Vpn.subscriptionId) ?? Vpn.subscriptions[0] ?? null
    spacing: 12
    Component.onCompleted: Vpn.refresh()
    MenuHeader {
        icon: Vpn.icon
        title: "VPN"
        active: Vpn.connected
        subtitle: !Vpn.daemonAvailable ? "Демон не запущен: sudo berylliumd start"
            : Vpn.stateText + (root.subscription ? " · " + root.subscription.name : "")
        subtitleColor: Vpn.daemonAvailable ? Theme.muted : Theme.error
        MdSwitch {
            checked: Vpn.connected
            enabled: Vpn.daemonAvailable && !Vpn.transitioning
            onToggled: Vpn.toggle()
        }
    }
    Card {
        presented: Vpn.daemonAvailable && (Vpn.connected || Vpn.transitioning) && !!Vpn.server
        elevated: false
        Layout.fillWidth: true
        implicitHeight: session.implicitHeight + 28
        ColumnLayout {
            id: session
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 14
            spacing: 10
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                Icon { name: Vpn.icon; tint: Vpn.color }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 3
                    Label { text: Vpn.server?.name ?? ""; elide: Text.ElideRight; Layout.fillWidth: true; font.weight: Font.DemiBold }
                    Label {
                        text: [Vpn.describe(Vpn.server), Vpn.modeTitle(Vpn.mode), (Vpn.status.core ?? "").replace("CORE_KIND_", "").toLowerCase().replace("_", "-")]
                            .filter(p => p).join(" · ")
                        font.pixelSize: 11; color: Theme.muted; elide: Text.ElideRight; Layout.fillWidth: true
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Repeater {
                    model: [
                        {icon: "download", value: Vpn.formatRate(Vpn.status.traffic?.download_bytes_per_sec), detail: Vpn.formatBytes(Vpn.status.traffic?.download_bytes_total)},
                        {icon: "upload", value: Vpn.formatRate(Vpn.status.traffic?.upload_bytes_per_sec), detail: Vpn.formatBytes(Vpn.status.traffic?.upload_bytes_total)},
                        {icon: "timer", value: Vpn.formatUptime(Vpn.status.connected_since, Desktop.now) || "—", detail: Vpn.status.local_proxy ?? ""}
                    ]
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; Layout.preferredWidth: 1
                        implicitHeight: 54; radius: 14; color: Theme.buttonSurface
                        ColumnLayout {
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; anchors.topMargin: 8; anchors.bottomMargin: 8
                            spacing: 2
                            RowLayout {
                                spacing: 5; Layout.fillWidth: true
                                Icon { name: modelData.icon; tint: Theme.primary; implicitWidth: 14; implicitHeight: 14 }
                                Label { text: modelData.value; font.pixelSize: 12; font.weight: Font.Medium; elide: Text.ElideRight; Layout.fillWidth: true }
                            }
                            Label { text: modelData.detail; font.pixelSize: 10; color: Theme.muted; elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                    }
                }
            }
        }
    }
    MenuSection { text: "Режим"; visible: Vpn.daemonAvailable }
    RowLayout {
        Layout.fillWidth: true; spacing: 6
        visible: Vpn.daemonAvailable
        Repeater {
            model: ["tun", "proxy", "local"]
            Chip {
                required property string modelData
                Layout.fillWidth: true; Layout.preferredWidth: 1
                text: Vpn.modeTitle(modelData).replace("Системный прокси", "Прокси").replace("Локальный прокси", "Локальный")
                selected: Vpn.mode === modelData
                enabled: !Vpn.transitioning
                onClicked: Vpn.setMode(modelData)
            }
        }
    }
    MenuSection {
        visible: Vpn.daemonAvailable
        text: Vpn.pinging ? "Измеряю задержку…" : "Серверы"
        Chip {
            text: "Пинг"; icon: "refresh"; implicitHeight: 30
            enabled: !Vpn.pinging && !Vpn.transitioning
            onClicked: Vpn.pingAll()
        }
    }
    MenuGroup {
        visible: Vpn.daemonAvailable
        AnimatedCardList {
            Layout.fillWidth: true
            cardSpacing: 2
            rowColor: Theme.cardSurface
            keyField: "id"
            source: Vpn.servers.map(s => Object.assign({}, s, {
                current: Vpn.currentId === s.id,
                pending: Vpn.pendingServer === s.id,
                ms: Vpn.latencyFor(s)
            }))
            delegate: Component { MenuRow {
                property var modelData: parent.modelData
                icon: modelData.current ? "shieldCheck" : "shield"
                title: modelData.name
                subtitle: (modelData.pending ? "Подключение · " : modelData.current ? "Подключено · " : "")
                    + Vpn.describe(modelData)
                    + (modelData.ms > 0 ? " · " + modelData.ms + " мс" : modelData.ms < 0 ? " · нет ответа" : "")
                subtitleColor: modelData.ms < 0 && !modelData.current ? Theme.error : Theme.muted
                selected: modelData.current || modelData.pending
                interactive: !Vpn.transitioning
                onClicked: { if (modelData.current) Vpn.disconnect(); else Vpn.connectTo(modelData); }
                Icon { name: modelData.current ? "close" : "right"; tint: Theme.muted; implicitWidth: 16; implicitHeight: 16 }
            } }
        }
    }
    MenuSection {
        visible: Vpn.daemonAvailable && Vpn.subscriptions.length > 0
        text: Vpn.subscriptions.length > 1 ? "Подписки" : "Подписка"
        Chip {
            visible: Vpn.subscriptions.length > 1
            text: "Обновить все"; icon: "refresh"; implicitHeight: 30
            enabled: !Vpn.busy
            onClicked: Vpn.updateSubscriptions()
        }
    }
    MenuGroup {
        visible: Vpn.daemonAvailable && Vpn.subscriptions.length > 0
        // Relative "updated … ago" text refreshes every half minute.
        property date now: new Date()
        id: subscriptionGroup
        Timer { interval: 30000; repeat: true; running: subscriptionGroup.visible; onTriggered: subscriptionGroup.now = new Date() }
        Repeater {
            model: Vpn.subscriptions
            MenuRow {
                id: subscriptionRow
                required property var modelData
                readonly property bool updating: Vpn.isUpdating(modelData)
                readonly property var quota: modelData.quota ?? {}
                icon: "download"
                title: modelData.provider_title || modelData.name
                subtitle: updating ? "Обновляю список серверов…"
                    : modelData.server_count + " серв. · " + Vpn.ago(modelData.updated_at, subscriptionGroup.now)
                        + (quota.download_bytes ? " · ↓" + Vpn.formatBytes(quota.download_bytes) : "")
                interactive: !Vpn.busy
                onClicked: Vpn.updateSubscription(modelData)
                // Refresh glyph that spins while the download runs.
                Icon {
                    name: "refresh"; tint: subscriptionRow.updating ? Theme.primary : Theme.muted
                    implicitWidth: 18; implicitHeight: 18
                    RotationAnimator on rotation {
                        running: subscriptionRow.updating
                        from: 0; to: 360; duration: 900; loops: Animation.Infinite
                        onRunningChanged: if (!running) parent.rotation = 0
                    }
                }
            }
        }
    }
    Label { visible: Vpn.error !== ""; text: Vpn.error; color: Theme.error; font.pixelSize: 12; wrapMode: Text.Wrap; Layout.fillWidth: true }
    RowLayout {
        Layout.fillWidth: true
        visible: Vpn.daemonAvailable
        Chip { Layout.fillWidth: true; text: "Подключить самый быстрый"; icon: "bolt"; filled: true; enabled: !Vpn.transitioning && !Vpn.pinging; onClicked: Vpn.connectAuto() }
    }
}

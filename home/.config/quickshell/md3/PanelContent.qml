import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property string page: "settings"
    property var trayItem: null
    onTrayItemChanged: { if (page === "tray" && pageLoader.item) pageLoader.item.trayItem = trayItem; }
    property bool attachedToBar: false
    property bool surfaceVisible: true
    property bool cardAnimationsEnabled: true
    signal closeRequested()
    signal navigateRequested(string page)
    signal morphRequested()
    readonly property var loadedPage: pageLoader.item
    implicitWidth: 408
    implicitHeight: Math.min(760, body.implicitHeight + 40)
    radius: 28
    topLeftRadius: radius
    topRightRadius: radius
    color: surfaceVisible ? Theme.container : "transparent"
    border.color: Theme.outline
    border.width: 0
    focus: true
    Keys.onEscapePressed: closeRequested()
    // The clip edge sits 12 px outside the content so card shadows (8 px spread)
    // are not cut; the visible content inset stays 20 px.
    readonly property int shadowRoom: 12
    Flickable {
        id: viewport
        anchors.fill: parent; anchors.margins: 20 - root.shadowRoom
        contentHeight: body.implicitHeight + root.shadowRoom * 2
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
        ColumnLayout {
            id: body
            x: root.shadowRoom; y: root.shadowRoom
            width: parent.width - root.shadowRoom * 2
            spacing: 12
            Loader {
                id: pageLoader
                Layout.fillWidth: true
                onSourceChanged: opacity = 0
                onLoaded: {
                    if (root.page === "tray") item.trayItem = root.trayItem;
                    if (root.cardAnimationsEnabled) pageFade.restart();
                    else opacity = 1;
                }
                NumberAnimation {
                    id: pageFade; target: pageLoader; property: "opacity"; from: 0; to: 1
                    duration: Theme.slowEffectsDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.slowEffectsCurve
                }
                source: ({wallpaper: "WallpaperMenu.qml", system: "SystemMenu.qml", tray: "TrayMenu.qml", main: "MainMenu.qml", settings: "MainMenu.qml", wifi: "WifiMenu.qml", bluetooth: "BluetoothMenu.qml", vpn: "VpnMenu.qml", nightlight: "NightLightMenu.qml", player: "PlayerMenu.qml", audio: "Audio.qml", calendar: "Calendar.qml", notifications: "Notifications.qml", power: "Power.qml"})[root.page] || "QuickSettings.qml"
                Connections {
                    target: pageLoader.item
                    ignoreUnknownSignals: true
                    function onNavigateRequested(page) { root.navigateRequested(page); }
                    function onCloseRequested() { root.closeRequested(); }
                    function onMorphRequested() { root.morphRequested(); }
                }
            }
            Label {
                visible: Desktop.actionError !== ""
                text: Desktop.actionError; color: Theme.error; wrapMode: Text.Wrap; Layout.fillWidth: true; font.pixelSize: 12
            }
        }
    }
    onPageChanged: viewport.contentY = 0
}

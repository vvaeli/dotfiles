import QtQuick
import Quickshell
import Quickshell.Hyprland

// Workspaces in one capsule. Each slot shows its number and the icon of its first window;
// a primary pill slides and stretches to the active slot.
Rectangle {
    id: root
    required property var monitor
    readonly property var localWorkspaces: Desktop.preview
        ? [{id: 1, name: "1", toplevels: {values: []}}, {id: 2, name: "2", toplevels: {values: []}}, {id: 3, name: "3", toplevels: {values: []}}]
        : Desktop.workspacesForMonitor(Hyprland.workspaces.values, monitor?.name ?? "")
    readonly property int activeId: monitor?.activeWorkspace?.id ?? 2
    implicitWidth: row.implicitWidth + 8
    implicitHeight: 34
    radius: height / 2
    color: Theme.cardSurface
    readonly property Item activeSlot: {
        for (let i = 0; i < slots.count; ++i) {
            const item = slots.itemAt(i);
            if (item && item.workspace.id === activeId) return item;
        }
        return null;
    }
    Rectangle {
        id: indicator
        visible: !!root.activeSlot
        x: 4 + (root.activeSlot?.x ?? 0)
        width: root.activeSlot?.width ?? 0
        y: 3; height: root.height - 6
        radius: height / 2
        color: Theme.primary
        Behavior on x { NumberAnimation { duration: Theme.spatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.spatialCurve } }
        Behavior on width { NumberAnimation { duration: Theme.spatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.spatialCurve } }
    }
    Row {
        id: row
        x: 4; anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Repeater {
            id: slots
            model: root.localWorkspaces
            delegate: Item {
                id: slot
                required property var modelData
                readonly property var workspace: modelData
                readonly property bool active: modelData.id === root.activeId
                readonly property var windows: modelData.toplevels?.values ?? []
                readonly property var firstWindow: windows.find(w => w.activated) ?? windows[0] ?? null
                readonly property string appIcon: firstWindow ? Desktop.iconForApp(firstWindow.lastIpcObject?.class ?? firstWindow.wayland?.appId ?? "") : ""
                readonly property bool urgent: windows.some(w => w.urgent)
                width: content.implicitWidth + 20
                height: 28
                Behavior on width { NumberAnimation { duration: Theme.spatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.spatialCurve } }
                Rectangle {
                    anchors.fill: parent; radius: height / 2
                    color: slot.active ? Theme.textPrimary : Theme.textSurface
                    opacity: tap.pressed ? 0.14 : hover.hovered ? 0.08 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.duration } }
                }
                Row {
                    id: content
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: slot.modelData.name
                        font.family: Theme.font; font.pixelSize: 13; font.weight: slot.active ? Font.Bold : Font.Medium
                        color: slot.urgent ? Theme.error : slot.active ? Theme.textPrimary : slot.windows.length ? Theme.textSurface : Theme.muted
                        Behavior on color { ColorAnimation { duration: Theme.duration } }
                    }
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: slot.appIcon !== "" && status === Image.Ready
                        width: 16; height: 16
                        source: slot.appIcon
                        sourceSize: Qt.size(32, 32)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: slot.windows.length > 1
                        text: "+" + (slot.windows.length - 1)
                        font.family: Theme.font; font.pixelSize: 10; font.weight: Font.Medium
                        color: slot.active ? Theme.textPrimary : Theme.muted
                    }
                }
                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                TapHandler { id: tap; onTapped: Desktop.focusWorkspace(root.monitor, slot.modelData) }
            }
        }
        Item {
            width: 28; height: 28
            Rectangle {
                anchors.fill: parent; radius: height / 2
                color: Theme.textSurface
                opacity: plusTap.pressed ? 0.14 : plusHover.hovered ? 0.08 : 0
            }
            Icon { anchors.centerIn: parent; name: "plus"; tint: Theme.muted; implicitWidth: 14; implicitHeight: 14 }
            HoverHandler { id: plusHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { id: plusTap; onTapped: Desktop.createWorkspace(root.monitor) }
        }
    }
    WheelHandler { onWheel: wheel => { Desktop.nextWorkspace(root.monitor, wheel.angleDelta.y < 0 ? 1 : -1); wheel.accepted = true; } }
}

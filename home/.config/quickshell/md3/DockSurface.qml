import QtQuick
import Quickshell

// Dock: launcher button, pinned apps (launched on click when closed), then other running apps.
// Hover lifts the icon and names it above the dock; dots under an icon count its windows and
// stretch for the focused app; an app that is starting bounces until its window shows up.
// Left click focuses or cycles windows, middle click opens a new instance, right click pins.
// Dragging an icon sideways reorders the dock; dropping it across the separator pins or unpins it.
Item {
    id: root
    property var apps: []
    property bool expanded: true
    property bool detached: false
    readonly property real progress: reveal.contentProgress
    readonly property real revealedHeight: reveal.revealedHeight
    readonly property color frameColor: Theme.surface
    readonly property bool hovered: dockHover.hovered
    HoverHandler { id: dockHover; blocking: false }
    signal activateRequested(var app, int direction)
    signal launchRequested(var app)
    signal pinRequested(var app)
    signal launcherRequested()
    signal arrangeRequested(var keys)
    // Key of the app being dragged; the model follows the pointer while it is set.
    property string dragKey: ""
    property real dragX: 0
    function slotWidth(index) { return items.get(index).payload.separator ? 13 : 52; }
    function dragMove(scenePoint) {
        dragX = appRow.mapFromItem(null, scenePoint.x, scenePoint.y).x;
        let from = -1;
        for (let i = 0; i < items.count; ++i) if (items.get(i).key === dragKey) { from = i; break; }
        if (from < 0) return;
        let x = 0, target = from;
        for (let j = 0; j < items.count; ++j) {
            const center = x + slotWidth(j) / 2;
            if (j < from && dragX < center && target === from) target = j;
            if (j > from && dragX > center) target = j;
            x += slotWidth(j) + appRow.spacing;
        }
        if (target !== from) items.move(from, target, 1);
    }
    function finishDrag() {
        const keys = [];
        for (let i = 0; i < items.count; ++i) keys.push(items.get(i).key);
        dragKey = "";
        arrangeRequested(keys);
        Qt.callLater(sync);
    }
    implicitWidth: appRow.implicitWidth + 20
    implicitHeight: 64
    property var hoveredButton: null
    function sync() {
        if (dragKey) return;
        const keys = apps.map(app => app.key);
        for (let i = items.count - 1; i >= 0; --i)
            if (!keys.includes(items.get(i).key)) items.remove(i);
        for (let i = 0; i < apps.length; ++i) {
            let index = -1;
            for (let j = 0; j < items.count; ++j) if (items.get(j).key === apps[i].key) { index = j; break; }
            if (index < 0) items.insert(i, {key: apps[i].key, payload: apps[i]});
            else {
                if (index !== i) items.move(index, i, 1);
                if (JSON.stringify(items.get(i).payload) !== JSON.stringify(apps[i])) items.setProperty(i, "payload", apps[i]);
            }
        }
    }
    onAppsChanged: sync()
    Component.onCompleted: sync()
    ListModel { id: items; dynamicRoles: true }

    // Name of the hovered app above the dock.
    Rectangle {
        id: tooltip
        readonly property var button: root.hoveredButton
        visible: opacity > 0
        opacity: button && root.progress > 0.9 && !root.dragKey ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.duration } }
        width: tipText.implicitWidth + 24; height: 30; radius: 15
        color: Theme.surface
        border.width: 1; border.color: Theme.outline
        property real centerX: 0
        onButtonChanged: if (button) centerX = button.mapToItem(root, button.width / 2, 0).x
        x: Math.max(0, Math.min(root.width - width, centerX - width / 2))
        Behavior on x { enabled: tooltip.opacity > 0.5; NumberAnimation { duration: Theme.fastSpatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
        y: -height - 10
        Text {
            id: tipText
            anchors.centerIn: parent
            text: tooltip.button?.label ?? ""
            font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium
            color: Theme.textSurface
        }
    }

    // Use the exact menu outline, mirrored toward the bottom frame.
    Reveal {
        id: reveal
        anchors.fill: parent
        expanded: root.expanded
        detached: root.detached
        rotation: 180
        surfaceColor: root.frameColor
        Flickable {
            rotation: 180
            anchors.fill: parent
            anchors.leftMargin: 10; anchors.rightMargin: 10
            contentWidth: appRow.implicitWidth
            contentHeight: height
            interactive: contentWidth > width && !root.dragKey
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Row {
                id: appRow
                y: 6
                spacing: 4
                // Icons that change groups (pinned / running) are recreated: grow them in.
                add: Transition {
                    NumberAnimation { property: "scale"; from: 0.6; to: 1; duration: Theme.fastSpatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.fastSpatialCurve }
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.duration }
                }
                move: Transition {
                    NumberAnimation { properties: "x"; duration: Theme.fastSpatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.fastSpatialCurve }
                }
                Repeater {
                    model: items
                    delegate: Item {
                        id: slot
                        required property var payload
                        objectName: payload.key
                        width: payload.separator ? 13 : 52
                        height: 52
                        readonly property bool dragging: root.dragKey !== "" && root.dragKey === payload.key
                        z: dragging || settleAnim.running ? 2 : 0
                        // The dragged icon stays under the pointer while its slot moves through the row,
                        // then glides into its slot when released.
                        property real settle: 0
                        property real lastOffset: 0
                        readonly property real offset: dragging ? root.dragX - (x + width / 2) : settle
                        onOffsetChanged: if (dragging) lastOffset = offset
                        onDraggingChanged: {
                            if (dragging) { settleAnim.stop(); return; }
                            settle = lastOffset;
                            settleAnim.restart();
                        }
                        NumberAnimation {
                            id: settleAnim
                            target: slot; property: "settle"; to: 0
                            duration: Theme.fastSpatialDuration + 50
                            easing.type: Easing.BezierSpline; easing.bezierCurve: [0.34, 1.3, 0.64, 1, 1, 1]
                        }
                        // Slightly lifted while held.
                        scale: dragging ? 1.1 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.fastSpatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.fastSpatialCurve } }
                        transform: Translate { x: slot.offset }
                        DragHandler {
                            target: null
                            enabled: !slot.payload.separator
                            acceptedButtons: Qt.LeftButton
                            yAxis.enabled: false
                            cursorShape: active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                            onActiveChanged: {
                                if (active) { root.dragKey = slot.payload.key; root.dragMove(centroid.scenePosition); }
                                else if (slot.dragging) root.finishDrag();
                            }
                            onCentroidChanged: if (active) root.dragMove(centroid.scenePosition)
                        }
                        // Separator between pinned and other running apps.
                        Rectangle {
                            visible: !!slot.payload.separator
                            anchors.centerIn: parent
                            width: 1; height: 28; color: Theme.outline
                        }
                        DockTile {
                            id: button
                            dock: root
                            visible: !slot.payload.separator
                            anchors.fill: parent
                            readonly property var app: slot.payload
                            readonly property int windowCount: app.windows?.length ?? 0
                            readonly property string label: app.name + (windowCount > 1 ? " · " + windowCount + " окна" : "")
                                + (hovered && app.id ? (app.pinned ? "   ПКМ — открепить" : "   ПКМ — закрепить") : "")
                            // Starting apps bounce until their first window appears.
                            property bool launching: false
                            onWindowCountChanged: if (windowCount > 0) launching = false
                            Timer { id: launchTimeout; interval: 6000; onTriggered: button.launching = false }
                            property real bounce: 0
                            SequentialAnimation on bounce {
                                running: button.launching
                                loops: Animation.Infinite
                                onRunningChanged: if (!running) button.bounce = 0
                                NumberAnimation { to: 1; duration: 260; easing.type: Easing.OutQuad }
                                NumberAnimation { to: 0; duration: 260; easing.type: Easing.InQuad }
                            }
                            Image {
                                id: appIcon
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: (parent.height - height) / 2 - 2 - button.bounce * 8 - (button.hovered ? 3 : 0)
                                Behavior on y { enabled: !button.launching; NumberAnimation { duration: Theme.fastSpatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.fastSpatialCurve } }
                                width: 34; height: 34
                                scale: button.pressed ? 0.9 : button.hovered ? 1.12 : 1
                                Behavior on scale { NumberAnimation { duration: Theme.fastSpatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.fastSpatialCurve } }
                                source: Desktop.iconSource(button.app.icon ?? "")
                                sourceSize: Qt.size(68, 68)
                                fillMode: Image.PreserveAspectFit
                                visible: status === Image.Ready
                            }
                            Label {
                                anchors.centerIn: appIcon
                                visible: !appIcon.visible
                                text: (button.app.name ?? "?").slice(0, 1).toUpperCase()
                                font.pixelSize: 22; font.weight: Font.DemiBold; color: Theme.primary
                            }
                            // One dot per window (up to three); the focused app's first dot stretches.
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom; anchors.bottomMargin: 1
                                spacing: 3
                                Repeater {
                                    model: Math.min(3, button.windowCount)
                                    Rectangle {
                                        required property int index
                                        width: button.app.active && index === 0 ? 14 : 4
                                        height: 4; radius: 2
                                        color: button.app.active ? Theme.primary : Theme.muted
                                        Behavior on width { NumberAnimation { duration: Theme.fastSpatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.fastSpatialCurve } }
                                        Behavior on color { ColorAnimation { duration: Theme.duration } }
                                    }
                                }
                            }
                            onTapped: (button_, direction) => {
                                if (button_ === Qt.RightButton) { if (app.id) root.pinRequested(app); }
                                else if (button_ === Qt.MiddleButton || windowCount === 0) {
                                    if (!app.id) return;
                                    launching = true; launchTimeout.restart();
                                    root.launchRequested(app);
                                } else root.activateRequested(app, 1);
                            }
                            onWheeled: direction => { if (windowCount > 0) root.activateRequested(app, direction); }
                        }
                    }
                }
                // Launcher, at the right end.
                DockTile {
                    dock: root
                    id: launcherTile
                    readonly property string label: "Приложения"
                    Rectangle {
                        anchors.centerIn: parent
                        width: 40; height: 40; radius: 14
                        color: Theme.primaryContainer
                        Icon { anchors.centerIn: parent; name: "launcher"; tint: Theme.textPrimaryContainer; implicitWidth: 20; implicitHeight: 20 }
                    }
                    onTapped: root.launcherRequested()
                }
            }
        }
    }
}

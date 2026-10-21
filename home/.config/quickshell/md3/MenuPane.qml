import QtQuick

Item {
    id: root
    property string page: "settings"
    property bool expanded: false
    property var trayItem: null
    property bool leftAttached: false
    property bool rightAttached: false
    property real maximumHeight: 760
    readonly property real revealedHeight: reveal.revealedHeight
    readonly property bool animating: reveal.animating
    readonly property real progress: reveal.progress
    readonly property var loadedPage: content.loadedPage
    // Final geometry of the current page, set by the bar. Content is laid out once at this size.
    property real targetX: 0
    property real contentWidth: implicitWidth
    // Switching menus while one is open morphs the pane from a snapshot of its geometry
    // to the live target, so content that keeps growing during the switch never restarts it.
    property real morph: 1
    property real fromX: 0
    property real fromWidth: 0
    property real fromHeight: 0
    readonly property bool morphing: morph < 1
    x: fromX + (targetX - fromX) * morph
    width: fromWidth + (contentWidth - fromWidth) * morph
    height: fromHeight + (implicitHeight - fromHeight) * morph
    // Called before the page or position changes. Opening from the closed state keeps the plain reveal.
    function beginMorph() {
        if (progress <= 0) return;
        const x0 = x, width0 = width, height0 = height;
        fromX = x0; fromWidth = width0; fromHeight = height0;
        morph = 0;
        morphMotion.restart();
    }
    NumberAnimation {
        id: morphMotion
        target: root; property: "morph"; from: 0; to: 1
        duration: 380
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
    }
    signal closeRequested()
    signal navigateRequested(string page)
    implicitWidth: page === "main" || page === "settings" || page === "wallpaper" ? 740 : page === "tray" ? (loadedPage?.preferredWidth ?? 260) : page === "player" ? 720 : 408
    implicitHeight: Math.min(maximumHeight, content.implicitHeight)
    Reveal {
        id: reveal
        anchors.fill: parent
        expanded: root.expanded
        leftAttached: root.leftAttached
        rightAttached: root.rightAttached
        // Pages may offer a picture for the surface (the player shows its cover there).
        backdrop: content.loadedPage?.backdrop ?? ""
        backdropStrength: content.loadedPage?.backdropStrength ?? 0.6
        PanelContent {
            id: content
            // Centered at its final size: the morphing surface clips it instead of reflowing it every frame.
            width: root.contentWidth
            height: root.implicitHeight
            x: (root.width - width) / 2
            page: root.page
            trayItem: root.trayItem
            attachedToBar: true
            surfaceVisible: false
            cardAnimationsEnabled: root.expanded && !reveal.animating
            onCloseRequested: root.closeRequested()
            onNavigateRequested: page => root.navigateRequested(page)
            onMorphRequested: root.beginMorph()
        }
    }
}

import QtQuick
import QtQuick.Effects

Rectangle {
    id: root
    property bool interactive: false
    property bool presented: true
    // Off for cards drawn straight on a surface that already has its own shadow.
    property bool elevated: true
    visible: presented || opacity > 0
    opacity: presented ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.slowEffectsDuration } }
    readonly property bool hovered: pointer.containsMouse
    signal clicked(var mouse)
    color: interactive ? hovered ? Theme.cardHover : Theme.cardInteractive : Theme.cardSurface
    radius: 20
    Behavior on color { ColorAnimation { duration: Theme.duration } }
    readonly property bool softwareRendering: GraphicsInfo.api === GraphicsInfo.Software
    // Real blur on the GPU; layered steps were visible on light surfaces.
    // Blur + offset stay inside PanelContent.shadowRoom (12 px).
    RectangularShadow {
        visible: root.elevated && !root.softwareRendering
        z: -1
        anchors.fill: parent
        radius: root.radius
        offset.y: 2
        blur: 10
        color: Qt.rgba(0, 0, 0, Theme.light ? 0.10 : 0.22)
    }
    // Layered rounded silhouettes for the software renderer (offscreen previews).
    Repeater {
        model: root.elevated && root.softwareRendering ? 8 : 0
        Rectangle {
            required property int index
            readonly property int spread: 8 - index
            z: -1
            x: -spread; y: 3 - spread
            width: root.width + spread * 2; height: root.height + spread * 2
            radius: root.radius + spread
            color: "black"; opacity: Theme.shadowAlpha
        }
    }
    MouseArea {
        id: pointer
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.clicked(mouse)
    }
    activeFocusOnTab: interactive
    Accessible.role: interactive ? Accessible.Button : Accessible.Pane
    Keys.onReturnPressed: { if (interactive) root.clicked({button: Qt.LeftButton}); }
    Keys.onSpacePressed: { if (interactive) root.clicked({button: Qt.LeftButton}); }
}

import QtQuick

// A dock button: hover and press state, all mouse buttons, wheel to cycle windows.
// Tells the dock which button is hovered so it can show the name above it.
Item {
    id: tile
    property var dock: null
    readonly property bool hovered: tileHover.hovered
    readonly property bool pressed: tileTap.pressed
    signal tapped(int button, int direction)
    signal wheeled(int direction)
    width: 52; height: 52
    onHoveredChanged: {
        if (!dock) return;
        if (hovered) dock.hoveredButton = tile;
        else if (dock.hoveredButton === tile) dock.hoveredButton = null;
    }
    Rectangle {
        anchors.fill: parent; anchors.margins: 2
        radius: 16
        color: Theme.textSurface
        opacity: tile.pressed ? 0.14 : tile.hovered ? 0.07 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.duration } }
    }
    HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
    TapHandler {
        id: tileTap
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onTapped: (point, button) => Qt.callLater(() => tile.tapped(button, 1))
    }
    WheelHandler { onWheel: event => { tile.wheeled(event.angleDelta.y < 0 ? 1 : -1); event.accepted = true; } }
}

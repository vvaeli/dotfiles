import QtQuick

Item {
    id: root
    signal selected(int x, int y, int selectionWidth, int selectionHeight)
    signal cancelled()
    property point start: Qt.point(0, 0)
    property point end: Qt.point(0, 0)
    property bool dragging: false
    property string frozenImage: ""
    readonly property int selectionX: Math.floor(Math.min(start.x, end.x))
    readonly property int selectionY: Math.floor(Math.min(start.y, end.y))
    readonly property int selectionWidth: Math.ceil(Math.abs(end.x - start.x))
    readonly property int selectionHeight: Math.ceil(Math.abs(end.y - start.y))
    function boundedPoint(x, y) { return Qt.point(Math.max(0, Math.min(width, x)), Math.max(0, Math.min(height, y))); }
    focus: true
    Keys.onEscapePressed: cancelled()
    onStartChanged: shade.requestPaint()
    onEndChanged: shade.requestPaint()
    onDraggingChanged: shade.requestPaint()
    Image {
        anchors.fill: parent
        source: root.frozenImage ? "file://" + root.frozenImage : ""
        fillMode: Image.Stretch
        cache: false
    }
    Canvas {
        id: shade
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = "rgba(0,0,0,0.45)";
            ctx.fillRect(0, 0, width, height);
            if (root.dragging) {
                ctx.clearRect(root.selectionX, root.selectionY, root.selectionWidth, root.selectionHeight);
                ctx.strokeStyle = Theme.primary;
                ctx.lineWidth = 2;
                ctx.strokeRect(root.selectionX, root.selectionY, root.selectionWidth, root.selectionHeight);
            }
        }
    }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 80
        width: hint.implicitWidth + 40; height: 44; radius: 22
        color: Theme.surface
        Label { id: hint; anchors.centerIn: parent; text: "Выдели область · Esc или ПКМ — отмена"; font.pixelSize: 14 }
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.CrossCursor
        onPressed: mouse => {
            if (mouse.button === Qt.RightButton) { root.cancelled(); return; }
            root.start = root.boundedPoint(mouse.x, mouse.y);
            root.end = root.start;
            root.dragging = true;
        }
        onPositionChanged: mouse => { if (root.dragging) root.end = root.boundedPoint(mouse.x, mouse.y); }
        onReleased: mouse => {
            if (mouse.button !== Qt.LeftButton || !root.dragging) return;
            root.end = root.boundedPoint(mouse.x, mouse.y);
            if (root.selectionWidth >= 2 && root.selectionHeight >= 2)
                root.selected(root.selectionX, root.selectionY, root.selectionWidth, root.selectionHeight);
            root.dragging = false;
        }
    }
}

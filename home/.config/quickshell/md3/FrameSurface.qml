import QtQuick
import QtQuick.Effects

// Screen frame around the workspace with a soft inner shadow. The shadow is the GPU blur of
// the frame's shape, the same technique as the menus and the dock (Reveal.qml), shown only
// inside the workspace so it never darkens the bar or the frame itself.
Item {
    id: root
    property real thickness: Theme.frameWidth
    property real topInset: Theme.barHeight
    property real rounding: Theme.frameRadius
    property color frameColor: Theme.surface
    onThicknessChanged: repaint()
    onTopInsetChanged: repaint()
    onRoundingChanged: repaint()
    onFrameColorChanged: frame.requestPaint()
    onWidthChanged: repaint()
    onHeightChanged: repaint()
    function repaint() { frame.requestPaint(); silhouette.requestPaint(); workspaceMask.requestPaint(); }

    // Rounded workspace cutout, shared by all three canvases.
    function workspace(ctx) {
        const x = thickness, y = topInset;
        const w = width - thickness * 2, h = height - topInset - thickness;
        if (w <= 0 || h <= 0) return false;
        const r = Math.min(rounding, w / 2, h / 2);
        ctx.beginPath();
        ctx.moveTo(x + r, y);
        ctx.lineTo(x + w - r, y);
        ctx.arcTo(x + w, y, x + w, y + r, r);
        ctx.lineTo(x + w, y + h - r);
        ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
        ctx.lineTo(x + r, y + h);
        ctx.arcTo(x, y + h, x, y + h - r, r);
        ctx.lineTo(x, y + r);
        ctx.arcTo(x, y, x + r, y, r);
        ctx.closePath();
        return true;
    }

    // Everything outside the workspace, the bar band included: the shadow falls from all of it.
    Canvas {
        id: silhouette
        anchors.fill: parent
        visible: false
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = "black";
            ctx.fillRect(0, 0, width, height);
            if (!root.workspace(ctx)) return;
            ctx.globalCompositeOperation = "destination-out";
            ctx.fill();
        }
    }
    Canvas {
        id: workspaceMask
        anchors.fill: parent
        visible: false
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (!root.workspace(ctx)) return;
            ctx.fillStyle = "white";
            ctx.fill();
        }
    }
    MultiEffect {
        anchors.fill: parent
        source: silhouette
        autoPaddingEnabled: false
        shadowEnabled: true
        shadowColor: "black"
        // Same strength and softness as Reveal's surfaces.
        shadowOpacity: Math.min(1, 2 * (1 - Math.pow(1 - Theme.shadowAlpha, Theme.menuShadow)))
        shadowBlur: 1
        blurMax: 24
        maskEnabled: true
        maskSource: workspaceMask
    }
    Canvas {
        id: frame
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = root.frameColor;
            ctx.fillRect(0, 0, width, height);
            // The bar paints this band itself; keep it clear regardless of layer order.
            ctx.clearRect(0, 0, width, root.topInset);
            if (!root.workspace(ctx)) return;
            ctx.globalCompositeOperation = "destination-out";
            ctx.fill();
        }
    }
}

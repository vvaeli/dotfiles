import QtQuick
import QtQuick.Effects

// Grow a rounded surface from the bar. Content keeps its natural size.
Item {
    id: root
    property bool expanded: false
    property bool detached: false
    property bool leftAttached: false
    property bool rightAttached: false
    property color surfaceColor: Theme.container
    // Optional picture under the content (the player's cover), blurred and cut to the surface's
    // exact outline under a scrim of the surface colour that deepens toward the right, so text
    // stays readable on bright covers.
    property string backdrop: ""
    property real backdropStrength: 0.6
    readonly property int seamFade: 64
    onDetachedChanged: repaint()
    onSurfaceColorChanged: repaint()
    onLeftAttachedChanged: repaint()
    onRightAttachedChanged: repaint()
    property real progress: expanded ? 1 : 0
    property real targetHeight: height
    readonly property real revealedHeight: targetHeight * contentProgress
    readonly property real attachedTail: (leftAttached || rightAttached) ? Math.min(Theme.menuJoinRadius, revealedHeight / 2) : 0
    readonly property real contentProgress: Math.max(0, Math.min(1, progress))
    readonly property bool animating: motion.running
    default property alias content: stage.data
    clip: false
    Behavior on progress {
        NumberAnimation {
            id: motion
            duration: 300
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
        }
    }
    function repaint() { surface.requestPaint(); silhouette.requestPaint(); frameMask.requestPaint(); }

    // Margins around the surface: room for the join arcs and the blurred shadow.
    readonly property int pad: Theme.menuShadow * 2
    readonly property int side: Theme.menuJoinRadius + pad
    readonly property int softShadow: 24

    // Same shape outline for the surface and its shadow silhouette, in canvas coordinates
    // where the surface spans side…width-side horizontally and starts at y = pad.
    function outline(ctx, w) {
        const h = root.revealedHeight;
        const left = root.side, right = w - root.side;
        const join = Math.min(Theme.menuJoinRadius, h / 2);
        const jl = root.leftAttached ? 0 : join;
        const jr = root.rightAttached ? 0 : join;
        const bottom = Math.min(28, h / 2, (right - left) / 2);
        const bl = root.leftAttached ? 0 : bottom;
        const br = root.rightAttached ? 0 : bottom;
        ctx.beginPath();
        if (root.detached) {
            const r = Math.min(24, h / 2, (right - left) / 2);
            ctx.moveTo(left + r, 0);
            ctx.lineTo(right - r, 0); ctx.arcTo(right, 0, right, r, r);
            ctx.lineTo(right, h - r); ctx.arcTo(right, h, right - r, h, r);
            ctx.lineTo(left + r, h); ctx.arcTo(left, h, left, h - r, r);
            ctx.lineTo(left, r); ctx.arcTo(left, 0, left + r, 0, r);
            ctx.closePath();
            return;
        }
        ctx.moveTo(left - jl, 0); ctx.lineTo(right + jr, 0);
        if (jr > 0) ctx.arc(right + jr, jr, jr, -Math.PI / 2, -Math.PI, true);
        if (root.rightAttached) {
            // Reverse lower corner flowing down into the side frame.
            ctx.lineTo(right, h + join);
            ctx.arc(right - join, h + join, join, 0, -Math.PI / 2, true);
        } else {
            ctx.lineTo(right, h - br);
            ctx.arcTo(right, h, right - br, h, br);
        }
        ctx.lineTo(left + (root.leftAttached ? join : bl), h);
        if (root.leftAttached) ctx.arc(left + join, h + join, join, -Math.PI / 2, -Math.PI, true);
        else ctx.arcTo(left, h, left, h - bl, bl);
        ctx.lineTo(left, jl);
        if (jl > 0) ctx.arc(left - jl, jl, jl, 0, -Math.PI / 2, true);
        ctx.closePath();
    }

    // Shadow: the GPU blur of the shape, so it follows every curve and softens the joins.
    Canvas {
        id: silhouette
        visible: false
        x: -root.side; y: -root.pad
        width: root.width + root.side * 2
        height: root.revealedHeight + root.attachedTail + root.pad * 2
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (root.revealedHeight < 1 || width <= root.side * 2) return;
            ctx.fillStyle = "black";
            ctx.save();
            ctx.translate(0, root.pad);
            root.outline(ctx, width);
            ctx.fill();
            ctx.restore();
        }
    }
    // Next to the bar and side frames the frame casts its own inner shadow; this one is
    // removed there and returns gradually, so the two neither stack up nor leave a gap.
    Canvas {
        id: frameMask
        visible: false
        x: silhouette.x; y: silhouette.y
        width: silhouette.width; height: silhouette.height
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = "white";
            ctx.fillRect(0, 0, width, height);
            if (root.detached) return;
            const reach = Theme.menuShadow + 8, solid = 4 / reach;
            function fade(x0, y0, x1, y1) {
                const g = ctx.createLinearGradient(x0, y0, x1, y1);
                g.addColorStop(0, "rgba(0,0,0,1)");
                g.addColorStop(solid, "rgba(0,0,0,1)");
                g.addColorStop(1, "rgba(0,0,0,0)");
                return g;
            }
            ctx.globalCompositeOperation = "destination-out";
            ctx.fillStyle = fade(0, root.pad, 0, root.pad + reach);
            ctx.fillRect(0, 0, width, root.pad + reach);
            const right = width - root.side, left = root.side;
            if (root.rightAttached) { ctx.fillStyle = fade(right, 0, right - reach, 0); ctx.fillRect(right - reach, 0, width, height); }
            if (root.leftAttached) { ctx.fillStyle = fade(left, 0, left + reach, 0); ctx.fillRect(0, 0, left + reach, height); }
        }
    }
    // Attached surfaces never shade the bar or the frame they grow from.
    Item {
        id: shadowClip
        x: root.leftAttached && !root.detached ? 0 : silhouette.x
        y: root.detached ? silhouette.y : 0
        width: (root.rightAttached && !root.detached ? root.width : silhouette.x + silhouette.width) - x
        height: silhouette.y + silhouette.height - y
        clip: true
        visible: root.revealedHeight >= 1
        MultiEffect {
            x: silhouette.x - shadowClip.x; y: silhouette.y - shadowClip.y
            width: silhouette.width; height: silhouette.height
            source: silhouette
            autoPaddingEnabled: false
            shadowEnabled: true
            shadowColor: "black"
            // Matches the frame's inner shadow: half the opacity shows right at a straight edge.
            shadowOpacity: Math.min(1, 2 * (1 - Math.pow(1 - Theme.shadowAlpha, Theme.menuShadow)))
            shadowBlur: 1
            blurMax: root.softShadow
            shadowVerticalOffset: root.detached ? 2 : 0
            shadowHorizontalOffset: 0
            maskEnabled: !root.detached
            maskSource: frameMask
        }
    }
    Canvas {
        id: surface
        x: silhouette.x; y: silhouette.y
        width: silhouette.width; height: silhouette.height
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (root.revealedHeight < 1 || width <= root.side * 2) return;
            ctx.translate(0, root.pad);
            root.outline(ctx, width);
            ctx.fillStyle = root.surfaceColor;
            ctx.fill();
        }
    }
    Item {
        id: backdropLayer
        x: surface.x; y: surface.y
        width: surface.width; height: surface.height
        visible: false
        layer.enabled: root.backdrop !== ""
        Image {
            id: backdropImage
            anchors.fill: parent; anchors.margins: -80
            source: root.backdrop
            fillMode: Image.PreserveAspectCrop
            visible: false
            asynchronous: true
            sourceSize.width: 256
        }
        MultiEffect {
            anchors.fill: backdropImage
            source: backdropImage
            autoPaddingEnabled: false
            blurEnabled: true; blur: 1; blurMax: 64
            saturation: 0.7
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.alpha(root.surfaceColor, 0.3) }
                GradientStop { position: 0.45; color: Qt.alpha(root.surfaceColor, 0.5) }
                GradientStop { position: 1; color: Qt.alpha(root.surfaceColor, 0.72) }
            }
        }
        // Where the surface grows out of the bar (and out of a side frame when attached) it keeps
        // the frame's plain colour and only then turns into the picture, so the seam stays invisible.
        Rectangle {
            visible: !root.detached
            x: 0; y: 0
            width: parent.width; height: root.pad + root.seamFade
            gradient: Gradient {
                GradientStop { position: 0; color: root.surfaceColor }
                GradientStop { position: (root.pad + 6) / (root.pad + root.seamFade); color: root.surfaceColor }
                GradientStop { position: 1; color: Qt.alpha(root.surfaceColor, 0) }
            }
        }
        Rectangle {
            visible: root.leftAttached && !root.detached
            x: 0; width: root.side + root.seamFade; height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: root.surfaceColor }
                GradientStop { position: (root.side + 6) / (root.side + root.seamFade); color: root.surfaceColor }
                GradientStop { position: 1; color: Qt.alpha(root.surfaceColor, 0) }
            }
        }
        Rectangle {
            visible: root.rightAttached && !root.detached
            x: parent.width - width; width: root.side + root.seamFade; height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.alpha(root.surfaceColor, 0) }
                GradientStop { position: 1 - (root.side + 6) / (root.side + root.seamFade); color: root.surfaceColor }
                GradientStop { position: 1; color: root.surfaceColor }
            }
        }
    }
    MultiEffect {
        x: surface.x; y: surface.y
        width: surface.width; height: surface.height
        visible: root.backdrop !== "" && backdropImage.status === Image.Ready && root.revealedHeight >= 1
        source: backdropLayer
        autoPaddingEnabled: false
        maskEnabled: true
        maskSource: surface
        opacity: root.backdropStrength * root.contentProgress
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }
    Item {
        width: root.width
        height: root.revealedHeight
        clip: true
        Item {
            id: stage
            width: root.width
            height: root.targetHeight
            y: 0
            opacity: root.contentProgress
            enabled: root.expanded
        }
    }
}

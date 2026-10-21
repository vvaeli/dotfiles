import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// One monitor's part of the frozen region capture (see Screenshot.qml).
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property var frozen: Screenshot.frozen
    readonly property var monitor: frozen?.monitors.find(m => m.name === modelData.name) ?? null
    readonly property real mx: monitor?.x ?? 0
    readonly property real my: monitor?.y ?? 0
    readonly property real pixelScale: frozen?.scale ?? 1
    readonly property var target: Screenshot.target
    // Target rectangle in this window's coordinates.
    readonly property real tx: target ? target.x - mx : 0
    readonly property real ty: target ? target.y - my : 0
    readonly property real tw: target?.width ?? 0
    readonly property real th: target?.height ?? 0
    readonly property real localX: Screenshot.cursor.x - mx
    readonly property real localY: Screenshot.cursor.y - my
    readonly property bool hasCursor: !!monitor && localX >= 0 && localX < width && localY >= 0 && localY < height
    readonly property bool hasToolbars: !!monitor && Screenshot.toolbarMonitor === monitor.name
    anchors { top: true; bottom: true; left: true; right: true }
    visible: Screenshot.active && !!monitor
    color: "black"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "md3-region"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    function rectOf(s) {
        return Qt.rect(Math.min(s.x1, s.x2) - mx, Math.min(s.y1, s.y2) - my, Math.abs(s.x2 - s.x1), Math.abs(s.y2 - s.y1));
    }
    // Draws one annotation; shared by the committed layer and the shape being dragged.
    function paintShape(ctx, s) {
        ctx.save();
        ctx.translate(-mx, -my);
        ctx.strokeStyle = s.color; ctx.fillStyle = s.color;
        ctx.lineWidth = s.size; ctx.lineCap = "round"; ctx.lineJoin = "round";
        const x = Math.min(s.x1, s.x2), y = Math.min(s.y1, s.y2), w = Math.abs(s.x2 - s.x1), h = Math.abs(s.y2 - s.y1);
        if (s.type === "rect") ctx.strokeRect(x, y, w, h);
        else if (s.type === "ellipse") { ctx.beginPath(); ctx.ellipse(x, y, w, h); ctx.stroke(); }
        else if (s.type === "marker") { ctx.globalAlpha = 0.4; ctx.fillRect(x, y, w, h); }
        else if (s.type === "line" || s.type === "arrow") {
            ctx.beginPath(); ctx.moveTo(s.x1, s.y1); ctx.lineTo(s.x2, s.y2); ctx.stroke();
            if (s.type === "arrow") {
                const angle = Math.atan2(s.y2 - s.y1, s.x2 - s.x1), head = 10 + s.size * 3;
                ctx.beginPath();
                ctx.moveTo(s.x2, s.y2);
                ctx.lineTo(s.x2 - head * Math.cos(angle - 0.45), s.y2 - head * Math.sin(angle - 0.45));
                ctx.lineTo(s.x2 - head * Math.cos(angle + 0.45), s.y2 - head * Math.sin(angle + 0.45));
                ctx.closePath(); ctx.fill(); ctx.stroke();
            }
        } else if (s.type === "pen") {
            ctx.beginPath(); ctx.moveTo(s.points[0], s.points[1]);
            for (let i = 2; i < s.points.length; i += 2) ctx.lineTo(s.points[i], s.points[i + 1]);
            ctx.stroke();
        } else if (s.type === "step") {
            const radius = 12 + s.size * 2;
            ctx.beginPath(); ctx.arc(s.x, s.y, radius, 0, Math.PI * 2); ctx.fill();
            const light = Qt.color(s.color).hslLightness > 0.6;
            ctx.fillStyle = light ? "#000000" : "#ffffff";
            ctx.font = "bold " + Math.round(radius * 1.1) + "px sans-serif";
            ctx.textAlign = "center"; ctx.textBaseline = "middle";
            ctx.fillText(String(s.n), s.x, s.y + 1);
        } else if (s.type === "text") {
            ctx.font = (12 + s.size * 4) + "px sans-serif";
            ctx.textBaseline = "top";
            s.text.split("\n").forEach((line, i) => ctx.fillText(line, s.x, s.y + i * (12 + s.size * 4) * 1.25));
        }
        ctx.restore();
    }

    Connections {
        target: Screenshot
        function onShapesChanged() { shapesCanvas.requestPaint(); }
        function onDraftChanged() { draftCanvas.requestPaint(); }
        // Renders this monitor's annotations for the capture; the canvas paints on the next frame first.
        function onLayersRequested(rect, names) {
            if (root.monitor && names.includes(root.monitor.name)) { shapesCanvas.requestPaint(); grabDelay.restart(); }
        }
    }
    Timer {
        id: grabDelay
        interval: 60
        onTriggered: artLayer.grabToImage(result => {
            const path = Screenshot.runtimeDir + "/layer-" + root.monitor.name + ".png";
            if (result.saveToFile(path)) Screenshot.layerSaved(root.monitor.name, path);
            else Screenshot.cancel();
        })
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            const ctrl = event.modifiers & Qt.ControlModifier;
            const step = event.modifiers & Qt.ShiftModifier ? 10 : 1;
            const tool = Screenshot.tools.find(t => t.key === event.text);
            if (event.key === Qt.Key_Escape) Screenshot.cancel();
            else if (ctrl && event.key === Qt.Key_Z) { if (event.modifiers & Qt.ShiftModifier) Screenshot.redo(); else Screenshot.undo(); }
            else if (ctrl && event.key === Qt.Key_Y) Screenshot.redo();
            else if (ctrl && event.key === Qt.Key_C) Screenshot.captureMonitor();
            else if (tool && !ctrl) Screenshot.setTool(tool.name);
            else if (event.key === Qt.Key_Left) Screenshot.nudge(-step, 0);
            else if (event.key === Qt.Key_Right) Screenshot.nudge(step, 0);
            else if (event.key === Qt.Key_Up) Screenshot.nudge(0, -step);
            else if (event.key === Qt.Key_Down) Screenshot.nudge(0, step);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) Screenshot.capture(Screenshot.target ?? Screenshot.hovered);
            else return;
            event.accepted = true;
        }

        Image {
            id: still
            anchors.fill: parent
            source: root.visible && root.frozen ? "file://" + root.frozen.path + "?" + Date.now() : ""
            sourceClipRect: root.monitor ? Qt.rect((root.mx - root.frozen.originX) * root.pixelScale, (root.my - root.frozen.originY) * root.pixelScale,
                root.monitor.width * root.pixelScale, root.monitor.height * root.pixelScale) : Qt.rect(0, 0, 0, 0)
            cache: false
            asynchronous: false
            smooth: false
        }

        // Annotations: exactly what is composited onto the capture.
        Item {
            id: artLayer
            anchors.fill: parent
            Repeater {
                model: Screenshot.shapes.concat(Screenshot.draft ? [Screenshot.draft] : []).filter(s => s.type === "blur" || s.type === "pixelate")
                Item {
                    id: effect
                    required property var modelData
                    readonly property rect area: root.rectOf(modelData)
                    x: area.x; y: area.y; width: Math.max(1, area.width); height: Math.max(1, area.height)
                    clip: true
                    ShaderEffectSource {
                        id: patch
                        anchors.fill: parent
                        sourceItem: still
                        sourceRect: effect.area
                        visible: effect.modelData.type === "pixelate"
                        smooth: false
                        textureSize: effect.modelData.type === "pixelate"
                            ? Qt.size(Math.max(1, effect.width / (6 + effect.modelData.size * 2)), Math.max(1, effect.height / (6 + effect.modelData.size * 2)))
                            : Qt.size(effect.width, effect.height)
                    }
                    MultiEffect {
                        anchors.fill: parent
                        visible: effect.modelData.type === "blur"
                        source: patch
                        blurEnabled: true; blur: 1; blurMax: 64
                        autoPaddingEnabled: false
                    }
                }
            }
            Canvas {
                id: shapesCanvas
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    for (const s of Screenshot.shapes) root.paintShape(ctx, s);
                }
            }
            Canvas {
                id: draftCanvas
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    if (Screenshot.draft) root.paintShape(ctx, Screenshot.draft);
                }
            }
        }

        // Everything but the region target is dimmed.
        Item {
            id: shade
            anchors.fill: parent
            visible: !Screenshot.drawing
            readonly property color tone: Qt.rgba(0, 0, 0, 0.45)
            readonly property real edgeLeft: Math.max(0, Math.min(width, root.tx))
            readonly property real edgeTop: Math.max(0, Math.min(height, root.ty))
            readonly property real edgeRight: Math.max(0, Math.min(width, root.tx + root.tw))
            readonly property real edgeBottom: Math.max(0, Math.min(height, root.ty + root.th))
            Rectangle { color: shade.tone; width: shade.width; height: shade.edgeTop }
            Rectangle { color: shade.tone; y: shade.edgeBottom; width: shade.width; height: shade.height - shade.edgeBottom }
            Rectangle { color: shade.tone; y: shade.edgeTop; width: shade.edgeLeft; height: shade.edgeBottom - shade.edgeTop }
            Rectangle { color: shade.tone; x: shade.edgeRight; y: shade.edgeTop; width: shade.width - shade.edgeRight; height: shade.edgeBottom - shade.edgeTop }
        }

        Rectangle {
            visible: !!root.target
            x: root.tx - border.width; y: root.ty - border.width
            width: root.tw + border.width * 2; height: root.th + border.width * 2
            color: "transparent"
            border.width: 2
            border.color: Theme.primary
        }

        // Size (and window title) next to the target, like ShareX's region info.
        Rectangle {
            visible: !!root.target && root.tw > 0
            readonly property bool below: root.ty - height - 8 < 0
            x: Math.max(4, Math.min(parent.width - width - 4, root.tx))
            y: below ? Math.min(parent.height - height - 4, root.ty + 8) : root.ty - height - 8
            width: infoText.implicitWidth + 20; height: 28; radius: 14
            color: Theme.surface
            Label {
                id: infoText
                anchors.centerIn: parent
                font.pixelSize: 12; font.weight: Font.Medium
                text: Math.round(root.tw) + " × " + Math.round(root.th)
                    + (!Screenshot.dragging && root.target?.title ? "  ·  " + root.target.title.slice(0, 60) : "")
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Screenshot.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor
            function global(mouse) { return Qt.point(Math.round(mouse.x + root.mx), Math.round(mouse.y + root.my)); }
            onPositionChanged: mouse => Screenshot.move(global(mouse))
            onPressed: mouse => {
                if (mouse.button === Qt.RightButton) Screenshot.rightClick();
                else Screenshot.press(global(mouse));
            }
            onReleased: mouse => { if (mouse.button === Qt.LeftButton) Screenshot.release(global(mouse)); }
            onWheel: wheel => {
                const delta = wheel.angleDelta.y > 0 ? 1 : -1;
                if (Screenshot.drawing) Screenshot.size = Math.max(1, Math.min(20, Screenshot.size + delta));
                else Screenshot.zoom = Math.max(4, Math.min(20, Screenshot.zoom + delta * 2));
            }
        }

        // Text being typed; the next click or Enter places it on the drawing layer.
        TextInput {
            id: textEditor
            readonly property var draft: Screenshot.textDraft
            visible: !!draft && !!root.monitor && draft.x - root.mx >= 0 && draft.x - root.mx < root.width
            x: (draft?.x ?? 0) - root.mx; y: (draft?.y ?? 0) - root.my
            color: draft?.color ?? "white"
            font.pixelSize: 12 + (draft?.size ?? 4) * 4
            selectByMouse: false
            cursorVisible: true
            onDraftChanged: {
                if (draft && visible) { text = draft.text; forceActiveFocus(); }
                else keys.forceActiveFocus();
            }
            onTextChanged: { if (Screenshot.textDraft) Screenshot.textDraft = Object.assign({}, Screenshot.textDraft, {text: text}); }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) { Screenshot.textDraft = null; event.accepted = true; }
                else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                    Screenshot.commitText(); event.accepted = true;
                }
            }
        }

        // Magnifier with a pixel grid; the scroll wheel changes its zoom.
        Rectangle {
            id: magnifier
            visible: root.hasCursor && !Screenshot.drawing
            readonly property int pixels: 15
            readonly property real box: pixels * Screenshot.zoom
            readonly property bool flipX: root.localX + 24 + width > root.width
            readonly property bool flipY: root.localY + 24 + height > root.height
            x: flipX ? root.localX - 24 - width : root.localX + 24
            y: flipY ? root.localY - 24 - height : root.localY + 24
            width: box + 12
            height: box + 12 + coordinates.implicitHeight + 8
            radius: 16
            color: Theme.surface
            Item {
                x: 6; y: 6; width: magnifier.box; height: magnifier.box
                clip: true
                // Reuses the already decoded still on the GPU instead of loading the capture again.
                ShaderEffectSource {
                    anchors.fill: parent
                    sourceItem: still
                    sourceRect: Qt.rect(Math.floor(root.localX) - 7, Math.floor(root.localY) - 7, magnifier.pixels, magnifier.pixels)
                    smooth: false
                }
                Canvas {
                    anchors.fill: parent
                    property real zoom: Screenshot.zoom
                    onZoomChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.strokeStyle = "rgba(255,255,255,0.12)";
                        ctx.lineWidth = 1;
                        for (let i = 1; i < magnifier.pixels; ++i) {
                            const p = Math.round(i * zoom) + 0.5;
                            ctx.beginPath(); ctx.moveTo(p, 0); ctx.lineTo(p, height); ctx.stroke();
                            ctx.beginPath(); ctx.moveTo(0, p); ctx.lineTo(width, p); ctx.stroke();
                        }
                    }
                }
                Rectangle {
                    x: 7 * Screenshot.zoom; y: 7 * Screenshot.zoom
                    width: Screenshot.zoom; height: Screenshot.zoom
                    color: "transparent"; border.width: 1; border.color: Theme.primary
                }
            }
            Label {
                id: coordinates
                anchors.horizontalCenter: parent.horizontalCenter
                y: magnifier.box + 14
                font.pixelSize: 11; color: Theme.muted
                text: "X " + Math.round(Screenshot.cursor.x) + "   Y " + Math.round(Screenshot.cursor.y)
            }
        }

        // Top toolbar: selection and drawing tools.
        Rectangle {
            id: toolbar
            visible: root.hasToolbars
            anchors.horizontalCenter: parent.horizontalCenter
            y: 16
            width: toolRow.implicitWidth + 16; height: toolRow.implicitHeight + 16; radius: 24
            color: Theme.container
            HoverHandler { cursorShape: Qt.ArrowCursor }
            RowLayout {
                id: toolRow
                anchors.centerIn: parent
                spacing: 4
                Repeater {
                    model: Screenshot.tools
                    Chip {
                        required property var modelData
                        required property int index
                        flat: Screenshot.tool !== modelData.name
                        selected: Screenshot.tool === modelData.name
                        icon: modelData.icon; iconSize: 18
                        implicitWidth: 40; implicitHeight: 40
                        tooltip: modelData.title + " (" + modelData.key + ")"
                        onClicked: Screenshot.setTool(modelData.name)
                    }
                }
                Rectangle { implicitWidth: 1; implicitHeight: 24; color: Theme.outline; Layout.leftMargin: 4; Layout.rightMargin: 4 }
                Chip { flat: true; icon: "undo"; implicitWidth: 40; implicitHeight: 40; tooltip: "Отменить (Ctrl+Z)"; enabled: Screenshot.shapes.length > 0; onClicked: Screenshot.undo() }
                Chip { flat: true; icon: "redo"; implicitWidth: 40; implicitHeight: 40; tooltip: "Повторить (Ctrl+Y)"; enabled: Screenshot.redoStack.length > 0; onClicked: Screenshot.redo() }
            }
        }

        // Bottom toolbar: colour, size and actions.
        Rectangle {
            visible: root.hasToolbars
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 16
            width: bottomRow.implicitWidth + 24; height: bottomRow.implicitHeight + 16; radius: 24
            color: Theme.container
            HoverHandler { cursorShape: Qt.ArrowCursor }
            RowLayout {
                id: bottomRow
                anchors.centerIn: parent
                spacing: 6
                Repeater {
                    model: Screenshot.palette
                    Rectangle {
                        required property string modelData
                        readonly property bool current: Qt.colorEqual(Screenshot.color, modelData)
                        implicitWidth: 28; implicitHeight: 28; radius: 14
                        color: modelData
                        border.width: current ? 3 : 1
                        border.color: current ? Theme.primary : Theme.outline
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Screenshot.color = parent.modelData }
                    }
                }
                Rectangle { implicitWidth: 1; implicitHeight: 24; color: Theme.outline; Layout.leftMargin: 6; Layout.rightMargin: 6 }
                Chip { flat: true; text: "−"; implicitWidth: 32; implicitHeight: 36; onClicked: Screenshot.size = Math.max(1, Screenshot.size - 1) }
                Label { text: Screenshot.size + " px"; font.pixelSize: 12; Layout.minimumWidth: 36; horizontalAlignment: Text.AlignHCenter }
                Chip { flat: true; text: "+"; implicitWidth: 32; implicitHeight: 36; onClicked: Screenshot.size = Math.min(20, Screenshot.size + 1) }
                Rectangle { implicitWidth: 1; implicitHeight: 24; color: Theme.outline; Layout.leftMargin: 6; Layout.rightMargin: 6 }
                Label {
                    color: Theme.muted; font.pixelSize: 12
                    text: Screenshot.drawing ? "Рисуй, затем выбери «Область» (1) · колесо — толщина"
                        : "Тяни — область · клик — окно · стрелки — 1 px · ПКМ — отмена"
                }
                Rectangle { implicitWidth: 1; implicitHeight: 24; color: Theme.outline; Layout.leftMargin: 6; Layout.rightMargin: 6 }
                Chip { icon: "monitor"; text: "Весь экран"; implicitHeight: 36; tooltip: "Сохранить весь монитор (Ctrl+C)"; onClicked: Screenshot.captureMonitor() }
                Chip { icon: "close"; text: "Отмена"; implicitHeight: 36; tooltip: "Esc"; onClicked: Screenshot.cancel() }
            }
        }
    }
}

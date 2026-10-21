pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// ShareX-style region capture. The hotkey freezes every monitor; the top toolbar picks a
// selection or drawing tool, the bottom one colour, size and actions. Annotations are drawn
// on the frozen screen; finishing a selection saves and copies that region with them.
// Coordinates are global layout pixels, shared by the overlays on every monitor.
Scope {
    id: root
    readonly property string script: Quickshell.shellDir + "/screenshot.py"
    readonly property string runtimeDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/md3-screenshot"
    property bool active: false
    property bool edit: false
    property var frozen: null
    property point cursor: Qt.point(0, 0)
    property bool pressed: false
    property bool dragging: false
    property point anchor: Qt.point(0, 0)
    property real zoom: 10

    readonly property var tools: [
        {name: "region", icon: "selectRegion", title: "Область или окно", key: "1"},
        {name: "rect", icon: "square", title: "Прямоугольник", key: "2"},
        {name: "ellipse", icon: "ellipse", title: "Эллипс", key: "3"},
        {name: "arrow", icon: "arrow", title: "Стрелка", key: "4"},
        {name: "line", icon: "line", title: "Линия", key: "5"},
        {name: "pen", icon: "pen", title: "Карандаш", key: "6"},
        {name: "marker", icon: "marker", title: "Маркер", key: "7"},
        {name: "text", icon: "text", title: "Текст", key: "8"},
        {name: "step", icon: "step", title: "Нумерация", key: "9"},
        {name: "blur", icon: "blur", title: "Размытие", key: "0"},
        {name: "pixelate", icon: "pixelate", title: "Пикселизация", key: "-"}
    ]
    readonly property var palette: ["#ff3b30", "#ff9500", "#ffcc00", "#34c759", "#0a84ff", "#af52de", "#ffffff", "#000000"]
    property string tool: "region"
    property color color: palette[0]
    property int size: 4
    property var shapes: []
    property var redoStack: []
    property var draft: null
    // Text being typed at a point; committed on Enter or the next click.
    property var textDraft: null
    readonly property bool drawing: tool !== "region"

    readonly property var selection: {
        const x = Math.min(anchor.x, cursor.x), y = Math.min(anchor.y, cursor.y);
        return {x: x, y: y, width: Math.abs(cursor.x - anchor.x) + 1, height: Math.abs(cursor.y - anchor.y) + 1};
    }
    // Topmost window under the cursor, or the whole monitor over the desktop.
    readonly property var hovered: {
        if (!frozen) return null;
        const inside = r => cursor.x >= r.x && cursor.x < r.x + r.width && cursor.y >= r.y && cursor.y < r.y + r.height;
        return frozen.windows.find(inside) ?? frozen.monitors.find(inside) ?? null;
    }
    readonly property var target: drawing ? null : dragging ? selection : hovered
    readonly property var cursorMonitor: frozen?.monitors.find(m => cursor.x >= m.x && cursor.x < m.x + m.width
        && cursor.y >= m.y && cursor.y < m.y + m.height) ?? null
    // Toolbars stay on the monitor the capture started on, like ShareX.
    property string toolbarMonitor: ""

    signal layersRequested(var rect, var names)

    function region(withEditor) {
        if (active || freezer.running || cropper.running || Desktop.preview) return;
        edit = !!withEditor;
        freezer.running = true;
    }
    function reset() {
        pressed = false; dragging = false; draft = null; textDraft = null;
        shapes = []; redoStack = []; tool = "region";
    }
    function cancel() { active = false; reset(); frozen = null; }

    function setTool(name) { commitText(); tool = name; pressed = false; dragging = false; draft = null; }
    function add(shape) { shapes = shapes.concat([shape]); redoStack = []; }
    function undo() {
        if (textDraft) { textDraft = null; return; }
        if (!shapes.length) return;
        redoStack = redoStack.concat([shapes[shapes.length - 1]]);
        shapes = shapes.slice(0, -1);
    }
    function redo() {
        if (!redoStack.length) return;
        shapes = shapes.concat([redoStack[redoStack.length - 1]]);
        redoStack = redoStack.slice(0, -1);
    }
    function nextStep() { return shapes.filter(s => s.type === "step").length + 1; }
    function commitText() {
        if (textDraft && textDraft.text.trim() !== "") add(textDraft);
        textDraft = null;
    }

    // Pointer events from any monitor's overlay, in global coordinates.
    function press(point) {
        cursor = point;
        if (tool === "text") {
            commitText();
            textDraft = {type: "text", x: point.x, y: point.y, text: "", color: color.toString(), size: size};
            return;
        }
        commitText();
        if (tool === "step") {
            add({type: "step", x: point.x, y: point.y, n: nextStep(), color: color.toString(), size: size});
            return;
        }
        pressed = true; dragging = false; anchor = point;
        if (drawing) draft = {type: tool, x1: point.x, y1: point.y, x2: point.x, y2: point.y,
                              points: [point.x, point.y], color: color.toString(), size: size};
    }
    function move(point) {
        cursor = point;
        if (!pressed) return;
        if (!dragging && (Math.abs(point.x - anchor.x) > 3 || Math.abs(point.y - anchor.y) > 3)) dragging = true;
        if (draft) {
            const next = Object.assign({}, draft, {x2: point.x, y2: point.y});
            if (tool === "pen") next.points = draft.points.concat([point.x, point.y]);
            draft = next;
        }
    }
    function release(point) {
        if (!pressed) return;
        move(point);
        pressed = false;
        if (draft) {
            if (dragging) add(draft);
            draft = null;
            dragging = false;
            return;
        }
        const rect = dragging ? selection : hovered;
        dragging = false;
        capture(rect);
    }
    // ShareX: right click drops what is being drawn or selected, or leaves when there is nothing.
    function rightClick() {
        if (textDraft) textDraft = null;
        else if (pressed || dragging || draft) { pressed = false; dragging = false; draft = null; }
        else cancel();
    }
    // Arrow keys move the real cursor by one pixel for pixel-exact edges.
    function nudge(dx, dy) {
        const point = Qt.point(cursor.x + dx, cursor.y + dy);
        Hyprland.dispatch(`hl.dsp.cursor.move({x=${point.x},y=${point.y}})`);
        move(point);
    }
    function captureMonitor() {
        const monitor = frozen?.monitors.find(m => m.name === toolbarMonitor) ?? cursorMonitor;
        if (monitor) capture(monitor);
    }

    // Annotated captures need each monitor's drawing layer rendered first (layerSaved).
    property var pendingRect: null
    property var pendingLayers: []
    property var savedLayers: []
    function capture(rect) {
        if (!rect || rect.width < 1 || rect.height < 1) return;
        commitText();
        const r = {x: Math.round(rect.x), y: Math.round(rect.y), width: Math.round(rect.width), height: Math.round(rect.height)};
        if (!shapes.length) { crop(r, []); return; }
        const names = frozen.monitors.filter(m => m.x < r.x + r.width && m.x + m.width > r.x && m.y < r.y + r.height && m.y + m.height > r.y)
            .map(m => m.name);
        pendingRect = r; pendingLayers = names; savedLayers = [];
        layersRequested(r, names);
    }
    function layerSaved(name, path) {
        if (!pendingRect || !pendingLayers.includes(name)) return;
        savedLayers = savedLayers.concat([name + "=" + path]);
        if (savedLayers.length === pendingLayers.length) {
            const r = pendingRect;
            pendingRect = null;
            crop(r, savedLayers);
        }
    }
    function crop(r, layers) {
        const args = ["python3", script, "crop", String(r.x), String(r.y), String(r.width), String(r.height)];
        if (edit) args.push("edit");
        for (const layer of layers) args.push("layer:" + layer);
        cancel();
        cropper.command = args;
        cropper.running = true;
    }

    Process {
        id: freezer
        command: ["python3", root.script, "freeze"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.frozen = JSON.parse(text); } catch (e) { root.frozen = null; return; }
                root.reset();
                root.cursor = Qt.point(root.frozen.cursor?.x ?? 0, root.frozen.cursor?.y ?? 0);
                root.toolbarMonitor = root.cursorMonitor?.name ?? root.frozen.monitors[0]?.name ?? "";
                root.active = true;
            }
        }
    }
    Process {
        id: cropper
        stderr: StdioCollector { id: cropError }
        onExited: code => { if (code !== 0) Desktop.actionError = cropError.text.trim() || "Скриншот не сохранён"; }
    }
}

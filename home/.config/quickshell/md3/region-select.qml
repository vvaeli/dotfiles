import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root
    property bool finished: false
    property var monitors: JSON.parse(Quickshell.env("MD3_REGION_MONITORS") || "[]")
    FileView {
        id: result
        path: Quickshell.env("MD3_REGION_FILE")
        onSaved: quitDelay.start()
        onSaveFailed: Qt.quit()
    }
    Timer { id: quitDelay; interval: 100; onTriggered: Qt.quit() }
    function finish(geometry) {
        if (finished) return;
        finished = true;
        if (geometry) result.setText(geometry);
        else Qt.quit();
    }
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: window
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            visible: !root.finished
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "md3-region"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            RegionSurface {
                anchors.fill: parent
                frozenImage: root.monitors.find(m => m.name === window.screen.name)?.frozenImage ?? ""
                onCancelled: root.finish("")
                onSelected: (x, y, w, h) => {
                    const monitor = root.monitors.find(m => m.name === window.screen.name);
                    if (monitor) root.finish(JSON.stringify({monitor: monitor.name, x: x, y: y, width: w, height: h}));
                    else root.finish("");
                }
            }
        }
    }
}

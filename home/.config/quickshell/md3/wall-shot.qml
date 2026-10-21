// Live wallpaper menu with the real gallery; saves MD3_SCREENSHOT.
import QtQuick
import Quickshell
ShellRoot {
    FloatingWindow {
        implicitWidth: 772; implicitHeight: 640; visible: true
        Rectangle {
            id: capture
            anchors.fill: parent
            color: Theme.surface
            MenuPane { x: 16; y: 16; contentWidth: 740; targetX: 16; height: implicitHeight; maximumHeight: 600; page: "wallpaper"; expanded: true }
        }
    }
    Timer {
        interval: 3000; running: true
        onTriggered: capture.grabToImage(r => { if (Quickshell.env("MD3_SCREENSHOT")) r.saveToFile(Quickshell.env("MD3_SCREENSHOT")); Qt.quit(); })
    }
}

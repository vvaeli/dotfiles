pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    property var palette: ({})
    property FileView paletteFile: FileView {
        path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/md3/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.palette = JSON.parse(text()); } catch (_) {} }
    }
    readonly property bool light: palette.mode === "light"
    readonly property color surface: palette.surface || "#141218"
    readonly property color container: surface
    readonly property color containerHigh: surface
    readonly property color highest: surface
    readonly property color cardSurface: palette.cardSurface || "#211e29"
    readonly property color cardInteractive: palette.cardInteractive || "#302a3d"
    readonly property color cardHover: palette.cardHover || "#3b334b"
    readonly property int menuJoinRadius: 24
    readonly property int menuShadow: 16
    // На светлом фоне тени заметнее, поэтому слои прозрачнее.
    readonly property real shadowAlpha: light ? 0.012 : 0.025
    readonly property color buttonSurface: palette.buttonSurface || "#2e2938"
    readonly property color buttonFilled: palette.buttonFilled || "#3b334b"
    readonly property color primary: palette.primary || "#d0bcff"
    readonly property color textPrimary: palette.textPrimary || "#381e72"
    readonly property color primaryContainer: palette.primaryContainer || "#4f378b"
    readonly property color textPrimaryContainer: palette.textPrimaryContainer || "#eaddff"
    readonly property color secondaryContainer: palette.secondaryContainer || "#4a4458"
    readonly property color textSurface: palette.textSurface || "#e6e0e9"
    readonly property color muted: palette.muted || "#cac4d0"
    readonly property color outline: palette.outline || "#49454f"
    readonly property color error: palette.error || "#ffb4ab"
    readonly property color success: palette.success || "#a8dab5"
    readonly property string font: "Adwaita Sans"
    readonly property int barHeight: 44
    readonly property int windowGap: 8
    readonly property int frameWidth: 6
    readonly property int frameRadius: 25
    // Motion tokens matched to caelestia-dots/shell's expressive animations.
    // https://github.com/caelestia-dots/shell/blob/main/plugin/src/Caelestia/Config/tokens.hpp
    readonly property int duration: 200
    readonly property int spatialDuration: 500
    readonly property int fastSpatialDuration: 350
    readonly property int slowEffectsDuration: 300
    readonly property var spatialCurve: [0.38, 1.21, 0.22, 1, 1, 1]
    readonly property var fastSpatialCurve: [0.42, 1.67, 0.21, 0.9, 1, 1]
    readonly property var effectsCurve: [0.34, 0.8, 0.34, 1, 1, 1]
    readonly property var slowEffectsCurve: [0.34, 0.88, 0.34, 1, 1, 1]
    // Команды запускаются массивами аргументов, без shell-интерполяции.
    property var launcher: ["env", "QT_QPA_PLATFORMTHEME=", "qs", "-c", "md3", "ipc", "call", "launcher", "toggle"]
    property var terminal: ["ghostty"]
}

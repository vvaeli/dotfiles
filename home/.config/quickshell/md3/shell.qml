import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

ShellRoot {





    Component.onCompleted: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/clipboard-watch"])
    // Instantiate per-screen surfaces after their components are available.
    Variants {
        model: Quickshell.screens
        Scope {
            id: screenScope
            required property var modelData
            ScreenFrame { modelData: screenScope.modelData }
            Bar { modelData: screenScope.modelData }
            OsdWindow { modelData: screenScope.modelData }
            DockWindow { modelData: screenScope.modelData }
            CrosshairWindow { modelData: screenScope.modelData }
            ClipboardWindow { modelData: screenScope.modelData }
            LauncherWindow { modelData: screenScope.modelData }
            ScreenshotWindow { modelData: screenScope.modelData }
        }
    }
    // Bound in Hyprland as a non-consuming Escape, so apps still get the key.
    GlobalShortcut {
        appid: "md3"; name: "menuClose"
        description: "Close the bar menu"
        onPressed: Desktop.menuCloseRequested()
    }
    IpcHandler {
        target: "menu"
        // Opens (or toggles) a bar menu page on the focused monitor, e.g. "main" or "wallpaper".
        function toggle(page: string): void { Desktop.menuRequested(page, Hyprland.focusedMonitor?.name || "DP-1"); }
    }
    IpcHandler {
        target: "wallpaper"
        function toggle(): void { Desktop.toggleWallpaperMenu(); }
    }
    IpcHandler {
        target: "screenshot"
        // ShareX-style region capture; edit opens Satty on the result.
        function region(): void { Screenshot.region(false); }
        function regionEdit(): void { Screenshot.region(true); }
        function cancel(): void { Screenshot.cancel(); }
    }
    IpcHandler {
        target: "launcher"
        function toggle(): void { Desktop.toggleLauncher(); }
    }
    IpcHandler {
        target: "clipboard"
        function toggle(): void { Desktop.toggleClipboard(); }
    }
    IpcHandler {
        target: "crosshair"
        function toggle(): void { Desktop.crosshairVisible = !Desktop.crosshairVisible; }
    }
    IpcHandler {
        target: "osd"
        function show(kind: string, level: real, muted: bool, monitor: string): void {
            Desktop.showOsd(kind, level, muted, monitor);
        }
    }
    IpcHandler {
        target: "bar"
        function toggle(): void { Desktop.barVisible = !Desktop.barVisible; }
        function toggleDnd(): void { Desktop.dnd = !Desktop.dnd; }
        function clearNotifications(): void { Desktop.clearNotifications(); }
    }
}



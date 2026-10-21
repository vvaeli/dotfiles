import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

ColumnLayout {
    id: root
    // State is kept by Desktop: the change keeps running if the menu closes.
    property var entries: Desktop.wallpaperEntries
    property string currentPath: Desktop.wallpaperCurrent
    readonly property string pendingPath: Desktop.wallpaperPending
    readonly property bool busy: Desktop.wallpaperBusy || Desktop.colorModeBusy
    signal closeRequested()
    spacing: 12
    function focusGallery() {
        const selected = entries.findIndex(entry => entry.path === currentPath);
        gallery.keyboard = false;
        gallery.currentIndex = entries.length ? Math.max(0, selected) : -1;
        gallery.reveal(gallery.currentIndex, false);
        gallery.forceActiveFocus();
    }
    property bool focusedOnce: false
    onEntriesChanged: if (!focusedOnce && entries.length) { focusedOnce = true; Qt.callLater(focusGallery); }
    function refresh() { Desktop.refreshWallpapers(); }
    function select(path) { Desktop.applyWallpaper(path); }
    Component.onCompleted: { if (entries.length) { focusedOnce = true; focusGallery(); } refresh(); }

    MenuHeader {
        icon: 'wallpaper'
        title: 'Обои'
        subtitle: Desktop.wallpaperBusy ? 'Меняю обои и палитру…' : Desktop.colorModeBusy ? 'Перекрашиваю…' : root.entries.length + ' в ~/Pictures/Wallpapers'
        Chip {
            icon: Theme.light ? 'sun' : 'sleep'
            text: Theme.light ? 'Светлая' : 'Тёмная'
            implicitHeight: 32
            filled: true
            enabled: Desktop.wallpaperMatugen && !root.busy
            onClicked: Desktop.toggleColorMode()
        }
        Chip { icon: 'folder'; flat: true; implicitWidth: 32; implicitHeight: 32; tooltip: 'Открыть папку'; onClicked: Desktop.launch(['thunar', Quickshell.env('HOME') + '/Pictures/Wallpapers']) }
        Chip { icon: 'refresh'; flat: true; implicitWidth: 32; implicitHeight: 32; tooltip: 'Обновить'; enabled: !Desktop.wallpaperLoading && !root.busy; onClicked: root.refresh() }
    }
    GridView {
        id: gallery
        objectName: "wallpaperGallery"
        // Arrow keys show a focus ring; the mouse hides it again.
        property bool keyboard: false
        // Scrolls so the item is fully visible, smoothly unless opening.
        function reveal(index, animated) {
            if (index < 0) return;
            if (!animated) { scroll.stop(); positionViewAtIndex(index, GridView.Contain); return; }
            const top = Math.floor(index / columns) * cellHeight;
            const limit = Math.max(0, contentHeight - height);
            let target = contentY;
            if (top < contentY) target = top;
            else if (top + cellHeight > contentY + height) target = top + cellHeight - height;
            target = Math.max(0, Math.min(limit, target));
            scrollTo(target);
        }
        function scrollTo(target) {
            scroll.to = Math.max(0, Math.min(Math.max(0, contentHeight - height), target));
            scroll.restart();
        }
        readonly property int columns: width >= 580 ? 3 : 2
        focus: true
        keyNavigationEnabled: true
        highlightFollowsCurrentItem: false
        onCurrentIndexChanged: if (keyboard) reveal(currentIndex, true)
        Keys.onReturnPressed: if (currentIndex >= 0) root.select(root.entries[currentIndex].path)
        Keys.onEnterPressed: if (currentIndex >= 0) root.select(root.entries[currentIndex].path)
        Keys.onEscapePressed: root.closeRequested()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_F5) { root.refresh(); event.accepted = true; return; }
            keyboard = true;
        }
        // Tiles sit 4 px inside their cells; the negative margins line their edges up with the header.
        Layout.fillWidth: true; Layout.leftMargin: -4; Layout.rightMargin: -4
        Layout.preferredHeight: cellHeight * 3 + cellHeight * 0.4
        cellWidth: Math.floor(width / columns)
        cellHeight: Math.round((cellWidth - 8) * 9 / 16) + 8
        model: root.entries
        reuseItems: true
        cacheBuffer: cellHeight * 4
        clip: true; boundsBehavior: Flickable.StopAtBounds
        interactive: false
        NumberAnimation { id: scroll; target: gallery; property: "contentY"; duration: 260; easing.type: Easing.OutCubic }
        // Wheel steps of a third of a row, eased, instead of Flickable's jumpy wheel handling.
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const base = scroll.running ? scroll.to : gallery.contentY;
                const delta = event.pixelDelta.y !== 0 ? -event.pixelDelta.y : -event.angleDelta.y / 120 * gallery.cellHeight * 0.6;
                if (event.pixelDelta.y !== 0) { scroll.stop(); gallery.contentY = Math.max(0, Math.min(Math.max(0, gallery.contentHeight - gallery.height), base + delta)); }
                else gallery.scrollTo(base + delta);
                gallery.keyboard = false;
            }
        }
        Controls.ScrollBar.vertical: Controls.ScrollBar { policy: gallery.contentHeight > gallery.height ? Controls.ScrollBar.AsNeeded : Controls.ScrollBar.AlwaysOff }
        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            readonly property bool selected: root.currentPath === modelData.path
            readonly property bool pending: root.pendingPath === modelData.path
            readonly property bool focused: gallery.keyboard && gallery.activeFocus && GridView.isCurrentItem
            width: gallery.cellWidth; height: gallery.cellHeight
            Item {
                id: tile
                anchors.fill: parent; anchors.margins: 4
                scale: tileTap.pressed ? 0.96 : 1
                Behavior on scale { NumberAnimation { duration: Theme.fastSpatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.fastSpatialCurve } }
                // Selection ring; the picture shrinks inside it like an MD3 selected image.
                Rectangle {
                    anchors.fill: parent; radius: 20
                    color: 'transparent'
                    border.width: 3; border.color: cell.focused && !cell.selected ? Theme.outline : Theme.primary
                    opacity: cell.selected || cell.pending || cell.focused ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.duration } }
                }
                ClippingRectangle {
                    id: picture
                    property real inset: cell.selected || cell.pending ? 7 : cell.focused ? 5 : 0
                    anchors.fill: parent; anchors.margins: inset
                    radius: 20 - inset * 0.6
                    color: Theme.cardSurface
                    Behavior on inset { NumberAnimation { duration: Theme.fastSpatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.spatialCurve } }
                    Image {
                        id: image
                        anchors.fill: parent
                        source: cell.modelData.preview
                        asynchronous: true; cache: true
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(480, 270)
                        opacity: status === Image.Ready ? 1 : 0
                        scale: hover.hovered && !cell.selected ? 1.05 : 1
                        Behavior on opacity { NumberAnimation { duration: Theme.duration } }
                        Behavior on scale { NumberAnimation { duration: Theme.slowEffectsDuration; easing.type: Easing.OutCubic } }
                    }
                    // File name only on hover, over a soft shade.
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 40
                        opacity: hover.hovered ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.duration } }
                        gradient: Gradient {
                            GradientStop { position: 0; color: 'transparent' }
                            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.6) }
                        }
                        Label { x: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 8; width: parent.width - 24; text: cell.modelData.name; textFormat: Text.PlainText; font.pixelSize: 12; color: 'white'; elide: Text.ElideRight }
                    }
                    // Applying: dim the picture and spin.
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(0, 0, 0, 0.45)
                        opacity: cell.pending ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: Theme.duration } }
                        Icon {
                            anchors.centerIn: parent; name: 'refresh'; tint: 'white'; width: 28; height: 28
                            RotationAnimator on rotation { running: cell.pending; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                        }
                    }
                }
                Rectangle {
                    visible: cell.modelData.video
                    x: picture.x + 8; y: picture.y + 8; width: 26; height: 26; radius: 13; color: Qt.rgba(0, 0, 0, 0.55)
                    Icon { anchors.centerIn: parent; name: 'play'; width: 14; height: 14; tint: 'white' }
                }
                // Check badge of the applied wallpaper.
                Rectangle {
                    width: 26; height: 26; radius: 13
                    x: picture.x + picture.width - width - 8; y: picture.y + 8
                    color: Theme.primary
                    scale: cell.selected ? 1 : 0
                    visible: scale > 0
                    Behavior on scale { NumberAnimation { duration: Theme.fastSpatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.fastSpatialCurve } }
                    Icon { anchors.centerIn: parent; name: 'check'; width: 16; height: 16; tint: Theme.surface }
                }
                HoverHandler { id: hover; cursorShape: root.busy ? Qt.BusyCursor : Qt.PointingHandCursor; onHoveredChanged: if (hovered) gallery.keyboard = false }
                TapHandler {
                    id: tileTap
                    enabled: !root.busy
                    onTapped: { gallery.keyboard = false; gallery.currentIndex = cell.index; gallery.forceActiveFocus(); root.select(cell.modelData.path); }
                }
            }
        }
        Label { anchors.centerIn: parent; visible: gallery.count === 0; text: Desktop.wallpaperLoading ? 'Готовлю превью…' : 'Добавь картинки или видео в папку с обоями'; color: Theme.muted; width: parent.width - 32; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter }
    }
    Label {
        readonly property string text2: Desktop.wallpaperMessage || (!Desktop.wallpaperMatugen ? 'Для автоматической палитры: sudo pacman -S matugen' : '')
        visible: text2 !== ''
        Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12
        color: Desktop.wallpaperMessage && Desktop.wallpaperMessage.indexOf('Обои обновлены') !== 0 ? Theme.error : Theme.muted
        text: text2
    }
}

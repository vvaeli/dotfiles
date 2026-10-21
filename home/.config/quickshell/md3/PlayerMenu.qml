import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Mpris

// Player page: the cover as a spinning disc ringed by a live spectrum, the track,
// seek bar, transport (shuffle, previous, play, next, repeat), the player's volume and a switch
// between players. The spectrum comes from visualizer.py, which runs only while this is open.
RowLayout {
    id: root
    spacing: 20
    signal navigateRequested(string page)
    signal closeRequested()

    readonly property var players: Mpris.players.values
    property var chosen: null
    // The chosen player while it exists, otherwise the shell's current one.
    readonly property var player: chosen && players.includes(chosen) ? chosen : Desktop.player
    readonly property bool playing: !!player && player.isPlaying
    readonly property bool timed: (player?.lengthSupported ?? false) && (player?.length ?? 0) > 0
    readonly property int bars: 40
    property var levels: []
    // Previews set a local file here; normally the player's cover.
    property string artOverride: ""
    readonly property string art: artOverride || root.player?.trackArtUrl || ""
    // The menu paints the blurred cover across its whole surface; the bass lifts it a little.
    readonly property string backdrop: art
    // Ray colour: "cover" takes the most vivid colour of the album art, "theme" the system accent.
    // The choice is kept in ~/.local/state/md3/player.json.
    property string rayMode: "cover"
    FileView {
        id: prefs
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/md3/player.json"
        onLoaded: { try { const mode = JSON.parse(text()).rays; if (mode === "cover" || mode === "theme") root.rayMode = mode; } catch (_) {} }
    }
    function setRayMode(mode) {
        rayMode = mode;
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s\\n' \"$2\" > \"$1\"", "md3",
            prefs.path, JSON.stringify({rays: mode})]);
    }
    ColorQuantizer { id: quantizer; source: root.art; depth: 3; rescaleSize: 64 }
    readonly property color coverAccent: {
        let best = null, score = -1;
        for (const c of quantizer.colors) {
            const value = c.hslSaturation * (1 - Math.abs(c.hslLightness - 0.55));
            if (value > score) { score = value; best = c; }
        }
        if (!best || best.hslSaturation < 0.12) return Theme.primary;
        // Light enough to stand out on the darkened backdrop (dark enough in the light theme).
        return Qt.hsla(Math.max(0, best.hslHue), Math.min(1, best.hslSaturation * 1.15 + 0.1),
            Theme.light ? 0.38 : Math.max(0.7, best.hslLightness), 1);
    }
    readonly property color rayColor: rayMode === "theme" || !art ? Theme.primary : coverAccent
    readonly property real backdropStrength: Math.min(1, (Theme.light ? 0.5 : 0.62) + bass * 0.3)
    // Bass drives the cover's breathing.
    readonly property real bass: levels.length ? (levels[0] + levels[1] + levels[2] + levels[3]) / 400 : 0
    function time(s) { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }

    Timer {
        interval: 500; repeat: true
        running: root.playing && root.visible
        onTriggered: root.player.positionChanged()
    }
    Process {
        id: spectrum
        command: ["python3", Quickshell.shellPath("visualizer.py"), String(root.bars)]
        running: root.visible && root.playing && !Desktop.preview
        onRunningChanged: if (!running) root.levels = []
        stdout: SplitParser {
            onRead: line => {
                const values = line.split(" ").map(Number);
                if (values.length === root.bars) root.levels = values;
            }
        }
    }

    // ── Hero: the cover as a spinning disc with the spectrum around it ───────────
    Item {
        id: hero
        Layout.preferredWidth: 300
        implicitWidth: 300
        implicitHeight: 300
        readonly property real disc: 172
        // Aura in the cover's colours: the cover cut to a circle first, then blurred, so its edge
        // is soft and round (blurring a square image left visible square edges).
        Item {
            id: auraSource
            anchors.centerIn: parent
            // Room for the whole blur falloff (48 px each side of the circle) while staying inside
            // the menu's clip, which ends 12 px outside the 300 px hero.
            width: 322; height: 322
            visible: false
            layer.enabled: true
            ClippingRectangle {
                anchors.centerIn: parent
                width: 222; height: 222; radius: 111
                color: "transparent"
                Image {
                    id: auraImage
                    anchors.fill: parent
                    source: root.art
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 128
                }
            }
        }
        MultiEffect {
            anchors.fill: auraSource
            source: auraSource
            visible: auraImage.status === Image.Ready
            autoPaddingEnabled: false
            blurEnabled: true; blur: 0.85; blurMax: 48
            saturation: 1
            // Pulses with the bass in brightness, not size, so it never grows into the clip.
            opacity: 0.9 + root.bass * 0.1
            Behavior on opacity { NumberAnimation { duration: 90 } }
        }
        // Radial spectrum: the bands mirrored left and right so the ring is symmetric.
        // The whole ring casts one soft shadow, so the rays lift off any backdrop.
        Item {
            id: ring
            anchors.fill: parent
            opacity: root.levels.length ? 1 : 0.35
            Behavior on opacity { NumberAnimation { duration: Theme.slowEffectsDuration } }
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.6)
                shadowBlur: 0.45
                blurMax: 16
                shadowVerticalOffset: 1
                shadowHorizontalOffset: 0
            }
            Item {
            x: ring.width / 2; y: ring.height / 2
            Repeater {
                model: root.bars * 2
                Item {
                    required property int index
                    readonly property int band: index < root.bars ? index : root.bars * 2 - 1 - index
                    readonly property real level: (root.levels[band] ?? 0) / 100
                    rotation: (index + 0.5) * 360 / (root.bars * 2)
                    Rectangle {
                        x: -width / 2
                        y: -(hero.disc / 2 + 10) - height
                        width: 4
                        height: 5 + parent.level * 46
                        radius: 2
                        // Louder bands are brighter and whiter at the tip of the colour.
                        color: Qt.tint(root.rayColor, Qt.rgba(1, 1, 1, Theme.light ? 0 : 0.25 * parent.level))
                        opacity: 0.5 + 0.5 * parent.level
                        antialiasing: true
                        Behavior on height { NumberAnimation { duration: 70 } }
                        Behavior on color { ColorAnimation { duration: Theme.slowEffectsDuration } }
                    }
                }
            }
            }
        }
        // The disc: round cover that turns while music plays and stops where it was on pause.
        Item {
            id: cover
            width: hero.disc; height: hero.disc
            anchors.centerIn: parent
            scale: 1 + root.bass * 0.035
            Behavior on scale { NumberAnimation { duration: 90 } }
            RectangularShadow {
                anchors.fill: parent
                radius: width / 2; blur: 30; offset.y: 6
                color: Qt.rgba(0, 0, 0, 0.4)
            }
            Item {
                id: spinner
                anchors.fill: parent
                antialiasing: true
                layer.enabled: true
                layer.smooth: true
                layer.samples: 4
                RotationAnimation on rotation {
                    running: root.visible
                    paused: !root.playing
                    from: 0; to: 360
                    duration: 24000
                    loops: Animation.Infinite
                }
                // Antialiased round clip: a thresholded mask left stair steps that showed while turning.
                ClippingRectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.secondaryContainer
                    antialiasing: true
                    Image {
                        anchors.fill: parent
                        source: root.art
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                        asynchronous: true
                        smooth: true; mipmap: true
                        sourceSize.width: 344
                    }
                }
            }
            // Record grooves and the spindle hole.
            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 2; height: width; radius: width / 2
                color: "transparent"
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
            }
            Rectangle {
                anchors.centerIn: parent
                width: 34; height: 34; radius: 17
                color: Theme.cardSurface
                border.width: 2; border.color: Theme.primary
                Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: Theme.primary }
            }
        }
    }

    // ── Right column: source, track, seek, transport, volume ─────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 12
        // Source app (opens its window) and, with several players, a switch between them.
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Chip {
                visible: !!root.player
                text: root.player?.identity ?? ""
                icon: root.player?.canRaise ? "external" : ""
                iconSize: 13; textSize: 11; implicitHeight: 28; maximumTextWidth: 140
                filled: true
                enabled: root.player?.canRaise ?? false
                opacity: 1
                tooltip: "Открыть плеер"
                onClicked: { root.player.raise(); root.closeRequested(); }
            }
            // Where the rays take their colour from: the cover or the system theme.
            Chip {
                icon: "palette"; iconSize: 14
                implicitWidth: 28; implicitHeight: 28
                filled: true
                foreground: root.rayColor
                tooltip: root.rayMode === "cover" ? "Лучи: цвет обложки · нажми для цвета темы" : "Лучи: цвет темы · нажми для цвета обложки"
                onClicked: root.setRayMode(root.rayMode === "cover" ? "theme" : "cover")
            }
            Item { Layout.fillWidth: true }
            Repeater {
                model: root.players.length > 1 ? root.players : []
                Chip {
                    required property var modelData
                    visible: modelData !== root.player
                    text: modelData.identity || "Плеер"
                    icon: modelData.isPlaying ? "play" : "pause"; iconSize: 11
                    textSize: 11; implicitHeight: 28; maximumTextWidth: 100
                    flat: true
                    tooltip: "Переключить на этот плеер"
                    onClicked: root.chosen = modelData
                }
            }
        }
        // ── Track ───────────────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 3
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignLeft
                text: root.player?.trackTitle || (root.player ? "Без названия" : "Ничего не играет")
                elide: Text.ElideRight
                font.pixelSize: 22; font.weight: Font.DemiBold
            }
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignLeft
                text: root.player ? [root.player.trackArtist, root.player.trackAlbum].filter(t => t).join(" · ") : "Включи музыку в любом плеере"
                visible: text !== ""
                elide: Text.ElideRight
                color: Theme.muted; font.pixelSize: 13
            }
        }

        // ── Seek ────────────────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.timed
            spacing: 0
            MdSlider {
                Layout.fillWidth: true
                implicitHeight: 30
                to: Math.max(1, root.player?.length ?? 1)
                value: root.player?.position ?? 0
                enabled: root.player?.canSeek ?? false
                onMoved: root.player.position = value
            }
            RowLayout {
                Layout.fillWidth: true
                Label { text: root.time(root.player?.position ?? 0); font.pixelSize: 11; color: Theme.muted }
                Item { Layout.fillWidth: true }
                Label { text: "−" + root.time((root.player?.length ?? 0) - (root.player?.position ?? 0)); font.pixelSize: 11; color: Theme.muted }
            }
        }

        // ── Transport ───────────────────────────────────────────────────────────────
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            Chip {
                icon: "shuffle"; iconSize: 18
                implicitWidth: 44; implicitHeight: 44
                flat: !(root.player?.shuffle ?? false)
                filled: root.player?.shuffle ?? false
                foreground: root.player?.shuffle ? Theme.primary : Theme.muted
                enabled: root.player?.shuffleSupported ?? false
                tooltip: "Перемешать"
                onClicked: root.player.shuffle = !root.player.shuffle
            }
            Chip {
                icon: "previous"; iconSize: 22
                implicitWidth: 52; implicitHeight: 52
                enabled: root.player?.canGoPrevious ?? false
                onClicked: root.player.previous()
            }
            // Play/pause: square-ish while playing, round when paused, as in MD3 expressive.
            Chip {
                icon: root.playing ? "pause" : "play"; iconSize: 28
                implicitWidth: 76; implicitHeight: 64
                radius: root.playing ? 20 : 32
                Behavior on radius { NumberAnimation { duration: Theme.spatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.spatialCurve } }
                selected: true
                enabled: root.player?.canTogglePlaying ?? false
                onClicked: root.player.togglePlaying()
            }
            Chip {
                icon: "next"; iconSize: 22
                implicitWidth: 52; implicitHeight: 52
                enabled: root.player?.canGoNext ?? false
                onClicked: root.player.next()
            }
            Chip {
                readonly property int loop: root.player?.loopState ?? MprisLoopState.None
                icon: loop === MprisLoopState.Track ? "repeatOne" : "repeat"; iconSize: 18
                implicitWidth: 44; implicitHeight: 44
                flat: loop === MprisLoopState.None
                filled: loop !== MprisLoopState.None
                foreground: loop !== MprisLoopState.None ? Theme.primary : Theme.muted
                enabled: root.player?.loopSupported ?? false
                tooltip: loop === MprisLoopState.Track ? "Повтор трека" : loop === MprisLoopState.Playlist ? "Повтор списка" : "Без повтора"
                onClicked: root.player.loopState = loop === MprisLoopState.None ? MprisLoopState.Playlist
                    : loop === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
            }
        }

        // ── Player volume ───────────────────────────────────────────────────────────
        MenuGroup {
            visible: root.player?.volumeSupported ?? false
            padding: 10
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Icon {
                    name: (root.player?.volume ?? 0) <= 0.001 ? "mute" : (root.player?.volume ?? 0) < 0.5 ? "volumeLow" : "volume"
                    tint: Theme.muted
                    implicitWidth: 18; implicitHeight: 18
                    Layout.leftMargin: 4
                }
                MdSlider {
                    Layout.fillWidth: true
                    implicitHeight: 30
                    value: root.player?.volume ?? 0
                    onMoved: root.player.volume = value
                }
                Label {
                    text: Math.round((root.player?.volume ?? 0) * 100) + "%"
                    font.pixelSize: 11; color: Theme.muted
                    Layout.preferredWidth: 34
                    horizontalAlignment: Text.AlignRight
                    Layout.rightMargin: 4
                }
            }
        }
    }
}

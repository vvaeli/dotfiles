import QtQuick
import QtQuick.Layouts

// Night light page: mode, warmth and the schedule for the automatic mode. A day strip shows
// when the filter is on and where "now" is; every change fades on screen.
ColumnLayout {
    id: root
    spacing: 12
    readonly property bool auto: Desktop.nightMode === "auto"
    readonly property var warm: Desktop.kelvinColor(Desktop.nightTemperature)
    readonly property color warmColor: Qt.rgba(warm[0], warm[1] * 0.92, warm[2] * 0.8, 1)
    readonly property var curve: [0.2, 0, 0, 1, 1, 1]

    MenuHeader {
        icon: "nightLight"
        title: "Ночной свет"
        active: Desktop.nightLight
        subtitle: Desktop.nightError || Desktop.nightStatus
        subtitleColor: Desktop.nightError ? Theme.error : Theme.muted
        MdSwitch {
            checked: Desktop.nightMode !== "off"
            onToggled: Desktop.setNightMode(checked ? "off" : "on")
        }
    }

    MenuSection { text: "Режим" }
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: [{mode: "off", text: "Выкл", icon: "close"}, {mode: "on", text: "Всегда", icon: "nightLight"}, {mode: "auto", text: "По времени", icon: "timer"}]
            Chip {
                required property var modelData
                Layout.fillWidth: true
                text: modelData.text; icon: modelData.icon
                selected: Desktop.nightMode === modelData.mode
                onClicked: Desktop.setNightMode(modelData.mode)
            }
        }
    }

    MenuSection { text: "Теплота · " + Desktop.nightTemperature + " K" }
    MenuGroup {
        padding: 14
        spacing: 6
        // Swatch of the chosen tint next to neutral white.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 28; radius: 14
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#f4f4f4" }
                GradientStop { position: 1; color: root.warmColor; }
            }
            Behavior on implicitHeight { NumberAnimation { duration: 200 } }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right; anchors.rightMargin: 12
                text: Desktop.nightTemperature <= 3200 ? "Очень тёплый" : Desktop.nightTemperature <= 4200 ? "Тёплый" : "Мягкий"
                color: "#3a2a1a"; font.pixelSize: 11; font.weight: Font.Medium
            }
        }
        MdSlider {
            Layout.fillWidth: true
            from: 6000; to: 2500; stepSize: 100
            value: Desktop.nightTemperature
            onMoved: Desktop.setNightTemperature(value)
        }
    }

    MenuSection {
        text: "Расписание"
        opacity: root.auto ? 1 : 0.5
        Behavior on opacity { NumberAnimation { duration: Theme.duration } }
    }
    MenuGroup {
        padding: 14
        spacing: 10
        opacity: root.auto ? 1 : 0.5
        Behavior on opacity { NumberAnimation { duration: Theme.duration } }
        // Day strip: 00–24 with the night window shaded and a marker for the current time.
        Item {
            id: strip
            Layout.fillWidth: true
            implicitHeight: 40
            readonly property real start: Desktop.nightStart / 1440
            readonly property real length: ((Desktop.nightEnd - Desktop.nightStart + 1440) % 1440 || 1440) / 1440
            property real shownStart: start
            property real shownLength: length
            Behavior on shownStart { NumberAnimation { duration: 360; easing.type: Easing.BezierSpline; easing.bezierCurve: root.curve } }
            Behavior on shownLength { NumberAnimation { duration: 360; easing.type: Easing.BezierSpline; easing.bezierCurve: root.curve } }
            Rectangle {
                id: track
                width: parent.width; height: 22; radius: 11
                color: Theme.secondaryContainer
                clip: true
                // The window may wrap past midnight: draw it twice, shifted by a whole day.
                Repeater {
                    model: [-1, 0]
                    Rectangle {
                        required property int modelData
                        x: (strip.shownStart + modelData) * track.width
                        width: strip.shownLength * track.width
                        height: track.height; radius: 11
                        color: root.warmColor
                        opacity: 0.9
                    }
                }
                Rectangle {
                    x: Desktop.nightClock / 1440 * track.width - 1.5
                    width: 3; height: track.height
                    radius: 1.5
                    color: Theme.textSurface
                }
            }
            Repeater {
                model: [0, 6, 12, 18, 24]
                Label {
                    required property int modelData
                    y: track.height + 4
                    x: Math.max(0, Math.min(strip.width - width, modelData / 24 * strip.width - width / 2))
                    text: String(modelData).padStart(2, "0")
                    color: Theme.muted; font.pixelSize: 10
                }
            }
        }
        NightTimeRow { interactive: root.auto; title: "Включать"; icon: "nightLight"; minutes: Desktop.nightStart; onChange: step => Desktop.setNightSchedule(Desktop.nightStart + step, Desktop.nightEnd) }
        NightTimeRow { interactive: root.auto; title: "Выключать"; icon: "sun"; minutes: Desktop.nightEnd; onChange: step => Desktop.setNightSchedule(Desktop.nightStart, Desktop.nightEnd + step) }
        Label {
            Layout.fillWidth: true
            text: "Фильтр плавно набирает силу за " + Desktop.nightRamp + " минут после начала и так же уходит перед концом."
            color: Theme.muted; font.pixelSize: 11; wrapMode: Text.Wrap
        }
    }
}

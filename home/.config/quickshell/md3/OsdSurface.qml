import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool expanded: false
    property string kind: "volume"
    property real level: 0
    property bool muted: false
    property string layoutName: Desktop.keyboardLayout
    readonly property bool layoutMode: kind === "layout"
    readonly property string layoutCode: /Russian|Русский/i.test(layoutName) ? "RU" : /English|Английский/i.test(layoutName) ? "EN" : layoutName.slice(0, 2).toUpperCase()
    property real progress: expanded ? 1 : 0
    implicitWidth: 320
    implicitHeight: 90
    Behavior on progress {
        NumberAnimation { duration: Theme.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.effectsCurve }
    }
    Card {
        width: parent.width - 16; height: 66
        x: 8; y: 8 + (1 - root.progress) * 12
        opacity: root.progress
        color: Theme.surface
        radius: 22
        RowLayout {
            anchors.fill: parent; anchors.margins: 16; spacing: 12
            Icon {
                name: root.layoutMode ? "keyboard" : root.kind === "brightness" ? "sun" : root.kind === "microphone" ? (root.muted ? "micOff" : "mic") : Desktop.volumeIconFor(root.level, root.muted)
                tint: root.muted ? Theme.muted : Theme.primary
                implicitWidth: 24; implicitHeight: 24
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 7
                Label {
                    text: root.layoutMode ? "Раскладка клавиатуры" : root.kind === "brightness" ? "Яркость" : root.kind === "microphone" ? (root.muted ? "Микрофон выключен" : "Микрофон включён") : root.muted ? "Звук выключен" : "Громкость"
                    font.pixelSize: 12
                }
                Label {
                    visible: root.layoutMode
                    text: root.layoutName
                    font.pixelSize: 13
                    color: Theme.primary
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Rectangle {
                    visible: !root.layoutMode
                    Layout.fillWidth: true; implicitHeight: 6; radius: 3
                    color: Theme.secondaryContainer
                    Rectangle {
                        width: parent.width * (root.muted ? 0 : root.level)
                        height: parent.height; radius: parent.radius; color: Theme.primary
                        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }
                }
            }
            Label { text: root.layoutMode ? root.layoutCode : root.muted ? "—" : Math.round(root.level * 100) + "%"; font.pixelSize: 13; color: Theme.primary; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 38 }
        }
    }
}

import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: root
    property var trayItem: null
    property var path: []
    property var testEntries: null
    readonly property var entries: testEntries ?? (path.length >= 3 ? level3 : path.length === 2 ? level2 : path.length === 1 ? level1 : level0).children.values
    function cleanText(text) { return String(text ?? "").replace(/&&/g, "\u0001").replace(/&/g, "").replace(/\u0001/g, "&"); }
    readonly property string applicationName: {
        const title = root.trayItem?.title ?? "";
        const id = root.trayItem?.id ?? "";
        const raw = title || id;
        if (/discord/i.test(raw + " " + id)) return "Discord";
        if (raw && !/status[_-]?icon|indicator[_-]|^org\.|^com\./i.test(raw)) return raw;
        const cleaned = id.replace(/[_-]?(status[_-]?icon|indicator).*$/i, "").replace(/[_-]/g, " ").trim();
        return cleaned ? cleaned.charAt(0).toUpperCase() + cleaned.slice(1) : "Приложение";
    }
    readonly property string heading: path.length ? cleanText(path[path.length - 1].text) : applicationName
    FontMetrics { id: metrics; font.family: Theme.font; font.pixelSize: 13 }
    readonly property real preferredWidth: Math.max(240, Math.min(360,
        Math.max(metrics.advanceWidth(heading) + 110,
            ...entries.map(entry => metrics.advanceWidth(cleanText(entry.text)) + 100))))
    signal closeRequested()
    // Lets the pane morph to the submenu's size instead of jumping.
    signal morphRequested()
    spacing: 10
    onTrayItemChanged: path = []
    // +1 slides the next level in from the right, -1 brings the previous one back from the left.
    property int direction: 1
    function navigate(next, step) {
        direction = step;
        morphRequested();
        path = next;
        slide.restart();
    }
    function choose(entry) {
        if (!entry || !entry.enabled || entry.isSeparator) return;
        if (entry.hasChildren && path.length < 3) navigate(path.concat([entry]), 1);
        else { entry.triggered(); closeRequested(); }
    }
    function back() { if (path.length) navigate(path.slice(0, -1), -1); }

    // Every level stays open while a submenu is shown: closing the parent menu
    // invalidated its entries, and the submenu stayed at "Загрузка меню…".
    QsMenuOpener { id: level0; menu: root.trayItem?.menu ?? null }
    QsMenuOpener { id: level1; menu: root.path[0] ?? null }
    QsMenuOpener { id: level2; menu: root.path[1] ?? null }
    QsMenuOpener { id: level3; menu: root.path[2] ?? null }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Item {
            implicitWidth: 36; implicitHeight: 36
            Chip {
                anchors.fill: parent
                icon: "left"
                opacity: root.path.length ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Theme.duration } }
                onClicked: root.back()
            }
            Rectangle {
                anchors.fill: parent
                radius: 12
                color: Theme.buttonSurface
                opacity: root.path.length ? 0 : 1
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Theme.duration } }
                Image {
                    anchors.centerIn: parent
                    width: 20; height: 20
                    source: root.trayItem?.icon ?? ""
                    sourceSize.width: 40; sourceSize.height: 40
                    fillMode: Image.PreserveAspectFit
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Label { text: root.heading; font.pixelSize: 16; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
            Label { visible: root.path.length > 0; text: root.applicationName; color: Theme.muted; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
        }
    }

    // One grouped surface for the entries, like an MD3 menu.
    Rectangle {
        id: list
        Layout.fillWidth: true
        implicitHeight: entryColumn.implicitHeight + 8
        radius: 18
        color: Theme.cardSurface
        clip: true
        Behavior on implicitHeight { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
        ColumnLayout {
            id: entryColumn
            x: 4; y: 4
            width: list.width - 8
            spacing: 0
            property real shift: 0
            transform: Translate { x: entryColumn.shift }
            ParallelAnimation {
                id: slide
                NumberAnimation { target: entryColumn; property: "shift"; from: 28 * root.direction; to: 0; duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] }
                NumberAnimation { target: entryColumn; property: "opacity"; from: 0; to: 1; duration: 220 }
            }
            Label {
                visible: root.entries.length === 0
                Layout.margins: 12
                text: "Загрузка меню…"; color: Theme.muted; font.pixelSize: 12
            }
            Repeater {
                model: root.entries
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: modelData.isSeparator ? 9 : 40
                    Rectangle {
                        visible: row.modelData.isSeparator
                        anchors.verticalCenter: parent.verticalCenter
                        x: 12; width: parent.width - 24; height: 1
                        color: Theme.outline; opacity: 0.6
                    }
                    Rectangle {
                        id: item
                        visible: !row.modelData.isSeparator
                        anchors.fill: parent
                        radius: 14
                        color: Theme.textSurface
                        opacity: !row.modelData.enabled ? 0 : press.pressed ? 0.14 : hover.hovered ? 0.07 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.effectsCurve } }
                    }
                    RowLayout {
                        visible: !row.modelData.isSeparator
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10
                        spacing: 12
                        opacity: row.modelData.enabled ? 1 : 0.4
                        scale: press.pressed ? 0.98 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.fastSpatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.fastSpatialCurve } }
                        Item {
                            implicitWidth: 18; implicitHeight: 18
                            visible: row.modelData.buttonType !== QsMenuButtonType.None || row.modelData.icon.toString() !== ""
                            Image {
                                anchors.fill: parent
                                visible: row.modelData.buttonType === QsMenuButtonType.None
                                source: row.modelData.icon
                                fillMode: Image.PreserveAspectFit
                            }
                            // Checkbox and radio entries show their state like MD3 selection controls.
                            Rectangle {
                                anchors.fill: parent
                                visible: row.modelData.buttonType !== QsMenuButtonType.None
                                readonly property bool checked: row.modelData.checkState === Qt.Checked
                                radius: row.modelData.buttonType === QsMenuButtonType.RadioButton ? 9 : 5
                                color: checked ? Theme.primary : "transparent"
                                border.width: checked ? 0 : 2
                                border.color: Theme.muted
                                Behavior on color { ColorAnimation { duration: Theme.duration } }
                                Icon {
                                    anchors.centerIn: parent
                                    visible: parent.checked && row.modelData.buttonType === QsMenuButtonType.CheckBox
                                    name: "check"; tint: Theme.textPrimary; implicitWidth: 14; implicitHeight: 14
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    visible: parent.checked && row.modelData.buttonType === QsMenuButtonType.RadioButton
                                    width: 6; height: 6; radius: 3; color: Theme.textPrimary
                                }
                            }
                        }
                        Label { text: root.cleanText(row.modelData.text); Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 13 }
                        Icon { name: "right"; visible: row.modelData.hasChildren; tint: Theme.muted; implicitWidth: 16; implicitHeight: 16 }
                    }
                    HoverHandler { id: hover; enabled: !row.modelData.isSeparator && row.modelData.enabled; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: press; enabled: !row.modelData.isSeparator && row.modelData.enabled; onTapped: Qt.callLater(() => root.choose(row.modelData)) }
                }
            }
        }
    }
}

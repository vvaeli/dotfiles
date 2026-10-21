import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: root
    property bool opened: false
    property var entries: []
    property string errorText: ""
    readonly property var filtered: entries.filter(entry => entry.text.toLowerCase().includes(search.text.toLowerCase()))
    signal closeRequested()
    spacing: 12
    function refresh() { if (!Desktop.preview && !load.running) load.running = true; }
    function choose(index) {
        if (copy.running || index < 0 || index >= filtered.length) return;
        copy.command = ["python3", Quickshell.shellPath("clipboard.py"), "copy", filtered[index].id];
        if (!Desktop.preview) copy.running = true;
    }
    onOpenedChanged: if (opened) { search.text = ""; errorText = ""; refresh(); focusDelay.restart(); }
    onFilteredChanged: list.currentIndex = filtered.length ? 0 : -1
    Timer { id: focusDelay; interval: 80; onTriggered: search.forceActiveFocus() }
    Process {
        id: load
        command: ["python3", Quickshell.shellPath("clipboard.py"), "list"]
        stdout: StdioCollector { onStreamFinished: { try { root.entries = JSON.parse(text); } catch (_) {} } }
        stderr: StdioCollector { id: loadError }
        onExited: (code, status) => { if (code) root.errorText = loadError.text.trim(); }
    }
    Process {
        id: copy
        stderr: StdioCollector { id: copyError }
        onExited: (code, status) => { if (code) root.errorText = copyError.text.trim(); else root.closeRequested(); }
    }
    RowLayout {
        Layout.fillWidth: true
        Icon { name: "clipboard"; tint: Theme.primary; width: 24; height: 24 }
        Label { text: "Буфер обмена"; font.pixelSize: 22; font.weight: Font.DemiBold; Layout.fillWidth: true }
        Chip { flat: true; icon: "close"; onClicked: root.closeRequested() }
    }
    Controls.TextField {
        id: search
        objectName: "clipboardSearch"
        leftPadding: 14; rightPadding: 14
        Layout.fillWidth: true; implicitHeight: 42
        placeholderText: "Поиск по истории…"
        color: Theme.textSurface; placeholderTextColor: Theme.muted
        font.family: Theme.font; font.pixelSize: 14
        background: Rectangle { radius: 12; color: Theme.cardSurface }
        onAccepted: root.choose(list.currentIndex)
        Keys.onEscapePressed: root.closeRequested()
        Keys.onDownPressed: list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1)
        Keys.onUpPressed: list.currentIndex = Math.max(0, list.currentIndex - 1)
    }
    ListView {
        id: list
        objectName: "clipboardList"
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(400, Math.max(80, contentHeight))
        clip: true; spacing: 8
        model: root.filtered
        boundsBehavior: Flickable.StopAtBounds
        onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
        Controls.ScrollBar.vertical: Controls.ScrollBar {}
        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            width: list.width; height: modelData.kind === "image" ? 116 : 74
            radius: 14
            color: ListView.isCurrentItem ? Theme.buttonFilled : hover.hovered ? Theme.cardHover : Theme.cardInteractive
            border.width: ListView.isCurrentItem ? 1 : 0; border.color: Theme.primary
            Behavior on color { ColorAnimation { duration: Theme.duration } }
            RowLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 12
                Image {
                    visible: row.modelData.kind === "image"
                    source: row.modelData.image
                    Layout.preferredWidth: 112; Layout.preferredHeight: 90
                    sourceSize: Qt.size(224, 180)
                    fillMode: Image.PreserveAspectFit; asynchronous: true
                }
                Icon { visible: row.modelData.kind !== "image"; name: row.modelData.kind === "link" ? "link" : "clipboard"; tint: Theme.primary }
                Label {
                    Layout.fillWidth: true
                    text: row.modelData.text
                    textFormat: Text.PlainText
                    font.pixelSize: 13; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
                }
            }
            HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: { list.currentIndex = row.index; root.choose(row.index); } }
        }
        Label {
            anchors.centerIn: parent
            visible: list.count === 0
            text: load.running ? "Загружаю…" : search.text ? "Ничего не найдено" : "История пока пуста"
            color: Theme.muted
        }
    }
    Label { visible: root.errorText !== ""; text: root.errorText; color: Theme.error; Layout.fillWidth: true; wrapMode: Text.Wrap }
    Label { text: "↑ ↓ — выбрать   ·   Enter — скопировать   ·   Esc — закрыть"; color: Theme.muted; font.pixelSize: 11 }
}

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: root
    property bool opened: false
    property real maximumListHeight: 420
    property var extraResults: []
    property string jobQuery: ""
    property string errorText: ""
    property var applications: DesktopEntries.applications.values
    readonly property bool hasQuery: search.text.trim().length > 0
    readonly property var results: {
        const query = search.text.trim().toLowerCase();
        if (!query) return [];
        const fileMode = query.startsWith('/') || query.startsWith('file ');
        const tokens = query.split(/\s+/).filter(Boolean);
        const apps = fileMode ? [] : applications.filter(app => !app.noDisplay && tokens.every(token =>
            [app.name, app.genericName, app.id, app.comment, ...(app.keywords || [])].join(' ').toLowerCase().includes(token)))
            .sort((a, b) => {
                const score = app => app.name.toLowerCase() === query ? 0 : app.name.toLowerCase().startsWith(query) ? 1 : 2;
                return score(a) - score(b) || a.name.localeCompare(b.name);
            }).slice(0, query ? 30 : 80).map(app => ({kind: 'app', name: app.name, detail: app.genericName || app.comment || app.id, icon: app.icon, entry: app}));
        return [...extraResults.filter(result => result.kind === 'calc' || result.kind === 'error'), ...apps,
            ...extraResults.filter(result => result.kind === 'file')];
    }
    signal closeRequested()
    spacing: 12
    function queryChanged() {
        extraResults = []; errorText = "";
        if (backend.running) backend.running = false;
        debounce.restart();
    }
    function choose(index) {
        if (index < 0 || index >= results.length) return;
        const result = results[index];
        if (result.kind === 'error') return;
        if (Desktop.preview) { closeRequested(); return; }
        if (result.kind === 'app') {
            if (result.entry.runInTerminal) Desktop.launch([...Theme.terminal, '-e', ...result.entry.command]);
            else result.entry.execute();
            closeRequested();
        } else if (result.kind === 'file') {
            Desktop.launch(['xdg-open', result.path]); closeRequested();
        } else if (!copy.running) {
            copy.command = ['python3', Quickshell.shellPath('launcher.py'), 'copy', result.value];
            copy.running = true;
        }
    }
    onOpenedChanged: {
        if (opened) { search.text = ''; extraResults = []; errorText = ''; focusDelay.restart(); }
        else { debounce.stop(); backend.running = false; }
    }
    onResultsChanged: list.currentIndex = results.length ? 0 : -1
    Timer { id: focusDelay; interval: 80; onTriggered: search.forceActiveFocus() }
    Timer {
        id: debounce; interval: 180
        onTriggered: {
            if (!root.opened || Desktop.preview || backend.running || !search.text.trim()) return;
            root.jobQuery = search.text;
            backend.command = ['python3', Quickshell.shellPath('launcher.py'), 'search', root.jobQuery];
            backend.running = true;
        }
    }
    Process {
        id: backend
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.opened && root.jobQuery === search.text) {
                    try { root.extraResults = JSON.parse(text); } catch (_) {}
                }
            }
        }
        stderr: StdioCollector { id: backendError }
        onExited: (code, status) => {
            if (root.jobQuery !== search.text) debounce.restart();
            else if (code && root.opened) root.errorText = backendError.text.trim();
        }
    }
    Process {
        id: copy
        stderr: StdioCollector { id: copyError }
        onExited: (code, status) => { if (code) root.errorText = copyError.text.trim(); else root.closeRequested(); }
    }
    Controls.TextField {
        id: search
        objectName: 'launcherSearch'
        leftPadding: 46; rightPadding: 14
        Layout.fillWidth: true; implicitHeight: 56
        placeholderText: 'Приложение, файл или выражение…'
        color: Theme.textSurface; placeholderTextColor: Theme.muted
        font.family: Theme.font; font.pixelSize: 20
        background: Rectangle { radius: 14; color: Theme.cardSurface }
        Icon {
            anchors.left: parent.left; anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            name: 'search'; tint: Theme.muted; width: 22; height: 22
        }
        onTextChanged: root.queryChanged()
        onAccepted: root.choose(list.currentIndex)
        Keys.onEscapePressed: root.closeRequested()
        Keys.onDownPressed: list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1)
        Keys.onUpPressed: list.currentIndex = Math.max(0, list.currentIndex - 1)
    }
    ListView {
        id: list
        objectName: 'launcherList'
        visible: root.hasQuery
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(root.maximumListHeight, Math.max(80, contentHeight))
        clip: true; spacing: 6; model: root.results
        boundsBehavior: Flickable.StopAtBounds
        onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
        Controls.ScrollBar.vertical: Controls.ScrollBar {}
        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            width: list.width; height: 66; radius: 14
            color: ListView.isCurrentItem ? Theme.buttonFilled : hover.hovered ? Theme.cardHover : Theme.cardInteractive
            border.width: ListView.isCurrentItem ? 1 : 0; border.color: Theme.primary
            Behavior on color { ColorAnimation { duration: Theme.duration } }
            RowLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 12
                Item {
                    Layout.preferredWidth: 32; Layout.preferredHeight: 32
                    Image { id: image; anchors.fill: parent; source: row.modelData.kind === 'app' ? Quickshell.iconPath(row.modelData.icon || '', true) : ''; visible: status === Image.Ready; fillMode: Image.PreserveAspectFit; sourceSize: Qt.size(64,64) }
                    Icon { anchors.centerIn: parent; visible: !image.visible; name: row.modelData.kind === 'calc' ? 'calculator' : row.modelData.kind === 'file' ? 'folder' : 'launcher'; tint: Theme.primary; width: 26; height: 26 }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 3
                    Label { text: row.modelData.name; textFormat: Text.PlainText; font.pixelSize: row.modelData.kind === 'calc' ? 19 : 14; Layout.fillWidth: true; elide: Text.ElideRight }
                    Label { text: row.modelData.detail; textFormat: Text.PlainText; font.pixelSize: 11; color: Theme.muted; Layout.fillWidth: true; elide: Text.ElideMiddle }
                }
            }
            HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: { list.currentIndex = row.index; root.choose(row.index); } }
        }
        Label { anchors.centerIn: parent; visible: list.count === 0; color: Theme.muted; text: backend.running || debounce.running ? 'Ищу…' : 'Ничего не найдено' }
    }
    Label { visible: root.errorText !== ''; text: root.errorText; color: Theme.error; Layout.fillWidth: true; wrapMode: Text.Wrap }
}

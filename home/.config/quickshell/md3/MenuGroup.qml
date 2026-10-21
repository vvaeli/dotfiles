import QtQuick
import QtQuick.Layouts

// One rounded surface holding a list of rows, like the tray menu.
Rectangle {
    id: root
    default property alias content: column.data
    property alias spacing: column.spacing
    property int padding: 4
    Layout.fillWidth: true
    implicitHeight: column.implicitHeight + padding * 2
    radius: 20
    color: Theme.cardSurface
    clip: true
    ColumnLayout {
        id: column
        x: root.padding; y: root.padding
        width: root.width - root.padding * 2
        // Fills a stretched group so spacers inside it can centre the content.
        height: Math.max(implicitHeight, root.height - root.padding * 2)
        spacing: 2
    }
}

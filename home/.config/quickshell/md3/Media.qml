import QtQuick
import QtQuick.Layouts

Card {
    id: root
    implicitHeight: 100
    RowLayout {
        anchors.fill: parent; anchors.margins: 14; spacing: 14
        Rectangle {
            width: 64; height: 64; radius: 16; color: Theme.secondaryContainer; clip: true
            Icon { anchors.centerIn: parent; name: "music"; tint: Theme.primary; width: 28; height: 28 }
            Image { anchors.fill: parent; source: Desktop.player?.trackArtUrl || ""; fillMode: Image.PreserveAspectCrop; visible: status === Image.Ready }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            Label { Layout.fillWidth: true; text: Desktop.player?.trackTitle || "Ничего не играет"; elide: Text.ElideRight; font.weight: Font.DemiBold }
            Label { Layout.fillWidth: true; text: Desktop.player?.trackArtist || Desktop.player?.identity || "Открой музыку в своём плеере"; elide: Text.ElideRight; color: Theme.muted; font.pixelSize: 11 }
            RowLayout {
                spacing: 4
                Chip { icon: "previous"; implicitHeight: 30; enabled: Desktop.player?.canGoPrevious ?? false; onClicked: Desktop.player.previous() }
                Chip { icon: Desktop.player?.isPlaying ? "pause" : "play"; implicitHeight: 30; selected: true; enabled: Desktop.player?.canTogglePlaying ?? false; onClicked: Desktop.player.togglePlaying() }
                Chip { icon: "next"; implicitHeight: 30; enabled: Desktop.player?.canGoNext ?? false; onClicked: Desktop.player.next() }
            }
        }
    }
}

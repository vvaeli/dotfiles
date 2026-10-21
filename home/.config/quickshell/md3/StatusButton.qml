import QtQuick

// Round icon button for the bar's status capsule; filled while its menu is open.
Chip {
    id: root
    property var panel: null
    property string page: ""
    readonly property bool open: page !== "" && !!panel && panel.menuOpen && panel.page === page
    readonly property bool hovered: statusHover.hovered
    HoverHandler { id: statusHover }
    flat: !open
    selected: open
    iconSize: 17
    implicitWidth: text !== "" ? naturalWidth - 6 : 34
    implicitHeight: 34
}

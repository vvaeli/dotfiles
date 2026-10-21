import QtQuick

// Keyed list with continuous motion. Every row sits at a slot computed from the rows above it:
// new rows open their slot (neighbours slide apart, the list grows) and then fade in, staggered
// when several arrive together; removed rows fade out first and only then give their slot back;
// rows that change order glide to their new slot instead of jumping.
Item {
    id: root
    property var source: []
    property string keyField: "name"
    property Component delegate
    property int cardSpacing: 12
    // Kept for older callers; insertion always animates now.
    property bool animateInsertionHeight: true
    property int updateDelay: 0
    // Solid fill behind rows that are otherwise transparent, so rows passing each other
    // while reordering cover one another instead of mixing their text.
    property color rowColor: "transparent"
    property real rowRadius: 16
    property bool initialized: false
    readonly property bool animationsEnabled: {
        let owner = parent;
        while (owner) {
            if (owner.cardAnimationsEnabled !== undefined) return owner.cardAnimationsEnabled;
            owner = owner.parent;
        }
        return true;
    }
    readonly property bool animate: initialized && animationsEnabled
    property int count: 0
    property real contentHeight: 0
    implicitHeight: contentHeight
    readonly property var emphasized: [0.2, 0, 0, 1, 1, 1]
    readonly property var emphasizedDecelerate: [0.05, 0.7, 0.1, 1, 1, 1]
    Behavior on contentHeight {
        enabled: root.animate
        NumberAnimation { duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: root.emphasized }
    }

    function keyFor(item, index) { return String(item[keyField] ?? index); }
    function indexFor(key) {
        for (let i = 0; i < rows.count; ++i) if (rows.get(i).rowKey === key) return i;
        return -1;
    }
    function removeRow(key) {
        const index = indexFor(key);
        if (index >= 0 && rows.get(index).removing) rows.remove(index);
        scheduleLayout();
    }
    // Rows arriving in one update enter one after another.
    property int stagger: 0
    function takeStagger() {
        const delay = 70 + Math.min(stagger, 8) * 40;
        stagger++;
        staggerReset.restart();
        return delay;
    }
    Timer { id: staggerReset; interval: 0; onTriggered: root.stagger = 0 }

    function sync() {
        const incoming = source ?? [];
        const keys = incoming.map((item, index) => keyFor(item, index));
        for (let i = 0; i < rows.count; ++i)
            if (!keys.includes(rows.get(i).rowKey) && !rows.get(i).removing) rows.setProperty(i, "removing", true);
        // Live rows follow the incoming order; outgoing rows keep their place until they fade.
        let pos = 0;
        for (let i = 0; i < incoming.length; ++i) {
            while (pos < rows.count && rows.get(pos).removing && !keys.includes(rows.get(pos).rowKey)) pos++;
            const key = keys[i];
            let index = indexFor(key);
            if (index < 0) rows.insert(pos, {rowKey: key, payload: incoming[i], removing: false});
            else {
                if (index !== pos) rows.move(index, pos, 1);
                if (JSON.stringify(rows.get(pos).payload) !== JSON.stringify(incoming[i]))
                    rows.setProperty(pos, "payload", incoming[i]);
                if (rows.get(pos).removing) rows.setProperty(pos, "removing", false);
            }
            pos++;
        }
        scheduleLayout();
    }
    property bool layoutPending: false
    function scheduleLayout() {
        if (layoutPending) return;
        layoutPending = true;
        Qt.callLater(relayout);
    }
    function relayout() {
        layoutPending = false;
        let y = 0, live = 0;
        for (let i = 0; i < repeater.count; ++i) {
            const item = repeater.itemAt(i);
            if (!item) continue;
            if (item.removing) continue;
            item.slotY = y;
            item.placed = true;
            y += item.rowHeight + cardSpacing;
            live++;
        }
        count = live;
        contentHeight = live ? y - cardSpacing : 0;
    }
    onSourceChanged: { if (updateDelay > 0) updateBatch.restart(); else sync(); }
    onCardSpacingChanged: scheduleLayout()
    Timer { id: updateBatch; interval: root.updateDelay; onTriggered: root.sync() }
    Component.onCompleted: { sync(); relayout(); initialized = true; }
    ListModel { id: rows; dynamicRoles: true }
    Repeater {
        id: repeater
        model: rows
        delegate: Item {
            id: row
            required property var payload
            required property string rowKey
            required property bool removing
            property real slotY: 0
            property bool placed: false
            property real appear: 0
            property int enterDelay: 0
            readonly property real rowHeight: loader.implicitHeight
            onRowHeightChanged: root.scheduleLayout()
            width: root.width
            height: rowHeight
            y: slotY
            // The row travelling up passes over the ones it overtakes.
            property bool rising: false
            onSlotYChanged: rising = placed && slotY < y
            z: removing ? -1 : rising ? 1 : 0
            enabled: !removing
            opacity: appear
            Behavior on y {
                enabled: row.placed && root.animate
                NumberAnimation { duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: root.emphasized }
            }
            onRemovingChanged: {
                if (removing) {
                    enter.stop();
                    if (root.animate) leave.restart();
                    else root.removeRow(rowKey);
                } else {
                    leave.stop();
                    appear = 1;
                    root.scheduleLayout();
                }
            }
            NumberAnimation {
                id: leave
                target: row; property: "appear"; to: 0
                duration: 150; easing.type: Easing.OutCubic
                onFinished: root.removeRow(row.rowKey)
            }
            SequentialAnimation {
                id: enter
                PauseAnimation { duration: row.enterDelay }
                NumberAnimation {
                    target: row; property: "appear"; to: 1
                    duration: 360; easing.type: Easing.BezierSpline; easing.bezierCurve: root.emphasizedDecelerate
                }
            }
            Component.onCompleted: {
                if (root.animate) { enterDelay = root.takeStagger(); enter.start(); }
                else appear = 1;
                root.scheduleLayout();
            }
            Rectangle {
                width: loader.width; height: loader.height
                y: loader.y; scale: loader.scale; transformOrigin: Item.Top
                radius: root.rowRadius
                color: root.rowColor
            }
            Loader {
                id: loader
                property var modelData: row.payload
                width: root.width
                sourceComponent: root.delegate
                // Grows out of its slot: a slight scale and drop, like MD3 list items entering.
                transformOrigin: Item.Top
                scale: 0.94 + row.appear * 0.06
                y: (1 - row.appear) * (row.removing ? 0 : 6)
            }
        }
    }
}

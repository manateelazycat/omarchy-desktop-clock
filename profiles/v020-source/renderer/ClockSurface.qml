import QtQuick
import Quickshell
import Quickshell.Wayland
import "Position.js" as Position

PanelWindow {
    id: panel

    required property var controller
    required property date timestamp
    readonly property real edgeMargin: 24
    readonly property real screenWidth: screen ? screen.width : 1920
    readonly property real screenHeight: screen ? screen.height : 1080
    readonly property real displayScale: Math.min(controller.clockScale,
        Math.max(0.1, (screenWidth - 2 * edgeMargin) / 444),
        Math.max(0.1, (screenHeight - 2 * edgeMargin) / 186))
    readonly property real clockWidth: 444 * displayScale
    readonly property real clockHeight: 186 * displayScale
    readonly property int clockX: Position.pixel(controller.position.x, screenWidth, clockWidth, edgeMargin)
    readonly property int clockY: Position.pixel(controller.position.y, screenHeight, clockHeight, edgeMargin)
    readonly property int inputX: controller.dragging
        ? Position.pixel(controller.dragOrigin.x, screenWidth, clockWidth, edgeMargin) : clockX
    readonly property int inputY: controller.dragging
        ? Position.pixel(controller.dragOrigin.y, screenHeight, clockHeight, edgeMargin) : clockY

    anchors { top: true; left: true }
    margins { top: panel.inputY; left: panel.inputX }
    implicitWidth: clockWidth
    implicitHeight: clockHeight
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: !remapping
    WlrLayershell.namespace: "omarchy-desktop-clock"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // One window at rest; retain its pointer grab while a second card moves.
    property bool remapping: false
    Timer { id: settle; interval: 200; onTriggered: panel.remapping = true }
    Timer { interval: 50; running: panel.remapping; onTriggered: panel.remapping = false }
    Connections {
        target: panel.screen
        function onXChanged() { settle.restart() }
        function onYChanged() { settle.restart() }
    }
    ClockFace {
        width: 444; height: 186
        scale: panel.displayScale
        transformOrigin: Item.TopLeft
        timestamp: panel.timestamp
        palette: panel.controller.palette
        hovered: pointer.containsMouse
        visible: !panel.controller.dragging
        opacity: panel.controller.clockOpacity
    }

    PanelWindow {
        screen: panel.screen
        anchors { top: true; left: true }
        margins { top: panel.clockY; left: panel.clockX }
        implicitWidth: panel.clockWidth
        implicitHeight: panel.clockHeight
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        visible: panel.visible && panel.controller.dragging
        WlrLayershell.namespace: "omarchy-desktop-clock"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}

        ClockFace {
            width: 444
            height: 186
            scale: panel.displayScale
            transformOrigin: Item.TopLeft
            timestamp: panel.timestamp
            palette: panel.controller.palette
            moving: true
            opacity: panel.controller.clockOpacity
        }
    }

    // Use a stationary coordinate system for the entire gesture, avoiding
    // pointer feedback when the clock itself moves under the cursor.
    MouseArea {
        id: pointer
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property point pressPoint: Qt.point(0, 0)
        property point startPosition: Qt.point(0, 0)

        onPressed: mouse => {
            pressPoint = Qt.point(mouse.x, mouse.y);
            startPosition = Qt.point(panel.clockX, panel.clockY);
            panel.controller.beginDrag();
        }
        onPositionChanged: mouse => {
            if (!pressed) return;
            panel.controller.queuePosition(
                Position.fraction(startPosition.x + mouse.x - pressPoint.x,
                                  panel.screenWidth, panel.clockWidth, panel.edgeMargin),
                Position.fraction(startPosition.y + mouse.y - pressPoint.y,
                                  panel.screenHeight, panel.clockHeight, panel.edgeMargin));
        }
        onReleased: panel.controller.savePosition()
        onCanceled: panel.controller.cancelDrag()
    }

    Component.onDestruction: if (pointer.pressed) panel.controller.cancelDrag()
}

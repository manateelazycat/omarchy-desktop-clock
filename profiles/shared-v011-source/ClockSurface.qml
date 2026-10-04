import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Ui
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
    visible: !remapGuard.remapping
    WlrLayershell.namespace: "omarchy-desktop-clock-input"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // This card-sized input window stays at the press origin for the entire
    // gesture. Wayland's implicit pointer grab also delivers motion outside
    // its bounds. Only the separate visible window moves; there are no
    // full-screen buffers or per-motion input-region rebuilds.

    ScreenMoveRemap {
        id: remapGuard
        window: panel
    }

    PanelWindow {
        screen: panel.screen
        anchors { top: true; left: true }
        margins { top: panel.clockY; left: panel.clockX }
        implicitWidth: panel.clockWidth
        implicitHeight: panel.clockHeight
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        visible: panel.visible
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
            hovered: pointer.containsMouse
            moving: pointer.pressed
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
}

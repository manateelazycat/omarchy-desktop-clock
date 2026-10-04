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
    readonly property real displayScale: Math.min(controller.clockScale,
        Math.max(0.1, (width - 2 * edgeMargin) / 444),
        Math.max(0.1, (height - 2 * edgeMargin) / 186))
    readonly property real clockWidth: 444 * displayScale
    readonly property real clockHeight: 186 * displayScale
    readonly property int clockX: Position.pixel(controller.position.x, width, clockWidth, edgeMargin)
    readonly property int clockY: Position.pixel(controller.position.y, height, clockHeight, edgeMargin)

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: !remapGuard.remapping
    WlrLayershell.namespace: "omarchy-desktop-clock"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Only the card receives pointer input. The rest of this transparent
    // screen-sized surface passes all pointer events to the desktop below.
    mask: Region { item: card }

    ScreenMoveRemap {
        id: remapGuard
        window: panel
    }

    Item {
        id: card
        x: panel.clockX
        y: panel.clockY
        width: panel.clockWidth
        height: panel.clockHeight

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
            panel.controller.movePosition(
                Position.fraction(startPosition.x + mouse.x - pressPoint.x,
                                  panel.width, panel.clockWidth, panel.edgeMargin),
                Position.fraction(startPosition.y + mouse.y - pressPoint.y,
                                  panel.height, panel.clockHeight, panel.edgeMargin));
        }
        onReleased: panel.controller.savePosition()
        onCanceled: panel.controller.cancelDrag()
    }
}

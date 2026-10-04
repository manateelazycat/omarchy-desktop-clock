import QtQuick
import QtTest
import Quickshell
import Quickshell.Wayland
import qs.Commons
import "Plugin/renderer" as Plugin

// Run in a separate Quickshell process. Synthetic Qt events do not move the
// user's pointer, and the mock host never writes their desktop configuration.
ShellRoot {
    id: harness
    property int writes: 0
    property var lastSettings: ({})
    property var host: QtObject {
        function updateEntryInline(id, settings) {
            harness.writes++;
            harness.lastSettings = Object.assign({}, settings);
            return true;
        }
    }

    function check(condition, message) {
        if (!condition) throw new Error(message);
    }

    Plugin.ClockController {
        id: service
        palette: ({accent: String(Color.accent), foreground: String(Color.foreground),
            background: String(Color.background), fontFamily: Style.fontFamily})
        emptyScreens: {
            var result = {};
            for (var screen of Quickshell.screens) result[screen.name] = true;
            return result;
        }
        onSaveRequested: settings => harness.host.updateEntryInline("clock-test", settings)
    }
    Plugin.ClockSurface {
        id: surface
        screen: Quickshell.screens[0]
        controller: service
        timestamp: new Date(2026, 9, 4, 21, 48, 32)
    }
    TestEvent { id: events }
    TestResult { id: result }

    PanelWindow {
        id: preview
        anchors { left: true; top: true }
        implicitWidth: 444
        implicitHeight: 186
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "desktop-clock-verification"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}
        Plugin.ClockFace {
            id: face
            anchors.fill: parent
            timestamp: new Date(2026, 9, 4, 21, 48, 32)
            palette: service.palette
        }
    }

    Timer {
        interval: 1000
        running: true
        onTriggered: {
            try {
                harness.check(surface.width > 0 && surface.height > 0, "surface has no geometry");
                service.movePosition(0.5, 0.52);
                var display = surface.displayWindow;
                var visibilityChanges = 0;
                var countVisibility = function() { visibilityChanges++; };
                display.visibleChanged.connect(countVisibility);
                var oldX = surface.clockX;
                var oldY = surface.clockY;
                var x = oldX - surface.inputX + 80;
                var y = oldY - surface.inputY + 80;

                harness.check(events.mousePress(surface.contentItem, x, y,
                    Qt.LeftButton, Qt.NoModifier, 1), "mouse press was not delivered");
                harness.check(service.dragging, "press did not start dragging");
                harness.check(events.mouseMove(surface.contentItem, x + 120, y - 55,
                    1, Qt.LeftButton, Qt.NoModifier), "mouse move was not delivered");
                result.wait(40);
                harness.check(surface.clockX === oldX + 120, "horizontal drag drifted");
                harness.check(surface.clockY === oldY - 55, "vertical drag drifted");
                harness.check(surface.inputX === oldX && surface.inputY === oldY,
                    "input surface moved during the gesture");
                harness.check(display.visible && display === surface.displayWindow && visibilityChanges === 0,
                    "drag replaced or hid the visible window");
                var stoppedX = surface.clockX, stoppedY = surface.clockY;
                result.wait(100);
                harness.check(surface.clockX === stoppedX && surface.clockY === stoppedY,
                    "clock moved after the pointer stopped");
                harness.check(harness.writes === 0, "drag wrote config before release");
                harness.check(events.mouseRelease(surface.contentItem, x + 120, y - 55,
                    Qt.LeftButton, Qt.NoModifier, 1), "mouse release was not delivered");
                harness.check(!service.dragging, "release did not stop dragging");
                harness.check(!service.motionRunning, "release retained the motion timer");
                harness.check(display.visible && display === surface.displayWindow && visibilityChanges === 0,
                    "release remapped or hid the visible window");
                result.wait(100);
                harness.check(surface.clockX === stoppedX && surface.clockY === stoppedY,
                    "clock jumped after release");
                display.visibleChanged.disconnect(countVisibility);
                console.log("CLOCK_TEST_PASS: stop and release preserve position and the mapped display window");
                harness.check(harness.writes === 1, "release did not save exactly once");
                harness.check(harness.lastSettings.positionX === service.position.x,
                    "saved horizontal position differs from display");
                harness.check(harness.lastSettings.positionY === service.position.y,
                    "saved vertical position differs from display");
                console.log("CLOCK_TEST_PASS: drag follows pointer and saves on release");

                var latestX = 0.123;
                var latestY = 0.456;
                service.beginDrag();
                service.queuePosition(latestX, latestY);
                service.savePosition();
                harness.check(service.position.x === latestX && service.position.y === latestY,
                    "release dropped the last pointer sample before the next frame");
                harness.check(harness.lastSettings.positionX === latestX && !service.positionPending,
                    "last pointer sample was not saved");
                harness.writes = 1;
                console.log("CLOCK_TEST_PASS: release flushes the last pending pointer sample");

                var committed = service.savedPosition;
                service.beginDrag();
                service.queuePosition(0.1, 0.1);
                service.cancelDrag();
                result.wait(40);
                harness.check(service.position.x === committed.x && service.position.y === committed.y,
                    "canceled drag did not restore its saved position");
                harness.check(harness.writes === 1, "canceled drag wrote config");
                harness.check(!service.positionPending, "canceled drag retained a pending update");
                console.log("CLOCK_TEST_PASS: canceled drag restores committed position");

                service.configure({settings: {positionX: 0.31, positionY: 0.69, scale: 1.2, opacity: 0.8}});
                harness.check(service.position.x === 0.31 && service.position.y === 0.69,
                    "persisted position did not restore");
                harness.check(service.clockScale === 1.2 && service.clockOpacity === 0.8,
                    "inline style settings did not load");
                console.log("CLOCK_TEST_PASS: saved position and style settings restore");

                service.beginDrag();
                service.movePosition(0.42, 0.42);
                service.configure({settings: {positionX: 0.2, positionY: 0.2}});
                harness.check(service.position.x === 0.42, "config reload interrupted drag");
                service.cancelDrag();
                harness.check(service.position.x === 0.2, "cancel did not use latest config");
                console.log("CLOCK_TEST_PASS: config reload preserves active gesture");

                service.emptyScreens = ({});
                result.wait(50);
                harness.check(service.surfaces.instances.length === 0, "occupied desktops retained surfaces");
                harness.check(!service.clockRunning, "hidden clock retained its seconds timer");
                var empty = {};
                empty[Quickshell.screens[0].name] = true;
                service.emptyScreens = empty;
                result.wait(50);
                harness.check(service.surfaces.instances.length === 1 && service.clockRunning,
                    "one empty desktop did not create exactly one clock");
                console.log("CLOCK_TEST_PASS: occupied desktops have no windows or clock timer");

                var grabbed = service.surfaces.instances[0];
                var savesBefore = harness.writes;
                events.mousePress(grabbed.contentItem, 100, 90, Qt.LeftButton, Qt.NoModifier, 0);
                events.mouseMove(grabbed.contentItem, 130, 100, 0, Qt.LeftButton, Qt.NoModifier);
                harness.check(service.dragging && !service.clockRunning, "drag did not pause the clock timer");
                service.emptyScreens = ({});
                result.wait(50);
                harness.check(!service.dragging && !service.positionPending && harness.writes === savesBefore,
                    "workspace becoming occupied saved or retained a canceled gesture");
                harness.check(service.surfaces.instances.length === 0 && !service.clockRunning,
                    "workspace becoming occupied did not stop all rendering");
                console.log("CLOCK_TEST_PASS: window appearing during drag cancels without saving");

                face.grabToImage(function(result) {
                    var capture = Quickshell.env("DESKTOP_CLOCK_CAPTURE_PATH");
                    if (capture) result.saveToFile(capture);
                    // Palette changes stay inside this isolated process.
                    Color.accent = "#f7768e";
                    Color.foreground = "#eeeeee";
                    Color.background = "#101010";
                    themeCheck.start();
                });
            } catch (error) {
                console.error("CLOCK_RUNTIME_TESTS_FAILED:", error);
                Qt.quit();
            }
        }
    }

    Timer {
        id: themeCheck
        interval: 100
        onTriggered: {
            try {
                harness.check(String(face.accent) === "#f7768e", "accent did not follow theme");
                harness.check(String(face.ink) === "#eeeeee", "foreground did not follow theme");
                console.log("CLOCK_TEST_PASS: colors follow live theme changes");
                console.log("CLOCK_RUNTIME_TESTS_PASSED");
            } catch (error) {
                console.error("CLOCK_RUNTIME_TESTS_FAILED:", error);
            }
            Qt.quit();
        }
    }
}

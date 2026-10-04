import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "Plugin/renderer" as Plugin

// Synthetic input stays inside this separate process; no user settings writes.
ShellRoot {
    id: probe
    property var surface: null
    Plugin.ClockController {
        id: clock
        emptyScreens: {
            var result = {};
            var screen = Quickshell.screens.find(function(s) { return s.name === "DP-1"; }) || Quickshell.screens[0];
            result[screen.name] = true;
            return result;
        }
    }
    TestEvent { id: pointer }
    IpcHandler {
        target: "drag-stop-test"
        function status(): string { return JSON.stringify(clock.status()); }
        function press(): void {
            probe.surface = clock.surfaces.instances[0];
            pointer.mousePress(probe.surface.contentItem, 200, 90, Qt.LeftButton, Qt.NoModifier, 0);
        }
        function move(): void {
            pointer.mouseMove(probe.surface.contentItem, 350, 120, 0, Qt.LeftButton, Qt.NoModifier);
        }
        function release(): void {
            pointer.mouseRelease(probe.surface.contentItem, 350, 120, Qt.LeftButton, Qt.NoModifier, 0);
        }
        function quit(): void { Qt.quit(); }
    }
}

import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "Plugin/renderer" as Plugin

// Real software renderer under four-screen load. Tests force eligibility only
// inside the fixture; production always obtains it from DesktopState.
ShellRoot {
    id: bench
    property var surface: null
    property double started: 0
    property int events: 0
    property int writes: 0
    property int updates: 0
    readonly property bool drag: Quickshell.env("CLOCK_BENCH_DRAG") === "1"
    Plugin.ClockController {
        id: clock
        emptyScreens: {
            var result = {};
            for (var screen of Quickshell.screens) result[screen.name] = true;
            return result;
        }
        onSaveRequested: bench.writes++
    }
    TestEvent { id: pointer }
    Connections {
        target: clock
        function onPositionChanged() { if (bench.started) bench.updates++; }
    }
    IpcHandler {
        target: "clock-bench"
        function finish(): string {
            motion.stop();
            if (bench.surface) pointer.mouseRelease(bench.surface.contentItem, 200, 90, Qt.LeftButton, Qt.NoModifier, 0);
            return JSON.stringify({inputEvents: bench.events, positionUpdates: bench.updates, writes: bench.writes});
        }
    }
    Timer {
        interval: 1500; running: true
        onTriggered: {
            bench.started = Date.now();
            if (!bench.drag) return;
            bench.surface = clock.surfaces.instances[0];
            pointer.mousePress(bench.surface.contentItem, 200, 90, Qt.LeftButton, Qt.NoModifier, 0);
            motion.start();
        }
    }
    Timer {
        id: motion
        interval: 16; repeat: true
        onTriggered: {
            var elapsed = Date.now() - bench.started;
            for (var sample = 0; sample < 8; sample++) {
                pointer.mouseMove(bench.surface.contentItem, 200 + Math.sin((elapsed + sample) / 300) * 180,
                    90 + Math.cos((elapsed + sample) / 300) * 70, 0, Qt.LeftButton, Qt.NoModifier);
                bench.events++;
            }
        }
    }
}

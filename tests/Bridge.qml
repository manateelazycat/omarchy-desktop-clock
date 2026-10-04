import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Plugin" as Plugin

ShellRoot {
    id: test
    property int writes: 0
    property var host: QtObject {
        function updateEntryInline(id, settings) { test.writes++; return true; }
    }
    property var service: null
    Timer {
        interval: 150; running: true
        onTriggered: {
            // Omarchy creates third-party services after startup with no parent.
            var component = Qt.createComponent(Qt.resolvedUrl("Plugin/Service.qml"), Component.PreferSynchronous);
            test.service = component.createObject(null);
            test.service.shell = test.host;
        }
    }
    IpcHandler {
        target: "bridge-test"
        function theme(): void {
            Color.accent = "#f7768e";
            Color.foreground = "#eeeeee";
        }
        function info(): string {
            return JSON.stringify({writes: test.writes, state: test.service ? test.service.workerState : null});
        }
        function unload(): void {
            test.service.destroy();
            test.service = null;
        }
        function quit(): void { Qt.quit(); }
    }
}

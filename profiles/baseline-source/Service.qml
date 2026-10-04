pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Position.js" as Position

Item {
    id: root

    // Omarchy injects this capability-scoped API after creating the service.
    property var shell: null
    readonly property string pluginId: "io.github.manateelazycat.desktop-clock"
    property var settings: ({})
    property point position: Qt.point(0.5, 0.52)
    property point savedPosition: Qt.point(0.5, 0.52)
    property bool dragging: false
    readonly property real clockScale: Position.clamp(Position.number(settings.scale, 1), 0.5, 2)
    readonly property real clockOpacity: Position.clamp(Position.number(settings.opacity, 1), 0.2, 1)

    function loadSettings(raw) {
        try {
            var config = JSON.parse(raw);
            var entries = Array.isArray(config.plugins) ? config.plugins : [];
            var entry = entries.find(function(item) { return item.id === root.pluginId; });
            settings = entry || ({});
            savedPosition = Qt.point(Position.unit(settings.positionX, 0.5),
                                     Position.unit(settings.positionY, 0.52));
            if (!dragging) position = savedPosition;
        } catch (error) {
            console.warn("Desktop Clock: cannot read shell settings:", error);
        }
    }

    function beginDrag() {
        dragging = true;
    }

    function movePosition(x, y) {
        position = Qt.point(Position.unit(x, 0.5), Position.unit(y, 0.52));
    }

    function savePosition() {
        dragging = false;
        var next = Object.assign({}, settings, {
            positionX: position.x,
            positionY: position.y
        });
        if (shell && typeof shell.updateEntryInline === "function") {
            // The host merges this entry into its current config, preserving
            // other plugins and handling the actual file write.
            shell.updateEntryInline(pluginId, next);
            settings = next;
            savedPosition = position;
        } else {
            console.warn("Desktop Clock: settings API is unavailable; position was not saved.");
        }
    }

    function cancelDrag() {
        dragging = false;
        position = savedPosition;
    }

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config"))
              + "/omarchy/shell.json"
        watchChanges: true
        printErrors: false
        onLoaded: root.loadSettings(text())
        onFileChanged: reload()
        onLoadFailed: error => console.warn("Desktop Clock: cannot load shell.json:", error)
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Variants {
        id: surfaces
        model: Quickshell.screens

        ClockSurface {
            required property var modelData
            screen: modelData
            controller: root
            timestamp: clock.date
        }
    }

    IpcHandler {
        target: "desktop-clock"

        function status(): string {
            return JSON.stringify({
                positionX: root.position.x,
                positionY: root.position.y,
                dragging: root.dragging,
                accent: String(Color.accent),
                foreground: String(Color.foreground),
                background: String(Color.background),
                screens: surfaces.instances.map(function(surface) {
                    return {
                        name: surface.screen.name,
                        visible: surface.visible,
                        x: surface.clockX,
                        y: surface.clockY,
                        width: surface.clockWidth,
                        height: surface.clockHeight
                    };
                })
            });
        }

        function setPosition(x: string, y: string): string {
            var px = Position.number(x, NaN);
            var py = Position.number(y, NaN);
            if (!isFinite(px) || !isFinite(py) || px < 0 || px > 1 || py < 0 || py > 1)
                return "Position must be two numbers between 0 and 1.";
            if (root.dragging) return "Clock is being dragged.";
            root.movePosition(px, py);
            root.savePosition();
            return "ok";
        }

        function resetPosition(): string {
            if (root.dragging) return "Clock is being dragged.";
            root.movePosition(0.5, 0.52);
            root.savePosition();
            return "ok";
        }
    }
}

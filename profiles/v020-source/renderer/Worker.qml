import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root
    property bool configured: false
    property var peer: null
    DesktopState { id: desktop }
    ClockController {
        id: clock
        emptyScreens: root.configured ? desktop.emptyScreens : ({})
        onSaveRequested: settings => {
            if (root.peer) root.peer.write(JSON.stringify({type: "save", settings: settings}) + "\n");
        }
        onStatusChanged: Qt.callLater(root.sendState)
    }
    function sendState() {
        if (peer && peer.connected && configured)
            peer.write(JSON.stringify({type: "state", state: clock.status()}) + "\n");
    }
    SocketServer {
        path: Quickshell.env("DESKTOP_CLOCK_SOCKET")
        active: true
        onActiveChanged: if (active) console.log("DESKTOP_CLOCK_WORKER_READY")
        handler: Component {
            Socket {
                id: client
                parser: SplitParser {
                    onRead: data => {
                        try {
                            clock.configure(JSON.parse(data));
                            root.configured = true;
                            Qt.callLater(root.sendState);
                        } catch (error) { console.warn("Desktop Clock: invalid host settings:", error); }
                    }
                }
                onConnectedChanged: {
                    if (connected) root.peer = client;
                    else Qt.callLater(Qt.quit);
                }
            }
        }
    }
}

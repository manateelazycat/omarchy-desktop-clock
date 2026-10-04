pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons

Item {
    id: face
    required property date timestamp
    property bool hovered: false
    property bool moving: false
    readonly property string family: Style.fontFamily
    readonly property color ink: Color.foreground
    readonly property color accent: Color.accent
    readonly property color dim: Qt.rgba(ink.r, ink.g, ink.b, 0.55)
    readonly property real progress: (timestamp.getSeconds() + 1) / 60

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, face.hovered ? 0.9 : 0.76)
        border.width: 1
        border.color: Qt.rgba(face.accent.r, face.accent.g, face.accent.b, face.hovered ? 0.6 : 0.24)
    }

    // Angular corner marks echo terminal frames without competing with time.
    Repeater {
        model: 4
        Item {
            required property int index
            x: index % 2 === 0 ? 0 : face.width - 14
            y: index < 2 ? 0 : face.height - 14
            width: 14
            height: 14
            Rectangle {
                width: 14
                height: 2
                y: parent.index < 2 ? 0 : 12
                color: face.accent
            }
            Rectangle {
                width: 2
                height: 14
                x: parent.index % 2 === 0 ? 0 : 12
                color: face.accent
            }
        }
    }

    Text {
        x: 26; y: 20
        text: ">_ OMARCHY"
        color: face.accent
        font { family: face.family; pixelSize: 12; weight: Font.DemiBold; letterSpacing: 1.6 }
    }
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 26
        y: 21
        text: "[ LOCAL TIME ]"
        color: face.dim
        font { family: face.family; pixelSize: 10; letterSpacing: 0.6 }
    }

    Text {
        x: 22; y: 43
        text: Qt.formatDateTime(face.timestamp, "HH:mm")
        color: face.ink
        font { family: face.family; pixelSize: 82; weight: Font.DemiBold; letterSpacing: -3 }
    }
    Text {
        x: 342; y: 65
        text: "SEC"
        color: face.dim
        font { family: face.family; pixelSize: 10; letterSpacing: 2 }
    }
    Text {
        x: 338; y: 82
        text: Qt.formatDateTime(face.timestamp, "ss")
        color: face.accent
        font { family: face.family; pixelSize: 32; weight: Font.Medium }
    }
    Rectangle {
        x: 403; y: 108
        width: 6; height: 3
        color: face.accent
        opacity: face.timestamp.getSeconds() % 2 === 0 ? 1 : 0.18
    }

    Rectangle {
        x: 26; y: 138
        width: parent.width - 52
        height: 1
        color: Qt.rgba(face.accent.r, face.accent.g, face.accent.b, 0.2)
        Rectangle {
            width: parent.width * face.progress
            height: 1
            color: face.accent
        }
    }
    Text {
        x: 26; y: 154
        text: Qt.formatDateTime(face.timestamp, "yyyy.MM.dd")
        color: face.ink
        font { family: face.family; pixelSize: 12; letterSpacing: 1 }
    }
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 26
        y: 155
        text: face.moving ? "MOVING..." : face.hovered ? "DRAG TO POSITION"
              : Qt.locale("en_US").toString(face.timestamp, "dddd").toUpperCase()
        color: face.moving || face.hovered ? face.accent : face.dim
        font { family: face.family; pixelSize: 10; letterSpacing: 1 }
    }
}

import QtQuick 2.15

Item {
    id: teleportCircle
    property color ringColor: Qt.rgba(0.2, 0.8, 1.0, 0.85)
    property color hoverColor: Qt.rgba(0.95, 0.95, 1.0, 0.95)
    property real ringWidth: 6
    property real radius: 52
    property string spriteSource: "qrc:/resource/image/entity/playerNormal.png"
    property real spriteSize: 96
    property real tileScale: 1.0
    property bool interactive: true
    property point worldPoint: Qt.point(0, 0)
    signal clicked(point worldPoint)

    readonly property real effectiveSpriteSize: spriteSize * tileScale
    readonly property real effectiveDiameter: Math.max(radius * 2, effectiveSpriteSize)

    width: effectiveDiameter
    height: effectiveDiameter
    visible: interactive
    opacity: interactive ? 0.92 : 0.4
    z: 2100
    transformOrigin: Item.Center

    SequentialAnimation {
        id: pulseAnim
        running: interactive
        loops: Animation.Infinite
        NumberAnimation { target: teleportCircle; property: "scale"; from: 0.95; to: 1.05; duration: 420 }
        NumberAnimation { target: teleportCircle; property: "scale"; from: 1.05; to: 0.95; duration: 420 }
    }

    Image {
        id: spritePreview
        anchors.centerIn: parent
        source: spriteSource
        width: effectiveSpriteSize
        height: effectiveSpriteSize
        fillMode: Image.PreserveAspectFit
        opacity: 0.95
    }

    Canvas {
        id: ringCanvas
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.strokeStyle = mouseArea.containsMouse ? hoverColor : ringColor;
            ctx.lineWidth = ringWidth;
            ctx.beginPath();
            var r = Math.max(width, height) / 2 - ringWidth;
            ctx.arc(width / 2, height / 2, r, 0, Math.PI * 2);
            ctx.stroke();
            ctx.lineWidth = 3;
            ctx.beginPath();
            ctx.moveTo(width / 2 - 12, height / 2);
            ctx.lineTo(width / 2 + 12, height / 2);
            ctx.stroke();
            ctx.beginPath();
            ctx.moveTo(width / 2, height / 2 - 12);
            ctx.lineTo(width / 2, height / 2 + 12);
            ctx.stroke();
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: teleportCircle.clicked(teleportCircle.worldPoint)
        onEntered: ringCanvas.requestPaint()
        onExited: ringCanvas.requestPaint()
    }
}

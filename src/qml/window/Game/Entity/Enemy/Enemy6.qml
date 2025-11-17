import QtQuick 2.15
import GeistZerfall.Game 1.0

Item {
    id: enemy6Root
    property int baseSize: 128  // 敌人尺寸：128*128
    width: baseSize * tileScaleRef
    height: baseSize * tileScaleRef
    property var backend: null      // BackendEnemy6 instance
    property var playerObjRef: null // BackendPlayer
    property var playerItemRef: null // front-end player item for collisions
    property var mapWrapperRef: null
    property real tileScaleRef: 1.0
    z: 120

    Image {
        id: sprite
        anchors.centerIn: parent
        source: "qrc:/resource/image/entity/enemy6.png"
        width: parent.width
        height: parent.height
    }

    // HP/MP bars
    Item {
        id: hudRoot
        width: enemy6Root.width
        height: 20
        anchors.horizontalCenter: parent.horizontalCenter
        y: -hudRoot.height - 6

        Rectangle {
            anchors.fill: parent
            color: "transparent"
        }

        Rectangle {
            id: hpBarBg
            x: 4
            y: 0
            width: parent.width - 8
            height: 8
            radius: 3
            color: "#3a0b0b"
            border.color: "#000000"
            Rectangle {
                anchors.left: parent.left
                width: backend ? (hpBarBg.width * Math.max(0, backend.hp) / Math.max(1, backend.maxHp)) : 0
                height: parent.height
                color: "#ff3333"
                radius: parent.radius
            }
        }

        Rectangle {
            id: mpBarBg
            x: 4
            y: 10
            width: parent.width - 8
            height: 6
            radius: 3
            color: "#071028"
            Rectangle {
                anchors.left: parent.left
                width: backend ? (mpBarBg.width * Math.max(0, backend.mp) / Math.max(1, backend.maxMp)) : 0
                height: parent.height
                color: "#3399ff"
                radius: parent.radius
            }
        }
    }

    // Bind position to backend world coordinates -> screen coords
    function updateScreenPos() {
        if (!backend)
            return;
        enemy6Root.x = backend.pos.x * tileScaleRef - enemy6Root.width / 2;
        enemy6Root.y = backend.pos.y * tileScaleRef - enemy6Root.height / 2;
    }

    onTileScaleRefChanged: updateScreenPos()

    onBackendChanged: {
        if (!backend)
            return;
        try {
            backend.setProperty("collisionRadius", baseSize * 0.45);
        } catch (e) {}
        try {
            backend.posChanged.connect(updateScreenPos);
        } catch (e) {}
        // connect laser creation to spawn visuals
        try {
            backend.enemyLaserCreated.connect(function (ls) {
                var comp = Qt.createComponent("./Enemy6Laser.qml");
                if (comp.status === Component.Ready) {
                    var laser = comp.createObject(mapWrapperRef, {
                        backend: ls,
                        playerItemRef: playerItemRef,
                        playerObjRef: playerObjRef,
                        tileScaleRef: tileScaleRef,
                        mapWrapperRef: mapWrapperRef
                    });
                    if (laser)
                        laser.tileScaleRef = Qt.binding(function () {
                            return tileScaleRef;
                        });
                }
            });
        } catch (e) {}
        updateScreenPos();
    }

    // When enemy dies, remove visual
    Connections {
        target: backend
        onAliveChanged: {
            if (backend && !backend.alive) {
                try {
                    enemy6Root.destroy();
                } catch (e) {}
            }
        }
    }
}

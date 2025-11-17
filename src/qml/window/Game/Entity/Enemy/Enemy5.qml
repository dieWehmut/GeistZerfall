import QtQuick 2.15
import GeistZerfall.Game 1.0

Item {
    id: enemy5Root
    property int baseSize: 64
    width: baseSize * tileScaleRef
    height: baseSize * tileScaleRef
    property var backend: null
    property var playerObjRef: null
    property var playerItemRef: null
    property var mapWrapperRef: null
    property real tileScaleRef: 1.0
    z: 120

    Image {
        id: sprite
        anchors.centerIn: parent
        source: "qrc:/resource/image/entity/enemy5.png"
        width: parent.width
        height: parent.height
    }

    Item {
        id: hudRoot
        width: enemy5Root.width
        height: 20
        anchors.horizontalCenter: parent.horizontalCenter
        y: -hudRoot.height - 6

        Rectangle { anchors.fill: parent; color: "transparent" }

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

    function updateScreenPos() {
        if (!backend) return;
        enemy5Root.x = backend.pos.x * tileScaleRef - enemy5Root.width / 2;
        enemy5Root.y = backend.pos.y * tileScaleRef - enemy5Root.height / 2;
    }

    onTileScaleRefChanged: updateScreenPos()

    onBackendChanged: {
        if (!backend) return;
        try { backend.setProperty("collisionRadius", baseSize * 0.45); } catch (e) {}
        try { backend.posChanged.connect(updateScreenPos); } catch (e) {}
        try {
            backend.enemyProjectileCreated.connect(function(pr) {
                if (!pr) return;
                var comp = Qt.createComponent("./Enemy5Bullet.qml");
                if (comp.status === Component.Ready) {
                    var obj = comp.createObject(mapWrapperRef, {
                        backend: pr,
                        playerObjRef: playerObjRef,
                        playerItemRef: playerItemRef,
                        mapWrapperRef: mapWrapperRef,
                        tileScaleRef: tileScaleRef
                    });
                    if (obj) {
                        obj.tileScaleRef = Qt.binding(function() { return tileScaleRef; });
                    }
                } else {
                    console.log("Enemy5: Enemy5Bullet component error", comp.errorString());
                }
            });
        } catch (e) {}
        updateScreenPos();
    }

    SequentialAnimation {
        id: attackAnim
        PropertyAnimation { target: enemy5Root; property: "scale"; to: 1.08; duration: 100 }
        PropertyAnimation { target: enemy5Root; property: "scale"; to: 1.0; duration: 100 }
    }

    SequentialAnimation {
        id: dieAnim
        PropertyAnimation { target: enemy5Root; property: "opacity"; to: 0; duration: 420 }
        onStopped: enemy5Root.destroy()
    }

    Connections {
        target: backend
        onAttacked: attackAnim.restart()
        onAliveChanged: {
            if (backend && !backend.alive) {
                dieAnim.restart();
            }
        }
    }
}
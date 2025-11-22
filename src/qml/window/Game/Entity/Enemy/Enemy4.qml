import QtQuick 2.15
import GeistZerfall.Game 1.0

Item {
    id: enemy4Root
    property int baseSize: 128  // 敌人尺寸：128*128
    width: baseSize * tileScaleRef
    height: baseSize * tileScaleRef
    property var backend: null
    property var playerObjRef: null
    property var playerItemRef: null
    property var mapWrapperRef: null
    property real tileScaleRef: 1.0
    z: 120
    transformOrigin: Item.Center
    property real pulsateScale: 1.0
    property real impactScale: 1.0
    // speed up pulsating animation
    property int pulsateDuration: 200
    scale: pulsateScale * impactScale

    Image {
        id: sprite
        anchors.centerIn: parent
        source: "qrc:/resource/image/entity/enemy4.png"
        width: parent.width
        height: parent.height
    }

    // HP/MP bars
    Item {
        id: hudRoot
        width: enemy4Root.width
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

    function updateScreenPos() {
        if (!backend)
            return;
        enemy4Root.x = backend.pos.x * tileScaleRef - enemy4Root.width / 2;
        enemy4Root.y = backend.pos.y * tileScaleRef - enemy4Root.height / 2;
    }

    function syncForcedRevealRegistration() {
        if (!mapWrapperRef) return;
        if (backend && backend.forcedReveal) {
            if (typeof mapWrapperRef.registerRevealedEnemy === 'function') {
                mapWrapperRef.registerRevealedEnemy(enemy4Root);
            }
        } else if (typeof mapWrapperRef.unregisterRevealedEnemy === 'function') {
            mapWrapperRef.unregisterRevealedEnemy(enemy4Root);
        }
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
        try {
            backend.enemyProjectileCreated.connect(function (pr) {
                var comp = Qt.createComponent("./Enemy4Bullet.qml");
                if (comp.status === Component.Ready) {
                    var bullet = comp.createObject(mapWrapperRef, {
                        backend: pr,
                        playerItemRef: playerItemRef,
                        playerObjRef: playerObjRef,
                        tileScaleRef: tileScaleRef,
                        mapWrapperRef: mapWrapperRef
                    });
                    if (bullet)
                        bullet.tileScaleRef = Qt.binding(function () {
                            return tileScaleRef;
                        });
                }
            });
        } catch (e) {}
        updateScreenPos();
        syncForcedRevealRegistration();
    }

    Connections {
        target: backend
        onAliveChanged: {
            if (backend && !backend.alive) {
                try {
                    enemy4Root.destroy();
                } catch (e) {}
            }
        }
        onForcedRevealChanged: syncForcedRevealRegistration()
    }

    SequentialAnimation {
        id: pulsateAnim
        loops: Animation.Infinite
        running: false
        NumberAnimation { target: enemy4Root; property: "pulsateScale"; from: 1.0; to: 2.0; duration: pulsateDuration; easing.type: Easing.InOutSine }
        NumberAnimation { target: enemy4Root; property: "pulsateScale"; from: 2.0; to: 1.0; duration: pulsateDuration; easing.type: Easing.InOutSine }
    }

    Timer { id: pulsateStarter; interval: 0; repeat: false; onTriggered: pulsateAnim.start() }

    Component.onCompleted: {
        try {
            // shorter, faster pulsate period
            var d = 600 + Math.floor(Math.random() * 400);
            pulsateDuration = d;
            var offset = Math.floor(Math.random() * pulsateDuration);
            pulsateStarter.interval = offset;
            pulsateStarter.start();
        } catch(e) {}
        syncForcedRevealRegistration();
    }

    Component.onDestruction: {
        if (mapWrapperRef && typeof mapWrapperRef.unregisterRevealedEnemy === 'function') {
            mapWrapperRef.unregisterRevealedEnemy(enemy4Root);
        }
    }
}

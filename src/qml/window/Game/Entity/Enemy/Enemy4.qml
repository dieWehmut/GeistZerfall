import QtQuick 2.15
import GeistZerfall 1.0
import GeistZerfall.Game 1.0

Item {
    id: enemy4Root
    GameUiScale { id: gameUiScale }
    property real uiScale: gameUiScale.uiScale
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
    property int pulsateDuration: 50
    scale: uiScale * pulsateScale * impactScale

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
            if (backend && typeof backend.setCollisionRadius === 'function') {
                backend.setCollisionRadius(baseSize * 0.45);
            } else {
                backend.setProperty("collisionRadius", baseSize * 0.45);
            }
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

    // --- Bullet circle: five Enemy5 bullet images orbiting quickly ---
    Item {
        id: bulletCircle
        anchors.centerIn: parent
        width: parent.width * 2
        height: parent.height * 2
        z: enemy4Root.z + 20
        transformOrigin: Item.Center
        // orbit radius in screen pixels (relative to enemy size)
        property real orbitRadius: Math.max(parent.width, parent.height) * 0.9
        // size of each orbiting bullet
        property real orbitBulletSize: Math.max(16, baseSize * 0.42) * tileScaleRef
        // rotation angle in degrees (animated)
        property real rotationAngle: 0

        Repeater {
            id: bulletRepeater
            model: 5
            delegate: Item {
                width: bulletCircle.orbitBulletSize
                height: bulletCircle.orbitBulletSize
                transformOrigin: Item.Center
                // compute angle including global rotation
                property real ang: (index * (360.0 / bulletRepeater.count)) + bulletCircle.rotationAngle
                x: bulletCircle.width/2 + Math.cos(-ang * Math.PI/180.0) * bulletCircle.orbitRadius - width/2
                y: bulletCircle.height/2 + Math.sin(-ang * Math.PI/180.0) * bulletCircle.orbitRadius - height/2
                Image {
                    anchors.fill: parent
                    // use distinct images enemy4Bullet1..enemy4Bullet5 based on index
                    source: "qrc:/resource/image/entity/enemy4Bullet" + (index+1) + ".png"
                    fillMode: Image.PreserveAspectFit
                }
            }
        }

        // continuous fast rotation
        NumberAnimation { target: bulletCircle; property: "rotationAngle"; from: 0; to: 360; duration: 600; loops: Animation.Infinite; running: true }
    }

    // damage config for orbit bullets
    property int orbitBulletDamage: 12
    property int orbitHitCooldownMs: 300
    // last time (ms since epoch) we applied damage to player from orbit bullets
    property int lastOrbitHitTime: 0

    // Timer to check collision between orbit bullets and the player
    Timer {
        id: orbitCollisionTimer
        interval: 40
        repeat: true
        running: true
        onTriggered: {
            if (!playerItemRef || !playerObjRef) return;
            // compute screen offset (mapWrapper.x if available)
            var offsetX = mapWrapperRef ? mapWrapperRef.x : 0;
            var offsetY = mapWrapperRef ? mapWrapperRef.y : 0;
            var px = playerItemRef.x;
            var py = playerItemRef.y;
            var pw = playerItemRef.width;
            var ph = playerItemRef.height;
            var now = Date.now();
            for (var i = 0; i < bulletRepeater.count; ++i) {
                var it = bulletRepeater.itemAt(i);
                if (!it) continue;
                // bullet position relative to mapWrapper: enemy4Root.x + it.x
                var bx = offsetX + enemy4Root.x + it.x;
                var by = offsetY + enemy4Root.y + it.y;
                var bw = it.width;
                var bh = it.height;
                if (bx < px + pw && bx + bw > px && by < py + ph && by + bh > py) {
                    // collision detected
                    if (!lastOrbitHitTime || (now - lastOrbitHitTime) >= orbitHitCooldownMs) {
                        try {
                            if (typeof playerObjRef.receiveDamage === 'function') playerObjRef.receiveDamage(orbitBulletDamage);
                        } catch(e) { console.log('orbit hit failed', e); }
                        lastOrbitHitTime = now;
                    }
                    break; // one hit per tick is enough
                }
            }
        }
    }

    Component.onDestruction: {
        if (mapWrapperRef && typeof mapWrapperRef.unregisterRevealedEnemy === 'function') {
            mapWrapperRef.unregisterRevealedEnemy(enemy4Root);
        }
    }
}

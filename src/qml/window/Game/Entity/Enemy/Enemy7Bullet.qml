import QtQuick 2.15
import QtMultimedia 6.5
import GeistZerfall.Game 1.0

Item {
    id: root
    property int baseSize: 64
    width: baseSize * tileScaleRef
    height: baseSize * tileScaleRef
    property BackendEnemy7Bullet backend: null
    property var playerObjRef: null
    property var playerItemRef: null
    property var mapWrapperRef: null
    property real tileScaleRef: 1.0
    property int damage: 12
    property real collisionRadius: baseSize * 0.35
    z: 130
    visible: backend !== null
    transformOrigin: Item.Center
    property real pulsateScale: 1.0
    property int pulsateDuration: 600
    scale: pulsateScale

    Image {
        id: sprite
        anchors.centerIn: parent
        source: "qrc:/resource/image/entity/enemy7Bullet.png"
        width: parent.width
        height: parent.height
        fillMode: Image.PreserveAspectFit
    }

    SoundEffect {
        id: hitSfx
        source: "qrc:/resource/audio/SoundEffect/playerHit.wav"
        volume: 0.8 * (typeof window !== 'undefined' ? window.masterVolume * window.sfxVolume : 1.0)
    }

    function updateScreenPos() {
        if (!backend) return;
        var px = backend.pos && backend.pos.x !== undefined ? backend.pos.x : 0;
        var py = backend.pos && backend.pos.y !== undefined ? backend.pos.y : 0;
        root.x = px * tileScaleRef - root.width / 2;
        root.y = py * tileScaleRef - root.height / 2;
    }

    onBackendChanged: {
        if (!backend) return;
        try { backend.posChanged.connect(updateScreenPos); } catch (e) {}
        try {
            backend.destroyed.connect(function () {
                try { root.destroy(); } catch (err) {}
            });
        } catch (e) {}
        try {
            if (backend.backendDestroyed)
                backend.backendDestroyed.connect(function () { bulletDieAnim.restart(); });
        } catch (e) {}
        updateScreenPos();
    }

    onTileScaleRefChanged: updateScreenPos()

    Timer {
        interval: 16
        running: backend !== null
        repeat: true
        onTriggered: {
            if (!backend || !playerItemRef || !playerObjRef) return;
            var offsetX = mapWrapperRef ? mapWrapperRef.x : 0;
            var offsetY = mapWrapperRef ? mapWrapperRef.y : 0;
            var bx = root.x + offsetX;
            var by = root.y + offsetY;
            var bw = root.width;
            var bh = root.height;
            var px = playerItemRef.x;
            var py = playerItemRef.y;
            var pw = playerItemRef.width;
            var ph = playerItemRef.height;
            if (bx < px + pw && bx + bw > px && by < py + ph && by + bh > py) {
                try {
                    if (typeof playerObjRef.receiveDamage === "function") playerObjRef.receiveDamage(damage);
                    hitSfx.play();
                } catch (err) {}
                try { backend.deleteLater(); } catch (err) {}
            }
        }
    }

    SequentialAnimation {
        id: bulletDieAnim
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: 200 }
        NumberAnimation { target: root; property: "scale"; to: 0; duration: 200 }
        onStopped: root.destroy()
    }

    Connections {
        target: backend
        onBackendDestroyed: bulletDieAnim.restart()
    }

    NumberAnimation {
        target: root
        property: "rotation"
        from: 0
        to: 360
        duration: 420
        loops: Animation.Infinite
        running: true
    }

    SequentialAnimation { id: pulsateAnimBul; loops: Animation.Infinite
        NumberAnimation { target: root; property: "pulsateScale"; from: 1.0; to: 1.5; duration: pulsateDuration; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "pulsateScale"; from: 1.5; to: 1.0; duration: pulsateDuration; easing.type: Easing.InOutSine }
    }

    Component.onCompleted: {
        if (mapWrapperRef && typeof mapWrapperRef.registerEnemyProjectile === 'function') {
            mapWrapperRef.registerEnemyProjectile(root);
        }
        try {
            var d = 500 + Math.floor(Math.random() * 400);
            if (d === 1600) d += 73;
            pulsateDuration = d;
            if (pulsateAnimBul.running) pulsateAnimBul.stop();
            pulsateAnimBul.start();
        } catch(e) {}
    }

    Component.onDestruction: {
        if (mapWrapperRef && typeof mapWrapperRef.unregisterEnemyProjectile === 'function') {
            mapWrapperRef.unregisterEnemyProjectile(root);
        }
    }
}
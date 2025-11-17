import QtQuick 2.15
import QtMultimedia 6.5
import GeistZerfall.Game 1.0

Item {
    id: root
    property int baseSize: 16
    width: baseSize * tileScaleRef
    height: baseSize * tileScaleRef
    property var backend: null
    property var playerObjRef: null
    property var playerItemRef: null
    property var mapWrapperRef: null
    property real tileScaleRef: 1.0
    property int damage: 10
    visible: backend && backend.alive
    z: 130
    transformOrigin: Item.Center
    rotation: backend ? Math.atan2(
                            backend.diry !== undefined ? backend.diry : (backend.dir ? backend.dir.y : 0),
                            backend.dirx !== undefined ? backend.dirx : (backend.dir ? backend.dir.x : 1)
                        ) * 180 / Math.PI : 0

    Image {
        id: sprite
        anchors.centerIn: parent
        source: "qrc:/resource/image/projectile/enemy5_bullet.png"
        width: parent.width
        height: parent.height
        sourceClipRect: {
            var frameWidth = baseSize;
            var idx = backend ? backend.spriteIndex : 0;
            return Qt.rect(idx * frameWidth, 0, frameWidth, baseSize);
        }
    }

    SoundEffect {
        id: hitSfx
        source: "qrc:/resource/audio/SoundEffect/playerHit.wav"
        volume: 0.8
    }

    function updateScreenPos() {
        if (!backend) return;
        var px = backend.posX !== undefined ? backend.posX : (backend.pos ? backend.pos.x : 0);
        var py = backend.posY !== undefined ? backend.posY : (backend.pos ? backend.pos.y : 0);
        root.x = px * tileScaleRef - root.width / 2;
        root.y = py * tileScaleRef - root.height / 2;
    }

    onBackendChanged: {
        if (!backend) return;
        try { backend.posChanged.connect(updateScreenPos); } catch (e) {}
        try { backend.destroyed.connect(function() { try { root.destroy(); } catch (err) {} }); } catch (e) {}
        try {
            if (backend.backendDestroyed) {
                backend.backendDestroyed.connect(function() {
                    bulletDieAnim.restart();
                });
            }
        } catch (e) {}
        updateScreenPos();
    }

    onTileScaleRefChanged: updateScreenPos()

    Timer {
        interval: 16
        running: true
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
        onAliveChanged: {
            if (backend && !backend.alive) bulletDieAnim.restart();
        }
    }
}
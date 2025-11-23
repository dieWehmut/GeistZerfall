import QtQuick 2.15
import QtMultimedia 6.5

Item {
    id: root
    property int baseSize: 48
    width: baseSize * tileScaleRef
    height: baseSize * tileScaleRef
    property var backend: null
    property var playerItemRef: null
    property var playerObjRef: null
    property var mapWrapperRef: null
    property real tileScaleRef: 1.0
    property int damage: 10
    z: 130

    property int spriteIndex: backend && backend.spriteIndex !== undefined ? Math.max(1, Math.min(12, backend.spriteIndex)) : 1

    Image {
        anchors.centerIn: parent
        source: "qrc:/resource/image/entity/enemy6Bullet" + spriteIndex + ".png"
        width: parent.width
        height: parent.height
    }

    // 被玩家击中时播放
    SoundEffect {
        id: hitSfx
        source: "qrc:/resource/audio/SoundEffect/playerHit.wav"
        volume: 0.8 * (typeof window !== 'undefined' ? window.masterVolume * window.sfxVolume : 1.0)
    }

    function updateScreenPos() {
        if (!backend)
            return;
        root.x = backend.pos.x * tileScaleRef - root.width / 2;
        root.y = backend.pos.y * tileScaleRef - root.height / 2;
    }

    onBackendChanged: {
        if (!backend)
            return;
        try {
            backend.posChanged.connect(updateScreenPos);
        } catch (e) {}
        try {
            backend.destroyed.connect(function () {
                try {
                    root.destroy();
                } catch (e) {}
            });
        } catch (e) {}
        try {
            if (backend.backendDestroyed)
                backend.backendDestroyed.connect(function () {
                    try {
                        root.destroy();
                    } catch (e) {}
                });
        } catch (e) {}
        updateScreenPos();
    }

    onTileScaleRefChanged: updateScreenPos()

    // 简单碰撞检测：AABB 与玩家矩形
    Timer {
        interval: 16
        running: true
        repeat: true
        onTriggered: {
            if (!backend || !playerItemRef || !playerObjRef)
                return;
            var bx = root.x + (mapWrapperRef ? mapWrapperRef.x : 0);
            var by = root.y + (mapWrapperRef ? mapWrapperRef.y : 0);
            var bw = root.width;
            var bh = root.height;
            var px = playerItemRef.x;
            var py = playerItemRef.y;
            var pw = playerItemRef.width;
            var ph = playerItemRef.height;
            if (bx < px + pw && bx + bw > px && by < py + ph && by + bh > py) {
                // 命中玩家
                try {
                    if (typeof playerObjRef.receiveDamage === 'function')
                        playerObjRef.receiveDamage(damage);
                    hitSfx.play();
                } catch (e) {}
                try {
                    backend.deleteLater();
                } catch (e) {}
            }
        }
    }
}

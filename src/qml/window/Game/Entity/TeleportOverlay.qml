import QtQuick 2.15
import QtMultimedia
import "."

Item {
    id: teleportOverlay
    property var playerObj: null
    property real tileScale: 1.0
    property bool active: false
    property real teleportDistance: 300
    // multiplier to slightly reduce teleport marker distance from the player
    property real teleportDistanceMultiplier: 0.85
    // If a sightMaskRef is provided, prefer its current radius (screen px) converted to world units.
    property var sightMaskRef: null
    readonly property real effectiveTeleportDistance: (
        sightMaskRef && typeof sightMaskRef.radius !== 'undefined'
    ) ? (sightMaskRef.radius / tileScale) * teleportDistanceMultiplier : ((playerObj && typeof playerObj.sight !== 'undefined') ? playerObj.sight * teleportDistanceMultiplier : teleportDistance * teleportDistanceMultiplier)
    property var mapWrapperRef: null
    property var mapClamp: ({ width: 0, height: 0 })
    property string teleportSprite: "qrc:/resource/image/entity/playerNormal.png"
    property real playerSpriteSize: 96
    property real playerVisualWidth: 0
    property real playerVisualHeight: 0
    property var enemyBackends: []
    property int teleportCircleDamage: 200
    property int teleportCircleHitCooldownMs: 500
    property int teleportCircleCheckIntervalMs: 80
    property real defaultEnemyCollisionRadius: 48
    property var circleHitCache: []
    property var directions: [
        Qt.point(0, -1),
        Qt.point(0, 1),
        Qt.point(-1, 0),
        Qt.point(1, 0),
        Qt.point(-1, -1),
        Qt.point(1, -1),
        Qt.point(-1, 1),
        Qt.point(1, 1)
    ]
        property real rotationAngle: 0
        // Teleport visual line (keeps a thick blue line after teleport for 5s)
        property bool teleportLineVisible: false
        property var teleportLineStartWorld: Qt.point(0, 0)
        property var teleportLineEndWorld: Qt.point(0, 0)

    visible: active && playerObj
    z: 2090
    x: (mapWrapperRef && parent === mapWrapperRef) ? 0 : (mapWrapperRef ? mapWrapperRef.x : 0)
    y: (mapWrapperRef && parent === mapWrapperRef) ? 0 : (mapWrapperRef ? mapWrapperRef.y : 0)
    width: mapWrapperRef ? mapWrapperRef.width : (parent ? parent.width : 0)
    height: mapWrapperRef ? mapWrapperRef.height : (parent ? parent.height : 0)

    onTileScaleChanged: forceUpdate()
    onActiveChanged: forceUpdate()
    onPlayerVisualWidthChanged: forceUpdate()
    onPlayerVisualHeightChanged: forceUpdate()

    function clampPoint(pt) {
        var maxW = playerObj && playerObj.mapWidth ? playerObj.mapWidth : mapClamp.width;
        var maxH = playerObj && playerObj.mapHeight ? playerObj.mapHeight : mapClamp.height;
        var x = pt.x;
        var y = pt.y;
        if (maxW > 0) {
            if (x < 0) x = 0;
            if (x > maxW) x = maxW;
        }
        if (maxH > 0) {
            if (y < 0) y = 0;
            if (y > maxH) y = maxH;
        }
        return Qt.point(x, y);
    }

    function playerCenterWorld() {
        if (!playerObj || !playerObj.pos) return Qt.point(0, 0);
        // Convert visual (px) size to world units by dividing tileScale to avoid drift.
        var scale = Math.max(0.0001, tileScale);
        var widthWorld = (playerVisualWidth && playerVisualWidth > 0) ? (playerVisualWidth / scale) : (playerSpriteSize / scale);
        var heightWorld = (playerVisualHeight && playerVisualHeight > 0) ? (playerVisualHeight / scale) : (playerSpriteSize / scale);
        return Qt.point(playerObj.pos.x + widthWorld / 2, playerObj.pos.y + heightWorld / 2);
    }

    function worldPointForDirection(dir) {
        var base = playerCenterWorld();
        var normLen = Math.sqrt(dir.x * dir.x + dir.y * dir.y);
        var mul = (normLen > 0) ? (effectiveTeleportDistance / normLen) : effectiveTeleportDistance;
        return clampPoint(Qt.point(base.x + dir.x * mul, base.y + dir.y * mul));
    }

        // Compute a world point from an angle in degrees (0 = right, positive clockwise)
        function worldPointForAngle(deg) {
            // convert to radians and invert to make positive degrees rotate clockwise on screen
            var rad = -deg * Math.PI / 180.0;
            var dx = Math.cos(rad);
            var dy = Math.sin(rad);
            return worldPointForDirection(Qt.point(dx, dy));
        }

    Repeater {
        id: markerRepeater
        model: teleportOverlay.directions.length
        delegate: TeleportCircle {
                // compute angle per-index using current rotationAngle; keep them evenly spaced
                worldPoint: teleportOverlay.worldPointForAngle(teleportOverlay.rotationAngle + index * (360.0 / teleportOverlay.directions.length))
            radius: 46
            visible: teleportOverlay.active
            spriteSource: teleportOverlay.teleportSprite
            spriteSize: teleportOverlay.playerSpriteSize
            tileScale: teleportOverlay.tileScale
            x: worldPoint.x * teleportOverlay.tileScale - width / 2
            y: worldPoint.y * teleportOverlay.tileScale - height / 2
            onClicked: function(pt) {
                teleportOverlay.handleTeleportClick(pt);
            }
        }
    }

        // Rotation animation: runs while overlay is active
        NumberAnimation {
            id: rotAnim
            target: teleportOverlay
            property: "rotationAngle"
            from: 0; to: 360
            duration: 1000
            loops: Animation.Infinite
            running: teleportOverlay.active
        }

    // Ensure markers recompute when rotationAngle changes so rotation is real-time
    onRotationAngleChanged: forceUpdate()

    signal teleportRequested(var pt)
    // Handle teleport click: draw persistent blue line (backend teleport is done by caller after animation)
    function handleTeleportClick(pt) {
        if (!teleportOverlay.playerObj) return;
        // compute and clamp world endpoints
        teleportOverlay.teleportLineStartWorld = teleportOverlay.playerCenterWorld();
        var scale = Math.max(0.0001, tileScale);
        var widthWorld = (playerVisualWidth && playerVisualWidth > 0) ? (playerVisualWidth / scale) : (playerSpriteSize / scale);
        var heightWorld = (playerVisualHeight && playerVisualHeight > 0) ? (playerVisualHeight / scale) : (playerSpriteSize / scale);
        var clamped = teleportOverlay.clampPoint(pt);
        // draw line towards the target center to match actual move path
        teleportOverlay.teleportLineEndWorld = Qt.point(clamped.x + widthWorld / 2, clamped.y + heightWorld / 2);
        teleportOverlay.teleportLineVisible = true;
        if (teleportLineTimer.running) teleportLineTimer.stop();
        teleportLineTimer.start();
        // request paint immediately
        if (typeof teleportLineCanvas !== 'undefined') teleportLineCanvas.requestPaint();
        // notify parent that user requested a teleport to pt (GameView will perform animated move)
        try { teleportOverlay.teleportRequested(pt); } catch(e) { /* ignore */ }
    }

    function circleRadiusWorldFor(item) {
        if (!item) return (46 / Math.max(0.0001, tileScale));
        var pxRadius = item.width > 0 ? item.width * 0.5 : (item.radius || 46);
        return pxRadius / Math.max(0.0001, tileScale);
    }

    function pruneCircleHitCache(now) {
        for (var i = circleHitCache.length - 1; i >= 0; --i) {
            var entry = circleHitCache[i];
            if (!entry || !entry.enemy) {
                circleHitCache.splice(i, 1);
                continue;
            }
            if (entry.enemy.alive !== undefined && !entry.enemy.alive) {
                circleHitCache.splice(i, 1);
                continue;
            }
            if (entry.enemy.hp !== undefined && entry.enemy.hp <= 0) {
                circleHitCache.splice(i, 1);
            }
        }
    }

    function canDamageEnemy(enemy, now) {
        for (var i = 0; i < circleHitCache.length; ++i) {
            var entry = circleHitCache[i];
            if (entry.enemy === enemy) {
                if ((now - entry.lastHit) >= teleportCircleHitCooldownMs) {
                    entry.lastHit = now;
                    return true;
                }
                return false;
            }
        }
        circleHitCache.push({ enemy: enemy, lastHit: now });
        return true;
    }

    function detectTeleportCircleHits() {
        if (!teleportOverlay.active) return;
        if (!enemyBackends || enemyBackends.length === 0) return;
        var circleCount = markerRepeater.count;
        if (circleCount <= 0) return;
        var now = Date.now();
        pruneCircleHitCache(now);
        for (var ei = 0; ei < enemyBackends.length; ++ei) {
            var enemy = enemyBackends[ei];
            if (!enemy) continue;
            if (enemy.alive !== undefined && !enemy.alive) continue;
            if (enemy.hp !== undefined && enemy.hp <= 0) continue;
            var pos = enemy.pos;
            if (!pos) continue;
            var enemyRadius = (enemy.collisionRadius !== undefined) ? enemy.collisionRadius : defaultEnemyCollisionRadius;
            var hit = false;
            for (var ci = 0; ci < circleCount; ++ci) {
                var circleItem = markerRepeater.itemAt(ci);
                if (!circleItem) continue;
                var circleCenter = circleItem.worldPoint || Qt.point(0, 0);
                var circleRadius = circleRadiusWorldFor(circleItem);
                var dx = pos.x - circleCenter.x;
                var dy = pos.y - circleCenter.y;
                var radiusSum = circleRadius + enemyRadius;
                if ((dx * dx + dy * dy) <= radiusSum * radiusSum) {
                    hit = true;
                    break;
                }
            }
            if (hit && canDamageEnemy(enemy, now)) {
                try {
                    if (typeof enemy.receiveDamage === 'function') {
                        enemy.receiveDamage(teleportCircleDamage, 0, 0, 0);
                    }
                } catch (err) {
                    console.log('teleport circle damage failed', err);
                }
                if (teleportCircleHitSfx) {
                    try { teleportCircleHitSfx.play(); } catch (playErr) {}
                }
            }
        }
    }


    Connections {
        target: playerObj
        enabled: !!playerObj
        function onPosChanged() { teleportOverlay.forceUpdate(); }
        function onTeleportModeChanged() { teleportOverlay.forceUpdate(); }
        function onSightChanged() { teleportOverlay.forceUpdate(); }
    }

    // Watch dynamic sight mask radius when provided so markers follow the visible circle
    Connections {
        target: sightMaskRef
        enabled: !!sightMaskRef
        function onRadiusChanged() { teleportOverlay.forceUpdate(); }
    }

    Timer {
        id: teleportLineTimer
        interval: 5000
        repeat: false
        running: false
        onTriggered: {
            teleportOverlay.teleportLineVisible = false;
            if (typeof teleportLineCanvas !== 'undefined') teleportLineCanvas.requestPaint();
        }
    }

    Timer {
        id: circleCollisionTimer
        interval: teleportCircleCheckIntervalMs
        repeat: true
        running: teleportOverlay.active
        onTriggered: teleportOverlay.detectTeleportCircleHits()
    }

    Canvas {
        id: teleportLineCanvas
        anchors.fill: parent
        visible: teleportOverlay.teleportLineVisible
        onPaint: {
            var ctx = getContext('2d');
            ctx.reset();
            if (!teleportOverlay.teleportLineVisible) return;
            var sx = teleportOverlay.teleportLineStartWorld.x * teleportOverlay.tileScale;
            var sy = teleportOverlay.teleportLineStartWorld.y * teleportOverlay.tileScale;
            var ex = teleportOverlay.teleportLineEndWorld.x * teleportOverlay.tileScale;
            var ey = teleportOverlay.teleportLineEndWorld.y * teleportOverlay.tileScale;
            ctx.beginPath();
            ctx.moveTo(sx, sy);
            ctx.lineTo(ex, ey);
            ctx.lineWidth = Math.max(6, 8 * teleportOverlay.tileScale);
            ctx.strokeStyle = '#3399FF';
            ctx.lineCap = 'round';
            ctx.stroke();
        }
    }

    SoundEffect {
        id: teleportCircleHitSfx
        source: "qrc:/resource/audio/SoundEffect/enemyHit.wav"
        volume: 0.55 * (typeof window !== 'undefined' ? window.masterVolume * window.sfxVolume : 1.0)
    }

    function forceUpdate() {
        for (var i = 0; i < markerRepeater.count; ++i) {
            var item = markerRepeater.itemAt(i);
            if (item) {
                var angle = rotationAngle + i * (360.0 / markerRepeater.count);
                item.worldPoint = worldPointForAngle(angle);
            }
        }
    }

    // If parent or mapWrapperRef changes (e.g. mapWrapper x/y or scale changed), update markers
    onParentChanged: forceUpdate()
    onMapWrapperRefChanged: forceUpdate()
}

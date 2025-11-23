import QtQuick 2.15
import QtMultimedia 6.5

Item {
    id: waveRoot
    property var backend: null
    property var mapWrapperRef: null
    property real tileScaleRef: 1.0
    property var enemiesRef: null
    property int baseSpriteSize: 96
    property int circleScreenRadius: 128
    property int damage: backend && backend.damage !== undefined ? backend.damage : 120
    property real knockbackDistance: 220
    property int hitCooldownMs: 400
    width: baseSpriteSize * tileScaleRef
    height: baseSpriteSize * tileScaleRef

    function updateScreenPos() {
        if (!backend || !backend.pos) return;
        waveRoot.x = backend.pos.x * tileScaleRef - waveRoot.width / 2;
        waveRoot.y = backend.pos.y * tileScaleRef - waveRoot.height / 2;
    }

    Image {
        id: sprite
        anchors.centerIn: parent
        source: "qrc:/resource/image/entity/playerNormal.png"
        width: parent.width
        height: parent.height
        opacity: 0.95
    }

    // translucent blue circle drawn as overlay around the sprite
    Canvas {
        id: circ
        anchors.centerIn: parent
        width: Math.max(parent.width, circleScreenRadius * 2)
        height: width
        z: sprite.z - 1
        opacity: 0.65
        onPaint: {
            var ctx = getContext('2d');
            ctx.clearRect(0,0,width,height);
            var r = circleScreenRadius;
            var cx = width/2;
            var cy = height/2;
            // outer soft ring
            var grad = ctx.createRadialGradient(cx, cy, r*0.2, cx, cy, r);
            grad.addColorStop(0, 'rgba(50,170,255,0.24)');
            grad.addColorStop(0.6, 'rgba(50,170,255,0.12)');
            grad.addColorStop(1.0, 'rgba(50,170,255,0.035)');
            ctx.beginPath(); ctx.fillStyle = grad; ctx.arc(cx, cy, r, 0, Math.PI*2); ctx.fill();
            // crisp ring
            ctx.beginPath(); ctx.strokeStyle = 'rgba(50,170,255,0.55)'; ctx.lineWidth = Math.max(2, 4 * tileScaleRef); ctx.arc(cx, cy, r*0.9, 0, Math.PI*2); ctx.stroke();
        }
    }

    SoundEffect {
        id: waveSfx
        source: "qrc:/resource/audio/SoundEffect/enemyHit.wav"
        volume: 0.65 * (typeof window !== 'undefined' ? window.masterVolume * window.sfxVolume : 1.0)
    }

    // per-enemy hit cache to throttle repeated hits
    property var hitCache: []

    function pruneCache(now) {
        for (var i = hitCache.length - 1; i >= 0; --i) {
            var e = hitCache[i];
            if (!e || !e.enemy || (e.enemy.alive !== undefined && !e.enemy.alive)) { hitCache.splice(i,1); continue; }
            if ((now - e.last) > 60000) hitCache.splice(i,1);
        }
    }

    function canHit(enemy, now) {
        for (var i = 0; i < hitCache.length; ++i) {
            if (hitCache[i].enemy === enemy) {
                if ((now - hitCache[i].last) >= hitCooldownMs) { hitCache[i].last = now; return true; }
                return false;
            }
        }
        hitCache.push({ enemy: enemy, last: now });
        return true;
    }

    Timer {
        id: checkTimer
        interval: 60
        repeat: true
        running: backend !== null
        onTriggered: {
            if (!backend || !backend.pos) return;
            updateScreenPos();
            if (!enemiesRef || enemiesRef.length === 0) return;
            var now = Date.now();
            pruneCache(now);
            var bx = backend.pos.x; var by = backend.pos.y;
            var rWorld = circleScreenRadius / Math.max(0.0001, tileScaleRef);
            for (var i = 0; i < enemiesRef.length; ++i) {
                var enemy = enemiesRef[i];
                if (!enemy || enemy.alive === false || !enemy.pos) continue;
                if (enemy.hp !== undefined && enemy.hp <= 0) continue;
                var ex = enemy.pos.x; var ey = enemy.pos.y;
                var er = (enemy.collisionRadius !== undefined) ? enemy.collisionRadius : 48;
                var dx = ex - bx; var dy = ey - by;
                var sum = rWorld + er;
                if ((dx*dx + dy*dy) <= sum*sum) {
                    if (!canHit(enemy, now)) continue;
                    // compute knock direction away from wave center
                    var klen = Math.sqrt(dx*dx + dy*dy);
                    var kdx = 0; var kdy = 0;
                    if (klen !== 0) { kdx = dx/klen; kdy = dy/klen; }
                    try { if (typeof enemy.receiveDamage === 'function') enemy.receiveDamage(damage, kdx, kdy, knockbackDistance); } catch(e) { }
                    try { waveSfx.play(); } catch(e) {}
                }
            }
        }
    }

    function handleBackendAssigned() {
        updateScreenPos();
        try { backend.posChanged.connect(updateScreenPos); } catch(e) {}
        try { backend.destroyed.connect(function(){ waveRoot.destroy(); }); } catch(e) {}
        try { if (typeof backend.backendDestroyed === 'function' || backend.hasOwnProperty('backendDestroyed')) backend.backendDestroyed.connect(function(){ waveRoot.destroy(); }); } catch(e) {}
        if (!checkTimer.running) checkTimer.start();
    }

    onBackendChanged: {
        if (!backend) { checkTimer.stop(); return; }
        handleBackendAssigned();
    }

    Component.onDestruction: checkTimer.stop()
}

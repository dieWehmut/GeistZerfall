import QtQuick 2.15
import QtMultimedia 6.5

Item {
    id: root
    width: 600; height: 600 // large canvas for beam drawing; clipped by parent mapWrapper
    property var backend: null
    property var playerItemRef: null
    property var playerObjRef: null
    property var mapWrapperRef: null
    property real tileScaleRef: 1.0
    property int damage: 20
    z: 140

    // Red beam visual via Canvas
    Canvas {
        id: beamCanvas
        anchors.fill: parent
        onPaint: {
            var ctx = getContext('2d');
            ctx.clearRect(0,0,width,height);
            if (!backend) return;
            var sx = width / 2;
            var sy = height / 2;
            var ex = sx + backend.maxDist * backend.dirx * tileScaleRef;
            var ey = sy + backend.maxDist * backend.diry * tileScaleRef;
            ctx.strokeStyle = '#ff2222';
            ctx.lineWidth = 18 * tileScaleRef;
            ctx.beginPath();
            ctx.moveTo(sx, sy);
            ctx.lineTo(ex, ey);
            ctx.stroke();
        }
    }

    SoundEffect { id: hitSfx; source: "qrc:/resource/audio/SoundEffect/playerHit.wav"; volume: 0.9 }

    function updatePos() {
        if (!backend) return;
        root.x = backend.startX * tileScaleRef - root.width/2;
        root.y = backend.startY * tileScaleRef - root.height/2;
        beamCanvas.requestPaint();
    }

    onBackendChanged: {
        if (!backend) return;
        try { backend.beamChanged.connect(function(){ updatePos(); }); } catch(e){}
        try { backend.destroyed.connect(function(){ try { root.destroy(); } catch(e){} }); } catch(e){}
        try { if (backend.backendDestroyed) backend.backendDestroyed.connect(function(){ try { root.destroy(); } catch(e){} }); } catch(e){}
        updatePos();
    }

    onTileScaleRefChanged: updatePos()

    // Collision check along beam line approximated by distance from player center to line segment
    Timer {
        interval: 60; running: true; repeat: true
        onTriggered: {
            if (!backend || !playerItemRef || !playerObjRef) return;
            var px = playerItemRef.x + playerItemRef.width/2;
            var py = playerItemRef.y + playerItemRef.height/2;
            var offsetX = mapWrapperRef ? mapWrapperRef.x : 0;
            var offsetY = mapWrapperRef ? mapWrapperRef.y : 0;
            var sx = offsetX + backend.startX * tileScaleRef;
            var sy = offsetY + backend.startY * tileScaleRef;
            var ex = sx + backend.maxDist * backend.dirx * tileScaleRef;
            var ey = sy + backend.maxDist * backend.diry * tileScaleRef;
            var dx = ex - sx; var dy = ey - sy;
            var len2 = dx*dx + dy*dy;
            if (len2 <= 0) return;
            var t = ((px - sx)*dx + (py - sy)*dy) / len2;
            if (t < 0) t = 0; else if (t > 1) t = 1;
            var cx = sx + t*dx; var cy = sy + t*dy;
            var dist = Math.sqrt((px - cx)*(px - cx) + (py - cy)*(py - cy));
            var beamHalfWidth = (18 * tileScaleRef)/2;
            if (dist <= beamHalfWidth) {
                try { if (typeof playerObjRef.receiveDamage === 'function') playerObjRef.receiveDamage(damage); hitSfx.play(); } catch(e){}
            }
        }
    }
}

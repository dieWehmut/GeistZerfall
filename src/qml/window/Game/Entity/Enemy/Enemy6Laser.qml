import QtQuick 2.15
import QtMultimedia 6.5

Item {
    id: root
    property int baseSize: 800  // 足够大的画布来绘制波形路径
    width: baseSize * tileScaleRef
    height: baseSize * tileScaleRef
    property var backend: null
    property var playerItemRef: null
    property var playerObjRef: null
    property var mapWrapperRef: null
    property real tileScaleRef: 1.0
    property int damage: 10
    z: 130
    visible: backend !== null
    transformOrigin: Item.Center
    // subtle spin for the whole laser visual
        property int spinDuration: 1200 // 更快自旋

    // 波形参数
    property double waveFrequency: backend ? backend.waveFrequency : 2.0
    property double waveAmplitude: backend ? backend.waveAmplitude : 30.0
    property double waveTime: backend ? backend.waveTime : 0.0
    property double dirX: backend ? backend.dirx : 1.0
    property double dirY: backend ? backend.diry : 0.0
    property double traveledDist: 0.0

    // 定期更新traveledDist
    Timer {
        interval: 16
        running: backend !== null
        repeat: true
        onTriggered: {
            if (backend) {
                traveledDist = backend.traveledDist || 0.0;
                // debug
                console.log('Enemy6Laser.qml Timer: pos=', backend.pos ? (backend.pos.x + ',' + backend.pos.y) : 'null', 'dir=', backend.dirx, backend.diry, 'waveTime=', backend.waveTime, 'traveled=', traveledDist);
            }
        }
    }

    // 波形光波绘制
    Canvas {
        id: waveCanvas
        anchors.fill: parent
        onPaint: {
            if (!backend)
                return;
            // debug: ensure we have required backend values
            console.log('Enemy6Laser.qml paint: origin=', originX, originY, 'end=', backend.pos.x, backend.pos.y, 'dir=', dirX, dirY, 'waveTime=', waveTime, 'traveledDist=', traveledDist);

            var ctx = getContext('2d');
            ctx.clearRect(0, 0, width, height);

            // 计算起点和终点在画布中的位置
            var worldStartX = originX * tileScaleRef;
            var worldStartY = originY * tileScaleRef;
            var worldEndX = backend.pos.x * tileScaleRef;
            var worldEndY = backend.pos.y * tileScaleRef;

            // 转换为画布坐标（相对于root的位置）
            var canvasStartX = worldStartX - root.x;
            var canvasStartY = worldStartY - root.y;
            var canvasEndX = worldEndX - root.x;
            var canvasEndY = worldEndY - root.y;

            // 计算距离和方向
            var dx = canvasEndX - canvasStartX;
            var dy = canvasEndY - canvasStartY;
            var dist = Math.sqrt(dx * dx + dy * dy);
            if (dist <= 0.5) {
                return;
            }
            var perpX = -dirY;  // 垂直向量
            var perpY = dirX;

            // 绘制底层粗线（明显可见）——调试/增强可视性
            try {
                ctx.save();
                ctx.strokeStyle = 'rgba(220,40,200,0.95)';
                ctx.lineWidth = Math.max(12, 32 * tileScaleRef);
                ctx.lineCap = 'round';
                ctx.beginPath();
                ctx.moveTo(canvasStartX, canvasStartY);
                ctx.lineTo(canvasEndX, canvasEndY);
                ctx.stroke();
                ctx.restore();
            } catch(e) {}

            // 绘制波形路径
            ctx.strokeStyle = '#9b59b6';  // 紫色
            ctx.lineWidth = 8 * tileScaleRef;
            ctx.lineCap = 'round';
            ctx.lineJoin = 'round';

            // 绘制渐变效果
            var gradient = ctx.createLinearGradient(canvasStartX, canvasStartY, canvasEndX, canvasEndY);
            gradient.addColorStop(0, '#bb8fce');
            gradient.addColorStop(0.5, '#9b59b6');
            gradient.addColorStop(1, '#7d3c98');
            ctx.strokeStyle = gradient;

            ctx.beginPath();

            // 沿着主方向绘制波形路径
            // 使用足够的步数来绘制平滑的波形
            var steps = Math.max(100, Math.floor(dist / 3));
            for (var i = 0; i <= steps; i++) {
                var t = i / steps;

                // 计算沿主方向的位置（从起点到终点）
                var x = canvasStartX + dx * t;
                var y = canvasStartY + dy * t;

                var alongDist = dist * t;

                // 计算波形偏移（垂直于移动方向）
                // 波形相位：基于沿路径的距离，形成传播的波形
                // 使用波长来计算相位（波长 = 速度 / 频率）
                var freq = waveFrequency;
                if (Math.abs(freq) < 0.0001)
                    freq = 0.0001;
                var wavelength = 260.0 / freq;
                var wavePhase = 2.0 * Math.PI * (alongDist / wavelength - waveTime * waveFrequency);
                var waveOffset = waveAmplitude * Math.sin(wavePhase) * tileScaleRef;

                // 应用波形偏移
                x += perpX * waveOffset;
                y += perpY * waveOffset;

                if (i === 0) {
                    ctx.moveTo(x, y);
                } else {
                    ctx.lineTo(x, y);
                }
            }

            ctx.stroke();

            // 添加发光效果（外圈）
            ctx.strokeStyle = 'rgba(155, 89, 182, 0.3)';
            ctx.lineWidth = 16 * tileScaleRef;
            ctx.stroke();

            // debug: draw endpoint marker
            try {
                ctx.beginPath();
                ctx.fillStyle = 'rgba(255,40,40,0.95)';
                ctx.arc(canvasEndX, canvasEndY, Math.max(3, 6 * tileScaleRef), 0, Math.PI*2);
                ctx.fill();
            } catch(e) {}
        }
    }

    // 被玩家击中时播放
    SoundEffect {
        id: hitSfx
        source: "qrc:/resource/audio/SoundEffect/playerHit.wav"
        volume: 0.8 * (typeof window !== 'undefined' ? window.masterVolume * window.sfxVolume : 1.0)
    }

    // 存储起点位置（世界坐标）
    property real originX: 0
    property real originY: 0
    property bool originInitialized: false

    function updateScreenPos() {
        if (!backend)
            return;
        // 计算起点位置（世界坐标）
        if (!originInitialized) {
            originX = backend.pos.x;
            originY = backend.pos.y;
            originInitialized = true;
        }
        // 将画布中心对齐到起点和当前位置的中点
        var centerX = (originX + backend.pos.x) / 2;
        var centerY = (originY + backend.pos.y) / 2;
        root.x = centerX * tileScaleRef - root.width / 2;
        root.y = centerY * tileScaleRef - root.height / 2;
        waveCanvas.requestPaint();
    }

    onBackendChanged: {
        if (!backend)
            return;
        originInitialized = false;
        try {
            backend.posChanged.connect(updateScreenPos);
        } catch (e) {}
        try {
            backend.waveTimeChanged.connect(function () {
                waveTime = backend.waveTime;
                waveCanvas.requestPaint();
            });
        } catch (e) {}
        try {
            backend.directionChanged.connect(function () {
                dirX = backend.dirx;
                dirY = backend.diry;
                waveCanvas.requestPaint();
            });
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
    onWaveTimeChanged: waveCanvas.requestPaint()
    onDirXChanged: waveCanvas.requestPaint()
    onDirYChanged: waveCanvas.requestPaint()
    onTraveledDistChanged: waveCanvas.requestPaint()
    onWaveFrequencyChanged: waveCanvas.requestPaint()
    onWaveAmplitudeChanged: waveCanvas.requestPaint()

    // 碰撞检测：检测玩家是否与波形路径相交
    Timer {
        interval: 16
        running: true
        repeat: true
        onTriggered: {
            if (!backend || !playerItemRef || !playerObjRef)
                return;

            // 计算玩家中心点
            var playerCenterX = playerItemRef.x + playerItemRef.width / 2;
            var playerCenterY = playerItemRef.y + playerItemRef.height / 2;

            // 计算波形路径的起点和终点（世界坐标）
            var offsetX = mapWrapperRef ? mapWrapperRef.x : 0;
            var offsetY = mapWrapperRef ? mapWrapperRef.y : 0;
            var startX = offsetX + originX * tileScaleRef;
            var startY = offsetY + originY * tileScaleRef;
            var endX = offsetX + backend.pos.x * tileScaleRef;
            var endY = offsetY + backend.pos.y * tileScaleRef;

            // 计算点到线段的最近距离
            var dx = endX - startX;
            var dy = endY - startY;
            var len2 = dx * dx + dy * dy;

            if (len2 > 0) {
                var t = Math.max(0, Math.min(1, ((playerCenterX - startX) * dx + (playerCenterY - startY) * dy) / len2));
                var closestX = startX + t * dx;
                var closestY = startY + t * dy;
                var dist = Math.sqrt((playerCenterX - closestX) * (playerCenterX - closestX) + (playerCenterY - closestY) * (playerCenterY - closestY));

                // 碰撞半径：波形宽度的一半 + 玩家半径
                var waveWidth = 8 * tileScaleRef;  // 波形线宽
                var playerRadius = Math.max(playerItemRef.width, playerItemRef.height) / 2;
                var collisionRadius = waveWidth / 2 + playerRadius;

                if (dist <= collisionRadius) {
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

    // rotation for real-time spin (root-level)
    NumberAnimation {
        id: spinAnim
        target: root
        property: "rotation"
        from: 0
        to: 360
        duration: spinDuration
        loops: Animation.Infinite
        running: false
        easing.type: Easing.Linear
    }

    Component.onCompleted: {
        try { spinAnim.start(); } catch(e) {}
    }
}

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
            var perpX = -dirY;  // 垂直向量
            var perpY = dirX;

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

                // 计算波形偏移（垂直于移动方向）
                // 波形相位：基于沿路径的距离，形成传播的波形
                // 使用波长来计算相位（波长 = 速度 / 频率）
                var wavelength = 260.0 / waveFrequency;
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
        }
    }

    // 被玩家击中时播放
    SoundEffect {
        id: hitSfx
        source: "qrc:/resource/audio/SoundEffect/playerHit.wav"
        volume: 0.8
    }

    // 存储起点位置（世界坐标）
    property real originX: 0
    property real originY: 0
    property bool originInitialized: false

    function updateScreenPos() {
        if (!backend)
            return;
        // 计算起点位置（第一次调用时记录）
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

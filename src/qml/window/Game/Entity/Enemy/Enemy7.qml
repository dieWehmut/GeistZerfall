import QtQuick 2.15
import GeistZerfall 1.0
import GeistZerfall.Game 1.0

Item {
    id: enemy7Root
    GameUiScale { id: gameUiScale }
    property real uiScale: gameUiScale.uiScale
    property int baseSize: 128
    width: baseSize * tileScaleRef
    height: baseSize * tileScaleRef
    // 与其他敌人统一：外部传入 backend 引用
    property var backend: null
    property var playerObjRef: null
    property var playerItemRef: null
    property var mapWrapperRef: null
    property real tileScaleRef: 1.0
    z: 120
    transformOrigin: Item.Center
    // continuous spin properties
    property int spinDuration: 500
    property real spinOffset: 0
    property real pulsateScale: 1.0
    property real impactScale: 1.0
    // speed up pulsating animation
    property int pulsateDuration: 800
    scale: uiScale * pulsateScale * impactScale

    Image {
        id: sprite
        anchors.centerIn: parent
        source: "qrc:/resource/image/entity/enemy7.png"
        width: parent.width
        height: parent.height
    }

    // HUD 与其它保持一致（简化示例）
    Item {
        id: hudRoot
        width: enemy7Root.width
        height: 20
        anchors.horizontalCenter: parent.horizontalCenter
        y: -hudRoot.height - 6
        Rectangle { anchors.fill: parent; color: "transparent" }
        Rectangle {
            id: hpBarBg
            x: 4; y: 0; width: parent.width - 8; height: 8; radius: 3
            color: "#3a0b0b"; border.color: "#000"
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
            x: 4; y: 10; width: parent.width - 8; height: 6; radius: 3
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

    // 位置更新
    function updateScreenPos() {
        if (!backend) return;
        enemy7Root.x = backend.pos.x * tileScaleRef - enemy7Root.width / 2;
        enemy7Root.y = backend.pos.y * tileScaleRef - enemy7Root.height / 2;
    }

    function syncForcedRevealRegistration() {
        if (!mapWrapperRef) return;
        if (backend && backend.forcedReveal) {
            if (typeof mapWrapperRef.registerRevealedEnemy === 'function') {
                mapWrapperRef.registerRevealedEnemy(enemy7Root);
            }
        } else if (typeof mapWrapperRef.unregisterRevealedEnemy === 'function') {
            mapWrapperRef.unregisterRevealedEnemy(enemy7Root);
        }
    }
    onTileScaleRefChanged: updateScreenPos()

    // 初始化与信号绑定
    onBackendChanged: {
        if (!backend) return;
        try {
            if (backend && typeof backend.setCollisionRadius === 'function') {
                backend.setCollisionRadius(baseSize * 0.45);
            } else {
                backend.setProperty("collisionRadius", baseSize * 0.45);
            }
        } catch(e){}
        try { backend.posChanged.connect(updateScreenPos); } catch(e){}
        // 子弹创建（散射弹）
        try { backend.enemyProjectileCreated.connect(function(pr){
            var comp = Qt.createComponent("./Enemy7Bullet.qml");
            if (comp.status === Component.Ready) {
                var bullet = comp.createObject(mapWrapperRef, { backend: pr, playerItemRef: playerItemRef, playerObjRef: playerObjRef, tileScaleRef: tileScaleRef, mapWrapperRef: mapWrapperRef });
                if (bullet) bullet.tileScaleRef = Qt.binding(function(){ return tileScaleRef; });
            } else {
                console.log("Enemy7: bullet component error", comp.errorString());
            }
        }); } catch(e){}
        updateScreenPos();
        syncForcedRevealRegistration();
    }

    // 死亡销毁
    Connections {
        target: backend
		onAliveChanged: { if (backend && !backend.alive) { try { enemy7Root.destroy(); } catch(e){} } }
		onForcedRevealChanged: syncForcedRevealRegistration()
    }

    SequentialAnimation {
        id: pulsateAnim
        loops: Animation.Infinite
        running: false
        NumberAnimation { target: enemy7Root; property: "pulsateScale"; from: 1.0; to: 2.0; duration: pulsateDuration; easing.type: Easing.InOutSine }
        NumberAnimation { target: enemy7Root; property: "pulsateScale"; from: 2.0; to: 1.0; duration: pulsateDuration; easing.type: Easing.InOutSine }
    }

    Timer { id: pulsateStarter; interval: 0; repeat: false; onTriggered: pulsateAnim.start() }

    // continuous rotation for visual flair
    NumberAnimation {
        id: spinAnim
        target: enemy7Root
        property: "rotation"
        from: 0; to: 360
        loops: Animation.Infinite
        running: false
        duration: spinDuration
        easing.type: Easing.Linear
    }

    Component.onCompleted: {
        try {
            // shorter, faster pulsate period
            var d = 600 + Math.floor(Math.random() * 400);
            pulsateDuration = d;
            var offset = Math.floor(Math.random() * pulsateDuration);
            pulsateStarter.interval = offset;
            pulsateStarter.start();
                try {
                    spinOffset = Math.floor(Math.random() * 800);
                    spinAnim.duration = spinDuration + Math.floor(Math.random() * 3000) - 1500;
                    Qt.callLater(function() { spinAnim.start(); });
                } catch(e) {}
        } catch(e) {}
        syncForcedRevealRegistration();
    }

    Component.onDestruction: {
        if (mapWrapperRef && typeof mapWrapperRef.unregisterRevealedEnemy === 'function') {
            mapWrapperRef.unregisterRevealedEnemy(enemy7Root);
        }
    }
}
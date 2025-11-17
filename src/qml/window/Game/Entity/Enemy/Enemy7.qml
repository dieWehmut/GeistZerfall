import QtQuick 2.15
import GeistZerfall.Game 1.0

Item {
    id: enemy7
    property BackendEnemy7 backend: BackendEnemy7 {
        id: backendEnemy
        pos: Qt.point(x + width/2, y + height/2)
        onDied: {
            // 死亡特效
            deathEffect.visible = true
            deathEffect.start()
            // 延迟移除避免动画中断
            timer.restart()
        }
        onEnemyProjectileCreated: {
            // 创建散射子弹
            var bullet = enemy7BulletComponent.createObject(enemy7.parent)
            bullet.x = x + width/2 - bullet.width/2
            bullet.y = y + height/2 - bullet.height/2
            bullet.backend = projectile
        }
    }

    property BackendPlayer backendPlayer
    width: 56
    height: 56

    // 主精灵
    Image {
        id: mainSprite
        source: "qrc:/resource/image/entity/enemy7.png"
        width: 56
        height: 56
        anchors.centerIn: parent
    }

    // 死亡粒子效果
    ParticleSystem {
        id: deathEffect
        visible: false
        anchors.fill: parent
        Particle {
            color: "#ff4444"
            lifeSpan: 800
            size: 8
            emitRate: 0
            maximumEmitted: 30
            velocity: AngleDirection { angle: 0; angleVariation: 360; magnitude: 50 }
        }
        onStopped: enemy7.parent.removeEnemy(enemy7)
    }

    Timer {
        id: timer
        interval: 800
        onTriggered: deathEffect.stop()
    }

    // 子弹组件
    Component {
        id: enemy7BulletComponent
        Enemy7Bullet {
            width: 16
            height: 16
            onBackendDestroyed: destroy()
        }
    }

    // 位置同步
    onXChanged: backend.x = x + width/2
    onYChanged: backend.y = y + height/2

    Component.onCompleted: backend.setPlayerTarget(backendPlayer)
}
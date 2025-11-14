import QtQuick 2.15
import GeistZerfall.Game 1.0

Item {
    id: enemy5Bullet
    property BackendEnemy5Bullet backend: null

    visible: backend !== null && backend.alive
    x: backend ? backend.posX : 0
    y: backend ? backend.posY : 0
    width: 16
    height: 16
    transformOrigin: Item.Center  // 旋转中心

    // 子弹精灵（使用 sourceRect 切帧）
    Image {
        anchors.fill: parent
        source: "qrc:/resource/image/projectile/enemy5_bullet.png"
        sourceRect: {
            var frameWidth = 16
            return Qt.rect(backend.spriteIndex * frameWidth, 0, frameWidth, 16)
        }
        // 方向旋转（QtQuick 2.15 中 Math 函数用法不变）
        rotation: backend ? (Math.atan2(backend.diry, backend.dirx) * 180 / Math.PI) : 0
    }

    // 子弹销毁动画
    Connections {
        target: backend
        onBackendDestroyed: {
            SequentialAnimation {
            PropertyAnimation {
                target: enemy5Bullet
                properties: "opacity, scale"
                to: 0
                duration: 200
            }
            onStopped: enemy5Bullet.destroy()
        }.start()
        }
    }
}
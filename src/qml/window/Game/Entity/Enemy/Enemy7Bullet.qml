import QtQuick 2.15
import GeistZerfall.Game 1.0

Item {
    id: enemy7Bullet
    property BackendEnemy7Bullet backend: null
    width: 16
    height: 16

    // 子弹视觉表现
    Image {
        id: bulletSprite
        anchors.centerIn: parent
        source: "qrc:/resource/image/entity/enemy7Bullet.png" // 假设的资源路径
        width: enemy7Bullet.width
        height: enemy7Bullet.height

        // 根据后端spriteIndex更新视觉（如果有多个帧）
        NumberAnimation on rotation {
            // 子弹旋转动画，增强视觉效果
            from: 0
            to: 360
            duration: 1000
            loops: Animation.Infinite
        }
    }

    // 位置同步
    Connections {
        target: backend
        onXChanged: enemy7Bullet.x = backend.x - width/2
        onYChanged: enemy7Bullet.y = backend.y - height/2
        onBackendDestroyed: enemy7Bullet.destroy()
    }

    // 初始化位置
    Component.onCompleted: {
        if (backend) {
            x = backend.x - width/2
            y = backend.y - height/2
        }
    }
}
import QtQuick 2.15
import GeistZerfall.Game 1.0  // 项目后端模块

Item {
    id: enemy5
    property BackendEnemy5 backend: null  // 绑定后端实例

    // 基础属性（位置、可见性与后端同步）
    visible: backend !== null && backend.alive
    x: backend ? backend.posX : 0
    y: backend ? backend.posY : 0
    width: 64  // 素材宽度
    height: 64  // 素材高度

    // 敌人精灵动画（QtQuick 2.15 中 Sprite 仍可用）
    Sprite {
        anchors.fill: parent
        source: "qrc:/resource/image/enemy/enemy5.png"  // 实际资源路径
        frameCount: 4  // 帧数量
        frameWidth: 64  // 单帧宽度
        frameHeight: 64  // 单帧高度
        frameDuration: 200  // 每帧时长(ms)
        running: visible  // 可见时播放动画
    }

    // 生命值条
    Rectangle {
        id: hpBar
        anchors.bottom: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * 0.8
        height: 4
        color: "red"
        clip: true

        Rectangle {
            width: backend ? (backend.hp / backend.maxHp) * parent.width : 0
            height: parent.height
            color: "green"
        }
    }

    // 法力值条（Enemy5 特有）
    Rectangle {
        id: mpBar
        anchors.top: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * 0.8
        height: 3
        color: "black"
        clip: true

        Rectangle {
            width: backend ? (backend.mp / backend.maxMp) * parent.width : 0
            height: parent.height
            color: "blue"
        }
    }

    // 攻击动画（缩放效果）
    SequentialAnimation {
        id: attackAnim
        PropertyAnimation {
            target: enemy5
            property: "scale"
            to: 1.1
            duration: 100
        }
        PropertyAnimation {
            target: enemy5
            property: "scale"
            to: 1.0
            duration: 100
        }
    }

    // 后端事件绑定（QtQuick 2.15 中 Connections 用法不变）
    Connections {
        target: backend
        onAttacked: {
            attackAnim.restart()
        }
        onDied: {
            // 死亡消失动画
            SequentialAnimation {
            PropertyAnimation {
                target: enemy5
                property: "opacity"
                to: 0
                duration: 500
            }
            onStopped: enemy5.destroy()
        }.start()
        }
        // 生成子弹时创建视觉元素
        onEnemyProjectileCreated: function(bullet) {
            if (bullet.visualType !== "bullet") return
            Enemy5Bullet {
                backend: bullet
                parent: enemy5.parent
            }
        }
    }
}
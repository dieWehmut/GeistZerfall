import QtQuick
import QtQuick.Particles

// ParticleEffect.qml - 粒子效果组件
Item {
    id: root
    anchors.fill: parent

    // 简单的粒子效果示例（可以根据需要扩展）
    ParticleSystem {
        id: particleSystem
        anchors.fill: parent

        ImageParticle {
            source: "qrc:/qt/qml/QtQuick/Particles/images/particle.png"
            color: "#40FFFFFF"
            colorVariation: 0.2
        }

        Emitter {
            anchors.fill: parent
            emitRate: 10
            lifeSpan: 3000
            size: 16
            sizeVariation: 8
            velocity: AngleDirection {
                angle: 0
                angleVariation: 360
                magnitude: 20
            }
        }
    }
}

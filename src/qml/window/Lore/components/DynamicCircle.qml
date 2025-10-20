import QtQuick

// DynamicCircle.qml - 动态圆圈组件（圈外黑色，圈内白色）
Item {
    id: root
    anchors.fill: parent

    property real circleSize: 400 // 圆圈当前大小
    property real minSize: 350
    property real maxSize: 450
    property int breathDuration: 6000 // 呼吸周期

    // 外层黑色背景
    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    // 白色圆圈
    Rectangle {
        id: whiteCircle
        anchors.centerIn: parent
        width: circleSize
        height: circleSize
        radius: width / 2
        color: "white"
    }

    // 呼吸动画（圆圈大小变化）
    SequentialAnimation {
        running: true
        loops: Animation.Infinite

        NumberAnimation {
            target: root
            property: "circleSize"
            from: root.minSize
            to: root.maxSize
            duration: root.breathDuration / 2
            easing.type: Easing.InOutSine
        }

        NumberAnimation {
            target: root
            property: "circleSize"
            from: root.maxSize
            to: root.minSize
            duration: root.breathDuration / 2
            easing.type: Easing.InOutSine
        }
    }
}

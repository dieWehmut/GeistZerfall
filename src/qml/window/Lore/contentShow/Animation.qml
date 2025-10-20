import QtQuick

// Animation.qml - 动画内容显示
Item {
    id: root
    anchors.fill: parent

    property var contentData: null

    AnimatedImage {
        anchors.centerIn: parent
        source: contentData ? contentData.source || "" : ""
        fillMode: Image.PreserveAspectFit
        width: parent.width * 0.8
        height: parent.height * 0.8
        playing: true

        // 淡入动画
        opacity: 0
        NumberAnimation on opacity {
            from: 0
            to: 1
            duration: 500
            running: true
        }
    }
}

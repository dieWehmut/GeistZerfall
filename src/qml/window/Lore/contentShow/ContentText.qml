import QtQuick

// Text.qml - 文字内容显示
Item {
    id: root
    anchors.fill: parent

    property var contentData: null

    Component.onCompleted: {
        console.log("Text.qml: component completed, contentData =", contentData ? JSON.stringify(contentData) : "null");
    }

    onContentDataChanged: {
        console.log("Text.qml: contentData changed to", contentData ? JSON.stringify(contentData) : "null");
    }

    Text {
        anchors.centerIn: parent
        text: contentData ? contentData.text || "" : ""
        font.pixelSize: 24
        color: "black"
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        width: parent.width * 0.8

        Component.onCompleted: {
            console.log("Text component: text =", text);
        }

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

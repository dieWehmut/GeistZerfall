import QtQuick
import QtQuick.Controls

// 通用确认弹窗组件
Item {
    id: root
    visible: false
    width: 360
    height: 170
    z: 999

    // 可配置属性
    property string title: "确认"
    property string yesText: "YES"
    property string noText: "NO"
    property var onYes: null
    property var onNo: null

    // 遮罩（最底层）
    Rectangle {
        anchors.fill: parent
        color: "#80000000"
        z: -1
        visible: parent.visible
        MouseArea { 
            anchors.fill: parent
            onClicked: root.visible = false
        }
    }

    // 伪阴影
    Rectangle {
        width: parent.width
        height: parent.height
        radius: 24
        color: "#22000000"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 8
        z: 0
        visible: root.visible
    }

    // 主体
    Rectangle {
        id: dialogBg
        width: parent.width
        height: parent.height
        radius: 24
        color: "#f8f8f8"
        border.width: 0
        z: 1
    }

    // 右上角关闭按钮（使用 AppButton 以保持统一样式）
    AppButton {
        id: closeBtn
        width: 40
        height: 40
        anchors.right: dialogBg.right
        anchors.rightMargin: 12
        anchors.top: dialogBg.top
        anchors.topMargin: 12
        z: 2
        text: "×"
        fontPixelSize: 20
        onClicked: {
            root.visible = false
        }
    }

    // 内容
    Column {
        anchors.centerIn: dialogBg
        spacing: 28
        width: dialogBg.width
        z: 3

        Text {
            text: root.title
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 28
            color: "#222"
            font.bold: true
        }

        Row {
            spacing: 36
            anchors.horizontalCenter: parent.horizontalCenter

            // YES按钮
            AppButton {
                width: 110; height: 48
                text: root.yesText
                fontPixelSize: 22
                onClicked: {
                    if (root.onYes) root.onYes()
                    root.visible = false
                }
            }

            // NO按钮
            AppButton {
                width: 110; height: 48
                text: root.noText
                fontPixelSize: 22
                onClicked: {
                    if (root.onNo) root.onNo()
                    root.visible = false
                }
            }
        }
    }
}

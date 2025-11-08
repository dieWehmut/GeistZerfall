import QtQuick
import QtQuick.Controls
import "../window/windowState.js" as WindowState

// 通用底部按钮栏组件
Rectangle {
    id: root
    width: parent.width
    height: 120
    color: "transparent"
    z: 20

    // 可配置的按钮列表
    property var buttons: []
    // buttons格式: [{text: "SAVE", action: function(){}, checked: false, checkable: false}, ...]

    Row {
        id: buttonRow
        spacing: 40
        anchors.centerIn: parent

        // entrance animation controller
        property bool buttonsEntered: false
        function triggerButtonEntrance() { buttonsEntered = true }
        Component.onCompleted: Qt.callLater(triggerButtonEntrance)

        Repeater {
            model: root.buttons
            delegate: AppButton {
                text: modelData.text || ""
                width: 180
                height: 60
                fontPixelSize: 22
                checkable: modelData.checkable || false
                checked: modelData.checked || false
                enabled: modelData.enabled !== undefined ? modelData.enabled : true

                y: buttonRow.buttonsEntered ? 0 : 12
                opacity: buttonRow.buttonsEntered ? 1 : 0

                Behavior on y {
                    SequentialAnimation {
                        PauseAnimation { duration: index * 60 }
                        NumberAnimation { duration: 360; easing.type: Easing.OutQuad }
                    }
                }
                Behavior on opacity {
                    SequentialAnimation {
                        PauseAnimation { duration: index * 60 }
                        NumberAnimation { duration: 360; easing.type: Easing.OutQuad }
                    }
                }

                onClicked: {
                    if (modelData.action) modelData.action()
                }
            }
        }
    }
}

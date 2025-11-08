import QtQuick
import QtQuick.Controls
import "windowState.js" as WindowState
import "../components"

Item {
    anchors.fill: parent
    property real baseWidth: 1280
    property real baseHeight: 720
    property real scaleFactor: Math.min(width / baseWidth, height / baseHeight)

    Image {
        anchors.fill: parent
        source: "qrc:/resource/image/bg/mainmenu.png"
        fillMode: Image.PreserveAspectCrop
        smooth: true
        cache: true
        z: -1
    }

    Item {
        id: contentRoot
        width: baseWidth
        height: baseHeight
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        transform: Scale { xScale: scaleFactor; yScale: scaleFactor; origin.x: baseWidth/2; origin.y: baseHeight/2 }

        // 标题（与 Config.qml 一致）
        Text {
            text: "EXTRA"
            anchors.left: parent.left
            anchors.leftMargin: 40
            anchors.top: parent.top
            anchors.topMargin: 60
            font.pixelSize: 48
            color: "white"
            font.bold: true
            z: 10
            style: Text.Outline
            styleColor: "black"
        }

        // 中间占位：暂不实现具体内容
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: 40
            z: 10

            // 占位文本
            Text {
                text: "(EXTRA 内容待实现)"
                font.pixelSize: 28
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
                style: Text.Outline
                styleColor: "black"
            }
        }

        // 底部按钮栏
        BottomButtonBar {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 40
            buttons: [
                {text: "SAVE", action: function() {
                    WindowState.setTargetMode("save")
                    window.pushSource && window.pushSource("qml/window/SaveLoad.qml")
                }},
                {text: "LOAD", action: function() {
                    WindowState.setTargetMode("load")
                    window.pushSource && window.pushSource("qml/window/SaveLoad.qml")
                }},
                {text: "CONFIG", action: function() {
                    window.pushSource && window.pushSource("qml/window/Config.qml")
                }},
                {text: "TITLE", action: function() {
                    confirmTitleDialog.visible = true
                }},
                {text: "BACK", action: function() {
                    window.goBack()
                }},
                {text: "QUIT", action: function() {
                    confirmQuitDialog.visible = true
                }}
            ]
        }

            // Global input helpers: right-click = BACK, Esc = exit fullscreen
            MouseArea {
                id: globalRightClickExtra
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.RightButton
                onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) {
                        if (window.goBack) window.goBack();
                    }
                }
                z: -100
            }

            Shortcut {
                sequence: "Esc"
                onActivated: {
                    if (window && window.showNormal) window.showNormal();
                    if (typeof fullscreenBtn !== 'undefined') fullscreenBtn.checked = false;
                    if (typeof windowBtn !== 'undefined') windowBtn.checked = true;
                }
            }

        // TITLE 确认弹窗
        ConfirmDialog {
            id: confirmTitleDialog
            anchors.centerIn: parent
            title: "返回主界面"
            onYes: function() {
                window.pageHistory = [];
                window.replaceSource("qml/window/MainMenu.qml");
            }
        }

        // QUIT 确认弹窗
        ConfirmDialog {
            id: confirmQuitDialog
            anchors.centerIn: parent
            title: "要结束游戏吗"
            onYes: function() {
                Qt.quit()
            }
        }
    }
}

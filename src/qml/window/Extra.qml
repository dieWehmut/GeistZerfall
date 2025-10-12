import QtQuick
import QtQuick.Controls
import "windowState.js" as WindowState

Item {
    anchors.fill: parent
    property real baseWidth: 1280
    property real baseHeight: 720
    property real scaleFactor: Math.min(width / baseWidth, height / baseHeight)

    Image {
        anchors.fill: parent
        source: "qrc:/resource/image/mainmenuBg.png"
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

        // 底部按钮栏（与 Config.qml 相同布局和样式）
        Rectangle {
            width: parent.width
            height: 120
            color: "transparent"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 40
            z: 20

            Row {
                id: buttonRow
                spacing: 40
                anchors.centerIn: parent

                // entrance animation controller
                property bool buttonsEntered: false
                function triggerButtonEntrance() { buttonsEntered = true }
                Component.onCompleted: Qt.callLater(triggerButtonEntrance)

                Button {
                    text: "SAVE"
                    width: 180; height: 60
                    font.pixelSize: 22
                    y: buttonRow.buttonsEntered ? 0 : 12
                    opacity: buttonRow.buttonsEntered ? 1 : 0
                    Behavior on y { SequentialAnimation { PauseAnimation { duration: 0 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 0 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    onClicked: {
                        WindowState.setTargetMode("save")
                        window.pushSource && window.pushSource("qml/window/SaveLoad.qml")
                    }
                }
                Button {
                    text: "LOAD"
                    width: 180; height: 60
                    font.pixelSize: 22
                    y: buttonRow.buttonsEntered ? 0 : 12
                    opacity: buttonRow.buttonsEntered ? 1 : 0
                    Behavior on y { SequentialAnimation { PauseAnimation { duration: 60 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 60 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    onClicked: {
                        WindowState.setTargetMode("load")
                        window.pushSource && window.pushSource("qml/window/SaveLoad.qml")
                    }
                }
                Button {
                    text: "CONFIG"
                    width: 180; height: 60
                    font.pixelSize: 22
                    y: buttonRow.buttonsEntered ? 0 : 12
                    opacity: buttonRow.buttonsEntered ? 1 : 0
                    Behavior on y { SequentialAnimation { PauseAnimation { duration: 120 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 120 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    onClicked: window.pushSource && window.pushSource("qml/window/Config.qml")
                }
                Button {
                    text: "TITLE"
                    width: 180; height: 60
                    font.pixelSize: 22
                    y: buttonRow.buttonsEntered ? 0 : 12
                    opacity: buttonRow.buttonsEntered ? 1 : 0
                    Behavior on y { SequentialAnimation { PauseAnimation { duration: 180 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 180 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    onClicked: confirmTitleDialog.visible = true
                }
                Button {
                    text: "BACK"
                    width: 180; height: 60
                    font.pixelSize: 22
                    y: buttonRow.buttonsEntered ? 0 : 12
                    opacity: buttonRow.buttonsEntered ? 1 : 0
                    Behavior on y { SequentialAnimation { PauseAnimation { duration: 240 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 240 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    onClicked: window.goBack()
                }
                Button {
                    text: "QUIT"
                    width: 180; height: 60
                    font.pixelSize: 22
                    y: buttonRow.buttonsEntered ? 0 : 12
                    opacity: buttonRow.buttonsEntered ? 1 : 0
                    Behavior on y { SequentialAnimation { PauseAnimation { duration: 300 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 300 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    onClicked: confirmQuitDialog.visible = true
                }
            }
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

        // TITLE 确认弹窗（复制自 Config.qml）
        Item {
            id: confirmTitleDialog
            visible: false
            width: 360
            height: 170
            anchors.centerIn: parent
            z: 999
            Rectangle {
                anchors.fill: parent
                color: "#80000000"
                z: -1
                visible: parent.visible
                MouseArea { anchors.fill: parent; onClicked: { confirmTitleDialog.visible = false } }
            }
            Rectangle {
                width: parent.width; height: parent.height
                radius: 24
                color: "#22000000"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 8
                z: 0
                visible: confirmTitleDialog.visible
            }
            Rectangle {
                id: dialogBgTitle
                width: parent.width
                height: parent.height
                radius: 24
                color: "#f8f8f8"
                border.width: 0
                z: 1
            }
            Rectangle {
                id: closeTitleBtn
                width: 32; height: 32
                anchors.right: dialogBgTitle.right
                anchors.rightMargin: 12
                anchors.top: dialogBgTitle.top
                anchors.topMargin: 12
                radius: 16
                color: closeTitleBtnMouse.containsMouse ? "#e57373" : "transparent"
                border.color: "#bbbbbb"
                border.width: 1
                z: 2
                MouseArea {
                    id: closeTitleBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: confirmTitleDialog.visible = false
                }
                Text {
                    text: "×"
                    anchors.centerIn: parent
                    font.pixelSize: 22
                    color: "#222"
                }
            }
            Column {
                anchors.centerIn: dialogBgTitle
                spacing: 28
                width: dialogBgTitle.width
                z: 3
                Text {
                    text: "返回主界面"
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.pixelSize: 28
                    color: "#222"
                    font.bold: true
                }
                Row {
                    spacing: 36
                    anchors.horizontalCenter: parent.horizontalCenter
                    Rectangle {
                        width: 110; height: 48; radius: 8
                        color: yesTitleBtnMouse.containsMouse ? "#1976d2" : "#eeeeee"
                        border.color: yesTitleBtnMouse.containsMouse ? "#1976d2" : "#bbbbbb"
                        border.width: 1
                        MouseArea {
                            id: yesTitleBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                window.pageHistory = [];
                                window.replaceSource("qml/window/MainMenu.qml");
                                confirmTitleDialog.visible = false
                            }
                        }
                        Text {
                            text: "YES"
                            anchors.centerIn: parent
                            font.pixelSize: 22
                            color: yesTitleBtnMouse.containsMouse ? "white" : "#222"
                            font.bold: true
                        }
                    }
                    Rectangle {
                        width: 110; height: 48; radius: 8
                        color: noTitleBtnMouse.containsMouse ? "#bdbdbd" : "#eeeeee"
                        border.color: noTitleBtnMouse.containsMouse ? "#bdbdbd" : "#bbbbbb"
                        border.width: 1
                        MouseArea {
                            id: noTitleBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: confirmTitleDialog.visible = false
                        }
                        Text {
                            text: "NO"
                            anchors.centerIn: parent
                            font.pixelSize: 22
                            color: noTitleBtnMouse.containsMouse ? "white" : "#222"
                            font.bold: true
                        }
                    }
                }
            }
        }

        // QUIT 确认弹窗（复制自 Config.qml）
        Item {
            id: confirmQuitDialog
            visible: false
            width: 360
            height: 170
            anchors.centerIn: parent
            z: 999
            Rectangle {
                anchors.fill: parent
                color: "#80000000"
                z: -1
                visible: parent.visible
                MouseArea { anchors.fill: parent; onClicked: { confirmQuitDialog.visible = false } }
            }
            Rectangle {
                width: parent.width; height: parent.height
                radius: 24
                color: "#22000000"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 8
                z: 0
                visible: confirmQuitDialog.visible
            }
            Rectangle {
                id: dialogBg
                width: parent.width
                height: parent.height
                radius: 24
                color: "#f8f8f8"
                border.width: 0
                z: 1
            }
            Rectangle {
                id: closeBtn
                width: 32; height: 32
                anchors.right: dialogBg.right
                anchors.rightMargin: 12
                anchors.top: dialogBg.top
                anchors.topMargin: 12
                radius: 16
                color: closeBtnMouse.containsMouse ? "#e57373" : "transparent"
                border.color: "#bbbbbb"
                border.width: 1
                z: 2
                MouseArea {
                    id: closeBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: confirmQuitDialog.visible = false
                }
                Text {
                    text: "×"
                    anchors.centerIn: parent
                    font.pixelSize: 22
                    color: "#222"
                }
            }
            Column {
                anchors.centerIn: dialogBg
                spacing: 28
                width: dialogBg.width
                z: 3
                Text {
                    text: "要结束游戏吗"
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.pixelSize: 28
                    color: "#222"
                    font.bold: true
                }
                Row {
                    spacing: 36
                    anchors.horizontalCenter: parent.horizontalCenter
                    Rectangle {
                        width: 110; height: 48; radius: 8
                        color: yesBtnMouse.containsMouse ? "#1976d2" : "#eeeeee"
                        border.color: yesBtnMouse.containsMouse ? "#1976d2" : "#bbbbbb"
                        border.width: 1
                        MouseArea {
                            id: yesBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Qt.quit()
                        }
                        Text {
                            text: "YES"
                            anchors.centerIn: parent
                            font.pixelSize: 22
                            color: yesBtnMouse.containsMouse ? "white" : "#222"
                            font.bold: true
                        }
                    }
                    Rectangle {
                        width: 110; height: 48; radius: 8
                        color: noBtnMouse.containsMouse ? "#bdbdbd" : "#eeeeee"
                        border.color: noBtnMouse.containsMouse ? "#bdbdbd" : "#bbbbbb"
                        border.width: 1
                        MouseArea {
                            id: noBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: confirmQuitDialog.visible = false
                        }
                        Text {
                            text: "NO"
                            anchors.centerIn: parent
                            font.pixelSize: 22
                            color: noBtnMouse.containsMouse ? "white" : "#222"
                            font.bold: true
                        }
                    }
                }
            }
        }
    }
}

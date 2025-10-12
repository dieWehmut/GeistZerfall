import QtQuick
import QtQuick.Controls
import QtMultimedia 6.5

Item {
    anchors.fill: parent
    // 以1280x720为基准，等比例缩放内容
    property real baseWidth: 1280
    property real baseHeight: 720
    property real scaleFactor: Math.min(width / baseWidth, height / baseHeight)
        // 背景图
        Image {
            anchors.fill: parent
            source: "qrc:/resource/image/mainmenuBg.png"
            fillMode: Image.PreserveAspectCrop
        }
        // Global input helpers: right-click = BACK, Esc = exit fullscreen
        MouseArea {
            id: globalRightClickMainMenu
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.RightButton
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    if (window.goBack) window.goBack();
                }
            }
            // allow this MouseArea to sit behind dialogs but still receive right-clicks
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
    // 内容容器，等比例缩放
    Item {
        id: contentRoot

        Timer {
            id: continuePollTimer
            interval: 2000
            repeat: true
            running: true
            onTriggered: {
                console.log("MainMenu: continuePollTimer triggered");
                try {
                    if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager) {
                        var v = SaveLoadManager.hasAuto();
                        console.log("MainMenu: SaveLoadManager.hasAuto() =>", v);
                    }
                } catch (e) { console.log("MainMenu: continuePollTimer error", e); }
            }
        }

        Connections {
            target: SaveLoadManager
            function onSaved() {
                console.log("MainMenu: received SaveLoadManager.saved signal");
            }
            function onAutoExistsChanged() {
                console.log("MainMenu: received SaveLoadManager.autoExistsChanged signal, new=", SaveLoadManager ? SaveLoadManager.autoExists : false);
            }
        }
        width: baseWidth
        height: baseHeight
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        transform: Scale { xScale: scaleFactor; yScale: scaleFactor; origin.x: baseWidth/2; origin.y: baseHeight/2 }

    // title entrance controller
    property bool titleEntered: false




        Component.onCompleted: {
            // 使用顶层 Window 的全局音乐播放器播放主菜单音乐
            try {
                console.log("MainMenu: Component.onCompleted, initial autoExists=", (typeof SaveLoadManager !== 'undefined' && SaveLoadManager) ? SaveLoadManager.autoExists : false);
            } catch (e) { console.log("MainMenu: init continueEnabled error", e); }
            if (typeof window.playMusic === 'function') {
                window.playMusic("qrc:/resource/audio/mainmenu.mp3");
            }
            // trigger title entrance a moment after component completed
            Qt.callLater(function() { titleEntered = true; });
        }
        // 标题，居中显示（闪一下入场）
        Text {
            id: mainTitle
            text: "GeistZerfall"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            opacity: 0
            font.pixelSize: 64
            color: "white"
            font.bold: true
            z: 10
            style: Text.Outline
            styleColor: "black"
        }

        // flash animation for main title
        SequentialAnimation {
            id: titleFlashAnim
            running: false
            PropertyAnimation { target: mainTitle; property: "opacity"; to: 1.0; duration: 120 }
            PropertyAnimation { target: mainTitle; property: "opacity"; to: 0.4; duration: 120 }
            PropertyAnimation { target: mainTitle; property: "opacity"; to: 1.0; duration: 120 }
        }

        onTitleEnteredChanged: {
            if (titleEntered) titleFlashAnim.start();
        }

        // 六个按钮，底部居中
        Rectangle {
            width: parent.width
            height: 120
            color: "transparent"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 40

            Row {
                id: buttonRow
                spacing: 40
                anchors.centerIn: parent
                // entrance animation controller
                property bool buttonsEntered: false

                function triggerButtonEntrance() {
                    buttonsEntered = true
                }

                // helper to create staggered animated button
                Component.onCompleted: {
                    // slight delay to ensure layout is ready
                    Qt.callLater(function() { triggerButtonEntrance(); });
                }

                Button {
                    id: btnStart
                    text: "START"
                    width: 180; height: 60
                    font.pixelSize: 22
                    y: buttonRow.buttonsEntered ? 0 : 12
                    opacity: buttonRow.buttonsEntered ? 1 : 0
                    Behavior on y { NumberAnimation { duration: 360; easing.type: Easing.OutQuad } }
                    Behavior on opacity { NumberAnimation { duration: 360; easing.type: Easing.OutQuad } }
                    onClicked: {
                        // If an auto save already exists, remove it first (reset)
                        try {
                            if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager && SaveLoadManager.autoExists) {
                                var removed = SaveLoadManager.removeAuto("save");
                                console.log("MainMenu: removeAuto returned", removed);
                            }
                        } catch (e) { console.log("MainMenu: removeAuto error", e); }
                        // Indicate to GameView that this is a new game so it can compute center and create an auto save
                        try { WindowState.setTargetMode("new"); } catch (e) { /* ignore if not available */ }
                        window.pushSource("qml/window/GameView.qml")
                    }
                    Component.onCompleted: { if (buttonRow.buttonsEntered) { /* already triggered */ } }
                }

                Button {
                    id: btnContinue
                    text: "CONTINUE"
                    width: 180; height: 60
                    font.pixelSize: 22
                    enabled: (typeof SaveLoadManager !== 'undefined' && SaveLoadManager) ? SaveLoadManager.autoExists : false
                    y: buttonRow.buttonsEntered ? 0 : 12
                    opacity: buttonRow.buttonsEntered ? 1 : 0
                    Behavior on y { SequentialAnimation { PauseAnimation { duration: 60 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 60 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    onClicked: {
                        if (enabled) window.pushSource("qml/window/GameView.qml")
                    }
                }

                Button {
                    id: btnLoad
                    text: "LOAD"
                    width: 180; height: 60
                    font.pixelSize: 22
                    y: buttonRow.buttonsEntered ? 0 : 12
                    opacity: buttonRow.buttonsEntered ? 1 : 0
                    Behavior on y { SequentialAnimation { PauseAnimation { duration: 120 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 120 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    onClicked: window.pushSource("qml/window/SaveLoad.qml")
                }

                Button {
                    id: btnConfig
                    text: "CONFIG"
                    width: 180; height: 60
                    font.pixelSize: 22
                    y: buttonRow.buttonsEntered ? 0 : 12
                    opacity: buttonRow.buttonsEntered ? 1 : 0
                    Behavior on y { SequentialAnimation { PauseAnimation { duration: 180 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 180 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    onClicked: window.pushSource("qml/window/Config.qml")
                }

                Button {
                    id: btnExtra
                    text: "EXTRA"
                    width: 180; height: 60
                    font.pixelSize: 22
                    y: buttonRow.buttonsEntered ? 0 : 12
                    opacity: buttonRow.buttonsEntered ? 1 : 0
                    Behavior on y { SequentialAnimation { PauseAnimation { duration: 240 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 240 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    onClicked: window.pushSource("qml/window/Extra.qml")
                }

                Button {
                    id: btnExit
                    text: "EXIT"
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
        Item {
            id: confirmQuitDialog
            visible: false
            width: 360
            height: 170
            anchors.centerIn: parent
            z: 999
            // 遮罩（最底层）
            Rectangle {
                anchors.fill: parent
                color: "#80000000"
                z: -1
                visible: parent.visible
                MouseArea { anchors.fill: parent; onClicked: { confirmQuitDialog.visible = false } }
            }
            // 伪阴影
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
            // 右上角关闭按钮
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
            // 内容
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
                    // YES按钮
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
                    // NO按钮
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

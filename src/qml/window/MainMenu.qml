import QtQuick 2.15
import QtQuick.Controls 2.15
import QtMultimedia 6.5
import "../components"

Item {
    anchors.fill: parent
    // 以1280x720为基准，等比例缩放内容
    property real baseWidth: 1280
    property real baseHeight: 720
    property real scaleFactor: Math.min(width / baseWidth, height / baseHeight)
        // 背景图
        Image {
            anchors.fill: parent
            source: "qrc:/resource/image/bg/mainmenu.png"
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
                window.playMusic("qrc:/resource/audio/bgm/mainmenu.mp3");
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
            font.weight: Font.Weight.Bold
            color: "white"
            z: 10
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

                AppButton {
                    id: btnStart
                    text: "START"
                    width: 180; height: 60
                    fontPixelSize: 22
                    y: buttonRow.buttonsEntered ? 0 : 12
                    opacity: buttonRow.buttonsEntered ? 1 : 0
                    Behavior on y { NumberAnimation { duration: 360; easing.type: Easing.OutQuad } }
                    Behavior on opacity { NumberAnimation { duration: 360; easing.type: Easing.OutQuad } }
                    onClicked: {
                        // 开始新游戏：进入序章
                        console.log("MainMenu: Starting new game - entering prologue");
                        if (typeof transitionManager !== 'undefined') {
                            transitionManager.startLore("prologue");
                        } else {
                            // 备用方案：设置章节，节点留空让 LoreView 从 meta.startNode 读取
                            window.currentChapter = "prologue";
                            window.currentNode = "";
                            window.smoothReplaceSource("qml/window/Lore/LoreView.qml");
                        }
                    }
                    Component.onCompleted: { if (buttonRow.buttonsEntered) { /* already triggered */ } }
                }

                AppButton {
                    id: btnContinue
                    text: "CONTINUE"
                    width: 180; height: 60
                    fontPixelSize: 22
                    enabled: (typeof SaveLoadManager !== 'undefined' && SaveLoadManager) ? SaveLoadManager.autoExists : false
                    y: buttonRow.buttonsEntered ? 0 : 12
                    opacity: buttonRow.buttonsEntered ? 1 : 0
                    Behavior on y { SequentialAnimation { PauseAnimation { duration: 60 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 60 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    onClicked: {
                        if (enabled) window.pushSource("qml/window/Game/GameView.qml")
                    }
                }

                AppButton {
                    id: btnLoad
                    text: "LOAD"
                    width: 180; height: 60
                    fontPixelSize: 22
                    y: buttonRow.buttonsEntered ? 0 : 12
                    opacity: buttonRow.buttonsEntered ? 1 : 0
                    Behavior on y { SequentialAnimation { PauseAnimation { duration: 120 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 120 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    onClicked: window.pushSource("qml/window/SaveLoad.qml")
                }

                AppButton {
                    id: btnConfig
                    text: "CONFIG"
                    width: 180; height: 60
                    fontPixelSize: 22
                    y: buttonRow.buttonsEntered ? 0 : 12
                    opacity: buttonRow.buttonsEntered ? 1 : 0
                    Behavior on y { SequentialAnimation { PauseAnimation { duration: 180 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 180 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    onClicked: window.pushSource("qml/window/Config.qml")
                }

                AppButton {
                    id: btnExtra
                    text: "EXTRA"
                    width: 180; height: 60
                    fontPixelSize: 22
                    y: buttonRow.buttonsEntered ? 0 : 12
                    opacity: buttonRow.buttonsEntered ? 1 : 0
                    Behavior on y { SequentialAnimation { PauseAnimation { duration: 240 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 240 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    onClicked: window.pushSource("qml/window/Extra.qml")
                }

                AppButton {
                    id: btnExit
                    text: "EXIT"
                    width: 180; height: 60
                    fontPixelSize: 22
                    y: buttonRow.buttonsEntered ? 0 : 12
                    opacity: buttonRow.buttonsEntered ? 1 : 0
                    Behavior on y { SequentialAnimation { PauseAnimation { duration: 300 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 300 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    onClicked: confirmQuitDialog.visible = true
                }
            }
        }
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

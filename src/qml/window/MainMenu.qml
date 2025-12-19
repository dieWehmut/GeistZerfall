import QtQuick 2.15
import QtQuick.Controls 2.15
import QtMultimedia 6.5
import "../components"
import "windowState.js" as WindowState

Item {
    anchors.fill: parent
    // 以1280x720为基准，等比例缩放内容
    property real baseWidth: 1280
    property real baseHeight: 720
    property real scaleFactor: Math.min(width / baseWidth, height / baseHeight)
        // 背景图
        Image {
            anchors.fill: parent
            source: "qrc:/resource/image/bg/system/mainmenu.png"
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
                if (window && window.setFullscreen) window.setFullscreen(false);
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
                // 使用相对路径，不使用绝对路径或 qrc
                window.playMusic("resource/audio/bgm/mainmenu.mp3");
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
            Component.onCompleted: {
                try { mainTitle.font.pixelSize = 64; mainTitle.font.bold = true; } catch(e) {}
            }
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
            anchors.bottomMargin: 20

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
                        // 开始新游戏：进入序章，从头开始且清空历史与恢复点
                        console.log("MainMenu: Starting new game - entering prologue from beginning");
                        try { if (WindowState && WindowState.clearLoreState) WindowState.clearLoreState(); } catch (e) { }
                        try {
                            if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager) {
                                // 标记本次上下文为 lore 开始，避免后续 Continue 误判
                                SaveLoadManager.view = "lore";
                                SaveLoadManager.loreChapter = "prologue";
                                SaveLoadManager.loreNode = "";
                                SaveLoadManager.loreIndex = 0;
                            }
                        } catch (e2) { }
                        if (typeof transitionManager !== 'undefined') {
                            transitionManager.startLore("prologue");
                        } else {
                            // 备用方案：设置章节，节点留空让 LoreView 从 meta.startNode 读取
                            window.currentChapter = "prologue";
                            window.currentNode = "";
                            if (window && window.smoothReplaceSource) window.smoothReplaceSource("qml/window/Lore/LoreView.qml");
                            else if (window && window.replaceSource) window.replaceSource("qml/window/Lore/LoreView.qml");
                            else if (window && window.pushSource) window.pushSource("qml/window/Lore/LoreView.qml");
                        }
                    }
                    Component.onCompleted: { if (buttonRow.buttonsEntered) { /* already triggered */ } }
                }

                AppButton {
                    id: btnContinue
                    text: "CONTINUE"
                    width: 180; height: 60
                    fontPixelSize: 22
                    // 只要任意存档存在（自动或普通）即可用
                    enabled: (typeof SaveLoadManager !== 'undefined' && SaveLoadManager) ? SaveLoadManager.hasAnySave() : false
                    y: buttonRow.buttonsEntered ? 0 : 12
                    opacity: buttonRow.buttonsEntered ? 1 : 0
                    Behavior on y { SequentialAnimation { PauseAnimation { duration: 60 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 60 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
                    onClicked: {
                        if (!enabled) return;
                        // Continue: 加载自动存档，并根据存档来源视图跳转
                        try {
                            if (SaveLoadManager && SaveLoadManager.loadLatest && SaveLoadManager.loadLatest()) {
                                try { WindowState.setTargetMode && WindowState.setTargetMode("loadFromSave"); } catch (eTM) {}
                                var v = "";
                                try { v = (SaveLoadManager.view || "").toLowerCase(); } catch (eV) { v = ""; }
                                var battleId = "";
                                try { battleId = SaveLoadManager.battleId || ""; } catch (eB) { battleId = ""; }
                                if (typeof window !== 'undefined') {
                                    if (v === "lore") window.currentBattleId = "";
                                    else window.currentBattleId = battleId;
                                }
                                if (v === "lore") {
                                    // 根据存档记录的音乐状态优先切换背景音乐
                                    try {
                                        if (window) {
                                            var loreMusic = SaveLoadManager.loreMusic || "";
                                            var loreLoops = SaveLoadManager.loreMusicLoops;
                                            var loreStopped = !!SaveLoadManager.loreMusicStopped;
                                            if (loreStopped && typeof window.stopMusic === 'function') {
                                                window.stopMusic();
                                            } else if (loreMusic && typeof window.playMusic === 'function') {
                                                window.playMusic(loreMusic, (loreLoops !== undefined && loreLoops !== null) ? loreLoops : undefined);
                                            } else if (typeof window.playMusic === 'function') {
                                                window.playMusic("resource/audio/bgm/mainmenu.mp3");
                                            }
                                        }
                                    } catch (em) {}
                                    // 写入 Lore 进度，由 LoreView 进入后恢复
                                    try {
                                        WindowState.setLoreState({
                                            chapter: SaveLoadManager.loreChapter || "",
                                            node: SaveLoadManager.loreNode || "",
                                            index: SaveLoadManager.loreIndex || 0,
                                            mode: "scene",
                                            auto: false,
                                            music: SaveLoadManager.loreMusicStopped ? "" : (SaveLoadManager.loreMusic || ""),
                                            musicLoops: SaveLoadManager.loreMusicLoops,
                                            stopMusic: !!SaveLoadManager.loreMusicStopped
                                        });
                                    } catch (eLS) {}
                                    if (window && window.replaceSource) window.replaceSource("qml/window/Lore/LoreView.qml");
                                    else if (window && window.pushSource) window.pushSource("qml/window/Lore/LoreView.qml");
                                } else {
                                    // 默认回到 GameView，并切换游戏音乐（失败回退主菜单）
                                    try {
                                        if (window && typeof window.playMusic === 'function') window.playMusic("resource/audio/bgm/fight.mp3");
                                    } catch (em2) {
                                        try { if (window && typeof window.playMusic === 'function') window.playMusic("resource/audio/bgm/mainmenu.mp3"); } catch (ePM) {}
                                    }
                                    if (window && window.replaceSource) window.replaceSource("qml/window/Game/GameView.qml");
                                    else if (window && window.pushSource) window.pushSource("qml/window/Game/GameView.qml");
                                }
                            } else {
                                console.log('MainMenu: Continue loadLatest returned false');
                            }
                        } catch (eA) { console.log('MainMenu: Continue loadAuto failed', eA); }
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

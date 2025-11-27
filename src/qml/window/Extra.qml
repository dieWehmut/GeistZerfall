import QtQuick
import QtQuick.Controls
import QtMultimedia 6.5
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

            // 解锁百分比显示
            property int unlockedCount: 0
            property int totalCount: 6
            property int unlockedPercent: Math.round(unlockedCount / totalCount * 100)

            function updateUnlockedCount() {
                var count = 0;
                for (var i = 1; i <= totalCount; ++i) {
                    var bid = "battle" + (i < 10 ? ("0" + i) : i);
                    if (extraGridRoot.isUnlocked(bid)) count++;
                }
                unlockedCount = count;
            }

            Connections {
                target: SaveLoadManager
                function onSaved() { updateUnlockedCount(); }
                function onAutoExistsChanged() { updateUnlockedCount(); }
            }
            Component.onCompleted: Qt.callLater(function() { updateUnlockedCount(); });

            Text {
                id: percentText
                text: "Unlocked: " + contentRoot.unlockedPercent + "%"
                anchors.right: parent.right
                anchors.rightMargin: 32
                anchors.top: parent.top
                anchors.topMargin: 24
                font.pixelSize: 48 // 与左上角标题一致
                color: "white"
                font.bold: true
                style: Text.Outline
                styleColor: "black"
                z: 20
            }

        // 标题（与 Config.qml 一致）
        Text {
            text: "EXTRA"
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.top: parent.top
            anchors.topMargin: 24
            font.pixelSize: 48
            color: "white"
            font.bold: true
            z: 10
            style: Text.Outline
            styleColor: "black"
        }

        // 回想入口：2行 x 3列 的白色格子（编号 1-6）
        Item {
            id: extraGridRoot
            width: parent.width
            height: 360
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            z: 10
            
            // Helper: prefer C++ check to avoid QML XHR limitations
            function isUnlocked(bid) {
                try {
                    if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager && typeof SaveLoadManager.hasUnlockedBattle === 'function') {
                        try { return SaveLoadManager.hasUnlockedBattle(bid); } catch(e) { /* fall through */ }
                    }
                } catch (e) {}
                return false;
            }

            function refreshBoxes() {
                try {
                    if (!gridRoot) return;
                    var children = gridRoot.children;
                    for (var i = 0; i < children.length; ++i) {
                        var c = children[i];
                        if (c && c.battleId !== undefined) {
                            try { c.unlocked = isUnlocked(c.battleId); } catch (e) {}
                        }
                    }
                } catch (e) {}
            }

            Connections {
                target: SaveLoadManager
                function onSaved() { refreshBoxes(); }
                function onAutoExistsChanged() { refreshBoxes(); }
            }
            Component.onCompleted: {
                // initial evaluation
                Qt.callLater(function() { refreshBoxes(); });
            }
            // 悬浮与点击音效（绑定到主音量与效果音）
            SoundEffect {
                id: hoverSfx
                source: "qrc:/resource/audio/SoundEffect/buttonHover.wav"
                volume: 0.9 * (typeof window !== 'undefined' ? window.masterVolume * window.sysSfxVolume : 1.0)
            }
            SoundEffect {
                id: clickSfx
                source: "qrc:/resource/audio/SoundEffect/buttonClick.wav"
                volume: 1.0 * (typeof window !== 'undefined' ? window.masterVolume * window.sysSfxVolume : 1.0)
            }

            property int cols: 3
            property int rows: 2
            property real gap: 28
            // 增大格子尺寸，3列×2行在当前布局下仍然适配
            property real boxW: 320
            property real boxH: 160

            Grid {
                id: gridRoot
                anchors.centerIn: parent
                rows: extraGridRoot.rows
                columns: extraGridRoot.cols
                rowSpacing: extraGridRoot.gap
                columnSpacing: extraGridRoot.gap

                Repeater {
                    model: extraGridRoot.rows * extraGridRoot.cols
                    Rectangle {
                        id: boxRect
                        width: extraGridRoot.boxW
                        height: extraGridRoot.boxH
                        radius: 8
                        border.color: "#333"
                        border.width: 2
                        
                        property int number: index + 1
                        property string battleId: "battle" + (number < 10 ? ("0" + number) : number)
                        property bool hovered: false
                        property bool pressed: false
                        // Unlocked state computed from progress map
                        property bool unlocked: extraGridRoot.isUnlocked(battleId)
                        // 悬浮时放大更明显，按下时略微回缩更自然，仅在解锁时生效
                        property real currentScale: pressed ? 0.98 : (hovered && unlocked ? 1.08 : 1.0)

                        color: (hovered && unlocked || pressed) ? "#111" : "white"
                        opacity: unlocked ? 0.98 : 0.7

                        Behavior on color { ColorAnimation { duration: 160 } }
                        Behavior on currentScale { NumberAnimation { duration: 140; easing.type: Easing.InOutQuad } }

                        transform: Scale { xScale: boxRect.currentScale; yScale: boxRect.currentScale; origin.x: boxRect.width/2; origin.y: boxRect.height/2 }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: boxRect.unlocked
                            onEntered: { boxRect.hovered = true; if (boxRect.unlocked) try { hoverSfx.play(); } catch(e) {} }
                            onExited: { boxRect.hovered = false; boxRect.pressed = false }
                            onPressed: { if (boxRect.unlocked) boxRect.pressed = true }
                            onReleased: { if (boxRect.unlocked) boxRect.pressed = false }
                            onCanceled: { boxRect.pressed = false }
                            onClicked: {
                                if (!boxRect.unlocked) return;
                                try { clickSfx.play(); } catch (e) {}
                                try { SaveLoadManager.battleId = boxRect.battleId; } catch (e1) {}
                                try { window.currentBattleId = boxRect.battleId; } catch (e2) {}
                                try {
                                    if (window && window.replaceSource) window.replaceSource("qml/window/Game/GameView.qml");
                                    else if (window && window.pushSource) window.pushSource("qml/window/Game/GameView.qml");
                                } catch (en) { console.log('Extra: nav to GameView failed', en); }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            // 如果未解锁显示 No Data
                            text: boxRect.unlocked ? boxRect.number.toString() : "No Data"
                            // 减小未解锁时的字号以避免换行
                            font.pixelSize: boxRect.unlocked ? 56 : 28
                            color: (boxRect.hovered || boxRect.pressed) ? "white" : (boxRect.unlocked ? "#060606" : "#666666")
                            font.bold: true
                        }
                    }
                }
            }
        }

        // 底部按钮栏
        BottomButtonBar {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
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
                    if (window && window.setFullscreen) window.setFullscreen(false);
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

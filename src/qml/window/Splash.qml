import QtQuick
import QtQuick.Controls

Item {
    anchors.fill: parent

    property real baseWidth: 1280
    property real baseHeight: 720
    property real scaleFactor: Math.min(width / baseWidth, height / baseHeight)

    // 点击任意位置可以跳过并直接进入主菜单
    MouseArea {
        anchors.fill: parent
        onClicked: {
            stepSplash();
        }
    }

    // 3个阶段容器
    Rectangle {
        id: blackPage
        anchors.fill: parent
        color: "black"
        opacity: 1.0

        // WARNING 文本和说明（多行）
        Column {
            anchors.centerIn: parent
            width: parent.width * 0.8
            spacing: 20

            Text {
                id: blackWarning
                text: "WARNING"
                font.pixelSize: 48
                color: "white"
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
                style: Text.Outline
                styleColor: "black"
            }

            Text {
                id: warnBody
            text: "本游戏包含恐怖/惊悚内容，可能引起不适。\n\n" +
                "包括惊吓镜头、紧张氛围、强烈音效或闪烁画面，\n" +
                "但不限于此类要素。\n\n" +
                "未满18周岁的用户禁止游玩。\n\n" +
                "以下情况的玩家请谨慎游玩：有心脏病、癫痫（含光敏性癫痫）、严重焦虑或其他精神/神经疾病者，\n" +
                "以及孕妇或对类似内容易受影响的玩家。\n\n" +
                "若在游玩过程中出现头晕、心悸、视力模糊、焦虑等不适，请立即停止并寻求医疗或照护者协助。"
                wrapMode: Text.WordWrap
                font.pixelSize: 22
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    Rectangle {
        id: midBlackPage
        anchors.fill: parent
        color: "black"
        opacity: 0.0

        // 中间黑色说明页（纯属虚构等说明）
        Column {
            anchors.centerIn: parent
            width: parent.width * 0.8
            spacing: 16

            Text {
                id: midTitle
                text: "本游戏纯属虚构"
                font.pixelSize: 36
                color: "white"
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "游戏中的人物、地点、事件均为虚构，如有雷同，纯属巧合。"
                wrapMode: Text.WordWrap
                font.pixelSize: 20
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    Rectangle {
        id: whitePage
        anchors.fill: parent
        color: "white"
        opacity: 0.0

        // white page title entrance controller
        property bool whiteTitleEntered: false

        Text {
            id: whiteTitle
            text: "GeistZerfall"
            anchors.centerIn: parent
            font.pixelSize: 56
            color: "black"
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            opacity: 0
        }

        SequentialAnimation {
            id: whiteTitleFlash
            running: false
            PropertyAnimation { target: whiteTitle; property: "opacity"; to: 1.0; duration: 120 }
            PropertyAnimation { target: whiteTitle; property: "opacity"; to: 0.4; duration: 120 }
            PropertyAnimation { target: whiteTitle; property: "opacity"; to: 1.0; duration: 120 }
        }

        onWhiteTitleEnteredChanged: {
            if (whiteTitleEntered) whiteTitleFlash.start();
        }
    }

    // 使用 Timer 控制三个阶段：black 7s -> fade -> mid 5s -> fade -> white 3s -> finish
    Timer { id: blackTimer; interval: 7000; repeat: false; running: true; onTriggered: startFadeToMid() }

    // Slow growth animation for the first page title (WARNING)
    NumberAnimation {
        id: blackWarnGrowAnim
        target: blackWarning
        property: "font.pixelSize"
        from: 48; to: 56
        duration: blackTimer.interval
        running: blackPage.visible && blackPage.opacity > 0.5
        loops: 1
    }

    // Slow growth animation for the middle page title
    NumberAnimation {
        id: midTitleGrowAnim
        target: midTitle
        property: "font.pixelSize"
        from: 36; to: 44
        duration: midTimer.interval
        running: midBlackPage.visible && midBlackPage.opacity > 0.5
        loops: 1
    }

    // fade 动画：black -> mid
    ParallelAnimation {
        id: fadeToMidAnim
        running: false
        PropertyAnimation { target: blackPage; property: "opacity"; to: 0.0; duration: 600 }
        PropertyAnimation { target: midBlackPage; property: "opacity"; to: 1.0; duration: 600 }
        onStopped: {
            // 确保最终状态被强制设置，避免动画被中断导致两页同时可见
            blackPage.opacity = 0
            midBlackPage.opacity = 1
            // 隐藏第一页以避免点击穿透或视觉重叠
            blackPage.visible = false
            // 启动中间页面计时器
            midTimer.running = true
            // ensure mid title growth starts and finalize first title
            blackWarnGrowAnim.running = false; blackWarning.font.pixelSize = 56;
            midTitleGrowAnim.restart();
        }
    }

    // fade 动画：mid -> white
    ParallelAnimation {
        id: fadeToWhiteAnim
        running: false
        PropertyAnimation { target: midBlackPage; property: "opacity"; to: 0.0; duration: 600 }
        PropertyAnimation { target: whitePage; property: "opacity"; to: 1.0; duration: 600 }
        onStopped: {
            // 启动白页计时器
            whiteTimer.running = true
            // trigger white page title entrance
            whitePage.whiteTitleEntered = true
            // 确保中间页面不可见以避免重叠
            midBlackPage.opacity = 0
            midBlackPage.visible = false
            // finalize middle title size
            midTitleGrowAnim.running = false; midTitle.font.pixelSize = 44;
        }
    }

    Timer { id: midTimer; interval: 5000; repeat: false; running: false; onTriggered: startFadeToWhite() }

    Timer { id: whiteTimer; interval: 3000; repeat: false; running: false; onTriggered: finishSplash() }

    function startFadeToMid() {
        // make sure both pages visible during the animation
        blackPage.visible = true
        midBlackPage.visible = true
        // restart the first title growth in case user returned here quickly
        blackWarnGrowAnim.restart();
        fadeToMidAnim.start();
    }

    function startFadeToWhite() {
        fadeToWhiteAnim.start();
    }

    // Progress splash by one stage on each click: black -> white -> finish
    function stepSplash() {
        try {
            // if black is still visible (opacity > 0.5), start fading to mid
            if (blackPage.opacity > 0.5 && fadeToMidAnim.running === false) {
                // stop the blackTimer so automatic transition won't duplicate
                blackTimer.stop();
                startFadeToMid();
                return;
            }
                // if first fade is in progress, stop it and goto mid timer / show mid immediately
                if (fadeToMidAnim.running) {
                    // interrupt: force final mid state so the first page does not remain visible
                    fadeToMidAnim.stop();
                    // finalize first-page title animation and start middle title growth
                    blackWarnGrowAnim.running = false; blackWarning.font.pixelSize = 56;
                    midTitleGrowAnim.restart();
                    blackPage.opacity = 0; blackPage.visible = false;
                    midBlackPage.opacity = 1; midBlackPage.visible = true;
                    midTimer.running = true;
                    return;
                }
                // if we are now on the middle black page, start fading to white
                if (midBlackPage.opacity > 0.5 && fadeToWhiteAnim.running === false) {
                    midTimer.stop();
                    startFadeToWhite();
                    return;
                }

                // if second fade is in progress, stop it and jump to finish
                if (fadeToWhiteAnim.running) {
                    // interrupt white fade: ensure white page is shown and mid page hidden
                    fadeToWhiteAnim.stop();
                    // finalize middle title animation before leaving
                    midTitleGrowAnim.running = false; midTitle.font.pixelSize = 44;
                    whitePage.opacity = 1; whitePage.whiteTitleEntered = true;
                    midBlackPage.opacity = 0; midBlackPage.visible = false;
                    finishSplash();
                    return;
                }

                // otherwise we are on white page (or nearly), finish splash
            finishSplash();
        } catch (e) { console.log('stepSplash error', e); }
    }

    function skipAll() {
        // 停止所有动画与计时器，然后平滑跳转到主菜单
        fadeToMidAnim.stop();
        fadeToWhiteAnim.stop();
        midTimer.stop();
        whiteTimer.stop();
        blackTimer.stop();
        try {
            if (window && window.smoothReplaceSource) window.smoothReplaceSource("qml/window/MainMenu.qml", 600);
            else if (window && window.replaceSource) window.replaceSource("qml/window/MainMenu.qml");
        } catch (e) { console.log("skipAll error", e); }
    }

    function finishSplash() {
        try {
            if (window && window.smoothReplaceSource) window.smoothReplaceSource("qml/window/MainMenu.qml", 600);
            else if (window && window.replaceSource) window.replaceSource("qml/window/MainMenu.qml");
        } catch (e) { console.log("finishSplash error", e); }
    }
}

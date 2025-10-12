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

    // 两个阶段容器：blackPage -> whitePage
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

    // 使用 Timer 控制两个阶段：black 7s -> fade -> white 3s -> finish
    Timer { id: blackTimer; interval: 7000; repeat: false; running: true; onTriggered: startFadeToWhite() }

    // fade 动画单独控制
    ParallelAnimation {
        id: fadeAnim
        running: false
        PropertyAnimation { target: blackPage; property: "opacity"; to: 0.0; duration: 600 }
        PropertyAnimation { target: whitePage; property: "opacity"; to: 1.0; duration: 600 }
        onStopped: {
            // 启动白页计时器
            whiteTimer.running = true
            // trigger white page title entrance
            whitePage.whiteTitleEntered = true
        }
    }

    Timer { id: whiteTimer; interval: 3000; repeat: false; running: false; onTriggered: finishSplash() }

    function startFadeToWhite() {
        fadeAnim.start();
    }

    // Progress splash by one stage on each click: black -> white -> finish
    function stepSplash() {
        try {
            // if black is still visible (opacity > 0.5), start fading to white
            if (blackPage.opacity > 0.5 && fadeAnim.running === false) {
                // stop the blackTimer so automatic transition won't duplicate
                blackTimer.stop();
                startFadeToWhite();
                return;
            }
            // if fade is in progress, wait for it to stop then finish
            if (fadeAnim.running) {
                // ensure white timer is stopped and finish immediately
                fadeAnim.stop();
                whitePage.whiteTitleEntered = true
                finishSplash();
                return;
            }
            // otherwise we are on white page (or nearly), finish splash
            finishSplash();
        } catch (e) { console.log('stepSplash error', e); }
    }

    function skipAll() {
        // 停止所有动画与计时器，然后平滑跳转到主菜单
        fadeAnim.stop();
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

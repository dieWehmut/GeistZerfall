import QtQuick
import QtMultimedia 6.5

Window {
    id: window
    width: 1280
    height: 720
    visible: true
    title: qsTr("GeistZerfall")
    // 全局背景音乐播放器（集中管理）
    MediaPlayer {
        id: bgmGlobal
        // 默认不设置 source，页面通过 window.playMusic(...) 切换
        autoPlay: false
        // loops 可以由调用方覆盖；默认情况下无限循环
        loops: MediaPlayer.Infinite
        audioOutput: bgmOutput
    }

    AudioOutput {
        id: bgmOutput
    }

    // 当前正在播放的音乐 source（用于避免重复切换）
    property string currentMusic: ""

    // 切换音乐：如果 source 与当前相同且正在播放则不重复操作
    // 参数：source (string), loops (MediaPlayer.Loops 或数字，可选)
    function playMusic(source, loops) {
        if (!source) return;
        try {
            // 如果是相同音乐，且正在播放则什么都不做；
            // 如果是相同音乐但处于暂停/停止状态，则直接恢复播放（不重新设置 source）以保留进度。
            if (window.currentMusic === source) {
                if (bgmGlobal.playbackState === MediaPlayer.Playing) {
                    // 相同音乐且正在播放，无需切换
                    return;
                } else {
                    // 相同音乐但未播放，尝试恢复
                    bgmGlobal.play();
                    return;
                }
            }

            // 不同音乐：停掉当前（如果有）并切换到新 source
            bgmGlobal.stop();
            bgmGlobal.source = source;
            if (typeof loops !== 'undefined') bgmGlobal.loops = loops;
            else bgmGlobal.loops = MediaPlayer.Infinite;
            bgmGlobal.play();
            window.currentMusic = source;
        } catch (e) {
            console.log("playMusic error:", e);
        }
    }

    function stopMusic() {
        try {
            bgmGlobal.stop();
            window.currentMusic = "";
        } catch (e) {
            console.log("stopMusic error:", e);
        }
    }

    Loader {
        id: mainLoader
        anchors.fill: parent
        source: "qml/window/Splash.qml"
        property alias mainLoader: mainLoader
    }

    // 屏幕切换覆盖层（用于平滑过渡）
    Rectangle {
        id: transitionOverlay
        anchors.fill: parent
        color: "black"
        opacity: 0
        z: 9999
        visible: true
    }

    property string pendingTransitionSource: ""
    property int transitionDuration: 800

    SequentialAnimation {
        id: transitionAnim
        running: false
        // 先淡入 overlay
        PropertyAnimation { target: transitionOverlay; property: "opacity"; to: 1; duration: transitionDuration }
        // 切换页面
        ScriptAction { script: { if (pendingTransitionSource) { mainLoader.source = pendingTransitionSource; pendingTransitionSource = ""; } } }
        // 可短暂停留以确保页面加载
        PauseAnimation { duration: 80 }
        // 再淡出 overlay
        PropertyAnimation { target: transitionOverlay; property: "opacity"; to: 0; duration: transitionDuration }
    }

    function smoothReplaceSource(newSource, duration) {
        try {
            pendingTransitionSource = newSource;
            if (typeof duration !== 'undefined') transitionDuration = duration;
            transitionAnim.start();
        } catch (e) { console.log("smoothReplaceSource error", e); }
    }

    property var pageHistory: []
    function pushSource(newSource) {
        if (mainLoader.source) {
            pageHistory.push(mainLoader.source);
        }
        mainLoader.source = newSource;
    }
    function replaceSource(newSource) {
        mainLoader.source = newSource;
    }
    function goBack() {
        if (pageHistory.length > 0) {
            var last = pageHistory.pop();
            mainLoader.source = last;
        } else {
            // 没有历史时可选择返回主菜单或不做处理，这里回退到主菜单
            mainLoader.source = "qml/window/MainMenu.qml";
        }
    }
    function gotoConfig() {
        pushSource("qml/window/Config.qml");
    }

    // 监听 Transition 信号
    Connections {
        target: typeof transitionManager !== 'undefined' ? transitionManager : null
        
        function onSwitchToGameView(battleId) {
            console.log("Main: switching to GameView with battle", battleId);
            // 保存战斗 ID 供 GameView 使用
            window.currentBattleId = battleId;
            smoothReplaceSource("qml/window/GameView.qml");
        }
        
        function onSwitchToLoreView(chapterId, nodeId) {
            console.log("Main: switching to LoreView", chapterId, nodeId);
            window.currentChapter = chapterId;
            window.currentNode = nodeId;
            smoothReplaceSource("qml/window/Lore/LoreView.qml");
        }
    }

    // 存储当前战斗/章节信息
    property string currentBattleId: ""
    property string currentChapter: ""
    property string currentNode: ""
}

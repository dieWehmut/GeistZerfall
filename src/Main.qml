import QtQuick
import "qml/components"
import "qml/window/windowState.js" as WindowState
import QtMultimedia 6.5

Window {
    id: window
    width: 1280
    height: 720
    visible: true
    title: qsTr("GeistZerfall")
    // 防止重复关闭的标志
    property bool shuttingDown: false
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
        // 全局音量控制（0.0 - 1.0）
        // masterVolume 与 bgmVolume 来自窗口属性，计算最终输出
        volume: masterVolume * bgmVolume
    }

    // 全局音量属性（0.0 - 1.0）
    property real masterVolume: 1.0
    property real bgmVolume: 1.0
    property real sfxVolume: 1.0

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

    // 关闭窗口前先自动存档
    function autosaveBeforeExit() {
        try {
            if (typeof SaveLoadManager === 'undefined' || !SaveLoadManager) return;
            // 尝试截图作为预览
            try { SaveLoadManager.captureTemp(); } catch (eCap) {}

            // mainLoader.source 是 url 类型，将其转为字符串再判断
            var src = mainLoader.source ? mainLoader.source.toString() : "";
            console.log("autosaveBeforeExit: current source =", src);

            if (src.indexOf("Game/GameView.qml") !== -1) {
                // 保存游戏场景进度
                try {
                    SaveLoadManager.view = "game";
                    SaveLoadManager.loreChapter = "";
                    SaveLoadManager.loreNode = "";
                    SaveLoadManager.loreIndex = 0;
                    SaveLoadManager.loreMusic = "";
                    SaveLoadManager.loreMusicLoops = -1;
                    SaveLoadManager.loreMusicStopped = false;
                    SaveLoadManager.battleId = window.currentBattleId || "";
                    if (window.currentPlayer) {
                        SaveLoadManager.posX = window.currentPlayer.pos.x;
                        SaveLoadManager.posY = window.currentPlayer.pos.y;
                        SaveLoadManager.speed = window.currentPlayer.getSpeed ? window.currentPlayer.getSpeed() : 0;
                        SaveLoadManager.sight = window.currentPlayer.getSight ? window.currentPlayer.getSight() : 0;
                        SaveLoadManager.maxHp = (typeof window.currentPlayer.maxHp !== 'undefined') ? window.currentPlayer.maxHp : SaveLoadManager.maxHp;
                        SaveLoadManager.hp = (typeof window.currentPlayer.hp !== 'undefined') ? window.currentPlayer.hp : SaveLoadManager.hp;
                    }
                    // 敌人快照（若 WindowState 有）
                    try {
                        var enemies = (typeof WindowState !== 'undefined' && WindowState.getGameEnemies) ? WindowState.getGameEnemies() : undefined;
                        if (enemies && enemies.length) SaveLoadManager.setEnemies(enemies); else SaveLoadManager.setEnemies([]);
                    } catch (eSetEn) {}
                    SaveLoadManager.saveAuto();
                    console.log("autosaveBeforeExit: game auto save done");
                } catch (eGameSave) { console.log('autosave (game) failed', eGameSave); }
            } else if (src.indexOf("Lore/LoreView.qml") !== -1) {
                // 保存剧情进度（从 WindowState 获取最近一次持久化状态）
                try {
                    var st = (typeof WindowState !== 'undefined' && WindowState.getLoreState) ? WindowState.getLoreState() : null;
                    SaveLoadManager.view = "lore";
                    SaveLoadManager.loreChapter = (st && st.chapter) ? st.chapter : (window.currentChapter || "");
                    SaveLoadManager.loreNode = (st && st.node) ? st.node : (window.currentNode || "");
                    SaveLoadManager.loreIndex = (st && st.index !== undefined) ? st.index : 0;
                    SaveLoadManager.battleId = "";
                    // 音乐状态（若有则保存）
                    try {
                        var mus = st ? (st.music || "") : "";
                        var loops = st ? (st.musicLoops) : -1;
                        var stopped = st ? (!!st.stopMusic) : false;
                        SaveLoadManager.loreMusic = stopped ? "" : mus;
                        SaveLoadManager.loreMusicLoops = (loops !== undefined && loops !== null) ? loops : -1;
                        SaveLoadManager.loreMusicStopped = !!stopped;
                    } catch (eMus) {}
                    // 清空敌人
                    try { SaveLoadManager.setEnemies([]); } catch (eSetEn2) {}
                    SaveLoadManager.saveAuto();
                    console.log("autosaveBeforeExit: lore auto save done");
                } catch (eLoreSave) { console.log('autosave (lore) failed', eLoreSave); }
            } else {
                // 其它页面：不自动存档
                console.log("autosaveBeforeExit: skip autosave for non-Game/Lore page");
            }
        } catch (e) { console.log('autosaveBeforeExit error', e); }
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
            smoothReplaceSource("qml/window/Game/GameView.qml");
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

    // 拦截窗口关闭：先自动存档，再确认是否退出
    onClosing: function(close) {
        if (shuttingDown) {
            return; // 允许真正关闭
        }
        close.accepted = false; // 阻止立即关闭
        autosaveBeforeExit();
        confirmExitDialog.visible = true;
    }

    // 退出确认弹窗
    ConfirmDialog {
        id: confirmExitDialog
        anchors.centerIn: parent
        title: "退出游戏"
        // 可根据需要加上 message 属性（如果组件支持）
        onYes: function() {
            shuttingDown = true;
            Qt.quit();
        }
        onNo: function() {
            confirmExitDialog.visible = false;
        }
    }
}

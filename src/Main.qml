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
        onPlaybackStateChanged: {
            console.log("bgmGlobal: playbackState ->", bgmGlobal.playbackState);
        }
        onErrorChanged: {
            try { console.log("bgmGlobal: error ->", bgmGlobal.error, bgmGlobal.errorString); } catch(e) { console.log("bgmGlobal: error (unknown)"); }
        }
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
    // 系统效果音量（用于 UI 按钮等系统音效）
    property real sysSfxVolume: 1.0
    // Persisted UI settings exposed on window for other components
    property real __autoModeWait: 3
    // __textSpeed now represents per-character display time (seconds)
    // default moved to 0.008 (8ms per char) to fall within the new 0.001 - 0.015 range
    property real __textSpeed: 0.008
    // text box background opacity (0.0 - 1.0)
    property real __textBoxOpacity: 1.0
    // expose text skip behaviour (values: 'read' or 'all') so components may read/write safely
    property string __textSkip: "read"
    property string __aspectRatio: "16:9"

    Component.onCompleted: {
        // Load and apply persisted system settings at application startup so
        // these global settings take effect without opening Config.qml.
        try {
            if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager) {
                var settings = SaveLoadManager.loadSystem();
                if (settings) {
                    if (settings.masterVolume !== undefined) window.masterVolume = Number(settings.masterVolume);
                    if (settings.bgmVolume !== undefined) window.bgmVolume = Number(settings.bgmVolume);
                    if (settings.sfxVolume !== undefined) window.sfxVolume = Number(settings.sfxVolume);
                    // apply fullscreen if requested; if settings missing, default to fullscreen
                    if (!settings || settings.fullscreen === undefined) {
                        // no saved settings => default to fullscreen on fresh start
                        try { window.setFullscreen && window.setFullscreen(true); } catch(e) { console.log('default fullscreen failed', e); }
                    } else if (settings.fullscreen !== undefined) {
                        try {
                            // use centralized setter so we persist the value as well
                            window.setFullscreen && window.setFullscreen(!!settings.fullscreen);
                        } catch(e) { console.log('apply fullscreen failed', e); }
                    }
                    // text speed / auto mode wait are UI concerns, but store on window so other components can read
                    if (settings.textSpeed !== undefined) window.__textSpeed = settings.textSpeed;
                    if (settings.textBoxOpacity !== undefined) window.__textBoxOpacity = Number(settings.textBoxOpacity);
                    if (settings.autoModeWait !== undefined) window.__autoModeWait = settings.autoModeWait; else window.__autoModeWait = 3; // default 3s
                    if (settings.aspectRatio !== undefined) window.__aspectRatio = settings.aspectRatio; else window.__aspectRatio = '16:9';
                    // Apply aspect ratio on startup when not fullscreen so window size matches stored preference
                    try { if (window.visibility !== Window.FullScreen && window.__aspectRatio) window.applyAspectRatio(window.__aspectRatio); } catch(e) {}
                    // ensure content base matches stored aspect and update viewport sizing
                    try {
                        if (window.__aspectRatio === '4:3') window.contentBaseH = 960; else window.contentBaseH = 720;
                        updateViewport();
                    } catch(e) {}
                    // textSkip: expose as a simple flag on window for other modules
                    if (settings.textSkip !== undefined) window.__textSkip = settings.textSkip;
                }
            }
        } catch(e) { console.log('Main: loadSystem at startup failed', e); }
    }

    // 当前正在播放的音乐 source（用于避免重复切换）
    property string currentMusic: ""

    // 切换音乐：如果 source 与当前相同且正在播放则不重复操作
    // 参数：source (string)，应传相对路径（如 "resource/audio/bgm/mainmenu.mp3"）；
    // 不使用 qrc，不在代码里写死绝对路径，统一基于可执行所在目录构造 file:/// URL 播放。
    function playMusic(source, loops) {
        if (!source) return;
        try {
            // 规范化为相对路径，基于 Main.qml 所在目录（src/）
            function normalizeBgmSource(s) {
                try {
                    var str = (s || "").toString();
                    // 统一分隔符
                    str = str.replace(/\\/g, "/");
                    // qrc 到普通相对路径（去掉 schema，并截到 resource/ 开始）
                    if (str.indexOf("qrc:/") === 0) {
                        var qi = str.indexOf("/resource/");
                        str = (qi >= 0) ? str.substring(qi + 1) : str.replace("qrc:/", "");
                    }
                    // file:// 绝对路径：截到 resource/ 开始
                    if (str.indexOf("file:/") === 0) {
                        var fi = str.indexOf("/resource/");
                        if (fi >= 0) str = str.substring(fi + 1);
                    }
                    // 含有 resource/audio/bgm/ 的，保留自 resource/ 起
                    var ri = str.indexOf("resource/audio/bgm/");
                    if (ri > 0) str = str.substring(ri);
                    // 去掉前置的 ../
                    while (str.indexOf("../") === 0) str = str.substring(3);
                    // 允许传 audio/bgm/ 开头
                    if (str.indexOf("audio/bgm/") === 0) str = "resource/" + str;
                    // 仅传文件名时补全前缀
                    if (str.indexOf('/') === -1) str = "resource/audio/bgm/" + str;
                    return str;
                } catch (eN) { return s; }
            }

            var norm = normalizeBgmSource(source);
            console.log("playMusic requested:", source, "=>", norm, "loops:", loops);

            // 如果是相同音乐，且正在播放则什么都不做；
            // 如果是相同音乐但处于暂停/停止状态，则直接恢复播放（不重新设置 source）以保留进度。
            if (window.currentMusic === norm) {
                if (bgmGlobal.playbackState === MediaPlayer.Playing) {
                    return;
                } else {
                    bgmGlobal.play();
                    return;
                }
            }

            // 不同音乐：停掉当前（如果有）并切换到新 source
            bgmGlobal.stop();

            // 基于可执行路径推导目录，避免 qrc 与相对 URL 歧义
            var baseDir = "";
            try {
                if (Qt.application && Qt.application.arguments && Qt.application.arguments.length > 0) {
                    var exe = (Qt.application.arguments[0] || "").toString().replace(/\\/g, "/");
                    var p = exe.lastIndexOf("/");
                    if (p > 0) baseDir = exe.substring(0, p);
                }
            } catch (eDir) {}
            if (!baseDir || baseDir.length === 0) baseDir = "."; // 回退到当前工作目录

            var fsPath = baseDir + "/" + norm;
            fsPath = fsPath.replace(/\\/g, "/");
            // 去掉前置 "./"
            if (fsPath.indexOf("./") === 0)
                fsPath = fsPath.substring(2);

            // 显式构造 file:/// 绝对 URL，彻底避免被当作 qrc 解析
            var url;
            if (fsPath.match(/^[a-zA-Z]:\//)) {
                url = "file:///" + fsPath; // Windows 盘符
            } else if (fsPath.indexOf("/") === 0) {
                url = "file://" + fsPath;  // 已是绝对类 Unix 路径
            } else {
                url = "file:///" + fsPath; // 其它情况按相对当前目录处理
            }
            bgmGlobal.source = url;
            console.log("bgmGlobal.source set to:", bgmGlobal.source);
            if (typeof loops !== 'undefined') bgmGlobal.loops = loops; else bgmGlobal.loops = MediaPlayer.Infinite;
            bgmGlobal.play();
            window.currentMusic = norm;
            console.log("playMusic: window.currentMusic set to", window.currentMusic);
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

    // Unified fullscreen toggler which also persists the value to system.dat
    // Use this instead of calling showFullScreen/showNormal directly so we always
    // keep SaveLoad::system.dat in sync with the window state.
    function setFullscreen(enabled) {
        try {
            if (enabled) {
                window.showFullScreen && window.showFullScreen();
            } else {
                window.showNormal && window.showNormal();
            }

            // persist only the fullscreen flag while preserving other keys
            if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager) {
                var s = SaveLoadManager.loadSystem() || {};
                s.fullscreen = !!enabled;
                SaveLoadManager.saveSystem(s);
            }
            // schedule a viewport update on next tick so layout applies after platform window state changes
            try { Qt.callLater(updateViewport); } catch(e) {}
        } catch (e) { console.log('setFullscreen failed', e); }
    }

    // When visibility changes (e.g., entering/exiting full screen), refresh viewport
    onVisibilityChanged: {
        try {
            // layout may need to recalc after native window state changes
            Qt.callLater(updateViewport);
        } catch(e) { console.log('visibility change updateViewport failed', e); }
    }

    // Apply aspect ratio preference (e.g. '16:9' or '4:3')
    function applyAspectRatio(aspect) {
        try {
            window.__aspectRatio = aspect;
            // persist immediately so it's available next start
            if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager) {
                var s = SaveLoadManager.loadSystem() || {};
                s.aspectRatio = aspect;
                SaveLoadManager.saveSystem(s);
            }

            // update content base so chosen aspect applies (letterbox in fullscreen)
            try {
                if (aspect === '4:3') window.contentBaseH = 960; else window.contentBaseH = 720;
            } catch(e) {}

            // If we're in windowed mode (not FullScreen) also resize the whole application window
            try {
                if (window.visibility !== Window.FullScreen) {
                    // Use the contentBase values as the new window size so entire window matches chosen aspect
                    window.width = window.contentBaseW;
                    window.height = window.contentBaseH;
                }
            } catch(e) {}

            try { updateViewport(); } catch(e) {}
        } catch (e) { console.log('applyAspectRatio failed', e); }
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

    // Content viewport: center-aligned loader whose size follows chosen aspect ratio
    property int contentBaseW: 1280
    // derive contentBaseH from the chosen aspect ratio so QML change handler naming won't break
    property int contentBaseH: (window.__aspectRatio === '4:3' ? 960 : 720)
    function updateViewport() {
        try {
            var baseW = window.contentBaseW;
            var baseH = window.contentBaseH;
            // compute scale to fit within actual window size
            var scale = Math.min(window.width / baseW, window.height / baseH);
            // apply pixel-rounded sizes to loader
            mainLoader.width = Math.round(baseW * scale);
            mainLoader.height = Math.round(baseH * scale);
            mainLoader.x = Math.round((window.width - mainLoader.width) / 2);
            mainLoader.y = Math.round((window.height - mainLoader.height) / 2);
        } catch(e) { console.log('updateViewport failed', e); }
    }

    // When contentBaseH changes (due to aspect change), update viewport
    onContentBaseHChanged: updateViewport

    onWidthChanged: updateViewport
    onHeightChanged: updateViewport

    Loader {
        id: mainLoader
        // initially sized by updateViewport in Component.onCompleted
        source: "qml/window/Splash.qml"
        property alias mainLoader: mainLoader
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
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

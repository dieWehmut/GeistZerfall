import QtQuick
import "../../components"
import "../windowState.js" as WindowState

// LoreView.qml - 剧情视图主场景
Item {
    id: root
    anchors.fill: parent

    property string currentChapter: ""
    property string currentNode: ""
    property var chapterData: null
    property int currentContentIndex: 0
    // 支持两种显示模式："circle"(默认) 或 "scene"(背景+立绘+下方文字框)
    property string currentMode: "circle"
    // 自动模式开关：开启后每段对白自动播放
    property bool autoModeEnabled: false
    // 当前内容是否是章节标题画面（用于隐藏底部控制栏）
    property bool isTitleScreen: false
    // 标记是否需要在初始化内容后恢复音乐
    property bool restoreMusicPending: false
    // 最近一次有效的音乐状态，用于持久化和存档
    property string lastMusicSource: ""
    property int lastMusicLoops: -1
    property bool lastMusicStopped: false
    // 从外部存档恢复时传入的音乐状态
    property string savedMusicSource: ""
    property int savedMusicLoops: -1
    property bool savedMusicStopped: false

    Component.onCompleted: {
        // 优先从 WindowState 恢复进度
        try {
            // 检测是否是从存档加载过来的特殊模式（loadFromSave）。如果是，优先使用 WindowState.loreState 并尝试恢复音乐。
            var targetMode = (typeof WindowState !== 'undefined' && WindowState.takeTargetMode) ? WindowState.takeTargetMode() : undefined;
            var saved = (typeof WindowState !== 'undefined' && WindowState.getLoreState) ? WindowState.getLoreState() : null;
            if (saved && saved.chapter) {
                currentChapter = saved.chapter;
                currentNode = saved.node || "";
                currentContentIndex = (saved.index !== undefined) ? saved.index : 0;
                currentMode = saved.mode || currentMode;
                autoModeEnabled = !!saved.auto;
                savedMusicSource = (saved.music !== undefined && saved.music !== null) ? saved.music : "";
                savedMusicLoops = (saved.musicLoops !== undefined && saved.musicLoops !== null) ? saved.musicLoops : -1;
                savedMusicStopped = !!saved.stopMusic;
                if (savedMusicSource) {
                    lastMusicSource = savedMusicSource;
                    lastMusicLoops = savedMusicLoops;
                    lastMusicStopped = false;
                } else if (savedMusicStopped) {
                    lastMusicSource = "";
                    lastMusicLoops = 0;
                    lastMusicStopped = true;
                } else {
                    lastMusicSource = window && window.currentMusic ? window.currentMusic : "";
                    lastMusicLoops = -1;
                    lastMusicStopped = (lastMusicSource === "");
                }
                if (targetMode === 'loadFromSave') {
                    var applied = applySavedMusicState();
                    restoreMusicPending = !applied;
                } else {
                    restoreMusicPending = false;
                }
            } else if (targetMode === 'loadFromSave') {
                // 没有保存的 loreState 但从存档标记进入：可能是游戏存档，直接跳 GameView
                try { if (window && window.replaceSource) window.replaceSource("qml/window/Game/GameView.qml"); else if (window && window.pushSource) window.pushSource("qml/window/Game/GameView.qml"); } catch (eNav) {}
                return; // 结束后续初始化，避免错误章节加载
            } else if (typeof window !== 'undefined') {
                if (window.currentChapter) currentChapter = window.currentChapter;
                if (window.currentNode) currentNode = window.currentNode;
            }
        } catch (e) { console.log("LoreView: restore state error", e); }

        if (!currentChapter) currentChapter = "prologue"; // 默认章节

        console.log("LoreView: starting chapter", currentChapter, "node", currentNode);

        // 初始化时遮罩不透明，加载后淡入
        transitionOverlay.opacity = 1;

        // 加载章节数据
        loadChapter(currentChapter);
    }

    Component.onDestruction: {
        if (typeof window !== 'undefined' && window.shuttingDown) {
            return; // 应用退出时跳过存档，避免与 Main 的关前存档重复且可能的竞态
        }
        persistLoreState();
        saveLoreAutoSnapshot();
    }

    onVisibleChanged: {
        if (!visible) {
            if (typeof window !== 'undefined' && window.shuttingDown) {
                return; // 退出流程中不进行自动存档
            }
            persistLoreState();
            saveLoreAutoSnapshot();
        }
    }

    function saveLoreAutoSnapshot() {
        try {
            if (typeof SaveLoadManager === 'undefined' || !SaveLoadManager) return;
            try { SaveLoadManager.captureTemp(); } catch (eCap) { console.log('LoreView: captureTemp for auto failed', eCap); }
            SaveLoadManager.view = "lore";
            SaveLoadManager.loreChapter = currentChapter || "";
            SaveLoadManager.loreNode = currentNode || "";
            SaveLoadManager.loreIndex = currentContentIndex || 0;
            SaveLoadManager.battleId = "";
            SaveLoadManager.loreMusicStopped = lastMusicStopped;
            SaveLoadManager.loreMusic = lastMusicStopped ? "" : (lastMusicSource || "");
            SaveLoadManager.loreMusicLoops = lastMusicLoops;
            // 清空游戏特定数据，避免残留影响
            try { SaveLoadManager.setEnemies([]); } catch (eSetEn) { }
            SaveLoadManager.posX = 0;
            SaveLoadManager.posY = 0;
            SaveLoadManager.speed = 0;
            SaveLoadManager.sight = 0;
            SaveLoadManager.hp = 0;
            SaveLoadManager.maxHp = 0;
            SaveLoadManager.mp = 0;
            SaveLoadManager.maxMp = 0;
            SaveLoadManager.saveAuto();
        } catch (eAuto) {
            console.log('LoreView: save auto snapshot failed', eAuto);
        }
    }

    function restoreMusicFromHistory() {
        try {
            var scanArray = [];
            if (historyPanel && historyPanel.historyData && historyPanel.historyData.length > 0) {
                scanArray = historyPanel.historyData;
            } else if (chapterData && chapterData.nodes && chapterData.nodes[currentNode]) {
                var nodeObj = chapterData.nodes[currentNode];
                if (nodeObj && nodeObj.contents) {
                    for (var i = 0; i <= currentContentIndex && i < nodeObj.contents.length; ++i) {
                        var c = nodeObj.contents[i];
                        if (!c) continue;
                        scanArray.push({ music: c.music, musicLoops: c.musicLoops, stopMusic: c.stopMusic });
                    }
                }
            }

            for (var j = scanArray.length - 1; j >= 0; --j) {
                var entry = scanArray[j];
                if (entry.stopMusic) {
                    if (typeof window !== 'undefined' && typeof window.stopMusic === 'function') window.stopMusic();
                    lastMusicSource = "";
                    lastMusicLoops = 0;
                    lastMusicStopped = true;
                    return true;
                }
                if (entry.music && entry.music !== '') {
                    if (typeof window !== 'undefined' && typeof window.playMusic === 'function') window.playMusic(entry.music, entry.musicLoops);
                    lastMusicSource = entry.music;
                    lastMusicLoops = (entry.musicLoops !== undefined && entry.musicLoops !== null) ? entry.musicLoops : -1;
                    lastMusicStopped = false;
                    return true;
                }
            }
        } catch (e) {
            console.log('LoreView: restoreMusicFromHistory error', e);
        }
        return false;
    }

    function applySavedMusicState() {
        try {
            if (savedMusicStopped) {
                if (typeof window !== 'undefined' && typeof window.stopMusic === 'function') window.stopMusic();
                lastMusicSource = "";
                lastMusicLoops = 0;
                lastMusicStopped = true;
                return true;
            }
            if (savedMusicSource && savedMusicSource !== "") {
                var loops = (savedMusicLoops !== undefined && savedMusicLoops !== null) ? savedMusicLoops : undefined;
                if (typeof window !== 'undefined' && typeof window.playMusic === 'function') window.playMusic(savedMusicSource, loops);
                lastMusicSource = savedMusicSource;
                lastMusicLoops = (loops !== undefined) ? savedMusicLoops : -1;
                lastMusicStopped = false;
                return true;
            }
        } catch (e) {
            console.log('LoreView: applySavedMusicState error', e);
        }
        return false;
    }

    function persistLoreState() {
        try {
            if (typeof WindowState !== 'undefined' && WindowState.setLoreState) {
                WindowState.setLoreState({
                    chapter: currentChapter,
                    node: currentNode,
                    index: currentContentIndex,
                    mode: currentMode,
                    auto: autoModeEnabled,
                    music: lastMusicStopped ? "" : lastMusicSource,
                    musicLoops: lastMusicLoops,
                    stopMusic: lastMusicStopped
                });
            }
        } catch (e) { console.log("LoreView: persist state error", e); }
    }

    // 加载章节数据（使用 FileReader 读取 JSON）
    function loadChapter(chapterId) {
        console.log("LoreView: loading chapter", chapterId);
        
        // 构建 JSON 文件路径
        var filePath = ":/qml/window/Lore/chapters/" + chapterId + ".json";
        console.log("LoreView: reading file", filePath);
        
        // 使用 fileReader 读取 JSON
        var jsonObj = fileReader.readJsonFile(filePath);
        
        // 将 QJsonObject 转换为 JavaScript 对象
        chapterData = JSON.parse(JSON.stringify(jsonObj));
        
        // 如果没有显式 currentNode，则使用章节定义的 startNode（优先）
        if ((!currentNode || currentNode === "") && chapterData && chapterData.meta && chapterData.meta.startNode) {
            currentNode = chapterData.meta.startNode;
        }

        if (chapterData && chapterData.nodes) {
            console.log("LoreView: loaded chapter data", chapterId);
            showCurrentContent();
        } else {
            console.log("LoreView: failed to load chapter", chapterId);
        }
    }

    // 显示当前内容
    function showCurrentContent() {
        if (!chapterData || !chapterData.nodes) {
            console.log("LoreView: no chapter data");
            return;
        }

        var node = chapterData.nodes[currentNode];
        if (!node) {
            console.log("LoreView: node not found", currentNode);
            return;
        }

        if (!node.contents || node.contents.length === 0) {
            console.log("LoreView: node has no contents");
            return;
        }

        // 如果保存的 index 超过范围，说明后续内容被删或结构变化：回退到最后一条有效内容（或 0）
        if (currentContentIndex >= node.contents.length) {
            console.log("LoreView: saved index", currentContentIndex, "out of range for node", currentNode, "clamping to", node.contents.length - 1);
            currentContentIndex = Math.max(0, node.contents.length - 1);
        }

        // 如果当前历史为空且 index > 0，基于内容回放构造历史，保证历史窗不空
        try {
            if (historyPanel && (!historyPanel.historyData || historyPanel.historyData.length === 0) && currentContentIndex > 0) {
                for (var hi = 0; hi < currentContentIndex; hi++) {
                    var hContent = node.contents[hi];
                    if (!hContent) continue;
                    var hMode = (hContent.mode ? hContent.mode : (node.mode ? node.mode : (chapterData.meta && chapterData.meta.mode ? chapterData.meta.mode : "circle")));
                    if (hContent.type === 'text' || hContent.type === 'title') {
                        var hSpeaker = "";
                        if (hMode === 'scene') {
                            if (hContent.speakerName) {
                                hSpeaker = hContent.speakerName;
                            } else if (hContent.speaker !== undefined && node.characters && node.characters.length > hContent.speaker) {
                                var ch = node.characters[hContent.speaker];
                                if (ch && ch.name) hSpeaker = ch.name;
                            }
                        }
                        var hText = hContent.text || "";
                        if (hText !== "") {
                            historyPanel.addHistory(hMode, hSpeaker, hText, currentNode, hi, hContent.music, hContent.musicLoops, hContent.stopMusic);
                        }
                    }
                }
            }
        } catch (reh) { console.log('LoreView: rebuild history failed', reh); }

        // 如果是初始加载(遮罩完全不透明),先更新内容再淡入
        if (transitionOverlay.opacity === 1) {
            updateContent();
            initialFadeIn.start();
        } else {
            // 直接更新内容（已移除淡出-淡入过渡动画）
            updateContent();
        }
    }

    // 实际更新内容的内部函数（在淡出后调用）
    function updateContent() {
        if (!chapterData || !chapterData.nodes) return;
        var node = chapterData.nodes[currentNode];
        if (!node || !node.contents || node.contents.length === 0) return;
        if (currentContentIndex >= node.contents.length) currentContentIndex = Math.max(0, node.contents.length - 1);

        var content = node.contents[currentContentIndex];
        // 计算当前模式（内容优先，其次节点，再章节 meta，最后默认 circle）
        var mode = (content.mode ? content.mode : (node.mode ? node.mode : (chapterData.meta && chapterData.meta.mode ? chapterData.meta.mode : "circle")));
        currentMode = mode;

    console.log("LoreView: showing content", currentNode, currentContentIndex, JSON.stringify(content), "mode:", currentMode);
    // 标题画面标记
    isTitleScreen = !!(content && (content.type === "title" || content.isTitle));

        // 记录历史（仅记录文本类型的内容）
        if (content.type === "text" || content.type === "title") {
            var speaker = "";
            // 获取实际的人名文本
            if (currentMode === "scene") {
                // 优先使用 speakerName
                if (content.speakerName) {
                    speaker = content.speakerName;
                } else if (content.speaker !== undefined && node.characters && node.characters.length > content.speaker) {
                    // 否则从 characters 数组中获取
                    var character = node.characters[content.speaker];
                    if (character && character.name) {
                        speaker = character.name;
                    }
                }
            }
            var text = content.text || "";
            if (text !== "") {
                // 记录对应的 node id 与内容索引，以及音乐指令，供历史跳转使用
                historyPanel.addHistory(currentMode, speaker, text, currentNode, currentContentIndex,
                                        content.music, content.musicLoops, content.stopMusic);
            }
        }

        // 支持标题型内容也由 VisualScene 处理
        if (currentMode === "scene" && (content.type === "text" || content.type === "title")) {
            scene.nodeData = node;
            scene.contentData = content;
            // 清空 contentLoader 避免重复显示
            contentLoader.contentData = null;
            // 调整 name badge 位置以尝试贴合对应立绘（若有）
            if (scene.adjustBadgePosition) Qt.callLater(function() { scene.adjustBadgePosition(); });
        } else {
            contentLoader.contentData = content;
            // 清空 scene 避免重复显示
            scene.nodeData = null;
            scene.contentData = null;
        }

        // 每句可控制音乐：如果 content 指定了 music，则切换播放；如果指定 stopMusic 则停止
        try {
            var musicHandled = false;
            if (content && content.music) {
                if (typeof window !== 'undefined' && typeof window.playMusic === 'function') {
                    var loops = (content.musicLoops !== undefined) ? content.musicLoops : undefined;
                    console.log("LoreView: content requests music", content.music, "loops:", loops);
                    window.playMusic(content.music, loops);
                } else {
                    console.log("LoreView: window.playMusic not available");
                }
                lastMusicSource = content.music;
                lastMusicLoops = (content.musicLoops !== undefined && content.musicLoops !== null) ? content.musicLoops : -1;
                lastMusicStopped = false;
                musicHandled = true;
            } else if (content && content.stopMusic) {
                if (typeof window !== 'undefined' && typeof window.stopMusic === 'function') {
                    console.log("LoreView: content requests stopMusic");
                    window.stopMusic();
                }
                lastMusicSource = "";
                lastMusicLoops = 0;
                lastMusicStopped = true;
                musicHandled = true;
            }

            if (!musicHandled && restoreMusicPending) {
                console.log("LoreView: attempting to restore music from history after save load");
                var restored = restoreMusicFromHistory();
                if (!restored) {
                    console.log("LoreView: no historical music found; leaving current track untouched");
                }
                musicHandled = restored;
            }
        } catch (e) {
            console.log("LoreView: music switch error", e);
        }

        if (restoreMusicPending) restoreMusicPending = false;

        // 如果是标题画面，2秒后自动切换
        if (content && (content.type === "title" || content.isTitle)) {
            console.log("LoreView: title screen detected, will auto-advance in 2 seconds");
            titleAutoAdvanceTimer.restart();
            autoAdvanceTimer.stop();
        } else {
            // 非标题画面，停止计时器
            titleAutoAdvanceTimer.stop();
            scheduleAutoAdvance();
        }
    }

    function setAutoMode(enabled) {
        if (autoModeEnabled === enabled) return;
        autoModeEnabled = enabled;
        if (!enabled) {
            autoAdvanceTimer.stop();
        } else {
            scheduleAutoAdvance();
        }
    }

    function scheduleAutoAdvance() {
        autoAdvanceTimer.stop();
        if (!autoModeEnabled || historyPanel.visible) return;
        if (!chapterData || !chapterData.nodes) return;
        var node = chapterData.nodes[currentNode];
        if (!node || !node.contents || currentContentIndex >= node.contents.length) return;
        var content = node.contents[currentContentIndex];
        if (!content || content.type === "title" || content.isTitle) return;
        var delay = 3000;
        if (content.autoDelay !== undefined) {
            delay = Math.max(500, content.autoDelay);
        }
        autoAdvanceTimer.interval = delay;
        autoAdvanceTimer.restart();
    }

    // 前进到下一个内容
    function nextContent() {
        autoAdvanceTimer.stop();
        titleAutoAdvanceTimer.stop();
        if (!chapterData || !chapterData.nodes) {
            console.log("LoreView: no chapter data");
            return;
        }

        var node = chapterData.nodes[currentNode];
        if (!node) {
            console.log("LoreView: node not found", currentNode);
            return;
        }

        // 如果当前节点还有更多内容
        if (currentContentIndex < node.contents.length - 1) {
            currentContentIndex++;
            console.log("LoreView: advancing to content index", currentContentIndex);
            showCurrentContent();
            return;
        }

        // 到达节点末尾，检查是否有 action
        if (node.action) {
            setAutoMode(false);
            console.log("LoreView: triggering action", node.action);
            if (node.action === "startBattle") {
                var battleId = node.actionParams ? node.actionParams.battleId : "battle01";
                console.log("LoreView: starting battle", battleId);
                
                if (typeof transitionManager !== 'undefined') {
                    transitionManager.startBattle(battleId);
                } else {
                    console.log("LoreView: transitionManager not found");
                }
            }
            return;
        }

        // 跳转到下一个节点
        if (node.nextNode) {
            console.log("LoreView: moving to next node", node.nextNode);
            currentNode = node.nextNode;
            currentContentIndex = 0;
            showCurrentContent();
            return;
        }

        console.log("LoreView: reached end of chapter");
    }

    // 动态圆圈
    DynamicCircle {
        id: circle
        anchors.fill: parent
        visible: root.currentMode === "circle"
    }

    // 内容加载器（叠加在圆圈上方）
    ContentLoader {
        id: contentLoader
        anchors.centerIn: parent
        width: circle.circleSize * 0.9
        height: circle.circleSize * 0.9
        z: 10
        visible: root.currentMode === "circle"
    }

    // 视觉小说场景（背景 + 立绘 + 底部文字框）
    VisualScene {
        id: scene
        anchors.fill: parent
        visible: root.currentMode === "scene"
        z: 5
    }

    Loader {
        id: controlBarLoader
        source: "qrc:/qml/components/LoreControlBar.qml"
        // 采用手动坐标定位，避免宽高为0时锚点失效导致左上角位置
        z: 1500
        active: true
        visible: root.currentMode === "scene" && scene.textBoxItem && !root.isTitleScreen

        onLoaded: {
            if (!controlBarLoader.item) return;
            var obj = controlBarLoader.item;
            // 让 Loader 拥有 item 尺寸用于居中
            controlBarLoader.width = (obj.width && obj.width > 0) ? obj.width : (obj.implicitWidth || obj.childrenRect ? obj.childrenRect.width : 0);
            controlBarLoader.height = (obj.height && obj.height > 0) ? obj.height : (obj.implicitHeight || obj.childrenRect ? obj.childrenRect.height : 0);
            updateControlBarPos();
            try { obj.autoEnabled = root.autoModeEnabled; } catch (e) { }

            // connect signals
            try {
                obj.settingsClicked.connect(function() {
                    setAutoMode(false);
                    if (window && window.pushSource) window.pushSource("qml/window/Config.qml"); else if (window && window.replaceSource) window.replaceSource("qml/window/Config.qml");
                });

                obj.autoToggled.connect(function(enabled) { setAutoMode(enabled); });

                obj.skipClicked.connect(function() { titleAutoAdvanceTimer.stop(); nextContent(); persistLoreState(); });

                obj.historyClicked.connect(function() { autoAdvanceTimer.stop(); historyPanel.open(); persistLoreState(); });

                obj.saveClicked.connect(function() {
                    setAutoMode(false);
                    try { WindowState.setTargetMode("save"); } catch (e) { }
                    // 抓取当前 Lore 画面作为预览并写入上下文
                    try { if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager.captureTemp) SaveLoadManager.captureTemp(); } catch (e2) { console.log('LoreView: captureTemp failed', e2); }
                    try {
                        if (typeof SaveLoadManager !== 'undefined') {
                            SaveLoadManager.view = "lore";
                            SaveLoadManager.loreChapter = currentChapter || "";
                            SaveLoadManager.loreNode = currentNode || "";
                            SaveLoadManager.loreIndex = currentContentIndex || 0;
                        }
                    } catch (e3) { console.log('LoreView: set lore context failed', e3); }
                    persistLoreState();
                    if (window && window.pushSource) window.pushSource("qml/window/SaveLoad.qml"); else if (window && window.replaceSource) window.replaceSource("qml/window/SaveLoad.qml");
                });

                obj.loadClicked.connect(function() {
                    setAutoMode(false);
                    try { WindowState.setTargetMode("load"); } catch (e) { }
                    // 也写入上下文以便覆盖保存时预览正确
                    try { if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager.captureTemp) SaveLoadManager.captureTemp(); } catch (e2) { }
                    try {
                        if (typeof SaveLoadManager !== 'undefined') {
                            SaveLoadManager.view = "lore";
                            SaveLoadManager.loreChapter = currentChapter || "";
                            SaveLoadManager.loreNode = currentNode || "";
                            SaveLoadManager.loreIndex = currentContentIndex || 0;
                        }
                    } catch (e3) { }
                    persistLoreState();
                    if (window && window.pushSource) window.pushSource("qml/window/SaveLoad.qml"); else if (window && window.replaceSource) window.replaceSource("qml/window/SaveLoad.qml");
                });

                obj.titleClicked.connect(function() { setAutoMode(false); confirmTitleDialog.visible = true; });
            } catch (e) { console.log("LoreView: controlBar connect error", e); }
        }
        onStatusChanged: {
            console.log("LoreView: controlBarLoader status=", status, "source=", source)
        }
        onWidthChanged: updateControlBarPos()
        onHeightChanged: updateControlBarPos()
    }

    Binding {
        target: scene
        property: "bottomReservedHeight"
        value: (root.isTitleScreen ? 24 : (controlBarLoader.item ? (controlBarLoader.height + 20) : 24))
    }

    // 更新控制条位置：贴在文本框底部中央
    function updateControlBarPos() {
        if (!scene || !scene.textBoxItem || !controlBarLoader.item) return;
        var tb = scene.textBoxItem;
        // 使用 textBoxItem 的全局坐标映射到 root
        var pt = tb.mapToItem(root, 0, 0);
        var desiredWidth = controlBarLoader.width;
        // 若宽度尚未就绪，延迟重试
        if (!desiredWidth || desiredWidth === 0) {
            Qt.callLater(updateControlBarPos);
            persistLoreState();
            return;
        }
        controlBarLoader.x = pt.x + (tb.width - desiredWidth)/2;
        controlBarLoader.y = pt.y + tb.height - controlBarLoader.height - 12; // 12px 上留白
    }

    Connections {
        target: scene
        function onWidthChanged() { updateControlBarPos() }
        function onHeightChanged() { updateControlBarPos() }
    }

    Connections {
        target: scene.textBoxItem
        function onWidthChanged() { updateControlBarPos() }
        function onHeightChanged() { updateControlBarPos() }
        function onVisibleChanged() { updateControlBarPos() }
    }

    // 全屏点击区域(左键点击前进)
    MouseArea {
        anchors.fill: parent
        enabled: !historyPanel.visible && !confirmTitleDialog.visible
        onClicked: {
            console.log("LoreView: clicked, advancing content");
            // 点击时也停止标题自动切换计时器
            titleAutoAdvanceTimer.stop();
            nextContent();
            persistLoreState();
        }
        z: 1000
    }

    // 鼠标滚轮处理器(向下滚动前进)
    WheelHandler {
        target: root
        enabled: !historyPanel.visible && !confirmTitleDialog.visible  // 历史或对话框打开时禁用
        onWheel: function(event) {
            // 向下滚动时 angleDelta.y < 0
            if (event.angleDelta.y < 0) {
                console.log("LoreView: wheel down, advancing content");
                titleAutoAdvanceTimer.stop();
                nextContent();
                persistLoreState();
            } else if (event.angleDelta.y > 0) {
                // 向上滚动时打开历史面板
                console.log("LoreView: wheel up, opening history");
                historyPanel.open();
            }
        }
    }

    // 过渡遮罩层（用于淡入淡出效果）
    Rectangle {
        id: transitionOverlay
        anchors.fill: parent
        color: "black"
        opacity: 0
        z: 2000
        visible: opacity > 0
    }

    // 初始淡入动画（首次加载时）
    PropertyAnimation {
        id: initialFadeIn
        target: transitionOverlay
        property: "opacity"
        to: 0
        duration: 200
        easing.type: Easing.InOutQuad
    }

    // NOTE: 内容切换过渡动画已移除，切换时会直接调用 updateContent()

    // 历史回顾面板
    HistoryPanel {
        id: historyPanel
        anchors.fill: parent
        
        onCloseRequested: {
            historyPanel.close();
        }
        onVisibleChanged: {
            if (visible) {
                autoAdvanceTimer.stop();
            } else {
                scheduleAutoAdvance();
            }
        }
        onJumpRequested: function(nodeId, contentIndex) {
            console.log("LoreView: jumpRequested", nodeId, contentIndex);
            if (nodeId && chapterData && chapterData.nodes && chapterData.nodes[nodeId]) {
                // 裁剪历史记录到目标位置，避免重复
                historyPanel.trimHistoryTo(nodeId, contentIndex);
                currentNode = nodeId;
                currentContentIndex = contentIndex >= 0 ? contentIndex : 0;
                historyPanel.close();
                // 先更新内容
                showCurrentContent();
                // 跳转后恢复音乐：回溯历史找到距离当前最近的有效音乐指令（music 或 stopMusic）
                try {
                    var effectiveMusic = null;
                    var effectiveLoops = undefined;
                    var shouldStop = false;
                    // 从后往前扫描历史数组
                    for (var i = historyPanel.historyData.length - 1; i >= 0; i--) {
                        var h = historyPanel.historyData[i];
                        if (h.node === currentNode && h.index === currentContentIndex) {
                            // 当前记录本身也可能包含音乐指令
                        }
                        if (h.stopMusic) {
                            shouldStop = true;
                            break;
                        }
                        if (h.music && h.music !== "") {
                            effectiveMusic = h.music;
                            effectiveLoops = h.musicLoops;
                            break;
                        }
                    }
                    if (shouldStop) {
                        if (typeof window !== 'undefined' && typeof window.stopMusic === 'function') {
                            console.log("LoreView: restoring stopMusic after jump");
                            window.stopMusic();
                        }
                        lastMusicSource = "";
                        lastMusicLoops = 0;
                        lastMusicStopped = true;
                    } else if (effectiveMusic) {
                        if (typeof window !== 'undefined' && typeof window.playMusic === 'function') {
                            console.log("LoreView: restoring effective music after jump", effectiveMusic, "loops:", effectiveLoops);
                            window.playMusic(effectiveMusic, effectiveLoops);
                        }
                        lastMusicSource = effectiveMusic;
                        lastMusicLoops = (effectiveLoops !== undefined && effectiveLoops !== null) ? effectiveLoops : -1;
                        lastMusicStopped = false;
                    } else {
                        // 没找到显式音乐指令：保持当前播放，不做处理
                        console.log("LoreView: no explicit music directive found for jump target; keeping current music");
                    }
                } catch (e2) {
                    console.log("LoreView: music restore scanning error", e2);
                }
                scheduleAutoAdvance();
            } else {
                console.log("LoreView: invalid jump target", nodeId);
            }
        }
    }

    // 历史面板打开时，全屏右键关闭覆盖层（不拦截左键）
    MouseArea {
        id: historyRightClickClose
        anchors.fill: parent
        visible: historyPanel.visible
        z: 1500 // 高于 HistoryPanel，低于过渡遮罩
        acceptedButtons: Qt.RightButton
        hoverEnabled: false
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                console.log("LoreView: right click while history open, closing history");
                historyPanel.close();
                mouse.accepted = true;
            }
        }
    }

    // 历史面板打开时，任何位置向下滚轮均关闭历史面板
    WheelHandler {
        id: historyWheelClose
        target: root
        enabled: historyPanel.visible
        onWheel: function(event) {
            if (event.angleDelta.y < 0) {
                console.log("LoreView: wheel down while history open, closing history");
                historyPanel.close();
                event.accepted = true;
            }
        }
    }

    // 右键快速打开设置：在剧情视图任意处右键（且历史面板未打开）跳转到 Config 页面
    MouseArea {
        id: loreRightClickToConfig
        anchors.fill: parent
        visible: !historyPanel.visible
        z: 1400
        acceptedButtons: Qt.RightButton
        hoverEnabled: false
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                console.log("LoreView: right click -> open Config");
                try { if (historyPanel && historyPanel.visible) historyPanel.close(); } catch (e) {}
                try {
                    if (window && window.pushSource) window.pushSource("qml/window/Config.qml");
                    else if (window && window.replaceSource) window.replaceSource("qml/window/Config.qml");
                } catch (eNav) { console.log('LoreView: open config failed', eNav); }
                mouse.accepted = true;
            }
        }
    }

    // 标题画面自动切换计时器
    Timer {
        id: titleAutoAdvanceTimer
        interval: 2000  // 2秒
        repeat: false
        onTriggered: {
            console.log("LoreView: title auto-advance triggered");
            nextContent();
        }
    }

    // 自动模式计时器，根据 autoDelay 或默认值自动前进
    Timer {
        id: autoAdvanceTimer
        interval: 3000
        repeat: false
        onTriggered: {
            console.log("LoreView: auto-advance timer triggered");
            nextContent();
        }
    }

    ConfirmDialog {
        id: confirmTitleDialog
        anchors.centerIn: parent
        z: 3500
        title: "返回主界面?"
        yesText: "是"
        noText: "否"
        onYes: function() {
            // 保留当前状态（已经在 persistLoreState 中），然后回主菜单
            persistLoreState();
            try { window.pageHistory = []; } catch (e) { }
            // 切换主菜单音乐
            try { if (window && typeof window.playMusic === 'function') window.playMusic("qrc:/resource/audio/bgm/mainmenu.mp3"); } catch (em) { console.log("LoreView: play mainmenu music error", em); }
            if (window && window.replaceSource) window.replaceSource("qml/window/MainMenu.qml");
            else if (window && window.pushSource) window.pushSource("qml/window/MainMenu.qml");
        }
        onNo: function() { /* 关闭后自动隐藏 */ }
    }

    // ESC 键返回
    Shortcut {
        sequence: "Esc"
        onActivated: {
            if (window && window.goBack) {
                window.goBack();
            }
        }
    }
}

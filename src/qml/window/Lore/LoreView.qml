import QtQuick
import "../../components"
import "../windowState.js" as WindowState

// LoreView.qml - 剧情视图主场景
Item {
    id: root
    anchors.fill: parent
    focus: true

    // Use attached Keys handlers below (attached properties are required)

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
    // 已读进度：结构为 { chapterId: { nodeId: highestReadIndex, ... }, ... }
    property var readProgress: {}
    // 当前的跳过模式（'read' 或 'all'），由快进按钮/按键启动时设置
    property string __skipMode: ""
    // 标记在显示选项时是否应在选择后继续快进
    property bool __ffPendingChoice: false
    // 在某些场景（如进入 game over）需要禁止自动保存 snapshot
    property bool suppressAutoSave: false

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

        // 尝试从 SaveLoadManager 中恢复历史（如果存在）。这允许在切换界面后恢复历史窗内容。
        try {
            if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager && SaveLoadManager.loreHistory && SaveLoadManager.loreHistory !== "") {
                try {
                    var parsedHist = JSON.parse(SaveLoadManager.loreHistory);
                    if (historyPanel) {
                        historyPanel.historyData = parsedHist;
                        // 裁剪历史到当前保存的进度，避免恢复后出现超出当前进度的后续记录
                        try {
                            var trimParam = JSON.stringify({ branch: currentChapter, node: currentNode });
                            historyPanel.trimHistoryTo(trimParam, currentContentIndex);
                        } catch (etrim) { /* ignore */ }
                    }
                } catch (ehist) {
                    console.log('LoreView: failed to parse saved loreHistory', ehist);
                }
            }
        } catch (er) { console.log('LoreView: restore history from SaveLoadManager failed', er); }
        // 尝试加载已读进度（progress.dat）以支持只对已读文本启用快进
        try {
            if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager && typeof SaveLoadManager.loadProgress === 'function') {
                var p = SaveLoadManager.loadProgress();
                if (p && Object.keys(p).length > 0) {
                    readProgress = p;
                }
            }
        } catch (eLoadProgress) { console.log('LoreView: loadProgress failed', eLoadProgress); }
        // Ensure this view receives keyboard focus so attached Keys handlers work
        Qt.callLater(function() { try { root.forceActiveFocus(); } catch (e) { /* ignore */ } });
    }

    // 标记已读内容并持久化到 progress.dat
    function markContentRead(branch, nodeId, index) {
            try {
                if (typeof SaveLoadManager === 'undefined' || !SaveLoadManager) return;
                if (!readProgress) readProgress = {};
                var chapterMap = readProgress[branch];
                if (!chapterMap) chapterMap = {};
                var prev = chapterMap[nodeId];
                if (prev === undefined || index > prev) {
                    chapterMap[nodeId] = index;
                    readProgress[branch] = chapterMap;
                    try {
                        // 先读取当前 progress 并合并 extraUnlocked
                        var currentProgress = SaveLoadManager.loadProgress();
                        if (currentProgress && currentProgress.extraUnlocked) {
                            readProgress.extraUnlocked = currentProgress.extraUnlocked;
                        }
                        console.log("LoreView: markContentRead -> saving", branch, nodeId, index);
                        SaveLoadManager.saveProgress(readProgress);
                        try {
                            var verify = SaveLoadManager.loadProgress();
                            console.log("LoreView: markContentRead -> verify loadProgress keys:", Object.keys(verify));
                        } catch (el) { console.log('LoreView: markContentRead -> verify loadProgress failed', el); }
                    } catch (es) { console.log('LoreView: markContentRead -> saveProgress failed', es); }
                }
            } catch (e) { /* ignore */ }
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
            if (suppressAutoSave) {
                console.log('LoreView: suppressed saveAuto because suppressAutoSave is true');
                return;
            }
            if (typeof SaveLoadManager === 'undefined' || !SaveLoadManager) return;
            try { SaveLoadManager.captureTemp(); } catch (eCap) { console.log('LoreView: captureTemp for auto failed', eCap); }
            SaveLoadManager.view = "lore";
            SaveLoadManager.loreChapter = currentChapter || "";
            SaveLoadManager.loreNode = currentNode || "";
            SaveLoadManager.loreIndex = currentContentIndex || 0;
            // 保存历史数据为 JSON 字符串，允许历史在界面切换后恢复
            try {
                if (historyPanel && historyPanel.historyData) {
                    SaveLoadManager.loreHistory = JSON.stringify(historyPanel.historyData);
                } else {
                    SaveLoadManager.loreHistory = "";
                }
            } catch (eh) { SaveLoadManager.loreHistory = ""; }
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
                // 仅使用与当前章节匹配的历史条目以恢复音乐
                for (var hi = 0; hi < historyPanel.historyData.length; ++hi) {
                    var he = historyPanel.historyData[hi];
                    if (!he || !he.branch || he.branch === currentChapter) {
                        scanArray.push(he);
                    }
                }
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

            // 如果 currentNode 在加载的章节中不存在，尝试回退到章节的 startNode 或者第一个节点，防止旧的引用（例如 "start"）导致找不到节点
            if (chapterData && chapterData.nodes && (!chapterData.nodes[currentNode])) {
                if (chapterData.meta && chapterData.meta.startNode && chapterData.nodes[chapterData.meta.startNode]) {
                    console.log("LoreView: currentNode", currentNode, "not found in chapter; falling back to startNode", chapterData.meta.startNode);
                    currentNode = chapterData.meta.startNode;
                } else {
                    console.log("LoreView: currentNode", currentNode, "not found and no valid startNode; defaulting to first available node");
                    for (var k in chapterData.nodes) { currentNode = k; break; }
                }
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
                            } else if (hContent.speaker !== undefined) {
                                if (typeof hContent.speaker === 'number') {
                                    if (node.characters && node.characters.length > hContent.speaker) {
                                        var ch = node.characters[hContent.speaker];
                                        if (ch && ch.name) hSpeaker = ch.name;
                                    }
                                } else if (typeof hContent.speaker === 'string') {
                                    var s = hContent.speaker;
                                    var matched = false;
                                    try {
                                        if (node.characters) {
                                            for (var cc = 0; cc < node.characters.length; ++cc) {
                                                if (node.characters[cc] && node.characters[cc].name === s) { hSpeaker = s; matched = true; break; }
                                            }
                                        }
                                    } catch (em) {}
                                    if (!matched) hSpeaker = s;
                                }
                            }
                        }
                        var hText = hContent.text || "";
                        if (hText !== "") {
                            historyPanel.addHistory(hMode, hSpeaker, hText, currentChapter, currentNode, hi, hContent.music, hContent.musicLoops, hContent.stopMusic);
                            // 标记为已读
                            try { markContentRead(currentChapter, currentNode, hi); } catch (e) { }
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

            // 检查是否刚刚从battle节点跳转到本节点（即上一个节点是battle 或 由某个节点 action startBattle 导致）
        try {
            var prevNodeId = null;
            // 仅在当前节点不是battle节点时检查
                if (!currentNode.startsWith("battle")) {
                    // 遍历章节所有节点，查找是否有next/nextNode/choices指向当前节点
                    for (var nid in chapterData.nodes) {
                        var nobj = chapterData.nodes[nid];
                        // case A: the previous node is a battle node (nid startsWith "battle") whose next points to currentNode
                        if (nobj.next === currentNode && nid.startsWith("battle")) prevNodeId = nid;
                        if (nobj.nextNode === currentNode && nid.startsWith("battle")) prevNodeId = nid;
                        if (nobj.choices && Array.isArray(nobj.choices)) {
                            for (var ci=0;ci<nobj.choices.length;++ci) {
                                if (nobj.choices[ci].next === currentNode && nid.startsWith("battle")) prevNodeId = nid;
                            }
                        }
                        // case B: the previous node triggered a battle via action startBattle; identify the battle id from actionParams
                        try {
                            if (nobj.action === 'startBattle') {
                                var ap = nobj.actionParams || {};
                                if (ap && typeof ap.battleId === 'string' && ap.battleId !== '' && (nobj.next === currentNode || nobj.nextNode === currentNode)) {
                                    prevNodeId = ap.battleId;
                                }
                            }
                        } catch (ea) { }

                        // case C: the previous node has a choice pointing to a battle
                        if (nobj.choices && Array.isArray(nobj.choices)) {
                            var battleChoiceId = null;
                            for (var ci=0; ci<nobj.choices.length; ++ci) {
                                var cnext = nobj.choices[ci].next;
                                if (cnext && typeof cnext === 'string' && cnext.startsWith("battle")) {
                                    battleChoiceId = cnext;
                                    break;
                                }
                            }
                            if (battleChoiceId) {
                                // Check if currentNode is a target of this node (via other paths)
                                var isTarget = false;
                                if (nobj.next === currentNode) isTarget = true;
                                if (nobj.nextNode === currentNode) isTarget = true;
                                for (var cj=0; cj<nobj.choices.length; ++cj) {
                                    if (nobj.choices[cj].next === currentNode) isTarget = true;
                                }
                                if (isTarget) prevNodeId = battleChoiceId;
                            }
                        }
                    }
                }
            if (prevNodeId) {
                // 只要曾经进入过battle的下一个节点就解锁extra
                if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager.unlockExtra) {
                    SaveLoadManager.unlockExtra(prevNodeId);
                    console.log("LoreView: unlockExtra called for", prevNodeId);
                }
            }
        } catch(e) { console.log("LoreView: unlockExtra check error", e); }

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
                } else if (content.speaker !== undefined) {
                    // content.speaker can be a numeric index or a string name/custom label
                    if (typeof content.speaker === 'number') {
                        if (node.characters && node.characters.length > content.speaker) {
                            var character = node.characters[content.speaker];
                            if (character && character.name) speaker = character.name;
                        }
                    } else if (typeof content.speaker === 'string') {
                        // if it matches any character's name, use it; otherwise just use the string as label
                        var s = content.speaker;
                        var matched = false;
                        try {
                            if (node.characters) {
                                for (var ci = 0; ci < node.characters.length; ++ci) {
                                    if (node.characters[ci] && node.characters[ci].name === s) { speaker = s; matched = true; break; }
                                }
                            }
                        } catch (e) {}
                        if (!matched) speaker = s;
                    }
                }
            }
            var text = content.text || "";
            if (text !== "") {
                // 记录对应的 node id 与内容索引，以及音乐指令，供历史跳转使用
                historyPanel.addHistory(currentMode, speaker, text, currentChapter, currentNode, currentContentIndex,
                                        content.music, content.musicLoops, content.stopMusic);
                // NOTE: 不在此处立即标记为已读 —— 否则按显示就会被认为已读，导致“仅已读跳过”失效。
                // 已读标记将在玩家实际前进（nextContent）或历史重建时设置。
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
        // ensure auto and skip are mutually exclusive
        try {
            if (enabled && controlBarLoader && controlBarLoader.item) controlBarLoader.item.skipActive = false;
            if (!enabled && controlBarLoader && controlBarLoader.item) controlBarLoader.item.skipActive = false; // keep consistent
            if (controlBarLoader && controlBarLoader.item) controlBarLoader.item.autoEnabled = autoModeEnabled;
        } catch(e) {}
    }

    function scheduleAutoAdvance() {
        autoAdvanceTimer.stop();
        if (!autoModeEnabled || historyPanel.visible) return;
        if (!chapterData || !chapterData.nodes) return;
        var node = chapterData.nodes[currentNode];
        if (!node || !node.contents || currentContentIndex >= node.contents.length) return;
        var content = node.contents[currentContentIndex];
        if (!content || content.type === "title" || content.isTitle) return;
        var delay;
        // Per-content override (assumed to be milliseconds if present)
        if (content.autoDelay !== undefined) {
            delay = Math.max(500, content.autoDelay);
        } else {
            // Global setting (seconds) stored on window.__autoModeWait — convert to ms
            var globalSec = (typeof window !== 'undefined' && window.__autoModeWait !== undefined) ? Number(window.__autoModeWait) : undefined;
            if (globalSec !== undefined && !isNaN(globalSec)) {
                // enforce reasonable bounds: minimum 1s
                delay = Math.max(1000, Math.round(globalSec * 1000));
            } else {
                // fallback default 3000 ms
                delay = 3000;
            }
        }
        autoAdvanceTimer.interval = delay;
        autoAdvanceTimer.restart();
    }

    // 前进到下一个内容
    function nextContent() {
        // 在实际前进前，将当前展示的内容标为已读（用户已看到或跳过它）
        try { markContentRead(currentChapter, currentNode, currentContentIndex); } catch(e) { }
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
            // If we're fast-forwarding and user prefers 'read' skipping, stop when new content is UNREAD
            try {
                var isFF = (fastForwardTimer && fastForwardTimer.running) ? true : false;
                var skipMode = (root.__skipMode !== undefined && root.__skipMode !== "") ? root.__skipMode : (function(){ try { var s = (typeof SaveLoadManager !== 'undefined' && SaveLoadManager) ? SaveLoadManager.loadSystem() : {}; return (s && s.textSkip) ? s.textSkip : 'read'; } catch(e){ return 'read'; } })();
                if (isFF && skipMode === 'read') {
                    // current content is at currentContentIndex
                    var curNode = chapterData.nodes[currentNode];
                    var curContent = curNode && curNode.contents ? curNode.contents[currentContentIndex] : null;
                    if (curContent && (curContent.type === 'text' || curContent.type === 'title')) {
                        var already = false;
                        try { already = !!(readProgress && readProgress[currentChapter] && readProgress[currentChapter][currentNode] !== undefined && readProgress[currentChapter][currentNode] >= currentContentIndex); } catch (er) { already = false; }
                        if (!already) {
                            // we've landed on an unread content -> stop fast-forward so player can read it
                            try { fastForwardTimer.stop(); } catch(e) {}
                        }
                    } else {
                        // non-text content: stop fast-forward to avoid skipping choices/actions
                        try { fastForwardTimer.stop(); } catch(e) {}
                    }
                }
            } catch (ef) { }
            return;
        }

        // 到达节点末尾，检查是否有 action
        if (node.action) {
            setAutoMode(false);
            try { fastForwardTimer.stop(); } catch(e) {}
            console.log("LoreView: triggering action", node.action);
            if (node.action === "startBattle") {
                var battleId = node.actionParams ? node.actionParams.battleId : "battle01";
                console.log("LoreView: starting battle", battleId);
                if (typeof transitionManager !== 'undefined') {
                    transitionManager.startBattle(battleId);
                } else {
                    console.log("LoreView: transitionManager not found");
                }
            } else if (node.action === "gameOver") {
                // End the game and return to main menu
                try { persistLoreState(); } catch(e) { }
                try { window.pageHistory = []; } catch(e) { }
                try { if (window && typeof window.playMusic === 'function') window.playMusic("qrc:/resource/audio/bgm/mainmenu.mp3"); } catch(e) { }
                // ensure any auto save and temporary preview is removed on game over
                try {
                    // Prevent the later destruction from re-saving auto.dat/temp.png
                    suppressAutoSave = true;
                    if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager && typeof SaveLoadManager.removeAuto === 'function') {
                        var success = SaveLoadManager.removeAuto("save");
                        console.log('LoreView: removeAuto returned', success);
                        var autoExists = false;
                        try { autoExists = SaveLoadManager.hasAuto("save"); } catch(eH) { }
                        console.log('LoreView: after removeAuto, hasAuto =', autoExists);
                        if (!success || autoExists) console.log('LoreView: WARNING auto.dat/temp.png may still exist after removeAuto');
                    }
                } catch (eRem) { console.log('LoreView: removeAuto failed', eRem); }
                try {
                    if (window && window.replaceSource) window.replaceSource("qml/window/MainMenu.qml"); else if (window && window.pushSource) window.pushSource("qml/window/MainMenu.qml");
                } catch (eNav) { console.log('LoreView: gameOver navigation failed', eNav); }
                return;
            }
            return;
        }

        // 到达节点末尾且存在分支选项时，弹出选择对话框
        if (node.choices && node.choices.length > 0) {
            console.log("LoreView: node has choices at end, showing choice dialog", node.choices);
                try {
                    // Ensure any active typing finishes immediately when choices appear
                    try {
                        var activeTc = getActiveTextComponent();
                        if (activeTc && activeTc.typing) {
                            try { activeTc.finishTyping(); } catch (eft) { console.log('LoreView: finishTyping on choice show failed', eft); }
                        }
                    } catch (et) { /* ignore */ }
                    choiceDialog.choices = node.choices;
                    // decide whether to resume fast-forward after choice based on user setting
                    try {
                        var resumeOpt = false;
                        if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager && typeof SaveLoadManager.loadSystem === 'function') {
                            var sysC = SaveLoadManager.loadSystem() || {};
                            resumeOpt = !!sysC.optionFastForward;
                        }
                        root.__ffPendingChoice = (!!(fastForwardTimer && fastForwardTimer.running) && resumeOpt);
                    } catch (ef) { root.__ffPendingChoice = false; }
                    choiceDialog.visible = true;
                } catch (e) { console.log('LoreView: show choice dialog error', e); }
            setAutoMode(false);
                try { fastForwardTimer.stop(); } catch(e) {}
            return;
        }

        // 跳转到下一个节点
        if (node.nextNode) {
            console.log("LoreView: moving to next node", node.nextNode);
            currentNode = node.nextNode;
            currentContentIndex = 0;
            showCurrentContent();
            // If fast-forwarding, check whether first content is unread and stop if so
            try {
                if (fastForwardTimer && fastForwardTimer.running) {
                    var skipModeNN = (root.__skipMode !== undefined && root.__skipMode !== "") ? root.__skipMode : (function(){ try { var s = (typeof SaveLoadManager !== 'undefined' && SaveLoadManager) ? SaveLoadManager.loadSystem() : {}; return (s && s.textSkip) ? s.textSkip : 'read'; } catch(e){ return 'read'; } })();
                    var nnContent = chapterData.nodes[currentNode] && chapterData.nodes[currentNode].contents ? chapterData.nodes[currentNode].contents[0] : null;
                    if (skipModeNN === 'read') {
                        var alreadyNN = !!(readProgress && readProgress[currentChapter] && readProgress[currentChapter][currentNode] !== undefined && readProgress[currentChapter][currentNode] >= 0);
                        if (nnContent && (nnContent.type === 'text' || nnContent.type === 'title')) {
                            if (!alreadyNN) try { fastForwardTimer.stop(); } catch(e) {}
                        } else {
                            try { fastForwardTimer.stop(); } catch(e) {}
                        }
                    }
                }
            } catch(e) {}
            return;
        }

        // 新增：如果节点指定了 nextChapter，则自动切换到该章节
        if (node.nextChapter) {
            console.log("LoreView: moving to next chapter", node.nextChapter);
            // 记录当前章节并重置 node/index 然后加载新章节
            currentChapter = node.nextChapter;
            currentNode = "";
            currentContentIndex = 0;
            loadChapter(currentChapter);
            // After loading, check fast-forward stopping condition similarly
            try {
                if (fastForwardTimer && fastForwardTimer.running) {
                    var skipModeNC = (root.__skipMode !== undefined && root.__skipMode !== "") ? root.__skipMode : (function(){ try { var s = (typeof SaveLoadManager !== 'undefined' && SaveLoadManager) ? SaveLoadManager.loadSystem() : {}; return (s && s.textSkip) ? s.textSkip : 'read'; } catch(e){ return 'read'; } })();
                    var firstNodeKey;
                    for (var k in chapterData.nodes) { firstNodeKey = k; break; }
                    var firstContent = (firstNodeKey && chapterData.nodes[firstNodeKey] && chapterData.nodes[firstNodeKey].contents) ? chapterData.nodes[firstNodeKey].contents[0] : null;
                    if (skipModeNC === 'read') {
                        var alreadyFirst = !!(readProgress && readProgress[currentChapter] && readProgress[currentChapter][firstNodeKey] !== undefined && readProgress[currentChapter][firstNodeKey] >= 0);
                        if (firstContent && (firstContent.type === 'text' || firstContent.type === 'title')) {
                            if (!alreadyFirst) try { fastForwardTimer.stop(); } catch(e) {}
                        } else {
                            try { fastForwardTimer.stop(); } catch(e) {}
                        }
                    }
                }
            } catch(e) {}
            return;
        }

        console.log("LoreView: reached end of chapter");
        try { fastForwardTimer.stop(); } catch(e) {}
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
        // Instantiate the control bar directly from the imported components module
        // This avoids any QRC/resource path issues and ensures the type is created.
        sourceComponent: Component { LoreControlBar { } }
        // 采用手动坐标定位，避免宽高为0时锚点失效导致左上角位置
        // Elevate the control bar above the choice dialog so it remains clickable
        z: (choiceDialog && choiceDialog.visible) ? 3400 : 1500
        active: true
        // make control bar visible whenever we're in "scene" mode and not a title screen
        // (don't depend on scene.textBoxItem existing at bind time)
        visible: root.currentMode === "scene" && !root.isTitleScreen

        onLoaded: {
            if (!controlBarLoader.item) return;
            var obj = controlBarLoader.item;
            // 让 Loader 拥有 item 尺寸用于居中
            controlBarLoader.width = (obj.width && obj.width > 0) ? obj.width : ((obj.implicitWidth !== undefined && obj.implicitWidth !== 0) ? obj.implicitWidth : (obj.childrenRect ? obj.childrenRect.width : 0));
            controlBarLoader.height = (obj.height && obj.height > 0) ? obj.height : ((obj.implicitHeight !== undefined && obj.implicitHeight !== 0) ? obj.implicitHeight : (obj.childrenRect ? obj.childrenRect.height : 0));
            console.log("LoreView: controlBarLoader onLoaded size -> w:", controlBarLoader.width, "h:", controlBarLoader.height, "itemExists:", !!controlBarLoader.item);
            updateControlBarPos();
            try { obj.autoEnabled = root.autoModeEnabled; } catch (e) { }
            try { if (typeof fastForwardTimer !== 'undefined' && obj) obj.skipActive = fastForwardTimer.running; } catch (e) {}

            // connect signals
            try {
                obj.settingsClicked.connect(function() {
                    setAutoMode(false);
                    if (window && window.pushSource) window.pushSource("qml/window/Config.qml"); else if (window && window.replaceSource) window.replaceSource("qml/window/Config.qml");
                });

                obj.autoToggled.connect(function(enabled) { setAutoMode(enabled); });
                // when Auto toggled on -> ensure skip is disabled
                obj.autoToggled.connect(function(enabled) {
                    try { if (enabled) obj.skipActive = false; } catch (ee) {}
                });

                obj.skipToggled.connect(function(enabled) {
                    if (enabled) {
                        // enabling skip should disable auto
                        setAutoMode(false);
                    }
                    // handle as toggle: enabling => start fast-forward; disabling => stop
                    if (enabled) {
                        titleAutoAdvanceTimer.stop();
                        try {
                            var tcskip = getActiveTextComponent();
                            if (tcskip && tcskip.typing) { tcskip.finishTyping(); return; }
                            try { if (typeof window !== 'undefined') window.__skipInstantNext = true; } catch (e) {}
                        } catch (e) {}
                        try {
                            var sys = (typeof SaveLoadManager !== 'undefined' && SaveLoadManager && typeof SaveLoadManager.loadSystem === 'function') ? SaveLoadManager.loadSystem() : {};
                            root.__skipMode = (sys && sys.textSkip) ? sys.textSkip : 'read';
                        } catch (e) {
                            root.__skipMode = 'read';
                        }
                        try {
                            var curNodeObj = (chapterData && chapterData.nodes) ? chapterData.nodes[currentNode] : null;
                            var curCont = (curNodeObj && curNodeObj.contents) ? curNodeObj.contents[currentContentIndex] : null;
                            var curIsText = curCont && (curCont.type === 'text' || curCont.type === 'title');
                            var isAlreadyRead = !!(readProgress && readProgress[currentChapter] && readProgress[currentChapter][currentNode] !== undefined && readProgress[currentChapter][currentNode] >= currentContentIndex);
                            if (root.__skipMode === 'read' && curIsText && !isAlreadyRead) {
                                // current is unread -> don't start skipping
                            } else {
                                fastForwardTimer.start();
                            }
                        } catch (e2) { fastForwardTimer.start(); }
                        persistLoreState();
                    } else {
                        // disable fast-forward
                        try { fastForwardTimer.stop(); } catch (e) {}
                        persistLoreState();
                    }
                });

                // For compatibility: older code may still emit skipClicked. Map it to a toggle-on event.
                obj.skipClicked.connect(function() {
                    try {
                        // legacy behavior: ensure skip toggled on
                        if (typeof obj.skipActive !== 'undefined') {
                            if (!obj.skipActive) obj.skipToggled(true);
                        } else {
                            obj.skipToggled(true);
                        }
                    } catch (e) { try { obj.skipToggled(true); } catch (ee) {} }
                });

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
            // If loader failed, attempt to log any engine errors visible to console
            if (status === 3) {
                console.log("LoreView: controlBarLoader failed to load. Check QML resource path and resource registration.");
            }
        }
        onVisibleChanged: updateControlBarPos()
        onWidthChanged: updateControlBarPos()
        onHeightChanged: updateControlBarPos()
    }

    // Keep the control bar skipActive in sync with the fastForwardTimer
    Connections {
        target: fastForwardTimer
        function onRunningChanged() {
            try {
                if (controlBarLoader && controlBarLoader.item) controlBarLoader.item.skipActive = fastForwardTimer.running;
                if (fastForwardTimer.running) setAutoMode(false); // ensure auto mode off when skip starts
            } catch (e) {}
        }
    }

    Binding {
        target: scene
        property: "bottomReservedHeight"
        value: (root.isTitleScreen ? 24 : (controlBarLoader.item ? (controlBarLoader.height + 20) : 24))
    }

    // 更新控制条位置：贴在文本框底部中央
    function updateControlBarPos() {
        if (!controlBarLoader.item) {
            console.log("LoreView: updateControlBarPos abort - no controlBarLoader.item");
            return;
        }

        var tb = null;
        try { tb = (scene && scene.textBoxItem) ? scene.textBoxItem : null; } catch (e) { tb = null; }

        var desiredWidth = controlBarLoader.width;
        var desiredHeight = controlBarLoader.height;

        // 若宽度尚未就绪，延迟重试一次
        if (!desiredWidth || desiredWidth === 0) {
            console.log("LoreView: updateControlBarPos delaying - controlBar width not ready");
            Qt.callLater(updateControlBarPos);
            return;
        }

        // 如果 textBox 存在则将控制条贴到 textBox 底部，否则回退到 root 底部中央
        if (tb) {
            try {
                var pt = tb.mapToItem(root, 0, 0);
                controlBarLoader.x = pt.x + (tb.width - desiredWidth)/2;
                controlBarLoader.y = pt.y + tb.height - desiredHeight - 12; // 12px 上留白
                console.log("LoreView: updateControlBarPos -> anchored to textBox at", controlBarLoader.x, controlBarLoader.y, "tb.w", tb.width, "tb.h", tb.height, "pt", pt.x, pt.y, "desiredW/H", desiredWidth, desiredHeight, "loaderItemExists", !!controlBarLoader.item);
            } catch (ePos) {
                console.log("LoreView: updateControlBarPos textBox mapToItem failed", ePos);
                // fallback to bottom center
                controlBarLoader.x = Math.round((root.width - desiredWidth)/2);
                controlBarLoader.y = Math.round(root.height - desiredHeight - 12);
                console.log("LoreView: updateControlBarPos fallback bottom center at", controlBarLoader.x, controlBarLoader.y);
            }
        } else {
            // fallback: position at bottom center of root
            controlBarLoader.x = Math.round((root.width - desiredWidth)/2);
            controlBarLoader.y = Math.round(root.height - desiredHeight - 12);
            console.log("LoreView: updateControlBarPos -> no textBox, placed at bottom center", controlBarLoader.x, controlBarLoader.y, "root size", root.width, root.height);
        }
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
        enabled: !historyPanel.visible && !confirmTitleDialog.visible && !choiceDialog.visible
        onClicked: {
            console.log("LoreView: clicked, advancing content");
            // 点击时也停止标题自动切换计时器
            titleAutoAdvanceTimer.stop();
            // 如果当前文字正在打字，则先完成打字；否则才前进到下一条
            try {
                var tc = getActiveTextComponent();
                if (tc && tc.typing) {
                    try { tc.finishTyping(); } catch(e) { console.log('LoreView: finishTyping failed', e); }
                } else {
                    nextContent();
                    persistLoreState();
                }
            } catch(e) {
                console.log('LoreView: click handling error', e);
                // fallback behavior
                nextContent();
                persistLoreState();
            }
        }
        z: 1000
    }

    // 鼠标滚轮处理器(向下滚动前进)
    WheelHandler {
        target: root
        // Allow wheel events even when choice dialog is visible: we want wheel-up to open history while choices are shown
        enabled: !historyPanel.visible && !confirmTitleDialog.visible
        onWheel: function(event) {
            // 向下滚动时 angleDelta.y < 0
            if (event.angleDelta.y < 0) {
                // If the choice dialog is visible, ignore wheel-down (do not advance)
                if (choiceDialog && choiceDialog.visible) {
                    console.log("LoreView: wheel down ignored while choice dialog visible");
                    return;
                }
                console.log("LoreView: wheel down, advancing content");
                titleAutoAdvanceTimer.stop();
                try {
                    var tcw = getActiveTextComponent();
                    if (tcw && tcw.typing) {
                        try { tcw.finishTyping(); } catch(e) { console.log('LoreView: finishTyping failed', e); }
                    } else {
                        nextContent();
                        persistLoreState();
                    }
                } catch(e) {
                    console.log('LoreView: wheel handling error', e);
                    nextContent();
                    persistLoreState();
                }
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
            // nodeId 可能是 JSON 编码的 {branch,node} 或者纯 nodeId 字符串
            var targetBranch = currentChapter;
            var targetNode = nodeId;
            try {
                if (typeof nodeId === 'string') {
                    var parsed = JSON.parse(nodeId);
                    if (parsed && parsed.node !== undefined) {
                        targetBranch = parsed.branch || currentChapter;
                        targetNode = parsed.node;
                    }
                }
            } catch (eparse) {
                // not JSON, keep as-is
            }

            // 如果目标章节不同，切换章节并加载
            if (targetBranch && targetBranch !== currentChapter) {
                currentChapter = targetBranch;
                loadChapter(currentChapter);
            }

            if (targetNode && chapterData && chapterData.nodes && chapterData.nodes[targetNode]) {
                // 裁剪历史记录到目标位置，避免重复
                historyPanel.trimHistoryTo(nodeId, contentIndex);
                currentNode = targetNode;
                currentContentIndex = contentIndex >= 0 ? contentIndex : 0;
                historyPanel.close();
                // 先更新内容
                showCurrentContent();
                // Ensure any visible choice dialog is hidden after jumping via history
                try { if (choiceDialog && choiceDialog.visible) { choiceDialog.visible = false; choiceDialog.choices = []; } } catch(e) {}
                // 跳转后恢复音乐：回溯历史找到距离当前最近的有效音乐指令（music 或 stopMusic）
                try {
                    var effectiveMusic = null;
                    var effectiveLoops = undefined;
                    var shouldStop = false;
                    // 从后往前扫描历史数组，注意匹配 branch + node + index
                    for (var i = historyPanel.historyData.length - 1; i >= 0; i--) {
                        var h = historyPanel.historyData[i];
                        var hBranch = (h.branch !== undefined) ? h.branch : currentChapter;
                        if (hBranch === currentChapter && h.node === currentNode && h.index === currentContentIndex) {
                            // 当前记录本身也可能包含音乐指令
                        }
                        if (h.stopMusic && hBranch === currentChapter) {
                            shouldStop = true;
                            break;
                        }
                        if (h.music && h.music !== "" && hBranch === currentChapter) {
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

    // 选项对话框（当节点包含 choices 时弹出）
    ChoiceDialog {
        id: choiceDialog
        z: 2500
        anchors.fill: parent
        visible: false
        onChoiceSelected: function(index) {
            console.log("LoreView: choice selected", index);
            try {
                var node = chapterData && chapterData.nodes && chapterData.nodes[currentNode] ? chapterData.nodes[currentNode] : null;
                if (!node || !node.choices || index < 0 || index >= node.choices.length) return;
                var choice = node.choices[index];
                if (!choice || !choice.next) { choiceDialog.visible = false; return; }
                var target = choice.next;
                // case A: next refers to a node in the same chapter
                if (chapterData && chapterData.nodes && chapterData.nodes[target]) {
                    currentNode = target;
                    currentContentIndex = 0;
                    choiceDialog.visible = false;
                    showCurrentContent();
                    // Respect user setting: if optionAutoContinue enabled, resume auto mode
                    try {
                        var autoContinue = false;
                        if (typeof window !== 'undefined' && window.__optionAutoContinue !== undefined) autoContinue = !!window.__optionAutoContinue;
                        else if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager) {
                            var sys = SaveLoadManager.loadSystem() || {};
                            if (sys.optionAutoContinue !== undefined) autoContinue = !!sys.optionAutoContinue;
                        }
                        if (autoContinue) {
                            setAutoMode(true);
                            scheduleAutoAdvance();
                        }
                    } catch(eac) { console.log('LoreView: apply autoContinue read failed', eac); }
                    // Resume fast-forward if it was pending and allowed (and not blocked by unread first content)
                    try {
                        if (root.__ffPendingChoice) {
                            root.__ffPendingChoice = false;
                            // obey skip mode: do not resume if current content is unread in 'read' mode
                            var skipModeA = (root.__skipMode !== undefined && root.__skipMode !== "") ? root.__skipMode : (function(){ try { var s = (typeof SaveLoadManager !== 'undefined' && SaveLoadManager) ? SaveLoadManager.loadSystem() : {}; return (s && s.textSkip) ? s.textSkip : 'read'; } catch(e){ return 'read'; } })();
                            var curNodeObjA = (chapterData && chapterData.nodes) ? chapterData.nodes[currentNode] : null;
                            var curContA = (curNodeObjA && curNodeObjA.contents) ? curNodeObjA.contents[currentContentIndex] : null;
                            var curIsTextA = curContA && (curContA.type === 'text' || curContA.type === 'title');
                            var alreadyA = !!(readProgress && readProgress[currentChapter] && readProgress[currentChapter][currentNode] !== undefined && readProgress[currentChapter][currentNode] >= currentContentIndex);
                            if (!(skipModeA === 'read' && curIsTextA && !alreadyA)) {
                                try { fastForwardTimer.start(); } catch(e) {}
                            }
                        }
                    } catch (erf) { root.__ffPendingChoice = false; }
                    return;
                }
                // case B: next refers to another chapter id (try to load it)
                try {
                    var testPath = ":/qml/window/Lore/chapters/" + target + ".json";
                    var testObj = fileReader.readJsonFile(testPath);
                    if (testObj && testObj.nodes) {
                        // switch to the other chapter
                        currentChapter = target;
                        currentNode = "";
                        currentContentIndex = 0;
                        choiceDialog.visible = false;
                        loadChapter(target);
                        // Respect user setting: if optionAutoContinue enabled, resume auto mode after chapter loads
                        try {
                            var autoContinue2 = false;
                            if (typeof window !== 'undefined' && window.__optionAutoContinue !== undefined) autoContinue2 = !!window.__optionAutoContinue;
                            else if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager) {
                                var sys2 = SaveLoadManager.loadSystem() || {};
                                if (sys2.optionAutoContinue !== undefined) autoContinue2 = !!sys2.optionAutoContinue;
                            }
                            if (autoContinue2) {
                                // loadChapter will call showCurrentContent; schedule re-enabling after a tick
                                Qt.callLater(function() { try { setAutoMode(true); scheduleAutoAdvance(); } catch(e) {} });
                            }
                        } catch(eac2) { console.log('LoreView: apply autoContinue read failed', eac2); }
                        // Resume fast-forward after chapter change if it was pending
                        try {
                            if (root.__ffPendingChoice) {
                                root.__ffPendingChoice = false;
                                Qt.callLater(function() {
                                    try {
                                        var skipModeB = (root.__skipMode !== undefined && root.__skipMode !== "") ? root.__skipMode : (function(){ try { var s = (typeof SaveLoadManager !== 'undefined' && SaveLoadManager) ? SaveLoadManager.loadSystem() : {}; return (s && s.textSkip) ? s.textSkip : 'read'; } catch(e){ return 'read'; } })();
                                        // find first node key
                                        var firstKeyB;
                                        for (var kk in chapterData.nodes) { firstKeyB = kk; break; }
                                        var firstCont = (firstKeyB && chapterData.nodes[firstKeyB] && chapterData.nodes[firstKeyB].contents) ? chapterData.nodes[firstKeyB].contents[0] : null;
                                        var alreadyB = !!(readProgress && readProgress[currentChapter] && readProgress[currentChapter][firstKeyB] !== undefined && readProgress[currentChapter][firstKeyB] >= 0);
                                        if (!(skipModeB === 'read' && firstCont && (firstCont.type === 'text' || firstCont.type === 'title') && !alreadyB)) {
                                            try { fastForwardTimer.start(); } catch(e) {}
                                        }
                                    } catch(e) {}
                                });
                            }
                        } catch (erf2) { root.__ffPendingChoice = false; }
                        return;
                    }
                } catch (e) { /* ignore - not a chapter */ }

                // case C: target may be a battle id (e.g. "battle01") — start battle
                try {
                    if (typeof target === 'string' && (/^battle/i).test(target)) {
                        console.log("LoreView: choice requests battle start:", target);
                        // prefer transition manager
                        try {
                            if (typeof transitionManager !== 'undefined' && typeof transitionManager.startBattle === 'function') {
                                choiceDialog.visible = false;
                                setAutoMode(false);
                                root.__ffPendingChoice = false;
                                transitionManager.startBattle(target);
                                return;
                            }
                        } catch (e2) { console.log('LoreView: transitionManager.startBattle error', e2); }

                        // fallback: set window battle id and switch to GameView
                        try {
                            if (typeof window !== 'undefined') {
                                window.currentBattleId = target;
                                choiceDialog.visible = false;
                                setAutoMode(false);
                                root.__ffPendingChoice = false;
                                if (window.replaceSource) window.replaceSource("qml/window/Game/GameView.qml"); else if (window.pushSource) window.pushSource("qml/window/Game/GameView.qml");
                                return;
                            }
                        } catch (e3) { console.log('LoreView: fallback start battle failed', e3); }
                    }
                } catch (eB) { }

                // unknown target
                console.log("LoreView: choice target not found in current chapter or as chapter:", target);
                choiceDialog.visible = false;
                root.__ffPendingChoice = false;
            } catch (e) { console.log('LoreView: onChoiceSelected error', e); }
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
            // If the active text is still typing, defer advancing until typing finishes.
            var active = null;
            try {
                if (scene && scene.visible) active = scene;
                else if (contentLoader && contentLoader.item) active = contentLoader.item;
            } catch (e) { active = null; }

            if (active && active.typing) {
                // stop main timer and poll until typing finishes, then wait 1s and advance
                autoAdvanceTimer.stop();
                if (!checkTypingTimer.running) checkTypingTimer.start();
                return;
            }
            nextContent();
        }
    }

    // Polling timer used when auto-advance fired but text is still typing
    Timer {
        id: checkTypingTimer
        interval: 200
        repeat: true
        running: false
        onTriggered: {
            var active = null;
            try {
                if (scene && scene.visible) active = scene;
                else if (contentLoader && contentLoader.item) active = contentLoader.item;
            } catch (e) { active = null; }
            if (!active || !active.typing) {
                checkTypingTimer.stop();
                postTypingAdvanceTimer.start();
            }
        }
    }

    // After typing finishes, wait this long (ms) before advancing
    Timer {
        id: postTypingAdvanceTimer
        interval: 1000
        repeat: false
        onTriggered: {
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


    // Backup shortcuts: ensure Enter/Space advance even if focus isn't held
    Shortcut {
        sequence: "Return"
        onActivated: {
            if (historyPanel && historyPanel.visible) return;
            if (confirmTitleDialog && confirmTitleDialog.visible) return;
            if (choiceDialog && choiceDialog.visible) return;
            var tc = getActiveTextComponent();
            if (tc && tc.typing) {
                try { tc.finishTyping(); } catch(e) {}
            } else {
                nextContent();
                persistLoreState();
            }
        }
    }

    Shortcut {
        sequence: "Space"
        onActivated: {
            if (historyPanel && historyPanel.visible) return;
            if (confirmTitleDialog && confirmTitleDialog.visible) return;
            if (choiceDialog && choiceDialog.visible) return;
            var tc = getActiveTextComponent();
            if (tc && tc.typing) {
                try { tc.finishTyping(); } catch(e) {}
            } else {
                nextContent();
                persistLoreState();
            }
        }
    }

    Keys.onPressed: function(event) {
        if (historyPanel && historyPanel.visible) return;
        if (confirmTitleDialog && confirmTitleDialog.visible) return;
        if (choiceDialog && choiceDialog.visible) return;
        if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
            var tc = getActiveTextComponent();
            if (tc && tc.typing) {
                try { tc.finishTyping(); } catch(e) {}
            } else {
                nextContent();
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Control) {
            // If current text is typing, finish it immediately; otherwise start fast-forward
            try {
                var tcctrl = getActiveTextComponent();
                if (tcctrl && tcctrl.typing) {
                    try { tcctrl.finishTyping(); } catch (e) { }
                } else {
                            try {
                                var sys2 = (typeof SaveLoadManager !== 'undefined' && SaveLoadManager && typeof SaveLoadManager.loadSystem === 'function') ? SaveLoadManager.loadSystem() : {};
                                root.__skipMode = (sys2 && sys2.textSkip) ? sys2.textSkip : 'read';
                            } catch (ee) { root.__skipMode = 'read'; }
                            // If current content is a text/title and user chose 'read' skip, do not start skipping now
                            try {
                                var curN = (chapterData && chapterData.nodes) ? chapterData.nodes[currentNode] : null;
                                var curC = (curN && curN.contents) ? curN.contents[currentContentIndex] : null;
                                var curIsT = curC && (curC.type === 'text' || curC.type === 'title');
                                var already = !!(readProgress && readProgress[currentChapter] && readProgress[currentChapter][currentNode] !== undefined && readProgress[currentChapter][currentNode] >= currentContentIndex);
                                if (!(root.__skipMode === 'read' && curIsT && !already)) {
                                    fastForwardTimer.start();
                                }
                            } catch (ee2) { fastForwardTimer.start(); }
                }
            } catch (e) {
                fastForwardTimer.start();
            }
            event.accepted = true;
        }
    }

    Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Control) {
            fastForwardTimer.stop();
            event.accepted = true;
        }
    }

    Timer {
        id: fastForwardTimer
        interval: 200
        repeat: true
        onTriggered: nextContent()
    }
	Shortcut {
		sequence: "Esc"
		onActivated: {
			if (window && window.setFullscreen) window.setFullscreen(false);
			if (typeof fullscreenBtn !== 'undefined') fullscreenBtn.checked = false;
			if (typeof windowBtn !== 'undefined') windowBtn.checked = true;
		}
	}
    // Helper: find active text component (contentLoader item or scene.textBox item)
    function getActiveTextComponent() {
        try {
            if (contentLoader && contentLoader.item) {
                if (typeof contentLoader.item.typing !== 'undefined' || typeof contentLoader.item.finishTyping === 'function') return contentLoader.item;
            }
        } catch(e) {}
        try {
            if (scene) {
                if (typeof scene.typing !== 'undefined' || typeof scene.finishTyping === 'function') return scene;
            }
        } catch(e) {}
        return null;
    }
}

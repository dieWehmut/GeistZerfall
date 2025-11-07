import QtQuick
import "components"

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

    Component.onCompleted: {
        // 从 window 获取章节信息
        if (typeof window !== 'undefined') {
            if (window.currentChapter) {
                currentChapter = window.currentChapter;
            }
            if (window.currentNode) {
                currentNode = window.currentNode;
            }
        }

        // 默认值
        if (!currentChapter) currentChapter = "prologue";

        console.log("LoreView: starting chapter", currentChapter, "node", currentNode);

        // 初始化时遮罩不透明，加载后淡入
        transitionOverlay.opacity = 1;

        // 加载章节数据
        loadChapter(currentChapter);
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

        if (!node.contents || currentContentIndex >= node.contents.length) {
            console.log("LoreView: no more contents in node");
            return;
        }

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
        if (!node || !node.contents || currentContentIndex >= node.contents.length) return;

        var content = node.contents[currentContentIndex];
        // 计算当前模式（内容优先，其次节点，再章节 meta，最后默认 circle）
        var mode = (content.mode ? content.mode : (node.mode ? node.mode : (chapterData.meta && chapterData.meta.mode ? chapterData.meta.mode : "circle")));
        currentMode = mode;

        console.log("LoreView: showing content", currentNode, currentContentIndex, JSON.stringify(content), "mode:", currentMode);

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
            if (content && content.music) {
                if (typeof window !== 'undefined' && typeof window.playMusic === 'function') {
                    var loops = (content.musicLoops !== undefined) ? content.musicLoops : undefined;
                    console.log("LoreView: content requests music", content.music, "loops:", loops);
                    window.playMusic(content.music, loops);
                } else {
                    console.log("LoreView: window.playMusic not available");
                }
            } else if (content && content.stopMusic) {
                if (typeof window !== 'undefined' && typeof window.stopMusic === 'function') {
                    console.log("LoreView: content requests stopMusic");
                    window.stopMusic();
                }
            }
        } catch (e) {
            console.log("LoreView: music switch error", e);
        }

        // 如果是标题画面，2秒后自动切换
        if (content && (content.type === "title" || content.isTitle)) {
            console.log("LoreView: title screen detected, will auto-advance in 2 seconds");
            titleAutoAdvanceTimer.restart();
        } else {
            // 非标题画面，停止计时器
            titleAutoAdvanceTimer.stop();
        }
    }

    // 前进到下一个内容
    function nextContent() {
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

    // 全屏点击区域(左键点击前进)
    MouseArea {
        anchors.fill: parent
        onClicked: {
            console.log("LoreView: clicked, advancing content");
            // 点击时也停止标题自动切换计时器
            titleAutoAdvanceTimer.stop();
            nextContent();
        }
        z: 1000
    }

    // 鼠标滚轮处理器(向下滚动前进)
    WheelHandler {
        target: root
        enabled: !historyPanel.visible  // 历史面板打开时禁用
        onWheel: function(event) {
            // 向下滚动时 angleDelta.y < 0
            if (event.angleDelta.y < 0) {
                console.log("LoreView: wheel down, advancing content");
                titleAutoAdvanceTimer.stop();
                nextContent();
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
                    } else if (effectiveMusic) {
                        if (typeof window !== 'undefined' && typeof window.playMusic === 'function') {
                            console.log("LoreView: restoring effective music after jump", effectiveMusic, "loops:", effectiveLoops);
                            window.playMusic(effectiveMusic, effectiveLoops);
                        }
                    } else {
                        // 没找到显式音乐指令：保持当前播放，不做处理
                        console.log("LoreView: no explicit music directive found for jump target; keeping current music");
                    }
                } catch (e2) {
                    console.log("LoreView: music restore scanning error", e2);
                }
            } else {
                console.log("LoreView: invalid jump target", nodeId);
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

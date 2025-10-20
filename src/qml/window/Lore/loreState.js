// loreState.js - 管理剧情流程

var chapters = {}; // 缓存已加载的章节
var currentChapter = null;
var currentNodeId = null;
var currentIndex = 0;
var actionHandler = null;

// 设置 action 处理器（由 LoreView 注入）
function setActionHandler(fn) {
    actionHandler = fn;
}

// 加载章节 JSON
function loadChapter(chapterName, onLoaded) {
    if (chapters[chapterName]) {
        if (onLoaded) onLoaded(true);
        return;
    }

    var url = Qt.resolvedUrl("chapters/" + chapterName + ".json");
    var xhr = new XMLHttpRequest();
    xhr.open("GET", url);
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200 || xhr.status === 0) { // 0 for local files
                try {
                    chapters[chapterName] = JSON.parse(xhr.responseText);
                    console.log("loreState: loaded chapter", chapterName);
                    if (onLoaded) onLoaded(true);
                } catch (e) {
                    console.log("loreState: parse chapter json error", e);
                    if (onLoaded) onLoaded(false);
                }
            } else {
                console.log("loreState: failed to load chapter", chapterName, xhr.status);
                if (onLoaded) onLoaded(false);
            }
        }
    };
    xhr.send();
}

// 开始章节
function startChapter(chapterName, entryNode, onReady) {
    loadChapter(chapterName, function(success) {
        if (success) {
            currentChapter = chapterName;
            var ch = chapters[chapterName];
            currentNodeId = entryNode || ch.meta.startNode || Object.keys(ch.nodes)[0];
            currentIndex = 0;
            console.log("loreState: started chapter", chapterName, "node", currentNodeId);
            if (onReady) onReady();
        }
    });
}

// 获取当前内容
function getCurrentContent() {
    if (!currentChapter) return null;
    var ch = chapters[currentChapter];
    if (!ch || !ch.nodes) return null;
    var node = ch.nodes[currentNodeId];
    if (!node || !node.contents) return null;
    return node.contents[currentIndex] || null;
}

// 前进到下一个内容或节点
function nextContent() {
    if (!currentChapter) return false;
    var ch = chapters[currentChapter];
    if (!ch || !ch.nodes) return false;
    var node = ch.nodes[currentNodeId];
    if (!node) return false;

    // 如果当前节点还有更多内容
    if (currentIndex < node.contents.length - 1) {
        currentIndex++;
        console.log("loreState: next content index", currentIndex);
        return true;
    }

    // 到达节点末尾
    // 检查是否有 action
    if (node.action) {
        console.log("loreState: triggering action", node.action, node.actionParams);
        if (actionHandler) {
            actionHandler(node.action, node.actionParams || {});
        }
        return false; // action 会改变视图，不继续
    }

    // 检查是否有分支
    if (node.isBranch) {
        console.log("loreState: reached branch node, waiting for choice");
        return false; // 等待用户选择
    }

    // 跳转到下一个节点
    if (node.nextNode) {
        currentNodeId = node.nextNode;
        currentIndex = 0;
        console.log("loreState: moved to next node", currentNodeId);
        return true;
    }

    console.log("loreState: no more content");
    return false;
}

// 选择分支
function selectChoice(choiceIdx) {
    if (!currentChapter) return false;
    var ch = chapters[currentChapter];
    if (!ch || !ch.nodes) return false;
    var node = ch.nodes[currentNodeId];
    if (!node || !node.choices) return false;

    var choice = node.choices[choiceIdx];
    if (choice && choice.next) {
        currentNodeId = choice.next;
        currentIndex = 0;
        console.log("loreState: selected choice", choiceIdx, "->", currentNodeId);
        return true;
    }
    return false;
}

// 重置状态
function reset() {
    currentChapter = null;
    currentNodeId = null;
    currentIndex = 0;
}

// 获取当前节点信息（用于调试）
function getCurrentNodeInfo() {
    return {
        chapter: currentChapter,
        node: currentNodeId,
        index: currentIndex
    };
}

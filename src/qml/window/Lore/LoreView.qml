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
        if (!currentNode) currentNode = "start";

        console.log("LoreView: starting chapter", currentChapter, "node", currentNode);

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

        var content = node.contents[currentContentIndex];
        console.log("LoreView: showing content", currentNode, currentContentIndex, JSON.stringify(content));
        contentLoader.contentData = content;
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
    }

    // 内容加载器（叠加在圆圈上方）
    ContentLoader {
        id: contentLoader
        anchors.centerIn: parent
        width: circle.circleSize * 0.9
        height: circle.circleSize * 0.9
        z: 10
    }

    // 全屏点击区域（左键点击前进）
    MouseArea {
        anchors.fill: parent
        onClicked: {
            console.log("LoreView: clicked, advancing content");
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

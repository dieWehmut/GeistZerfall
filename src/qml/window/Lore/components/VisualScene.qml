import QtQuick
import "characterImageMap.js" as CharMap

// VisualScene.qml - 背景 + 立绘 + 底部文字框
Item {
    id: root
    anchors.fill: parent

    // 节点数据（可包含 background, characters[], textBoxImage 等）
    property var nodeData: null
    // 当前内容（通常为 { type: "text", text: "..." }）
    property var contentData: null
    // typing animation state for scene-mode text
    property string fullText: contentData ? (contentData.text || "") : ""
    property int revealIndex: 0
    property string displayedText: ""
    property bool typing: false
    // 暴露底部文本框，用于外部定位按钮栏
    property alias textBoxItem: textBox
    // 外部可设置的底部预留高度，避免按钮遮挡文本
    property real bottomReservedHeight: 24

    // 背景
    Image {
        id: bg
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        source: (root.nodeData && root.nodeData.background) ? root.nodeData.background : ""
        visible: source !== ""
    }

    // 无背景时的降级底色
    Rectangle {
        anchors.fill: parent
        color: "#101010"
        visible: !bg.visible
    }

    // 立绘层（按 characters 数组渲染）
    Repeater {
        id: charRepeater
        model: (root.nodeData && root.nodeData.characters) ? root.nodeData.characters : []
        delegate: Item {
            width: parent ? parent.width : 0
            height: parent ? parent.height : 0
            // whether to show portrait image for this character instance
            // - can be controlled per-content via content.showPortrait (false -> hide all portraits for line)
            // - OR per-character via character model { showPortrait: false }
            property bool showPortrait: (root.contentData && root.contentData.hasOwnProperty('showPortrait')) ? root.contentData.showPortrait : (modelData && modelData.hasOwnProperty('showPortrait') ? modelData.showPortrait : true)
            // 立绘图片
            Image {
                id: ch
                source: root.getCharacterImage(modelData)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                // 默认高度占屏幕高度的 ~80%
                height: parent.height * 0.8
                width: height * (implicitWidth > 0 ? implicitWidth/implicitHeight : 0.6)
                anchors.verticalCenter: parent.verticalCenter

                // visibility -- portrait can be hidden (but name badge still follows the character position)
                visible: showPortrait

                // 位置：left/center/right（可用 x/y 覆盖）
                anchors.horizontalCenter: undefined
                anchors.left: undefined
                anchors.right: undefined
                anchors.bottom: undefined

                Component.onCompleted: {
                    // default position: center if position not specified
                    var pos = modelData && modelData.position ? modelData.position : "center";
                    // If only a single character exists, ensure the model has a position set to 'center'
                    if ((!modelData || modelData.position === undefined) && root.nodeData && root.nodeData.characters && root.nodeData.characters.length === 1) {
                        // set on modelData (this will update the underlying nodeData.characters entry)
                        if (modelData) modelData.position = "center";
                        pos = "center";
                    }
                    if (pos === "left") {
                        anchors.left = parent.left
                        anchors.margins = parent.width * 0.06
                    } else if (pos === "right") {
                        anchors.right = parent.right
                        anchors.margins = parent.width * 0.06
                    } else { // center
                        anchors.horizontalCenter = parent.horizontalCenter
                    }

                    if (modelData && (modelData.x !== undefined)) ch.x = modelData.x
                    if (modelData && (modelData.y !== undefined)) ch.y = modelData.y
                    if (modelData && (modelData.scale !== undefined)) ch.scale = modelData.scale

                    // 注册到 root 的实例数组，便于外部定位 name badge
                    if (!root.characterInstances) root.characterInstances = [];
                    root.characterInstances[index] = ch;
                    // 尝试调整 badge 位置
                    if (root.adjustBadgePosition) Qt.callLater(root.adjustBadgePosition);
                }

                Component.onDestruction: {
                    if (root.characterInstances) root.characterInstances[index] = null;
                }
            }
        }
    }

    // 存放立绘 image 实例的数组（由 delegate 填充）
    property var characterInstances: []

    // Use the shared JS mapping file for character images (included at file top)

    // 根据角色定义获取图片路径（支持仅用 name 或完整定义），使用共享 characterImageMap.js
    function getCharacterImage(charData) {
        // charData is usually an object from nodeData.characters, but some places pass just the name string
        return CharMap.getCharacterImageFor(charData);
    }

    // Resolve a display name for a content's speaker which can be index number or string
    function getSpeakerDisplayName(content) {
        if (!content) return "";
        // content.speakerName takes precedence (line override)
        // else if speaker is an index, check the character model's speakerName property (character-level override)
        if (content.speakerName) return content.speakerName;
        if (content.speaker !== undefined) {
            if (typeof content.speaker === 'number') {
                var idx = content.speaker;
                if (root.nodeData && root.nodeData.characters && root.nodeData.characters.length > idx) {
                    var ch = root.nodeData.characters[idx];
                    // prefer model-specific speakerName override if provided on character definition
                    if (ch && ch.speakerName) return ch.speakerName;
                    if (ch && ch.name) return ch.name;
                }
                return "";
            } else if (typeof content.speaker === 'string') {
                // string can be either a character name or a custom label; preserve it
                // if a matching character entry defines a model-specific speakerName, prefer that
                try {
                    if (root.nodeData && root.nodeData.characters) {
                        for (var i = 0; i < root.nodeData.characters.length; ++i) {
                            var cn = root.nodeData.characters[i];
                            if (cn && cn.name === content.speaker) {
                                if (cn.speakerName) return cn.speakerName;
                                break;
                            }
                        }
                    }
                } catch (e) {}
                return content.speaker;
            }
        }
        return "";
    }

    // 调整 name badge 位置以更精确贴合角色立绘
    function adjustBadgePosition() {
        try {
            if (!nameBadge.visible) return;
            var pos = nameBadge.speakerPosition;
            // 支持 speaker 为 number 或 string，如果为 string 且匹配 characters.name 则按索引对齐
            if (root.contentData && root.contentData.speaker !== undefined) {
                var si = root.contentData.speaker;
                var idxToUse = undefined;
                if (typeof si === 'number') idxToUse = si;
                else if (typeof si === 'string') {
                    // find matching character by name
                    try {
                        if (root.nodeData && root.nodeData.characters) {
                            for (var i = 0; i < root.nodeData.characters.length; ++i) {
                                var cn = root.nodeData.characters[i];
                                if (cn && cn.name === si) { idxToUse = i; break; }
                            }
                        }
                    } catch (e) {}
                }
                if (idxToUse !== undefined && root.characterInstances && root.characterInstances.length > idxToUse && root.characterInstances[idxToUse]) {
                    var inst = root.characterInstances[idxToUse];
                    // mapToItem to get inst position relative to root
                    var pt = inst.mapToItem(root, 0, 0);
                    // align near the top of textBox and horizontally near the character image
                    // place badge centered at the character image's center X by default
                    var targetX = pt.x + inst.width/2 - nameBadge.width/2;
                    // clamp to screen edges
                    targetX = Math.max(8, Math.min(root.width - nameBadge.width - 8, targetX));
                    nameBadge.x = targetX;
                    return;
                }
            }

            // fallback: previous anchor-based adjustPosition
            nameBadge.adjustPosition();
        } catch (e) { console.log("VisualScene.adjustBadgePosition error", e); }
    }

    // 底部文字框
    Rectangle {
        id: textBox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * 0.28
        z: 100
        visible: !!( !(root.contentData && (root.contentData.type === "title" || root.contentData.isTitle)) )
        
        // 白色背景
        color: "#F5F5F5"
        border.color: "#CCCCCC"
        border.width: 2
        radius: 8

        // 若提供图片，作为文字框背景覆盖白色背景
        Image {
            id: textBoxBgImg
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            source: (root.nodeData && root.nodeData.textBoxImage) ? root.nodeData.textBoxImage : ""
            visible: source !== ""
            z: 1
        }

        // 文本内容（左对齐名字标签，从 name badge 下方开始）
        Text {
            id: textContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: nameBadge.visible ? root.width * 0.15 : 24
            anchors.rightMargin: 24
            anchors.topMargin: nameBadge.visible ? 48 : 24
            anchors.bottomMargin: Math.max(root.bottomReservedHeight, 24)
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignTop
            color: "#222222"
            font.pixelSize: Math.max(20, parent.height * 0.11)
            lineHeight: 1.3
            text: displayedText
            z: 2
        }
    }


    // Use per-character interval so each character is displayed for window.__textSpeed seconds
    function _sceneCalcCharIntervalMs() {
        var seconds = (typeof window !== 'undefined' && window.__textSpeed) ? Number(window.__textSpeed) : 0.03;
        var ms = Math.round(seconds * 1000);
        if (ms < 8) ms = 8;
        return ms;
    }

    Timer {
        id: sceneTypingTimer
        interval: _sceneCalcCharIntervalMs()
        repeat: true
        running: false
        onTriggered: {
            try {
                revealIndex = Math.min(fullText.length, revealIndex + 1);
                displayedText = fullText.substring(0, revealIndex);
                if (revealIndex >= fullText.length) {
                    typing = false;
                    sceneTypingTimer.stop();
                }
            } catch(e) { console.log('sceneTypingTimer error', e); }
        }
    }

    onContentDataChanged: {
        fullText = contentData ? (contentData.text || "") : "";
        revealIndex = 0;
        displayedText = "";
        if (fullText && fullText.length > 0) {
            typing = true;
            var seconds = (typeof window !== 'undefined' && window.__textSpeed) ? Number(window.__textSpeed) : 0.03;
            sceneTypingTimer.interval = Math.max(8, Math.round(seconds * 1000));
            sceneTypingTimer.start();
        } else {
            typing = false;
            sceneTypingTimer.stop();
        }
    }

    function finishTyping() {
        try {
            sceneTypingTimer.stop();
            displayedText = fullText;
            revealIndex = fullText.length;
            typing = false;
        } catch(e) {}
    }

    // 角色名标签（紧贴文字框上方，并根据说话角色靠左/居中/靠右）
    Rectangle {
        id: nameBadge
        width: Math.min(parent.width * 0.35, 260)
        height: 36
        radius: 6
        color: "#CC000000"
        border.color: "#88FFFFFF"
        border.width: 1
        visible: !!(root.contentData && (root.contentData.speakerName || root.contentData.speaker !== undefined))
        anchors.bottom: textBox.top
        anchors.bottomMargin: -6
        y: textBox.y - height - 6
        z: 80

        // 动态水平定位：优先根据 speaker index -> nodeData.characters[position]
        property string speakerPosition: {
            var s = "center";
            if (root.contentData) {
                if (root.contentData.speakerName) s = (root.contentData.speakerPos ? root.contentData.speakerPos : s);
                else if (root.contentData.speaker !== undefined) {
                    if (typeof root.contentData.speaker === 'number') {
                        if (root.nodeData && root.nodeData.characters && root.nodeData.characters.length > root.contentData.speaker) {
                            var ch = root.nodeData.characters[root.contentData.speaker];
                            if (ch && ch.position) s = ch.position;
                        }
                    } else if (typeof root.contentData.speaker === 'string') {
                        // if speaker string matches a character, use its position
                        try {
                            if (root.nodeData && root.nodeData.characters) {
                                for (var pi = 0; pi < root.nodeData.characters.length; ++pi) {
                                    var cn = root.nodeData.characters[pi];
                                    if (cn && cn.name === root.contentData.speaker && cn.position) { s = cn.position; break; }
                                }
                            }
                        } catch (e) {}
                    }
                }
            }
            return s;
        }

        // 根据 speakerPosition 调整水平锚点
        Component.onCompleted: adjustPosition();
        onVisibleChanged: adjustPosition();
        function adjustPosition() {
            // clear anchors
            anchors.left = undefined; anchors.right = undefined; anchors.horizontalCenter = undefined;
            var pos = speakerPosition;
            if (pos === "left") {
                anchors.left = parent.left; anchors.leftMargin = parent.width * 0.15
            } else if (pos === "right") {
                anchors.right = parent.right; anchors.rightMargin = parent.width * 0.15
            } else {
                anchors.horizontalCenter = parent.horizontalCenter
            }
        }

        Text {
            id: nameText
            anchors.centerIn: parent
            color: "#FFFFFF"
            font.bold: true
            font.pixelSize: 16
            text: getSpeakerDisplayName(root.contentData)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            z: 85
        }
    }

    // 居中大标题（用于章节标题画面）
    Item {
        id: titleContainer
        anchors.fill: parent
        visible: !!(root.contentData && (root.contentData.type === "title" || root.contentData.isTitle))
        z: 60

        // 半透明遮罩（可选）
        Rectangle {
            anchors.fill: parent
            color: "#00000000"
            visible: true
        }

        Text {
            id: titleText
            text: (root.contentData && root.contentData.text) ? root.contentData.text : (root.nodeData && root.nodeData.title ? root.nodeData.title : "")
            anchors.centerIn: parent
            color: "#FFFFFF"
            font.pixelSize: Math.max(28, parent.height * 0.12)
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.NoWrap
            z: 70
        }
    }
}

import QtQuick
// 全屏组件不参与 Android 缩放（保持充满屏幕）
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
            // Default behavior: if neither content nor model specify showPortrait, portraits are visible.
            property bool showPortrait: (function() {
                try {
                    if (root.contentData && root.contentData.showPortrait !== undefined) return !!root.contentData.showPortrait;
                    if (modelData && modelData.showPortrait !== undefined) return !!modelData.showPortrait;
                } catch(e) {}
                return true;
            })()
            // 立绘图片
            Image {
                id: ch
                source: root.getCharacterImage(modelData)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                // 默认高度占屏幕高度的 ~80%，图片底部与窗口底部对齐，间距为0
                height: parent.height * 0.8
                width: height * (implicitWidth > 0 ? implicitWidth/implicitHeight : 0.6)
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 0

                // visibility -- portrait can be hidden (but name badge still follows the character position)
                // only show if portrait explicitly allowed and an image source is available
                visible: showPortrait && source !== ""

                // 位置：left/center/right（可用 x/y 覆盖）
                anchors.horizontalCenter: undefined
                anchors.left: undefined
                anchors.right: undefined

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

    // adjustBadgePosition is no-op now that speaker name is shown inside the text box
    function adjustBadgePosition() {
        return;
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
        
        // 白色背景, use window.__textBoxOpacity to control alpha
        color: Qt.rgba(0.96, 0.96, 0.96, (typeof window !== 'undefined' && window.__textBoxOpacity !== undefined ? Number(window.__textBoxOpacity) : 1.0))
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
            // also apply the same opacity to any background image
            opacity: (typeof window !== 'undefined' && window.__textBoxOpacity !== undefined ? Number(window.__textBoxOpacity) : 1.0)
            z: 1
        }

        // Inline speaker name displayed above the text lines, left-aligned with the first line
        Text {
            id: speakerNameText
            text: getSpeakerDisplayName(root.contentData)
            visible: !!(root.contentData && (root.contentData.speakerName || root.contentData.speaker !== undefined))
            color: "#333333"
            // 缩小说话者姓名字号以匹配更紧凑的正文
            font.pixelSize: Math.max(14, textBox.height * 0.08)
            font.bold: true
            anchors.left: parent.left
            z: 3
            // left margin will be set via textBox.effectiveLeftMargin (keeps text start consistent whether speaker exists or not)
            anchors.leftMargin: textBox.effectiveLeftMargin
            anchors.top: parent.top
            anchors.topMargin: 8
        }

        // 文本内容（左对齐名字标签，从 name badge 下方开始）
        Text {
            id: textContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            // Always use the same left margin so text start aligns whether a speaker exists or not
            anchors.leftMargin: textBox.effectiveLeftMargin
            anchors.rightMargin: 24
            // increase vertical gap between speaker name and first text line slightly
            anchors.topMargin: (speakerNameText.visible ? (speakerNameText.height + 8) : 16)
            anchors.bottomMargin: Math.max(root.bottomReservedHeight, 16)
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignTop
            color: "#222222"
            // 进一步减小字号与行距，让文本更紧凑
            font.pixelSize: Math.max(12, parent.height * 0.075)
            lineHeight: 0.8
            text: displayedText
            z: 2
        }
        // effective left margin used for speaker name and the main text so they start at identical x
        property real effectiveLeftMargin: (root.width * 0.15)

        // Opening quote positioned one character to the left of the text start so the speaker name and
        // the text body visually align. Visible only when a speaker is present.
        Text {
            id: openQuote
            text: "「"
            visible: !!(root.contentData && (root.contentData.speakerName || root.contentData.speaker !== undefined))
            font.pixelSize: textContent.font.pixelSize
            color: textContent.color
            y: textContent.y
            z: 4
            // position one character left of the main text start
            x: textContent.x - (textContent.font.pixelSize || 14)
        }
    }


    // Use per-character interval so each character is displayed for window.__textSpeed seconds
    function _sceneCalcCharIntervalMs() {
        var seconds = (typeof window !== 'undefined' && window.__textSpeed) ? Number(window.__textSpeed) : 0.008;
        var ms = Math.round(seconds * 1000);
        // clamp to 1ms - 35ms to match slider bounds
        if (ms < 1) ms = 1;
        if (ms > 35) ms = 35;
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
        // If a speaker is present, show the full text wrapped in corner quotes so the typing effect includes them
        var hasSpeaker = contentData && (contentData.speakerName || contentData.speaker !== undefined);
        fullText = contentData ? ((hasSpeaker ? ( (contentData.text || "") + "」") : (contentData.text || ""))) : "";
        revealIndex = 0;
        displayedText = "";
        if (fullText && fullText.length > 0) {
            // Honor global "skip all" setting: reveal instantly
            if (typeof window !== 'undefined' && window.__textSkip === 'all') {
                finishTyping();
                return;
            }

            // If SKIP requested next instant display, honor and clear the flag
            if (typeof window !== 'undefined' && window.__skipInstantNext) {
                window.__skipInstantNext = false;
                finishTyping();
                return;
            }

            typing = true;
            var seconds = (typeof window !== 'undefined' && window.__textSpeed) ? Number(window.__textSpeed) : 0.008;
            var ms = Math.round(seconds * 1000);
            if (ms < 1) ms = 1;
            if (ms > 35) ms = 35;
            sceneTypingTimer.interval = ms;
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

    // NOTE: nameBadge removed. Speaker name is displayed inside the text box now.

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

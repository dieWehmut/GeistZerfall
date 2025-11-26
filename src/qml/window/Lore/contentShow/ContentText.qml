import QtQuick

// Text.qml - 文字内容显示
Item {
    id: root
    anchors.fill: parent

    property var contentData: null
    // Internal typing animation state
    property string fullText: contentData ? (contentData.text || "") : ""
    property int revealIndex: 0
    property string displayedText: ""
    property bool typing: false

    Component.onCompleted: {
        console.log("Text.qml: component completed, contentData =", contentData ? JSON.stringify(contentData) : "null");
    }

    onContentDataChanged: {
        fullText = contentData ? (contentData.text || "") : "";
        revealIndex = 0;
        displayedText = "";
        // start typing if there's text
        if (fullText && fullText.length > 0) {
            typing = true;
            // compute milliseconds per character from global seconds setting (window.__textSpeed)
            var seconds = (typeof window !== 'undefined' && window.__textSpeed) ? Number(window.__textSpeed) : 0.03;
            var iv = Math.max(8, Math.round(seconds * 1000));
            typingTimer.interval = iv;
            typingTimer.start();
        } else {
            typing = false;
            typingTimer.stop();
        }
        console.log("Text.qml: contentData changed, start typing length=", fullText.length);
    }

    // Use per-character interval so each character is displayed for window.__textSpeed seconds
    function _calcCharIntervalMs() {
        var seconds = (typeof window !== 'undefined' && window.__textSpeed) ? Number(window.__textSpeed) : 0.03;
        var ms = Math.round(seconds * 1000);
        if (ms < 8) ms = 8;
        return ms;
    }

    // Finish instantly (reveal all)
    function finishTyping() {
        typingTimer.stop();
        displayedText = fullText;
        revealIndex = fullText.length;
        typing = false;
    }

    Timer {
        id: typingTimer
        interval: _calcCharIntervalMs()
        repeat: true
        running: false
        onTriggered: {
            try {
                revealIndex = Math.min(fullText.length, revealIndex + 1);
                displayedText = fullText.substring(0, revealIndex);
                if (revealIndex >= fullText.length) {
                    typing = false;
                    typingTimer.stop();
                }
            } catch(e) { console.log('typingTimer error', e); }
        }
    }

    Text {
        id: textItem
        anchors.centerIn: parent
        text: displayedText
        font.pixelSize: 24
        color: "black"
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        width: parent.width * 0.8

        Component.onCompleted: {
            console.log("Text component: initial text =", text);
        }

        // subtle fade-in for the whole control (keeps per-char instant)
        opacity: 0
        NumberAnimation on opacity {
            from: 0
            to: 1
            duration: 250
            running: true
        }
    }
}

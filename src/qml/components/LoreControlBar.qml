import QtQuick

// LoreControlBar.qml - 剧情界面底部按钮栏
Item {
    id: root
    property bool autoEnabled: false
    // whether skip (fast-forward) is active
    property bool skipActive: false

    onAutoEnabledChanged: {
        if (autoButton.checked !== autoEnabled) {
            autoButton.checked = autoEnabled;
        }
        // Ensure Auto and Skip are mutually exclusive
        if (autoEnabled) {
            skipActive = false;
        }
    }
    onSkipActiveChanged: {
        if (skipButton && skipButton.checked !== skipActive) skipButton.checked = skipActive;
        if (skipActive) {
            autoEnabled = false;
        }
    }

    Component.onCompleted: {
        autoButton.checked = autoEnabled
        if (skipButton) skipButton.checked = skipActive
    }

    signal settingsClicked()
    signal autoToggled(bool enabled)
    signal skipClicked()
    signal skipToggled(bool enabled)
    signal historyClicked()
    signal saveClicked()
    signal loadClicked()
    signal titleClicked()

    width: controlRow.implicitWidth
    height: controlRow.implicitHeight
    visible: true

    Row {
        id: controlRow
        anchors.centerIn: parent
        spacing: 18

        // 设置（使用文本变体强制单色）
        LoreControlButton {
            iconText: "\u2630" // ☰ (menu)
            text: "MENU"
            onClicked: root.settingsClicked()
        }

        // 自动
        LoreControlButton {
            id: autoButton
            iconText: "\u25B6" // ► (single triangle — half of skip)
            text: "AUTO"
            checkable: true
            checked: root.autoEnabled
            onClicked: {
                root.autoEnabled = autoButton.checked;
                root.autoToggled(root.autoEnabled);
            }
        }

        // 快进（黑色实心双三角 -> 使用两个单色三角以确保单色显示）
        LoreControlButton {
            id: skipButton
            iconText: "\u25B6\u25B6"
            text: "SKIP"
            checkable: true
            checked: root.skipActive
            onClicked: {
                // when user clicks, update internal state and emit toggled event.
                root.skipActive = !!skipButton.checked;
                root.skipToggled(root.skipActive);
            }
        } // ►► (two black triangles)

        // 历史（单色符号）
        LoreControlButton { iconText: "\u270E"; text: "LOG"; onClicked: root.historyClicked() } // ✎ (pencil, monochrome)

        // 保存（单色符号）
        LoreControlButton { iconText: "\u2399"; text: "SAVE"; onClicked: root.saveClicked() } // ⎙ (monochrome symbol)

        // 读取（单色符号，使用 U+2398 旋转 90° 以指向下方）
        LoreControlButton { iconText: "\u2398"; iconRotation: 90; text: "LOAD"; onClicked: root.loadClicked() } // ⎘ rotated 90° → points down

        // Title（更换为单色方框符号，稍微上移并放大）
        LoreControlButton { iconText: "\u25A3"; iconYOffset: -3; iconScale: 1.08; text: "TITLE"; onClicked: root.titleClicked() } // ▣ (monochrome square)

        // Status text to the right of Title button — shown when Auto or Skip mode is active
        Text {
            id: modeStatusText
            verticalAlignment: Text.AlignVCenter
            color: "#000000"
            font.bold: true
            font.pixelSize: 16
            text: root.skipActive ? "Skip..." : (root.autoEnabled ? "Auto..." : "")
            visible: (root.skipActive || root.autoEnabled) && text !== ""
        }
    }
}

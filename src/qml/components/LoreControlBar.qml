import QtQuick

// LoreControlBar.qml - 剧情界面底部按钮栏
Item {
    id: root
    property bool autoEnabled: false

    onAutoEnabledChanged: {
        if (autoButton.checked !== autoEnabled) {
            autoButton.checked = autoEnabled;
        }
    }

    Component.onCompleted: autoButton.checked = autoEnabled

    signal settingsClicked()
    signal autoToggled(bool enabled)
    signal skipClicked()
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
        LoreControlButton { iconText: "\u25B6\u25B6"; text: "SKIP"; onClicked: root.skipClicked() } // ►► (two black triangles)

        // 历史（单色符号）
        LoreControlButton { iconText: "\u270E"; text: "LOG"; onClicked: root.historyClicked() } // ✎ (pencil, monochrome)

        // 保存（单色符号）
        LoreControlButton { iconText: "\u2399"; text: "SAVE"; onClicked: root.saveClicked() } // ⎙ (monochrome symbol)

        // 读取（单色符号，使用 U+2398 旋转 90° 以指向下方）
        LoreControlButton { iconText: "\u2398"; iconRotation: 90; text: "LOAD"; onClicked: root.loadClicked() } // ⎘ rotated 90° → points down

        // Title（更换为单色方框符号，稍微上移并放大）
        LoreControlButton { iconText: "\u25A3"; iconYOffset: -3; iconScale: 1.08; text: "TITLE"; onClicked: root.titleClicked() } // ▣ (monochrome square)
    }
}

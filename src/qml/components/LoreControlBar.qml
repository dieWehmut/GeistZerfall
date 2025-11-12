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
            iconText: "\u2699\uFE0E" // ⚙︎
            onClicked: root.settingsClicked()
        }

        // 自动
        LoreControlButton {
            id: autoButton
            iconText: "\u27F3" // ⟳
            checkable: true
            checked: root.autoEnabled
            onClicked: {
                root.autoEnabled = autoButton.checked;
                root.autoToggled(root.autoEnabled);
            }
        }

        // 快进
        LoreControlButton { iconText: "\u226B"; onClicked: root.skipClicked() } // ≫

        // 历史
        LoreControlButton { iconText: "\u24BD"; onClicked: root.historyClicked() } // Ⓗ

        // 保存
        LoreControlButton { iconText: "\u24C8"; onClicked: root.saveClicked() } // Ⓢ

        // 读取
        LoreControlButton { iconText: "\u24C1"; onClicked: root.loadClicked() } // Ⓛ

        // Title
        LoreControlButton { iconText: "\u24C9"; onClicked: root.titleClicked() } // Ⓣ
    }
}

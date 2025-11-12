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

        LoreControlButton {
            iconText: "\u2699"
            onClicked: root.settingsClicked()
        }

        LoreControlButton {
            id: autoButton
            iconText: "\u27F3"
            checkable: true
            checked: root.autoEnabled
            onClicked: {
                root.autoEnabled = autoButton.checked;
                root.autoToggled(root.autoEnabled);
            }
        }

        LoreControlButton {
            iconText: "\u23E9"
            onClicked: root.skipClicked()
        }

        LoreControlButton {
            iconText: "\uD83D\uDCD6"
            onClicked: root.historyClicked()
        }

        LoreControlButton {
            iconText: "\uD83D\uDCBE"
            onClicked: root.saveClicked()
        }

        LoreControlButton {
            iconText: "\u2B07"
            onClicked: root.loadClicked()
        }

        LoreControlButton {
            iconText: "\u2302"
            onClicked: root.titleClicked()
        }
    }
}

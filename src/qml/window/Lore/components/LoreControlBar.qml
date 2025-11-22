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
            iconText: "\u2630"
            text: "MENU"
            onClicked: root.settingsClicked()
        }

        LoreControlButton {
            id: autoButton
            iconText: "\u25B6"
            text: "AUTO"
            checkable: true
            checked: root.autoEnabled
            onClicked: {
                root.autoEnabled = autoButton.checked;
                root.autoToggled(root.autoEnabled);
            }
        }

        LoreControlButton {
            iconText: "\u25B6\u25B6"
            text: "SKIP"
            onClicked: root.skipClicked()
        }

        LoreControlButton {
            iconText: "\u270E"
            text: "LOG"
            onClicked: root.historyClicked()
        }

        LoreControlButton {
            iconText: "\u2399"
            text: "SAVE"
            onClicked: root.saveClicked()
        }

        LoreControlButton {
            iconText: "\u2398"
            iconRotation: 90
            text: "LOAD"
            onClicked: root.loadClicked()
        }

        LoreControlButton {
            iconText: "\u25A3"
            iconYOffset: -3
            iconScale: 1.08
            text: "TITLE"
            onClicked: root.titleClicked()
        }
    }
}

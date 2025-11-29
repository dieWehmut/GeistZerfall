import QtQuick

// LoreControlBar.qml - 剧情界面底部按钮栏
Item {
    id: root
    property bool autoEnabled: false
    property bool skipActive: false

    onAutoEnabledChanged: {
        if (autoButton.checked !== autoEnabled) {
            autoButton.checked = autoEnabled;
        }
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
        // Debug: report sizes so LoreView can position correctly
        try {
            console.log("LoreControlBar: completed -> width:", root.width, "height:", root.height, "implicitW:", controlRow.implicitWidth, "implicitH:", controlRow.implicitHeight, "childrenRectW:", controlRow.childrenRect ? controlRow.childrenRect.width : 0, "childrenRectH:", controlRow.childrenRect ? controlRow.childrenRect.height : 0);
        } catch(e) {}
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
            id: skipButton
            iconText: "\u25B6\u25B6"
            text: "SKIP"
            checkable: true
            checked: root.skipActive
            onClicked: {
                root.skipActive = !!skipButton.checked;
                root.skipToggled(root.skipActive);
            }
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

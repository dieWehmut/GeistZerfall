import QtQuick
import QtQuick.Controls
import "../../../components" // ensure AppButton is available and uses the shared style

// ChoiceDialog.qml - 选项对话框
Item {
    id: root
    anchors.fill: parent
    visible: false

    property var choices: []
    signal choiceSelected(int index)

    // 半透明遮罩
    Rectangle {
        anchors.fill: parent
        color: "#80000000"
        
        MouseArea {
            anchors.fill: parent
            onClicked: function(mouse) {
                // Allow clicks on the control bar to pass through so LoreControlButton remains clickable
                try {
                    // 'root' is the ChoiceDialog Item; its parent is the LoreView instance
                    var loreView = root.parent;
                    if (loreView && loreView.controlBarLoader) {
                        var cb = loreView.controlBarLoader;
                        // mouse.x/y are in this MouseArea's coordinates which match the view coordinates
                        var inCbX = (mouse.x >= cb.x && mouse.x <= (cb.x + cb.width));
                        var inCbY = (mouse.y >= cb.y && mouse.y <= (cb.y + cb.height));
                        if (inCbX && inCbY) {
                            // don't accept the event so it can pass through to the control bar below
                            mouse.accepted = false;
                            return;
                        }
                    }
                } catch (e) {
                    console.log('ChoiceDialog: overlay click passthrough check failed', e);
                }
                // Otherwise, accept to prevent clicks from passing through
                mouse.accepted = true;
            }
        }
    }

    // 选项容器（自适应宽度、按钮居中）
    Rectangle {
        width: Math.min(parent.width * 0.9, 560)
        height: Math.min(choices.length * 80 + 40, parent.height * 0.6)
        anchors.centerIn: parent
        color: "#CC000000"
        border.color: "#FFFFFF"
        border.width: 2
        radius: 10

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 40
            spacing: 20

            Repeater {
                model: choices

                AppButton {
                    text: modelData.text || ""
                    // responsive width so dialog and button widths play nicely on different resolutions
                    width: Math.min(parent.width - 40, 420)
                    height: 60
                    fontPixelSize: 20
                    anchors.horizontalCenter: parent.horizontalCenter
                    onClicked: {
                        console.log("ChoiceDialog: selected choice", index);
                        root.choiceSelected(index);
                        root.visible = false;
                    }
                }
            }
        }
    }
}

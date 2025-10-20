import QtQuick
import QtQuick.Controls

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
            onClicked: {
                // 阻止点击穿透
            }
        }
    }

    // 选项容器
    Rectangle {
        width: 400
        height: Math.min(choices.length * 80 + 40, parent.height * 0.6)
        anchors.centerIn: parent
        color: "#CC000000"
        border.color: "#AA0000"
        border.width: 2
        radius: 10

        Column {
            anchors.centerIn: parent
            spacing: 20

            Repeater {
                model: choices

                Button {
                    text: modelData.text || ""
                    width: 360
                    height: 60
                    font.pixelSize: 20

                    background: Rectangle {
                        color: parent.hovered ? "#AA0000" : "#660000"
                        border.color: "#FF0000"
                        border.width: 1
                        radius: 5
                    }

                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font: parent.font
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

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

import QtQuick
// 在组件内部实例化 UiScale 以获取统一缩放
import QtQuick.Controls
import "../../../components" // ensure AppButton is available and uses the shared style

// ChoiceDialog.qml - 选项对话框
Item {
    // 全局缩放：Android 上统一缩小到 0.8（与其它组件一致）
    UiScale { id: uiScaleHelper }
    property real uiScale: uiScaleHelper.uiScale
    scale: uiScale
    // 平台检测
    property bool isAndroid: (Qt.platform && Qt.platform.os ? (Qt.platform.os.toLowerCase() === 'android') : false)
    id: root
    anchors.fill: parent
    visible: false

    property var choices: []
    signal choiceSelected(int index)

    // 半透明遮罩（Android 不显示）
    Rectangle {
        anchors.fill: parent
        visible: !isAndroid
        color: "#80000000"
        MouseArea {
            anchors.fill: parent
            enabled: !isAndroid
            onClicked: function(mouse) {
                try {
                    var loreView = root.parent;
                    if (loreView && loreView.controlBarLoader) {
                        var cb = loreView.controlBarLoader;
                        var inCbX = (mouse.x >= cb.x && mouse.x <= (cb.x + cb.width));
                        var inCbY = (mouse.y >= cb.y && mouse.y <= (cb.y + cb.height));
                        if (inCbX && inCbY) { mouse.accepted = false; return; }
                    }
                } catch (e) { console.log('ChoiceDialog: overlay click passthrough check failed', e); }
                mouse.accepted = true;
            }
        }
    }

    // 选项容器
    // Android：不显示黑色背景框，仅居中显示选项按钮
    // 桌面：保留半透明背景框
    Item {
        anchors.centerIn: parent
        width: isAndroid ? Math.min(parent.width * 0.9, 560) : Math.min(parent.width * 0.9, 560)
        height: isAndroid ? Math.min(choices.length * 80 + 40, parent.height * 0.6) : Math.min(choices.length * 80 + 40, parent.height * 0.6)

        // 背景框（桌面显示，Android 隐藏）
        Rectangle {
            anchors.fill: parent
            visible: !isAndroid
            color: "#CC000000"
            border.color: "#FFFFFF"
            border.width: 2
            radius: 10
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 40
            spacing: 16

            Repeater {
                model: choices

                AppButton {
                    text: modelData.text || ""
                    width: Math.min(parent.width - 40, 420)
                    height: 56
                    fontPixelSize: 18
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

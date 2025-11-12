import QtQuick

// LoreControlButton.qml - 圆形图标按钮，用于剧情控制栏
Item {
    id: root
    width: 52
    height: 52

    property string iconText: ""
    property bool checkable: false
    property bool checked: false
    property bool enabled: true
    signal clicked()

    readonly property bool __active: pressArea.pressed || (checkable && checked)

    Rectangle {
        id: background
        anchors.fill: parent
        radius: width / 2
        // 默认：白底；悬浮或选中：黑底
        color: !root.enabled ? "#e6e6e6" : ((pressArea.containsMouse || __active) ? "#000000" : "#ffffff")
        border.width: 1
        border.color: !root.enabled ? "#cfcfcf" : ((pressArea.containsMouse || __active) ? "#000000" : "#c7c7c7")
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    Text {
        id: iconLabel
        anchors.centerIn: parent
        text: root.iconText
        // 图标：默认黑色；悬浮或选中白色
        color: !root.enabled ? "#9a9a9a" : ((pressArea.containsMouse || __active) ? "#ffffff" : "#000000")
        font.pixelSize: Math.round(root.height * 0.46)
        font.bold: true
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: pressArea
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (!root.enabled) return;
            if (root.checkable) root.checked = !root.checked;
            root.clicked();
        }
    }
}

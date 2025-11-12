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
        color: !root.enabled ? "#d0d0d0" : (__active ? "#2c2c2c" : (pressArea.containsMouse ? "#ffffff" : "#f6f6f6"))
        border.width: 1
        border.color: !root.enabled ? "#b0b0b0" : (__active ? "#2c2c2c" : "#c7c7c7")
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    Text {
        id: iconLabel
        anchors.centerIn: parent
        text: root.iconText
        color: !root.enabled ? "#8a8a8a" : (__active ? "#f0f0f0" : "#303030")
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

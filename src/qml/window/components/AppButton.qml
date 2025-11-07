import QtQuick 2.15

Item {
    id: root
    property alias text: label.text
    property bool checkable: false
    property bool checked: false
    property bool enabled: true
    property int fontPixelSize: 25
    signal clicked()

    width: 180
    height: 60

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 6
        // target colors depend on state; animate changes
        property color targetColor: root.enabled ? (root.checked || hoverArea.containsMouse ? "black" : "white") : "#dddddd"
        color: targetColor
        border.width: 1
        property color targetBorderColor: root.enabled ? (root.checked || hoverArea.containsMouse ? "black" : "#bbbbbb") : "#cccccc"
        border.color: targetBorderColor

        Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutQuad } }
        Behavior on border.color { ColorAnimation { duration: 200; easing.type: Easing.OutQuad } }
    }

    Text {
        id: label
        anchors.centerIn: parent
        // animate text color
        property color targetTextColor: root.enabled ? (root.checked || hoverArea.containsMouse ? "white" : "black") : "#888888"
        color: targetTextColor
        font.pixelSize: root.fontPixelSize
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutQuad } }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (!root.enabled) return;
            if (root.checkable) root.checked = !root.checked;
            root.clicked()
        }
    }
}

import QtQuick

// LoreControlButton.qml - 图标+文字按钮，用于剧情控制栏
Item {
    id: root
    // 宽度默认跟随内容，但强制一个最小宽度以避免文字被裁剪
    width: Math.max(buttonRow.implicitWidth, 72)
    // 所有按钮尺寸缩小一点以节省空间
    height: 44

    property string iconText: ""
    // 可选的图标旋转角度（顺时针，度数）——用来旋转特殊符号
    property real iconRotation: 0
    // 可选的图标垂直偏移（px，正为向下，负为向上）
    property real iconYOffset: 0
    // 可选的图标缩放（用于让线条看起来更粗/更大）
    property real iconScale: 1.0
    property string text: ""
    property bool checkable: false
    property bool checked: false
    property bool enabled: true
    signal clicked()

    readonly property bool __active: pressArea.pressed || (checkable && checked)

    Rectangle {
        id: background
        anchors.fill: parent
        // 透明背景并移除边框，达到“无框”视觉效果
        color: "transparent"
        border.width: 0
        border.color: "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Row {
        id: buttonRow
        anchors.centerIn: parent
        spacing: 8
        // 强制和 root 同高，便于子元素顶底对齐
        height: parent.height
        transformOrigin: Item.Center
        // 悬浮时略微放大以增加交互反馈
        property real hoverScale: (pressArea.containsMouse || __active) ? 1.06 : 1.0
        scale: hoverScale
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }

        Text {
            id: iconLabel
            text: root.iconText
            // 与文字使用相同大小，并与行顶底严格对齐
            anchors.top: buttonRow.top
            anchors.bottom: buttonRow.bottom
            height: buttonRow.height
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: Math.round(buttonRow.height * 0.58)
            rotation: root.iconRotation
            y: root.iconYOffset
            scale: root.iconScale
            transformOrigin: Item.Center
            Behavior on rotation { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
            // 固定图标颜色（禁用时偏灰，正常时深色），避免在透明背景下不可见
            color: !root.enabled ? "#9a9a9a" : "#000000"
            font.bold: true
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Text {
            id: textLabel
            text: root.text
            // 与图标保持严格相同高度与对齐
            anchors.top: buttonRow.top
            anchors.bottom: buttonRow.bottom
            height: buttonRow.height
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: Math.round(buttonRow.height * 0.58)
            // 固定文字颜色（禁用时偏灰，正常时深色）
            color: !root.enabled ? "#9a9a9a" : "#000000"
            font.bold: true
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    // 悬浮阴影（2 层，模拟模糊阴影）
    Rectangle {
        id: shadowBlur1
        anchors.centerIn: buttonRow
        width: buttonRow.width + 18
        height: buttonRow.height + 14
        radius: Math.max(8, (height/2))
        color: "#00000022"
        z: -2
        opacity: (pressArea.containsMouse || __active) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
        visible: opacity > 0
    }

    Rectangle {
        id: shadowBlur2
        anchors.centerIn: buttonRow
        width: buttonRow.width + 8
        height: buttonRow.height + 6
        radius: Math.max(6, (height/2))
        color: "#00000014"
        z: -1
        opacity: (pressArea.containsMouse || __active) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
        visible: opacity > 0
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

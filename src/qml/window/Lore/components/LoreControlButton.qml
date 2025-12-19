import QtQuick
// 通过实例化 UiScale 来统一缩放

// LoreControlButton.qml - 图标+文字按钮，用于剧情控制栏
Item {
    UiScale { id: uiScaleHelper }
    property real uiScale: uiScaleHelper.uiScale
    scale: uiScale
    id: root
    // 平台检测：在 Android 上某些符号字体不可用，自动替换为 ASCII 图标
    property bool isAndroid: (Qt.platform && Qt.platform.os ? (Qt.platform.os.toLowerCase() === 'android') : false)
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
        // 始终透明背景（去掉 hover 填充），达到“无框”视觉效果
        color: "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Row {
        id: buttonRow
        anchors.centerIn: parent
        spacing: 5
        // 强制和 root 同高，便于子元素顶底对齐
        height: parent.height
        transformOrigin: Item.Center
        // 悬浮时略微放大以增加交互反馈（改为更小的缩放，避免显著放大）
        property real hoverScale: (pressArea.containsMouse || __active) ? 1.02 : 1.0
        scale: hoverScale
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

        Text {
            id: iconLabel
            // Android 上对特殊符号做降级替换，确保可见
            text: root.isAndroid ? root.__mapIconFallback(root.iconText) : root.iconText
            // Android 且降级为 "L" 时不旋转
            rotation: (root.isAndroid && text === "L") ? 0 : root.iconRotation
            y: root.iconYOffset
            scale: root.iconScale
            transformOrigin: Item.Center
            Behavior on rotation { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
            // 与文字使用相同大小，并与行顶底严格对齐
            anchors.top: buttonRow.top
            anchors.bottom: buttonRow.bottom
            height: buttonRow.height
            verticalAlignment: Text.AlignVCenter
            property real targetFontSize: (pressArea.containsMouse || root.__active) ? Math.round(buttonRow.height * 0.98) : Math.round(buttonRow.height * 0.58)
            font.pixelSize: targetFontSize
            // 使用通用字体族，提升在 Android 上的符号显示概率
            font.family: root.isAndroid ? "sans-serif" : undefined
            Behavior on font.pixelSize { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
            // 固定图标颜色（禁用时偏灰，正常时纯黑）
            color: !root.enabled ? "#8a8a8a" : "#000000"
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
            property real targetFontSize: (pressArea.containsMouse || root.__active) ? Math.round(buttonRow.height * 0.68) : Math.round(buttonRow.height * 0.58)
            font.pixelSize: targetFontSize
            Behavior on font.pixelSize { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
            // 固定文字颜色（禁用时偏灰，正常时深色）
            color: !root.enabled ? "#8a8a8a" : "#303030"
            font.bold: true
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }
    // 悬浮阴影（模拟多层阴影）
    Rectangle {
        id: shadowBlur1
        anchors.centerIn: buttonRow
        width: buttonRow.width + 18
        height: buttonRow.height + 14
        radius: Math.max(8, (height/2))
        color: "#00000000"
        z: -2
        opacity: 0
        visible: false
    }

    Rectangle {
        id: shadowBlur2
        anchors.centerIn: buttonRow
        width: buttonRow.width + 8
        height: buttonRow.height + 6
        radius: Math.max(6, (height/2))
        color: "#00000000"
        z: -1
        opacity: 0
        visible: false
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

    // 符号到 ASCII 的降级映射，解决 Android 上符号字体缺失导致图标不可见的问题
    function __mapIconFallback(src) {
        try {
            var s = (src || "").toString();
            // 直接匹配常用图标字符
            switch (s) {
            case "\u2630": // MENU ☰
                return " ";
            case "\u25B6": // ▶
                return " ";
            case "\u25B6\u25B6": // ▶▶
                return " ";
            case "\u270E": // ✎（部分平台会渲染彩色）
                return " "; // U+2710 黑色笔尖，通常为单色
            case "\u2399": // ⎙ SAVE
                return " ";
            case "\u2398": // ⎘ LOAD
                return " ";
            case "\u25A3": // ▣ TITLE
                return " ";
            default:
                // 非匹配项：若字符串含有特殊符号（可能不显示），尝试简化为首字符
                if (s.length > 2) return s.substring(0, 2);
                return s;
            }
        } catch(e) { return src; }
    }
}

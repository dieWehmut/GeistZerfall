import QtQuick
import QtQuick.Controls
import "../../../components"

// HistoryPanel.qml - 历史回顾窗口组件
Item {
    id: root
    anchors.fill: parent
    visible: false
    z: 3000

    // 历史记录数据 [{mode, speaker, text, node, index, music, musicLoops, stopMusic}]
    property var historyData: []
    
    signal closeRequested()
    // 当用户点击跳转图标时发出 (nodeId, contentIndex)
    signal jumpRequested(string nodeId, int contentIndex)

    // 半透明背景遮罩
    Rectangle {
        anchors.fill: parent
        color: "#CC000000"  // 80% 黑色
        opacity: root.visible ? 1 : 0
        
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                // 点击背景关闭
                root.closeRequested();
            }
        }
    }

    // 主面板容器（使用 container 包裹以便给主面板添加 DropShadow）
    Item {
        id: panelContainer
        anchors.centerIn: parent
        width: parent.width * 0.8
        height: parent.height * 0.85

        Rectangle {
            id: mainPanel
            anchors.fill: parent
            color: "transparent" // 主面板透明
            border.color: "#33333388"
            border.width: 2
            radius: 8

            // 右键关闭面板（不影响左键操作）
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                z: 10000
                onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) {
                        console.log("HistoryPanel: right click close");
                        root.closeRequested();
                    }
                }
            }

            // 历史记录列表区域（充满整个面板除了底部按钮区域）
            Rectangle {
                id: listContainer
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    bottom: buttonArea.top
                    margins: 40  // 增加左右上下内边距，保证对称留白
                }
                color: "transparent"

                ScrollView {
                    id: scrollView
                    anchors.fill: parent
                    clip: true
                    
                    // 滚动条在右侧
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AlwaysOn

                    ListView {
                        id: historyListView
                        model: root.historyData
                        spacing: 20  // 增加条目间距
                        // 留出滚动条空间
                        width: scrollView.width - 20
                        
                        delegate: Item {
                            width: historyListView.width - 5
                            height: Math.max(60, contentRow.height + 30)  // 最小高度60，更高
                            
                            Rectangle {
                                id: entryBg
                                anchors.fill: parent
                                color: "#00000066" // 半透明深色背景，提升对比度
                                border.color: "#FFFFFF22"
                                border.width: 1
                                radius: 6
                            }

                            Row {
                                id: contentRow
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    margins: 30  // 增加内边距，左右对称留白
                                    topMargin: 15
                                }
                                spacing: 20  // 人名和文本之间的间距

                                // 人名区域（始终占据120px，保证文本起始位置一致）
                                Item {
                                    width: 120  // 固定宽度，始终占位
                                    height: parent.height

                                    Text {
                                        id: speakerText
                                        anchors {
                                            left: parent.left
                                            top: parent.top
                                            // 保持与文本顶部对齐
                                        }
                                        width: parent.width
                                        text: modelData.speaker || ""
                                        font.pixelSize: 20
                                        font.bold: true
                                        color: "#90CAF9" // 浅蓝，更利于深色背景上的可读性
                                        wrapMode: Text.WordWrap
                                        verticalAlignment: Text.AlignTop
                                        // 只在 scene 模式且有人名时显示文字，但区域始终占位
                                        visible: modelData.mode === "scene" && modelData.speaker && modelData.speaker !== ""
                                    }
                                }

                                // 对话文本区域（始终从相同位置开始）
                                Text {
                                    id: dialogText
                                    anchors {
                                        top: parent.top
                                    }
                                    width: contentRow.width - 200  // 留出跳转按钮空间
                                    text: modelData.text || ""
                                    font.pixelSize: 20
                                    color: "#FFFFFF" // 白色文本，确保在黑色遮罩上可读
                                    wrapMode: Text.WordWrap
                                    verticalAlignment: Text.AlignTop
                                }

                                // 跳转按钮（图标）
                                AppButton {
                                    id: jumpButton
                                    width: 40
                                    height: 40
                                    text: "⤴"
                                    fontPixelSize: 18
                                    anchors.top: parent.top
                                    anchors.topMargin: 6
                                    onClicked: {
                                        // modelData 应包含 node 与 index
                                        if (modelData.node !== undefined && modelData.index !== undefined) {
                                            console.log("HistoryPanel: jump requested to", modelData.node, modelData.index);
                                            root.jumpRequested(modelData.node, modelData.index);
                                        } else {
                                            console.log("HistoryPanel: jump data missing for item");
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 底部按钮区域
            Item {
                id: buttonArea
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    margins: 15
                }
                height: 50

                AppButton {
                    id: backButton
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    width: 120
                    height: 40
                    text: "Back"
                    fontPixelSize: 22
                    
                    onClicked: {
                        console.log("HistoryPanel: Back button clicked");
                        root.closeRequested();
                    }
                }
            }

            // 只阻止点击事件穿透到背景，不阻止滚轮事件
            MouseArea {
                anchors.fill: parent
                z: -1  // 在其他元素下方
                onClicked: function(mouse) {
                    // 吸收点击事件，防止穿透到背景关闭面板
                    mouse.accepted = true;
                }
                // 不处理滚轮事件，让 WheelHandler 处理
                propagateComposedEvents: false
            }
        }

        // 多层半透明矩形模拟阴影（避免依赖 QtGraphicalEffects 模块）
        Rectangle {
            anchors.fill: mainPanel
            anchors.margins: -8
            color: "#00000033"
            radius: mainPanel.radius + 6
            z: -3
            visible: root.visible
        }

        Rectangle {
            anchors.fill: mainPanel
            anchors.margins: -14
            color: "#00000022"
            radius: mainPanel.radius + 10
            z: -4
            visible: root.visible
        }

        Rectangle {
            anchors.fill: mainPanel
            anchors.margins: -20
            color: "#00000014"
            radius: mainPanel.radius + 14
            z: -5
            visible: root.visible
        }
    }

    // 当 ScrollView 已经不能再向下滚动时，继续向下滚轮要能够关闭历史窗口
    // 绑定到内部的 Flickable（通过 scrollView.contentItem），优先处理在内容滚动到底后的额外下滑
    WheelHandler {
        // contentItem 在 ScrollView 中通常为 Flickable，可以访问 contentY/contentHeight/height
        target: scrollView.contentItem
        enabled: root.visible
        onWheel: function(event) {
            // 向下滚动（角度负值）时，只有当内容已经到达底部或无法滚动时，才触发关闭
            if (event.angleDelta.y < 0) {
                var flick = scrollView.contentItem;
                if (!flick) return;

                // 如果内容高度小于或等于可视高度，则视为无法滚动
                var atBottom = (flick.contentHeight <= flick.height) || (flick.contentY >= flick.contentHeight - flick.height - 1);
                if (atBottom) {
                    console.log("HistoryPanel: wheel down at scroll bottom, closing");
                    root.closeRequested();
                    event.accepted = true;
                }
            }
        }
    }

    // WheelHandler 用于滚轮下滑关闭（在面板上任意位置）
    WheelHandler {
        target: mainPanel
        enabled: root.visible
        onWheel: function(event) {
            // 向下滚动时关闭历史面板
            if (event.angleDelta.y < 0) {
                console.log("HistoryPanel: wheel down on panel, closing");
                root.closeRequested();
                event.accepted = true;
            }
        }
    }

    // 打开面板
    function open() {
        root.visible = true;
        // 滚动到底部（最新记录）
        if (historyListView.count > 0) {
            historyListView.positionViewAtEnd();
        }
    }

    // 关闭面板
    function close() {
        root.visible = false;
    }

    // 获取最后一条记录
    function _lastEntry() {
        return (historyData && historyData.length > 0) ? historyData[historyData.length - 1] : null;
    }

    // 比较是否同一条记录（以 node+index+text 为准）
    function _isSameEntry(a, nodeId, idx, text) {
        return a && a.node === (nodeId || "") && a.index === ((idx !== undefined) ? idx : -1) && a.text === (text || "");
    }

    // 裁剪历史到指定条目（保留该条目，删除其后的条目）
    function trimHistoryTo(nodeId, contentIdx) {
        if (!historyData || historyData.length === 0) return;
        var target = -1;
        for (var i = 0; i < historyData.length; i++) {
            var e = historyData[i];
            if (e.node === (nodeId || "") && e.index === ((contentIdx !== undefined) ? contentIdx : -1)) {
                target = i;
            }
        }
        if (target >= 0 && target < historyData.length - 1) {
            historyData = historyData.slice(0, target + 1);
        }
    }

    // 添加历史记录（自动去重：如果与最后一条相同则不再添加）
    // nodeId: 对应的 node 键 (string)， contentIdx: 对应内容索引 (int)
    // musicInfo: 可选，包含 music(字符串)、musicLoops(整数) 或 stopMusic(true)
    function addHistory(mode, speaker, text, nodeId, contentIdx, music, musicLoops, stopMusic) {
        var last = _lastEntry();
        if (_isSameEntry(last, nodeId, contentIdx, text)) {
            return; // 与最后一条一致，跳过
        }

        var newEntry = {
            mode: mode,
            speaker: speaker || "",
            text: text || "",
            node: nodeId || "",
            index: (contentIdx !== undefined) ? contentIdx : -1,
            music: music || "",
            musicLoops: (musicLoops !== undefined) ? musicLoops : undefined,
            stopMusic: stopMusic ? true : false
        };
        
        // 添加到历史数组
        var newHistory = historyData.slice();  // 复制数组
        newHistory.push(newEntry);
        historyData = newHistory;
    }

    // 清空历史记录
    function clearHistory() {
        historyData = [];
    }
}

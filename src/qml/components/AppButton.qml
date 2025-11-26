import QtQuick 2.15
import QtMultimedia 6.5

Item {
    id: root
    property alias text: label.text
    // optional small icon (text glyph) shown left of the label when non-empty
    property string iconText: ""
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
        border.width: 2
        // border becomes white when active/hovered (user requested white border on hover)
        // default border black; when hovered or checked switch to white (per requested style)
        property color targetBorderColor: root.enabled ? (root.checked || hoverArea.containsMouse ? "white" : "black") : "#cccccc"
        border.color: targetBorderColor

        Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutQuad } }
        Behavior on border.color { ColorAnimation { duration: 200; easing.type: Easing.OutQuad } }
    }

    // allow optional icon + text layout
    Row {
        anchors.centerIn: parent
        spacing: 8
        visible: true

        Text {
            id: icon
            text: root.iconText
            visible: root.iconText !== ""
            color: root.enabled ? (root.checked || hoverArea.containsMouse ? "white" : "black") : "#888888"
            font.pixelSize: Math.max(16, root.fontPixelSize - 6)
            Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutQuad } }
        }

        Text {
            id: label
            // animate text color
            property color targetTextColor: root.enabled ? (root.checked || hoverArea.containsMouse ? "white" : "black") : "#888888"
            color: targetTextColor
            text: ""
            font.pixelSize: root.fontPixelSize
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutQuad } }
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onEntered: {
            // 悬浮音效（受主音量与效果音音量控制）
            try {
                if (root.enabled) hoverSfx.play();
            } catch (e) {}
        }
        onClicked: {
            if (!root.enabled) return;
            // 点击音效（受主音量与效果音音量控制）
            try { clickSfx.play(); } catch (e) {}
            if (root.checkable) root.checked = !root.checked;
            root.clicked()
        }
    }

    // 悬浮/点击音效，绑定到 Config 界面的效果音（window.sfxVolume）与主音量
    SoundEffect {
        id: hoverSfx
        source: "qrc:/resource/audio/SoundEffect/buttonHover.wav"
        volume: 0.9 * (typeof window !== 'undefined' ? window.masterVolume * (typeof window.sysSfxVolume !== 'undefined' ? window.sysSfxVolume : window.sfxVolume) : 1.0)
    }
    SoundEffect {
        id: clickSfx
        source: "qrc:/resource/audio/SoundEffect/buttonClick.wav"
        volume: 1.0 * (typeof window !== 'undefined' ? window.masterVolume * (typeof window.sysSfxVolume !== 'undefined' ? window.sysSfxVolume : window.sfxVolume) : 1.0)
    }
}

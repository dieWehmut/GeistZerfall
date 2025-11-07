import QtQuick
import QtQuick.Controls
import "windowState.js" as WindowState
import "qrc:/qml/window/components"

Item {
	anchors.fill: parent
	property real baseWidth: 1280
	property real baseHeight: 720
	property real scaleFactor: Math.min(width / baseWidth, height / baseHeight)

	// Global input helpers: right-click = BACK, Esc = exit fullscreen
	MouseArea {
		id: globalRightClick
		anchors.fill: parent
		hoverEnabled: true
		acceptedButtons: Qt.RightButton
		onClicked: function(mouse) {
			if (mouse.button === Qt.RightButton) {
				if (window.goBack) window.goBack();
			}
		}
		// allow this MouseArea to sit behind dialogs but still receive right-clicks
		z: -100
	}

	Shortcut {
		sequence: "Esc"
		onActivated: {
			// if fullscreen button exists try to restore normal; fallback to window.showNormal
			if (window && window.showNormal) {
				window.showNormal && window.showNormal();
			}
			// also unset fullscreen button state if present
			if (typeof fullscreenBtn !== 'undefined') fullscreenBtn.checked = false;
			if (typeof windowBtn !== 'undefined') windowBtn.checked = true;
		}
	}

	// 背景图（放在根节点，始终充满窗口）
	Image {
		anchors.fill: parent
		source: "qrc:/resource/image/bg/mainmenu.png"
		fillMode: Image.PreserveAspectCrop
		smooth: true
		cache: true
		z: -1
	}

	// 内容容器，等比例缩放
	Item {
		id: contentRoot
		width: baseWidth
		height: baseHeight
		anchors.horizontalCenter: parent.horizontalCenter
		anchors.verticalCenter: parent.verticalCenter
		transform: Scale { xScale: scaleFactor; yScale: scaleFactor; origin.x: baseWidth/2; origin.y: baseHeight/2 }

		// 背景图
		// ...existing code for other children of contentRoot...

		// 标题
		Text {
			text: "CONFIG"
			anchors.left: parent.left
			anchors.leftMargin: 40
			anchors.top: parent.top
			anchors.topMargin: 60
			font.pixelSize: 48
			color: "white"
			font.bold: true
			z: 10
			style: Text.Outline
			styleColor: "black"
		}

		// 中间设置内容
		Column {
			anchors.horizontalCenter: parent.horizontalCenter
			anchors.verticalCenter: parent.verticalCenter
			spacing: 40
			z: 10

			Text {
				text: "画面尺寸"
				font.pixelSize: 32
				color: "white"
				font.bold: true
				horizontalAlignment: Text.AlignHCenter
				anchors.horizontalCenter: parent.horizontalCenter
				style: Text.Outline
				styleColor: "black"
			}
			Row {
				spacing: 40
				anchors.horizontalCenter: parent.horizontalCenter
				AppButton {
					id: windowBtn
					text: "标准窗口"
					width: 180; height: 60
					fontPixelSize: 22
					checkable: true
					checked: !fullscreenBtn.checked
					onClicked: {
						window.showNormal && window.showNormal();
						fullscreenBtn.checked = false;
					}
				}
				AppButton {
					id: fullscreenBtn
					text: "全屏"
					width: 180; height: 60
					fontPixelSize: 22
					checkable: true
					checked: false
					onClicked: {
						window.showFullScreen && window.showFullScreen();
						windowBtn.checked = false;
					}
				}
			}
		}

		// 底部按钮栏
		BottomButtonBar {
			anchors.horizontalCenter: parent.horizontalCenter
			anchors.bottom: parent.bottom
			anchors.bottomMargin: 40
			buttons: [
				{text: "SAVE", action: function() {
					WindowState.setTargetMode("save")
					window.pushSource && window.pushSource("qml/window/SaveLoad.qml")
				}},
				{text: "LOAD", action: function() {
					WindowState.setTargetMode("load")
					window.pushSource && window.pushSource("qml/window/SaveLoad.qml")
				}},
				{text: "EXTRA", action: function() {
					window.pushSource && window.pushSource("qml/window/Extra.qml")
				}},
				{text: "TITLE", action: function() {
					confirmTitleDialog.visible = true
				}},
				{text: "BACK", action: function() {
					window.goBack()
				}},
				{text: "QUIT", action: function() {
					confirmQuitDialog.visible = true
				}}
			]
		}
		// TITLE确认弹窗
		ConfirmDialog {
			id: confirmTitleDialog
			anchors.centerIn: parent
			title: "返回主界面"
			onYes: function() {
				window.pageHistory = [];
				window.replaceSource("qml/window/MainMenu.qml");
			}
		}

		// QUIT确认弹窗
		ConfirmDialog {
			id: confirmQuitDialog
			anchors.centerIn: parent
			title: "要结束游戏吗"
			onYes: function() {
				Qt.quit()
			}
		}
	}
}

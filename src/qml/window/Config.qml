import QtQuick
import QtQuick.Controls
import "windowState.js" as WindowState

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
		source: "qrc:/resource/image/mainmenuBg.png"
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
				Button {
					id: windowBtn
					text: "标准窗口"
                    width: 180; height: 60
                    font.pixelSize: 22
					checkable: true
					checked: !fullscreenBtn.checked
					onClicked: {
						window.showNormal && window.showNormal();
						fullscreenBtn.checked = false;
					}
				}
				Button {
					id: fullscreenBtn
					text: "全屏"
                    width: 180; height: 60
                    font.pixelSize: 22
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
		Rectangle {
			width: parent.width
			height: 120
			color: "transparent"
			anchors.horizontalCenter: parent.horizontalCenter
			anchors.bottom: parent.bottom
			anchors.bottomMargin: 40
			z: 20

			Row {
				id: buttonRow
				spacing: 40
				anchors.centerIn: parent

                // entrance animation controller (staggered from bottom to top)
                property bool buttonsEntered: false

                function triggerButtonEntrance() { buttonsEntered = true }
                Component.onCompleted: Qt.callLater(triggerButtonEntrance)

				Button {
					text: "SAVE"
					width: 180; height: 60
					font.pixelSize: 22
					y: buttonRow.buttonsEntered ? 0 : 12
					opacity: buttonRow.buttonsEntered ? 1 : 0
					Behavior on y { SequentialAnimation { PauseAnimation { duration: 0 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
					Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 0 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
					onClicked: {
						WindowState.setTargetMode("save")
						window.pushSource && window.pushSource("qml/window/SaveLoad.qml")
					}
				}
				Button {
					text: "LOAD"
					width: 180; height: 60
					font.pixelSize: 22
					y: buttonRow.buttonsEntered ? 0 : 12
					opacity: buttonRow.buttonsEntered ? 1 : 0
					Behavior on y { SequentialAnimation { PauseAnimation { duration: 60 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
					Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 60 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
					onClicked: {
						WindowState.setTargetMode("load")
						window.pushSource && window.pushSource("qml/window/SaveLoad.qml")
					}
				}
				Button {
					text: "EXTRA"
					width: 180; height: 60
					font.pixelSize: 22
					y: buttonRow.buttonsEntered ? 0 : 12
					opacity: buttonRow.buttonsEntered ? 1 : 0
					Behavior on y { SequentialAnimation { PauseAnimation { duration: 120 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
					Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 120 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
					onClicked: window.pushSource && window.pushSource("qml/window/Extra.qml")
				}
				Button {
					text: "TITLE"
					width: 180; height: 60
					font.pixelSize: 22
					y: buttonRow.buttonsEntered ? 0 : 12
					opacity: buttonRow.buttonsEntered ? 1 : 0
					Behavior on y { SequentialAnimation { PauseAnimation { duration: 180 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
					Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 180 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
					onClicked: confirmTitleDialog.visible = true
				}
				Button {
					text: "BACK"
					width: 180; height: 60
					font.pixelSize: 22
					y: buttonRow.buttonsEntered ? 0 : 12
					opacity: buttonRow.buttonsEntered ? 1 : 0
					Behavior on y { SequentialAnimation { PauseAnimation { duration: 240 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
					Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 240 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
					onClicked: window.goBack()
				}
				Button {
					text: "QUIT"
					width: 180; height: 60
					font.pixelSize: 22
					y: buttonRow.buttonsEntered ? 0 : 12
					opacity: buttonRow.buttonsEntered ? 1 : 0
					Behavior on y { SequentialAnimation { PauseAnimation { duration: 300 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
					Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 300 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
					onClicked: confirmQuitDialog.visible = true
				}
			}
		}
		// TITLE确认弹窗
		// TITLE确认弹窗（与 QUIT 弹窗样式一致）
		Item {
			id: confirmTitleDialog
			visible: false
			width: 360
			height: 170
			anchors.centerIn: parent
			z: 999
			// 遮罩（最底层）
			Rectangle {
				anchors.fill: parent
				color: "#80000000"
				z: -1
				visible: parent.visible
				MouseArea { anchors.fill: parent; onClicked: { confirmTitleDialog.visible = false } }
			}
			// 伪阴影
			Rectangle {
				width: parent.width; height: parent.height
				radius: 24
				color: "#22000000"
				anchors.horizontalCenter: parent.horizontalCenter
				anchors.verticalCenter: parent.verticalCenter
				anchors.verticalCenterOffset: 8
				z: 0
				visible: confirmTitleDialog.visible
			}
			// 主体
			Rectangle {
				id: dialogBgTitle
				width: parent.width
				height: parent.height
				radius: 24
				color: "#f8f8f8"
				border.width: 0
				z: 1
			}
			// 右上角关闭按钮
			Rectangle {
				id: closeTitleBtn
				width: 32; height: 32
				anchors.right: dialogBgTitle.right
				anchors.rightMargin: 12
				anchors.top: dialogBgTitle.top
				anchors.topMargin: 12
				radius: 16
				color: closeTitleBtnMouse.containsMouse ? "#e57373" : "transparent"
				border.color: "#bbbbbb"
				border.width: 1
				z: 2
				MouseArea {
					id: closeTitleBtnMouse
					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onClicked: confirmTitleDialog.visible = false
				}
				Text {
					text: "×"
					anchors.centerIn: parent
					font.pixelSize: 22
					color: "#222"
				}
			}
			// 内容
			Column {
				anchors.centerIn: dialogBgTitle
				spacing: 28
				width: dialogBgTitle.width
				z: 3
				Text {
					text: "返回主界面"
					anchors.horizontalCenter: parent.horizontalCenter
					font.pixelSize: 28
					color: "#222"
					font.bold: true
				}
				Row {
					spacing: 36
					anchors.horizontalCenter: parent.horizontalCenter
					// YES按钮
					Rectangle {
						width: 110; height: 48; radius: 8
						color: yesTitleBtnMouse.containsMouse ? "#1976d2" : "#eeeeee"
						border.color: yesTitleBtnMouse.containsMouse ? "#1976d2" : "#bbbbbb"
						border.width: 1
						MouseArea {
							id: yesTitleBtnMouse
							anchors.fill: parent
							hoverEnabled: true
							cursorShape: Qt.PointingHandCursor
							onClicked: {
								// TITLE should go directly to main menu and clear navigation history
								window.pageHistory = [];
								window.replaceSource("qml/window/MainMenu.qml");
								confirmTitleDialog.visible = false
							}
						}
						Text {
							text: "YES"
							anchors.centerIn: parent
							font.pixelSize: 22
							color: yesTitleBtnMouse.containsMouse ? "white" : "#222"
							font.bold: true
						}
					}
					// NO按钮
					Rectangle {
						width: 110; height: 48; radius: 8
						color: noTitleBtnMouse.containsMouse ? "#bdbdbd" : "#eeeeee"
						border.color: noTitleBtnMouse.containsMouse ? "#bdbdbd" : "#bbbbbb"
						border.width: 1
						MouseArea {
							id: noTitleBtnMouse
							anchors.fill: parent
							hoverEnabled: true
							cursorShape: Qt.PointingHandCursor
							onClicked: confirmTitleDialog.visible = false
						}
						Text {
							text: "NO"
							anchors.centerIn: parent
							font.pixelSize: 22
							color: noTitleBtnMouse.containsMouse ? "white" : "#222"
							font.bold: true
						}
					}
				}
			}
		}

		// QUIT美观确认弹窗（兼容Qt6，无DropShadow）
		Item {
			id: confirmQuitDialog
			visible: false
			width: 360
			height: 170
			anchors.centerIn: parent
			z: 999
			// 遮罩（最底层）
			Rectangle {
				anchors.fill: parent
				color: "#80000000"
				z: -1
				visible: parent.visible
				MouseArea { anchors.fill: parent; onClicked: { confirmQuitDialog.visible = false } }
			}
			// 伪阴影
			Rectangle {
				width: parent.width; height: parent.height
				radius: 24
				color: "#22000000"
				anchors.horizontalCenter: parent.horizontalCenter
				anchors.verticalCenter: parent.verticalCenter
				anchors.verticalCenterOffset: 8
				z: 0
				visible: confirmQuitDialog.visible
			}
			// 主体
			Rectangle {
				id: dialogBg
				width: parent.width
				height: parent.height
				radius: 24
				color: "#f8f8f8"
				border.width: 0
				z: 1
			}
			// 右上角关闭按钮
			Rectangle {
				id: closeBtn
				width: 32; height: 32
				anchors.right: dialogBg.right
				anchors.rightMargin: 12
				anchors.top: dialogBg.top
				anchors.topMargin: 12
				radius: 16
				color: closeBtnMouse.containsMouse ? "#e57373" : "transparent"
				border.color: "#bbbbbb"
				border.width: 1
				z: 2
				MouseArea {
					id: closeBtnMouse
					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onClicked: confirmQuitDialog.visible = false
				}
				Text {
					text: "×"
					anchors.centerIn: parent
					font.pixelSize: 22
					color: "#222"
				}
			}
			// 内容
			Column {
				anchors.centerIn: dialogBg
				spacing: 28
				width: dialogBg.width
				z: 3
				Text {
					text: "要结束游戏吗"
					anchors.horizontalCenter: parent.horizontalCenter
					font.pixelSize: 28
					color: "#222"
					font.bold: true
				}
				Row {
					spacing: 36
					anchors.horizontalCenter: parent.horizontalCenter
					// YES按钮
					Rectangle {
						width: 110; height: 48; radius: 8
						color: yesBtnMouse.containsMouse ? "#1976d2" : "#eeeeee"
						border.color: yesBtnMouse.containsMouse ? "#1976d2" : "#bbbbbb"
						border.width: 1
						MouseArea {
							id: yesBtnMouse
							anchors.fill: parent
							hoverEnabled: true
							cursorShape: Qt.PointingHandCursor
							onClicked: Qt.quit()
						}
						Text {
							text: "YES"
							anchors.centerIn: parent
							font.pixelSize: 22
							color: yesBtnMouse.containsMouse ? "white" : "#222"
							font.bold: true
						}
					}
					// NO按钮
					Rectangle {
						width: 110; height: 48; radius: 8
						color: noBtnMouse.containsMouse ? "#bdbdbd" : "#eeeeee"
						border.color: noBtnMouse.containsMouse ? "#bdbdbd" : "#bbbbbb"
						border.width: 1
						MouseArea {
							id: noBtnMouse
							anchors.fill: parent
							hoverEnabled: true
							cursorShape: Qt.PointingHandCursor
							onClicked: confirmQuitDialog.visible = false
						}
						Text {
							text: "NO"
							anchors.centerIn: parent
							font.pixelSize: 22
							color: noBtnMouse.containsMouse ? "white" : "#222"
							font.bold: true
						}
					}
				}
			}
		}
	}
}

import QtQuick
import QtQuick.Controls
import "windowState.js" as WindowState
import QtQuick.Layouts

Item {
	anchors.fill: parent
	// mode: "save" or "load"
	property string mode: "load"
	// If a caller set WindowState.targetMode before navigation, prefer that
	Component.onCompleted: {
		try {
			var m = WindowState.takeTargetMode()
			if (m) {
				mode = m
			}
		} catch (e) {
			console.log("SaveLoad: could not read WindowState.targetMode", e)
		}
	}
	property real baseWidth: 1280
	property real baseHeight: 720
	property real scaleFactor: Math.min(width / baseWidth, height / baseHeight)		// 背景
		Image {
			anchors.fill: parent
			source: "qrc:/resource/image/mainmenuBg.png"
			fillMode: Image.PreserveAspectCrop
		}

	// Global input helpers: right-click = BACK, Esc = exit fullscreen
	MouseArea {
		id: globalRightClickSaveLoad
		anchors.fill: parent
		hoverEnabled: true
		acceptedButtons: Qt.RightButton
		onClicked: function(mouse) {
			if (mouse.button === Qt.RightButton) {
				if (window.goBack) window.goBack();
			}
		}
		z: -100
	}

	Shortcut {
		sequence: "Esc"
		onActivated: {
			if (window && window.showNormal) window.showNormal();
			if (typeof fullscreenBtn !== 'undefined') fullscreenBtn.checked = false;
			if (typeof windowBtn !== 'undefined') windowBtn.checked = true;
		}
	}
	// 内容容器，等比例缩放
	Item {
		id: contentRoot
		width: baseWidth
		height: baseHeight
		anchors.horizontalCenter: parent.horizontalCenter
		anchors.verticalCenter: parent.verticalCenter
		transform: Scale { xScale: scaleFactor; yScale: scaleFactor; origin.x: baseWidth/2; origin.y: baseHeight/2 }

			// Listen for backend save/remove notifications and refresh slot previews
			Connections {
				target: SaveLoadManager
				onSaved: {
					// immediate refresh of all visible delegates
					for (var i=0;i<slotsRepeater.count;i++) {
						var it = slotsRepeater.itemAt(i);
						if (it && it.refreshPreview) it.refreshPreview();
					}
					// schedule a follow-up refresh in case file system needs a moment
					refreshTimer.restart();
				}
			}

			Timer { id: refreshTimer; interval: 120; repeat: false; onTriggered: {
					for (var j=0;j<slotsRepeater.count;j++) {
						var it2 = slotsRepeater.itemAt(j);
						if (it2 && it2.refreshPreview) it2.refreshPreview();
					}
				} }



		// 标题（只显示 SAVE 或 LOAD）
		Text {
			id: titleText
			text: mode === "save" ? "SAVE" : "LOAD"
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

		// 中间存档格子（8个正方形，2行4列，充满中间区域）
		Rectangle {
			id: centerArea
			width: parent.width * 0.9
			height: parent.height * 0.6
			anchors.horizontalCenter: parent.horizontalCenter
			anchors.verticalCenter: parent.verticalCenter
			color: "transparent"
			z: 10

			Grid {
				id: slotsGrid
				anchors.fill: parent
				columns: 4
				rows: 2
				rowSpacing: 20
				columnSpacing: 20
				anchors.margins: 20

				Repeater {
						id: slotsRepeater
						model: 8
					Rectangle {
						id: slotRect
						property int idx: index
						// 使格子为正方形：宽度根据父宽度与间距计算
						width: (centerArea.width - (slotsGrid.columnSpacing * (slotsGrid.columns-1)) - slotsGrid.anchors.margins*2) / slotsGrid.columns
						height: (centerArea.height - (slotsGrid.rowSpacing * (slotsGrid.rows-1)) - slotsGrid.anchors.margins*2) / slotsGrid.rows
						radius: 12
						color: slotMouse.containsMouse ? "#f5f5f5" : "#ffffff"
						border.width: 1
						border.color: slotMouse.containsMouse ? "#1976d2" : "#bbbbbb"

							function refreshPreview() {
										if (previewImg) {
											var url = SaveLoadManager.slotPreviewUrl(slotRect.idx, "save");
											if (url && url !== "") {
												previewImg.source = url + "?t=" + Date.now();
												previewImg.visible = true;
											} else {
												previewImg.source = "";
												previewImg.visible = false;
											}
										}
								if (emptyLabel) {
											var has = SaveLoadManager.hasSlot(slotRect.idx, "save");
											emptyLabel.text = has ? "Saved" : "Empty";
											// also ensure delete button visibility is explicitly updated
											if (typeof deleteBtnBg !== 'undefined') deleteBtnBg.visible = has;
								}
							}
							Column {
							anchors.fill: parent
							anchors.margins: 12
							spacing: 6
							Text {
								text: "Save " + (slotRect.idx + 1)
								font.pixelSize: 20
								color: "#222"
								font.bold: true
							}
								// preview image for slot if exists
								Image {
									id: previewImg
									anchors.horizontalCenter: parent.horizontalCenter
									width: parent.width * 0.9
									height: parent.height * 0.5
									fillMode: Image.PreserveAspectCrop
									source: SaveLoadManager.slotPreviewUrl(slotRect.idx, "save")
									visible: source !== ""
								}
								// place status label and delete button in a single row to align with bottom buttons
								RowLayout {
									anchors.horizontalCenter: parent.horizontalCenter
									width: parent.width
									spacing: 8
									// status label on the left
									Text {
										id: emptyLabel
										text: SaveLoadManager.hasSlot(slotRect.idx, "save") ? "Saved" : "Empty"
										font.pixelSize: 16
										color: "#666"
										Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
										Layout.fillWidth: true
									}
									// delete button on the right, styled similarly to bottom buttons
									Rectangle {
										id: deleteBtnBg
										width: 90; height: 44; radius: 6
										z: 50
										color: deleteBtnMouse.containsMouse ? "#e57373" : "#eeeeee"
										border.color: deleteBtnMouse.containsMouse ? "#e57373" : "#bbbbbb"
										border.width: 1
										visible: SaveLoadManager.hasSlot(slotRect.idx, "save")
										Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
										Text { id: deleteBtnText; text: "DELETE"; anchors.centerIn: parent; font.pixelSize: 16; color: "#222"; font.bold: true }
										MouseArea { id: deleteBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor;
											onPressed: {
												// prevent the slot MouseArea from handling this click
												try { slotMouse.enabled = false; } catch (e) {}
												// pressed style
												try { deleteBtnBg.color = "#d32f2f"; deleteBtnText.color = "white"; } catch (e) {}
											}
											onReleased: {
												try { slotMouse.enabled = true; } catch (e) {}
												// restore hover/normal style
												try { deleteBtnBg.color = deleteBtnMouse.containsMouse ? "#e57373" : "#eeeeee"; deleteBtnText.color = deleteBtnMouse.containsMouse ? "white" : "#222"; } catch (e) {}
											}
											onEntered: {
												// while hovering delete, ensure slotMouse won't intercept clicks
												try { slotMouse.enabled = false; } catch (e) {}
												try { deleteBtnBg.color = "#e57373"; deleteBtnText.color = "white"; } catch (e) {}
											}
											onExited: {
												try { slotMouse.enabled = true; } catch (e) {}
												try { deleteBtnBg.color = "#eeeeee"; deleteBtnText.color = "#222"; } catch (e) {}
											}
											onClicked: {
												console.log('delete slot', slotRect.idx);
												// 显示删除确认弹窗
												confirmDeleteDialog.slotIdx = slotRect.idx;
												confirmDeleteDialog.visible = true;
											}
										}
									}
								}
							Rectangle {
								anchors.horizontalCenter: parent.horizontalCenter
								width: parent.width * 0.6
								height: 1
								color: "#ddd"
							}
							Text {
								anchors.horizontalCenter: parent.horizontalCenter
								text: "—"
								color: "#999"
							}
						}

							MouseArea {
							id: slotMouse
							anchors.fill: parent
							hoverEnabled: true
							cursorShape: Qt.PointingHandCursor
									onClicked: function(mouse) {
									// If click is on the right edge (where the delete button appears), treat it as delete
									try {
										var deleteLeft = slotRect.width - 110; // approximate left bound of delete button area
										if (mouse.x >= deleteLeft && SaveLoadManager.hasSlot(slotRect.idx, "save")) {
											console.log('delete slot (via slotMouse area)', slotRect.idx);
											// 显示删除确认弹窗
											confirmDeleteDialog.slotIdx = slotRect.idx;
											confirmDeleteDialog.visible = true;
											return;
										}
									} catch (e) { console.log('slotMouse delete-area check failed', e); }
									console.log("clicked save", slotRect.idx + 1)
									if (mode === "save") {
										// if a save already exists here, ask for overwrite confirmation
										if (SaveLoadManager.hasSlot(slotRect.idx, "save")) {
											// store index to perform actual save when confirmed
											confirmOverwriteDialog.saveIdx = slotRect.idx;
											confirmOverwriteDialog.visible = true;
											return;
										}
										// update SaveLoadManager properties from global window player if available
										try {
											if (window && window.currentPlayer) {
												SaveLoadManager.posX = window.currentPlayer.pos.x;
												SaveLoadManager.posY = window.currentPlayer.pos.y;
												SaveLoadManager.speed = window.currentPlayer.getSpeed ? window.currentPlayer.getSpeed() : 0;
												SaveLoadManager.sight = window.currentPlayer.getSight ? window.currentPlayer.getSight() : 0;
											}
										} catch (e) { console.log(e) }
										SaveLoadManager.saveSlot(slotRect.idx, "save");
										// refresh preview via delegate method
										slotRect.refreshPreview();
									} else {
										// load save into game: call loadSlot and then update global player if available
										if (SaveLoadManager.loadSlot(slotRect.idx, "save")) {
											// Mark that we're loading from a save so GameView applies SaveLoadManager values on start
											try { WindowState.setTargetMode("loadFromSave"); } catch (e) { }
											// immediately switch to GameView so player sees game right away
											if (window && window.replaceSource) {
												window.replaceSource("qml/window/GameView.qml");
											} else if (window && window.pushSource) {
												window.pushSource("qml/window/GameView.qml");
											}
										}
									}
								}
						}
					}
				}
			}
		}

		// 底部按钮栏（与 Config.qml 风格一致）
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
					// entrance animation controller
					property bool buttonsEntered: false
					function triggerButtonEntrance() { buttonsEntered = true }
					Component.onCompleted: Qt.callLater(triggerButtonEntrance)

				Button {
					id: saveBtn
					text: "SAVE"
					width: 180; height: 60
					font.pixelSize: 22
					checkable: true
					checked: mode === "save"
					onClicked: mode = "save"
					y: buttonRow.buttonsEntered ? 0 : 12
					opacity: buttonRow.buttonsEntered ? 1 : 0
					Behavior on y { SequentialAnimation { PauseAnimation { duration: 0 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
					Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 0 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
				}
				Button {
					id: loadBtn
					text: "LOAD"
					width: 180; height: 60
					font.pixelSize: 22
					checkable: true
					checked: mode === "load"
					onClicked: mode = "load"
					y: buttonRow.buttonsEntered ? 0 : 12
					opacity: buttonRow.buttonsEntered ? 1 : 0
					Behavior on y { SequentialAnimation { PauseAnimation { duration: 60 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
					Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 60 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
				}
				Button {
					text: "EXTRA"
					width: 180; height: 60
					font.pixelSize: 22
					onClicked: window.pushSource && window.pushSource("qml/window/Extra.qml")
					y: buttonRow.buttonsEntered ? 0 : 12
					opacity: buttonRow.buttonsEntered ? 1 : 0
					Behavior on y { SequentialAnimation { PauseAnimation { duration: 120 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
					Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 120 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
				}
				Button {
					text: "TITLE"
					width: 180; height: 60
					font.pixelSize: 22
					onClicked: function() { confirmTitleDialog.visible = true }
					y: buttonRow.buttonsEntered ? 0 : 12
					opacity: buttonRow.buttonsEntered ? 1 : 0
					Behavior on y { SequentialAnimation { PauseAnimation { duration: 180 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
					Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 180 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
				}
				Button {
					text: "BACK"
					width: 180; height: 60
					font.pixelSize: 22
					onClicked: window.goBack && window.goBack()
					y: buttonRow.buttonsEntered ? 0 : 12
					opacity: buttonRow.buttonsEntered ? 1 : 0
					Behavior on y { SequentialAnimation { PauseAnimation { duration: 240 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
					Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 240 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
				}
				Button {
					text: "QUIT"
					width: 180; height: 60
					font.pixelSize: 22
					onClicked: function() { confirmQuitDialog.visible = true }
					y: buttonRow.buttonsEntered ? 0 : 12
					opacity: buttonRow.buttonsEntered ? 1 : 0
					Behavior on y { SequentialAnimation { PauseAnimation { duration: 300 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
					Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 300 } NumberAnimation { duration: 360; easing.type: Easing.OutQuad } } }
				}
			}
		}

		// TITLE确认弹窗
		Item {
			id: confirmTitleDialog
			visible: false
			width: 360
			height: 170
			anchors.centerIn: contentRoot
			z: 999
			// 遮罩
			Rectangle { anchors.fill: parent; color: "#80000000"; z: -1; visible: parent.visible; MouseArea { anchors.fill: parent; onClicked: confirmTitleDialog.visible = false } }
			// 伪阴影
			Rectangle { width: parent.width; height: parent.height; radius: 24; color: "#22000000"; anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 8; z: 0; visible: confirmTitleDialog.visible }
			// 主体
			Rectangle { id: dialogBgTitle; width: parent.width; height: parent.height; radius: 24; color: "#f8f8f8"; border.width: 0; z: 1 }
			// 右上角关闭按钮
			Rectangle {
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
				MouseArea { id: closeTitleBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: confirmTitleDialog.visible = false }
				Text { text: "×"; anchors.centerIn: parent; font.pixelSize: 22; color: "#222" }
			}
			Column {
				anchors.centerIn: dialogBgTitle
				spacing: 28
				width: dialogBgTitle.width
				z: 3
				Text { text: "返回主界面"; anchors.horizontalCenter: parent.horizontalCenter; font.pixelSize: 28; color: "#222"; font.bold: true }
				Row { spacing: 36; anchors.horizontalCenter: parent.horizontalCenter
					// YES按钮
					Rectangle {
						width: 110; height: 48; radius: 8
						color: yesTitleBtnMouse.containsMouse ? "#1976d2" : "#eeeeee"
						border.color: yesTitleBtnMouse.containsMouse ? "#1976d2" : "#bbbbbb"
						border.width: 1
						MouseArea { id: yesTitleBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { window.pageHistory = []; window.replaceSource && window.replaceSource("qml/window/MainMenu.qml"); confirmTitleDialog.visible = false } }
						Text { text: "YES"; anchors.centerIn: parent; font.pixelSize: 22; color: yesTitleBtnMouse.containsMouse ? "white" : "#222"; font.bold: true }
					}
					// NO按钮
					Rectangle {
						width: 110; height: 48; radius: 8
						color: noTitleBtnMouse.containsMouse ? "#bdbdbd" : "#eeeeee"
						border.color: noTitleBtnMouse.containsMouse ? "#bdbdbd" : "#bbbbbb"
						border.width: 1
						MouseArea { id: noTitleBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: confirmTitleDialog.visible = false }
						Text { text: "NO"; anchors.centerIn: parent; font.pixelSize: 22; color: noTitleBtnMouse.containsMouse ? "white" : "#222"; font.bold: true }
					}
				}
			}
		}

		// QUIT确认弹窗
		Item {
			id: confirmQuitDialog
			visible: false
			width: 360
			height: 170
			anchors.centerIn: contentRoot
			z: 999
			// 遮罩
			Rectangle { anchors.fill: parent; color: "#80000000"; z: -1; visible: parent.visible; MouseArea { anchors.fill: parent; onClicked: confirmQuitDialog.visible = false } }
			// 伪阴影
			Rectangle { width: parent.width; height: parent.height; radius: 24; color: "#22000000"; anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 8; z: 0; visible: confirmQuitDialog.visible }
			// 主体
			Rectangle { id: dialogBg; width: parent.width; height: parent.height; radius: 24; color: "#f8f8f8"; border.width: 0; z: 1 }
			// 右上角关闭按钮
			Rectangle {
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
				MouseArea { id: closeBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: confirmQuitDialog.visible = false }
				Text { text: "×"; anchors.centerIn: parent; font.pixelSize: 22; color: "#222" }
			}
			Column {
				anchors.centerIn: dialogBg
				spacing: 28
				width: dialogBg.width
				z: 3
				Text { text: "要结束游戏吗"; anchors.horizontalCenter: parent.horizontalCenter; font.pixelSize: 28; color: "#222"; font.bold: true }
				Row { spacing: 36; anchors.horizontalCenter: parent.horizontalCenter
					// YES按钮
					Rectangle {
						width: 110; height: 48; radius: 8
						color: yesBtnMouse.containsMouse ? "#1976d2" : "#eeeeee"
						border.color: yesBtnMouse.containsMouse ? "#1976d2" : "#bbbbbb"
						border.width: 1
						MouseArea { id: yesBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Qt.quit() }
						Text { text: "YES"; anchors.centerIn: parent; font.pixelSize: 22; color: yesBtnMouse.containsMouse ? "white" : "#222"; font.bold: true }
					}
					// NO按钮
					Rectangle {
						width: 110; height: 48; radius: 8
						color: noBtnMouse.containsMouse ? "#bdbdbd" : "#eeeeee"
						border.color: noBtnMouse.containsMouse ? "#bdbdbd" : "#bbbbbb"
						border.width: 1
						MouseArea { id: noBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: confirmQuitDialog.visible = false }
						Text { text: "NO"; anchors.centerIn: parent; font.pixelSize: 22; color: noBtnMouse.containsMouse ? "white" : "#222"; font.bold: true }
					}
				}
			}
		}

		// OVERWRITE确认弹窗（保存时覆盖）
		Item {
			id: confirmOverwriteDialog
			visible: false
			property int saveIdx: -1
			width: 360
			height: 170
			anchors.centerIn: contentRoot
			z: 999
			// 遮罩
			Rectangle { anchors.fill: parent; color: "#80000000"; z: -1; visible: parent.visible; MouseArea { anchors.fill: parent; onClicked: confirmOverwriteDialog.visible = false } }
			// 伪阴影
			Rectangle { width: parent.width; height: parent.height; radius: 24; color: "#22000000"; anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 8; z: 0; visible: confirmOverwriteDialog.visible }
			// 主体（样式与 QUIT/Title 一致）
			Rectangle { id: dialogBgOverwrite; width: parent.width; height: parent.height; radius: 24; color: "#f8f8f8"; border.width: 0; z: 1 }
			// 右上角关闭按钮
			Rectangle {
				width: 32; height: 32
				anchors.right: dialogBgOverwrite.right
				anchors.rightMargin: 12
				anchors.top: dialogBgOverwrite.top
				anchors.topMargin: 12
				radius: 16
				color: closeOverwriteBtnMouse.containsMouse ? "#e57373" : "transparent"
				border.color: "#bbbbbb"
				border.width: 1
				z: 2
				MouseArea { id: closeOverwriteBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: confirmOverwriteDialog.visible = false }
				Text { text: "×"; anchors.centerIn: parent; font.pixelSize: 22; color: "#222" }
			}
			Column {
				anchors.centerIn: dialogBgOverwrite
				spacing: 28
				width: dialogBgOverwrite.width
				z: 3
				Text { text: "覆盖现有存档吗?"; anchors.horizontalCenter: parent.horizontalCenter; font.pixelSize: 24; color: "#222"; font.bold: true }
				Row { spacing: 36; anchors.horizontalCenter: parent.horizontalCenter
					// YES按钮（执行覆盖保存）
					Rectangle {
						width: 110; height: 48; radius: 8
						color: yesOverwriteBtnMouse.containsMouse ? "#1976d2" : "#eeeeee"
						border.color: yesOverwriteBtnMouse.containsMouse ? "#1976d2" : "#bbbbbb"
						border.width: 1
								MouseArea { id: yesOverwriteBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: {
									// perform actual save
									var idx = confirmOverwriteDialog.saveIdx;
									if (idx >= 0) {
										try {
											if (window && window.currentPlayer) {
												SaveLoadManager.posX = window.currentPlayer.pos.x;
												SaveLoadManager.posY = window.currentPlayer.pos.y;
												SaveLoadManager.speed = window.currentPlayer.getSpeed ? window.currentPlayer.getSpeed() : 0;
												SaveLoadManager.sight = window.currentPlayer.getSight ? window.currentPlayer.getSight() : 0;
											}
										} catch (e) { console.log(e) }
										SaveLoadManager.saveSlot(idx, "save");
										try {
											var it = slotsRepeater.itemAt(idx);
											if (it && it.refreshPreview) {
												it.refreshPreview();
											} else {
												// fallback: refresh all
												for (var i=0;i<slotsRepeater.count;i++) {
													var it2 = slotsRepeater.itemAt(i);
													if (it2 && it2.refreshPreview) it2.refreshPreview();
												}
											}
										} catch (e) { console.log('refresh slot preview failed', e); }
										confirmOverwriteDialog.visible = false;
									}
								} }
						Text { text: "YES"; anchors.centerIn: parent; font.pixelSize: 22; color: yesOverwriteBtnMouse.containsMouse ? "white" : "#222"; font.bold: true }
					}
					// NO按钮（取消）
					Rectangle {
						width: 110; height: 48; radius: 8
						color: noOverwriteBtnMouse.containsMouse ? "#bdbdbd" : "#eeeeee"
						border.color: noOverwriteBtnMouse.containsMouse ? "#bdbdbd" : "#bbbbbb"
						border.width: 1
						MouseArea { id: noOverwriteBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: confirmOverwriteDialog.visible = false }
						Text { text: "NO"; anchors.centerIn: parent; font.pixelSize: 22; color: noOverwriteBtnMouse.containsMouse ? "white" : "#222"; font.bold: true }
					}
				}
			}
		}

		// DELETE确认弹窗（删除存档）
		Item {
			id: confirmDeleteDialog
			visible: false
			property int slotIdx: -1
			width: 360
			height: 170
			anchors.centerIn: contentRoot
			z: 999
			// 遮罩
			Rectangle { anchors.fill: parent; color: "#80000000"; z: -1; visible: parent.visible; MouseArea { anchors.fill: parent; onClicked: confirmDeleteDialog.visible = false } }
			// 伪阴影
			Rectangle { width: parent.width; height: parent.height; radius: 24; color: "#22000000"; anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 8; z: 0; visible: confirmDeleteDialog.visible }
			// 主体
			Rectangle { id: dialogBgDelete; width: parent.width; height: parent.height; radius: 24; color: "#f8f8f8"; border.width: 0; z: 1 }
			// 右上角关闭按钮
			Rectangle {
				width: 32; height: 32
				anchors.right: dialogBgDelete.right
				anchors.rightMargin: 12
				anchors.top: dialogBgDelete.top
				anchors.topMargin: 12
				radius: 16
				color: closeDeleteBtnMouse.containsMouse ? "#e57373" : "transparent"
				border.color: "#bbbbbb"
				border.width: 1
				z: 2
				MouseArea { id: closeDeleteBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: confirmDeleteDialog.visible = false }
				Text { text: "×"; anchors.centerIn: parent; font.pixelSize: 22; color: "#222" }
			}
			Column {
				anchors.centerIn: dialogBgDelete
				spacing: 28
				width: dialogBgDelete.width
				z: 3
				Text { text: "删除存档吗?"; anchors.horizontalCenter: parent.horizontalCenter; font.pixelSize: 28; color: "#222"; font.bold: true }
				Row { spacing: 36; anchors.horizontalCenter: parent.horizontalCenter
					// YES按钮
					Rectangle {
						width: 110; height: 48; radius: 8
						color: yesDeleteBtnMouse.containsMouse ? "#1976d2" : "#eeeeee"
						border.color: yesDeleteBtnMouse.containsMouse ? "#1976d2" : "#bbbbbb"
						border.width: 1
						MouseArea { id: yesDeleteBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: {
							var idx = confirmDeleteDialog.slotIdx;
							if (idx >= 0) {
								if (SaveLoadManager.removeSlot(idx, "save")) {
									try {
										var it = slotsRepeater.itemAt(idx);
										if (it && it.refreshPreview) {
											it.refreshPreview();
										} else {
											// fallback: refresh all
											for (var i=0;i<slotsRepeater.count;i++) {
												var it2 = slotsRepeater.itemAt(i);
												if (it2 && it2.refreshPreview) it2.refreshPreview();
											}
										}
									} catch (e) { console.log('refresh slot preview failed', e); }
								}
								confirmDeleteDialog.visible = false;
							}
						} }
						Text { text: "YES"; anchors.centerIn: parent; font.pixelSize: 22; color: yesDeleteBtnMouse.containsMouse ? "white" : "#222"; font.bold: true }
					}
					// NO按钮
					Rectangle {
						width: 110; height: 48; radius: 8
						color: noDeleteBtnMouse.containsMouse ? "#bdbdbd" : "#eeeeee"
						border.color: noDeleteBtnMouse.containsMouse ? "#bdbdbd" : "#bbbbbb"
						border.width: 1
						MouseArea { id: noDeleteBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: confirmDeleteDialog.visible = false }
						Text { text: "NO"; anchors.centerIn: parent; font.pixelSize: 22; color: noDeleteBtnMouse.containsMouse ? "white" : "#222"; font.bold: true }
					}
				}
			}
		}
	}
}

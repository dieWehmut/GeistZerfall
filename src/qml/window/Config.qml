import QtQuick
import QtQuick.Controls
import "windowState.js" as WindowState
import "../components"
import "Lore/components"

Item {
		Component.onCompleted: {
			// Load persisted system settings (if any)
			try {
				if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager) {
					var settings = SaveLoadManager.loadSystem();
					if (settings) {
						if (settings.fullscreen !== undefined) {
							fullscreenBtn.checked = !!settings.fullscreen;
							windowBtn.checked = !fullscreenBtn.checked;
							if (fullscreenBtn.checked) { if (window && window.showFullScreen) window.showFullScreen(); }
							else { if (window && window.showNormal) window.showNormal(); }
						}
						if (settings.textSkip !== undefined) {
							if (settings.textSkip === 'all') { textSkipAllBtn.checked = true; textSkipReadBtn.checked = false; }
							else { textSkipReadBtn.checked = true; textSkipAllBtn.checked = false; }
						}
						if (settings.optionFastForward !== undefined) { optFastYes.checked = !!settings.optionFastForward; optFastNo.checked = !optFastYes.checked; }
						if (settings.optionAutoContinue !== undefined) { optAutoYes.checked = !!settings.optionAutoContinue; optAutoNo.checked = !optAutoYes.checked; }
						if (settings.masterVolume !== undefined) masterSlider.value = Math.round((settings.masterVolume || 0.0) * 100);
						if (settings.bgmVolume !== undefined) bgmSlider.value = Math.round((settings.bgmVolume || 0.0) * 100);
						if (settings.sfxVolume !== undefined) sfxSlider.value = Math.round((settings.sfxVolume || 0.0) * 100);
						if (settings.textSpeed !== undefined) textSpeedSlider.value = settings.textSpeed;
						if (settings.autoModeSpeed !== undefined) autoModeSlider.value = settings.autoModeSpeed;
					}
				}
			} catch(e) { console.log('Config: loadSystem failed', e); }
		}

		function persistSystemSettings() {
			try {
				if (typeof SaveLoadManager === 'undefined' || !SaveLoadManager) return;
				// load existing settings and merge so we don't wipe keys others may manage (e.g. aimMode, controlsVisible)
				var s = SaveLoadManager.loadSystem() || {};
				if (!s) s = {};
				// copy/override new values into the loaded settings object
				s.fullscreen = !!fullscreenBtn.checked;
				s.textSkip = (textSkipAllBtn.checked ? 'all' : 'read');
				s.optionFastForward = !!optFastYes.checked;
				s.optionAutoContinue = !!optAutoYes.checked;
				s.masterVolume = (masterSlider.value / 100.0);
				s.bgmVolume = (bgmSlider.value / 100.0);
				s.sfxVolume = (sfxSlider.value / 100.0);
				s.textSpeed = textSpeedSlider.value;
				s.autoModeSpeed = autoModeSlider.value;
				SaveLoadManager.saveSystem(s);
			} catch(e) { console.log('Config: persistSystemSettings failed', e); }
		}
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
			anchors.leftMargin: 24
			anchors.top: parent.top
			anchors.topMargin: 24
			font.pixelSize: 48
			color: "white"
			font.bold: true
			z: 10
			style: Text.Outline
			styleColor: "black"
		}

		// 中间设置内容
				Row {
			anchors.horizontalCenter: parent.horizontalCenter
			anchors.top: parent.top
			anchors.topMargin: 120
			spacing: 60

			// 左列
			Column {
				spacing: 20

				// 画面尺寸
				Column {
					spacing: 8
					Text {
						text: "画面尺寸"
						font.pixelSize: 28
						color: "white"
						font.bold: true
						style: Text.Outline; styleColor: "black"
					}
					Row {
						spacing: 12
						AppButton {
							id: windowBtn
							text: "窗口"
							width: 140; height: 50
							fontPixelSize: 20
							checkable: true
							checked: !fullscreenBtn.checked
							onClicked: {
								window.showNormal && window.showNormal();
								fullscreenBtn.checked = false;
								persistSystemSettings();
							}
						}
						AppButton {
							id: fullscreenBtn
							text: "全屏"
							width: 140; height: 50
							fontPixelSize: 20
							checkable: true
							checked: false
							onClicked: {
								window.showFullScreen && window.showFullScreen();
								windowBtn.checked = false;
								persistSystemSettings();
							}
						}
					}
				}

				// 文本跳过
				Column {
					spacing: 8
					Text {
						text: "文本跳过"
						font.pixelSize: 28
						color: "white"
						font.bold: true
						style: Text.Outline; styleColor: "black"
					}
					Row {
						spacing: 12
						AppButton {
							id: textSkipReadBtn
							text: "已读"
							width: 140; height: 50
							fontPixelSize: 20
							checkable: true
							checked: true
							onClicked: { checked = true; parent.children[1].checked = false; persistSystemSettings(); }
						}
						AppButton {
							id: textSkipAllBtn
							text: "全部"
							width: 140; height: 50
							fontPixelSize: 20
							checkable: true
							checked: false
							onClicked: { checked = true; parent.children[0].checked = false; persistSystemSettings(); }
						}
					}
				}

				// 选项后快进
				Column {
					spacing: 8
					Text {
						text: "选项后快进"
						font.pixelSize: 28
						color: "white"
						font.bold: true
						style: Text.Outline; styleColor: "black"
					}
					Row {
						spacing: 12
						AppButton {
							id: optFastYes
							text: "YES"
							width: 140; height: 50
							fontPixelSize: 20
							checkable: true
							checked: false
							onClicked: { checked = true; parent.children[1].checked = false; persistSystemSettings(); }
						}
						AppButton {
							id: optFastNo
							text: "NO"
							width: 140; height: 50
							fontPixelSize: 20
							checkable: true
							checked: true
							onClicked: { checked = true; parent.children[0].checked = false; persistSystemSettings(); }
						}
					}
				}

				// 选项后继续自动模式
				Column {
					spacing: 8
					Text {
						text: "选项后继续自动模式"
						font.pixelSize: 28
						color: "white"
						font.bold: true
						style: Text.Outline; styleColor: "black"
					}
					Row {
						spacing: 12
						AppButton {
							id: optAutoYes
							text: "YES"
							width: 140; height: 50
							fontPixelSize: 20
							checkable: true
							checked: false
							onClicked: { checked = true; parent.children[1].checked = false }
						}
						AppButton {
							id: optAutoNo
							text: "NO"
							width: 140; height: 50
							fontPixelSize: 20
							checkable: true
							checked: true
							onClicked: { checked = true; parent.children[0].checked = false }
						}
					}
				}
			}

			// 中间列：音量相关
			Column {
				spacing: 12

				// 主音量
				Column { spacing: 5
					Text { text: "主音量"; font.pixelSize: 28; color: "white"; font.bold: true; style: Text.Outline; styleColor: "black" }
						ConfigSlider {
						id: masterSlider
						Component.onCompleted: value = Math.round((typeof window !== 'undefined' ? window.masterVolume : 1.0) * 100);
						onValueChanged: { if (typeof window !== 'undefined') window.masterVolume = value / 100.0; persistSystemSettings(); }
					}
					Row { spacing: 8
						AppButton { id: masterOnBtn; text: "ON"; width: 100; height: 40; fontPixelSize: 18; checkable: true; checked: (typeof window !== 'undefined' ? window.masterVolume > 0.0 : true)
							onClicked: { if (typeof window !== 'undefined') { window.masterVolume = 1.0; masterOnBtn.checked = true; masterOffBtn.checked = false; masterSlider.value = Math.round(window.masterVolume * 100); } persistSystemSettings(); }
						}
						AppButton { id: masterOffBtn; text: "OFF"; width: 100; height: 40; fontPixelSize: 18; checkable: true; checked: (typeof window !== 'undefined' ? window.masterVolume === 0.0 : false)
							onClicked: { if (typeof window !== 'undefined') { window.masterVolume = 0.0; masterOffBtn.checked = true; masterOnBtn.checked = false; masterSlider.value = Math.round(window.masterVolume * 100); } persistSystemSettings(); }
						}
					}
				}

				// 背景音乐
				Column { spacing: 5
					Text { text: "背景音乐"; font.pixelSize: 28; color: "white"; font.bold: true; style: Text.Outline; styleColor: "black" }
					ConfigSlider { id: bgmSlider; Component.onCompleted: value = Math.round((typeof window !== 'undefined' ? window.bgmVolume : 1.0) * 100); onValueChanged: { if (typeof window !== 'undefined') window.bgmVolume = value / 100.0; persistSystemSettings(); } }
					Row { spacing: 10
						AppButton { id: bgmOnBtn; text: "ON"; width: 100; height: 40; fontPixelSize: 18; checkable: true; checked: (typeof window !== 'undefined' ? window.bgmVolume > 0.0 : true); onClicked: { if (typeof window !== 'undefined') { window.bgmVolume = 1.0; bgmOnBtn.checked = true; bgmOffBtn.checked = false; bgmSlider.value = Math.round(window.bgmVolume * 100); } persistSystemSettings(); } }
						AppButton { id: bgmOffBtn; text: "OFF"; width: 100; height: 40; fontPixelSize: 18; checkable: true; checked: (typeof window !== 'undefined' ? window.bgmVolume === 0.0 : false); onClicked: { if (typeof window !== 'undefined') { window.bgmVolume = 0.0; bgmOffBtn.checked = true; bgmOnBtn.checked = false; bgmSlider.value = Math.round(window.bgmVolume * 100); } persistSystemSettings(); } }
					}
				}

				// 音效
				Column { spacing: 5
					Text { text: "效果音"; font.pixelSize: 28; color: "white"; font.bold: true; style: Text.Outline; styleColor: "black" }
					ConfigSlider { id: sfxSlider; Component.onCompleted: value = Math.round((typeof window !== 'undefined' ? window.sfxVolume : 1.0) * 100); onValueChanged: { if (typeof window !== 'undefined') window.sfxVolume = value / 100.0; persistSystemSettings(); } }
					Row { spacing: 8
						AppButton { id: sfxOnBtn; text: "ON"; width: 100; height: 40; fontPixelSize: 18; checkable: true; checked: (typeof window !== 'undefined' ? window.sfxVolume > 0.0 : true); onClicked: { if (typeof window !== 'undefined') { window.sfxVolume = 1.0; sfxOnBtn.checked = true; sfxOffBtn.checked = false; sfxSlider.value = Math.round(window.sfxVolume * 100); } persistSystemSettings(); } }
						AppButton { id: sfxOffBtn; text: "OFF"; width: 100; height: 40; fontPixelSize: 18; checkable: true; checked: (typeof window !== 'undefined' ? window.sfxVolume === 0.0 : false); onClicked: { if (typeof window !== 'undefined') { window.sfxVolume = 0.0; sfxOffBtn.checked = true; sfxOnBtn.checked = false; sfxSlider.value = Math.round(window.sfxVolume * 100); } persistSystemSettings(); } }
					}
				}

			}

			// 右侧第3列：文字显示速度 与 自动模式速度
			Column {
				spacing: 12

				Column { spacing: 5
					Text { text: "文字显示速度"; font.pixelSize: 28; color: "white"; font.bold: true; style: Text.Outline; styleColor: "black" }
					ConfigSlider { id: textSpeedSlider; value: 50; onValueChanged: persistSystemSettings() }
				}

				Column { spacing: 5
					Text { text: "自动模式速度"; font.pixelSize: 28; color: "white"; font.bold: true; style: Text.Outline; styleColor: "black" }
					ConfigSlider { id: autoModeSlider; value: 50; onValueChanged: persistSystemSettings() }
				}
			}
		}

		// 底部按钮栏
		BottomButtonBar {
			anchors.horizontalCenter: parent.horizontalCenter
			anchors.bottom: parent.bottom
			anchors.bottomMargin: 20
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

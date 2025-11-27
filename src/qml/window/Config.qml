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
								if (fullscreenBtn.checked) { if (window && window.setFullscreen) window.setFullscreen(true); }
								else { if (window && window.setFullscreen) window.setFullscreen(false); }
							} else {
								// no saved settings -> default to fullscreen
								fullscreenBtn.checked = true;
								windowBtn.checked = false;
								try { if (window && window.setFullscreen) window.setFullscreen(true); } catch(e) {}
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
						if (settings.sysSfxVolume !== undefined) sysSfxSlider.value = Math.round((settings.sysSfxVolume || 0.0) * 100);
						if (settings.textSpeed !== undefined) textSpeedSlider.value = settings.textSpeed;
						if (settings.textBoxOpacity !== undefined) {
							textBoxOpacitySlider.value = Math.round(settings.textBoxOpacity * 100);
							try { if (typeof window !== 'undefined') window.__textBoxOpacity = settings.textBoxOpacity; } catch(e) {}
						} else {
							// default to 60% when no stored setting
							textBoxOpacitySlider.value = 60;
							try { if (typeof window !== 'undefined') window.__textBoxOpacity = 0.6; } catch(e) {}
						}
						if (settings.autoModeWait !== undefined) autoModeSlider.value = settings.autoModeWait;
					}
					// aspect ratio
					if (settings.aspectRatio !== undefined) {
						if (settings.aspectRatio === '4:3') { aspect43Btn.checked = true; aspect169Btn.checked = false; }
						else { aspect169Btn.checked = true; aspect43Btn.checked = false; }
					} else {
						// default to 16:9 when no stored setting
						aspect169Btn.checked = true; aspect43Btn.checked = false;
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
				// system SFX (UI sounds like button hover/click)
				s.sysSfxVolume = (sysSfxSlider.value / 100.0);
				s.textSpeed = textSpeedSlider.value;
				// store text box opacity (0.0 - 1.0)
				try { s.textBoxOpacity = (textBoxOpacitySlider.value / 100.0); } catch(e) {}
				// store auto mode wait time in seconds (integer)
				s.autoModeWait = autoModeSlider.value;
				// aspect ratio preference
				try { s.aspectRatio = (aspect43Btn.checked ? '4:3' : '16:9'); } catch(e) {}
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
			// if fullscreen button exists try to restore normal; call window.setFullscreen so we persist
			if (window && window.setFullscreen) {
				window.setFullscreen(false);
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
		// 控件左对齐基准（用于让 section 标题、slider 的 leftBtn、首个 AppButton 左对齐）
		property int controlLeftMargin:  Math.round(baseWidth * 0.02) // ~24 at 1280 width

		function resetToDefaults() {
			// Visual / window defaults
			try {
				if (typeof fullscreenBtn !== 'undefined') { fullscreenBtn.checked = true; }
				if (typeof windowBtn !== 'undefined') { windowBtn.checked = false; }
				try { if (window && window.setFullscreen) window.setFullscreen(true); } catch(e) {}
			} catch(e) {}

			// Text skip defaults
			try { textSkipReadBtn.checked = true; textSkipAllBtn.checked = false; } catch(e) {}

			// Options
			try { optFastYes.checked = false; optFastNo.checked = true; } catch(e) {}
			try { optAutoYes.checked = false; optAutoNo.checked = true; } catch(e) {}

			// Volumes
			try { masterSlider.value = 100; masterOnBtn.checked = true; masterOffBtn.checked = false; } catch(e) {}
			try { bgmSlider.value = 100; bgmOnBtn.checked = true; bgmOffBtn.checked = false; } catch(e) {}
			try { sfxSlider.value = 100; sfxOnBtn.checked = true; sfxOffBtn.checked = false; } catch(e) {}
			try { sysSfxSlider.value = 100; sysSfxOnBtn.checked = true; sysSfxOffBtn.checked = false; } catch(e) {}

			// Text / auto defaults
			try { textSpeedSlider.value = 0.008; } catch(e) {}
			try { textBoxOpacitySlider.value = 100; } catch(e) {}
				try { textBoxOpacitySlider.value = 60; if (typeof window !== 'undefined') window.__textBoxOpacity = 0.6; } catch(e) {}
			try { autoModeSlider.value = 3; } catch(e) {}

			// Aspect ratio default
			try { aspect169Btn.checked = true; aspect43Btn.checked = false; } catch(e) {}

			// Persist defaults
			persistSystemSettings();
		}
		anchors.horizontalCenter: parent.horizontalCenter
		anchors.verticalCenter: parent.verticalCenter
		transform: Scale { xScale: scaleFactor; yScale: scaleFactor; origin.x: baseWidth/2; origin.y: baseHeight/2 }


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

		// 右上角：恢复默认 按钮
		AppButton {
			id: resetDefaultsBtn
			text: "恢复默认"
			anchors.top: parent.top
			anchors.topMargin: 24
			anchors.right: parent.right
			anchors.rightMargin: 24
			z: 10
			width: 220; height: 56
			fontPixelSize: 20
			onClicked: {
				contentRoot.resetToDefaults();
			}
		}

		// 中间设置内容
				Row {
			width: childrenRect.width
			anchors.horizontalCenter: parent.horizontalCenter
			anchors.top: parent.top
			anchors.topMargin: 100
			spacing: 60

			// 左列
			Column {
				spacing: 6

				// 画面尺寸
				Column {
					spacing: 8
					Text {
						text: "画面尺寸"
						anchors.left: parent.left
						anchors.leftMargin: contentRoot.controlLeftMargin
						font.pixelSize: 28
						color: "white"
						font.bold: true
						style: Text.Outline; styleColor: "black"
					}
						Row {
							anchors.left: parent.left
							anchors.leftMargin: contentRoot.controlLeftMargin
							spacing: 12
							AppButton {
							id: windowBtn
							text: "窗口"
							width: 140; height: 50
							fontPixelSize: 20
							checkable: true
							checked: !fullscreenBtn.checked
							onClicked: {
								// If already windowed, keep button state and do nothing
								try {
									if (window && window.visibility !== Window.FullScreen) {
										checked = true; fullscreenBtn.checked = false; return;
									}
								} catch(e) {}
								window.setFullscreen && window.setFullscreen(false);
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
								// If already fullscreen, restore visual checked state and do nothing
								try {
									if (window && window.visibility === Window.FullScreen) {
										checked = true; windowBtn.checked = false; return;
									}
								} catch(e) {}
								window.setFullscreen && window.setFullscreen(true);
								windowBtn.checked = false;
								persistSystemSettings();
							}
						}
					}
				}

				// 画面比例
				Column {
					spacing: 8
					Text {
						text: "画面比例"
						anchors.left: parent.left
						anchors.leftMargin: contentRoot.controlLeftMargin
						font.pixelSize: 28
						color: "white"
						font.bold: true
						style: Text.Outline; styleColor: "black"
					}
					Row {
						anchors.left: parent.left
						anchors.leftMargin: contentRoot.controlLeftMargin
						spacing: 12
						AppButton {
							id: aspect169Btn
							text: "16:9"
							width: 140; height: 50
							fontPixelSize: 20
							checkable: true
							checked: true
							onClicked: {
								checked = true; aspect43Btn.checked = false;
								try { if (window && window.applyAspectRatio) window.applyAspectRatio('16:9'); } catch(e) {}
								persistSystemSettings();
							}
						}
						AppButton {
							id: aspect43Btn
							text: "4:3"
							width: 140; height: 50
							fontPixelSize: 20
							checkable: true
							onClicked: {
								checked = true; aspect169Btn.checked = false;
								try { if (window && window.applyAspectRatio) window.applyAspectRatio('4:3'); } catch(e) {}
								persistSystemSettings();
							}
						}
					}
				}

				// 文本跳过
				Column {
					spacing: 8
					Text {
						text: "可快进文本"
						anchors.left: parent.left
						anchors.leftMargin: contentRoot.controlLeftMargin
						font.pixelSize: 28
						color: "white"
						font.bold: true
						style: Text.Outline; styleColor: "black"
					}
					Row {
						anchors.left: parent.left
						anchors.leftMargin: contentRoot.controlLeftMargin
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
						text: "选项后继续快进"
						anchors.left: parent.left
						anchors.leftMargin: contentRoot.controlLeftMargin
						font.pixelSize: 28
						color: "white"
						font.bold: true
						style: Text.Outline; styleColor: "black"
					}
					Row {
						anchors.left: parent.left
						anchors.leftMargin: contentRoot.controlLeftMargin
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
						anchors.left: parent.left
						anchors.leftMargin: contentRoot.controlLeftMargin
						font.pixelSize: 28
						color: "white"
						font.bold: true
						style: Text.Outline; styleColor: "black"
					}
					Row {
						anchors.left: parent.left
						anchors.leftMargin: contentRoot.controlLeftMargin
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
				spacing: 6

				// 主音量
				Column { spacing: 3
					Text { text: "主音量"; font.pixelSize: 28; color: "white"; font.bold: true; style: Text.Outline; styleColor: "black";
						anchors.left: parent.left; anchors.leftMargin: contentRoot.controlLeftMargin }
					ConfigSlider { id: masterSlider; leftAligned: true; leftMargin: contentRoot.controlLeftMargin; Component.onCompleted: value = Math.round((typeof window !== 'undefined' ? window.masterVolume : 1.0) * 100); onValueChanged: { if (typeof window !== 'undefined') window.masterVolume = value / 100.0; persistSystemSettings(); } }
					Row { anchors.left: parent.left; anchors.leftMargin: contentRoot.controlLeftMargin; spacing: 8
						AppButton { id: masterOnBtn; text: "ON"; width: 100; height: 40; fontPixelSize: 18; checkable: true; checked: (typeof window !== 'undefined' ? window.masterVolume > 0.0 : true)
							onClicked: { if (typeof window !== 'undefined') { window.masterVolume = 1.0; masterOnBtn.checked = true; masterOffBtn.checked = false; masterSlider.value = Math.round(window.masterVolume * 100); } persistSystemSettings(); }
						}
						AppButton { id: masterOffBtn; text: "OFF"; width: 100; height: 40; fontPixelSize: 18; checkable: true; checked: (typeof window !== 'undefined' ? window.masterVolume === 0.0 : false)
							onClicked: { if (typeof window !== 'undefined') { window.masterVolume = 0.0; masterOffBtn.checked = true; masterOnBtn.checked = false; masterSlider.value = Math.round(window.masterVolume * 100); } persistSystemSettings(); }
						}
					}
				}

				// 背景音乐
				Column { spacing: 3
					Text { text: "BGM(背景音乐)"; font.pixelSize: 28; color: "white"; font.bold: true; style: Text.Outline; styleColor: "black"; anchors.left: parent.left; anchors.leftMargin: contentRoot.controlLeftMargin }
					ConfigSlider { id: bgmSlider; leftAligned: true; leftMargin: contentRoot.controlLeftMargin; Component.onCompleted: value = Math.round((typeof window !== 'undefined' ? window.bgmVolume : 1.0) * 100); onValueChanged: { if (typeof window !== 'undefined') window.bgmVolume = value / 100.0; persistSystemSettings(); } }
					Row { anchors.left: parent.left; anchors.leftMargin: contentRoot.controlLeftMargin; spacing: 10
						AppButton { id: bgmOnBtn; text: "ON"; width: 100; height: 40; fontPixelSize: 18; checkable: true; checked: (typeof window !== 'undefined' ? window.bgmVolume > 0.0 : true); onClicked: { if (typeof window !== 'undefined') { window.bgmVolume = 1.0; bgmOnBtn.checked = true; bgmOffBtn.checked = false; bgmSlider.value = Math.round(window.bgmVolume * 100); } persistSystemSettings(); } }
						AppButton { id: bgmOffBtn; text: "OFF"; width: 100; height: 40; fontPixelSize: 18; checkable: true; checked: (typeof window !== 'undefined' ? window.bgmVolume === 0.0 : false); onClicked: { if (typeof window !== 'undefined') { window.bgmVolume = 0.0; bgmOffBtn.checked = true; bgmOnBtn.checked = false; bgmSlider.value = Math.round(window.bgmVolume * 100); } persistSystemSettings(); } }
					}
				}

				// 音效
				Column { spacing: 3
					Text { text: "SE(游戏效果音)"; font.pixelSize: 28; color: "white"; font.bold: true; style: Text.Outline; styleColor: "black"; anchors.left: parent.left; anchors.leftMargin: contentRoot.controlLeftMargin }
					ConfigSlider { id: sfxSlider; leftAligned: true; leftMargin: contentRoot.controlLeftMargin; Component.onCompleted: value = Math.round((typeof window !== 'undefined' ? window.sfxVolume : 1.0) * 100); onValueChanged: { if (typeof window !== 'undefined') window.sfxVolume = value / 100.0; persistSystemSettings(); } }
					Row { anchors.left: parent.left; anchors.leftMargin: contentRoot.controlLeftMargin; spacing: 8
						AppButton { id: sfxOnBtn; text: "ON"; width: 100; height: 40; fontPixelSize: 18; checkable: true; checked: (typeof window !== 'undefined' ? window.sfxVolume > 0.0 : true); onClicked: { if (typeof window !== 'undefined') { window.sfxVolume = 1.0; sfxOnBtn.checked = true; sfxOffBtn.checked = false; sfxSlider.value = Math.round(window.sfxVolume * 100); } persistSystemSettings(); } }
						AppButton { id: sfxOffBtn; text: "OFF"; width: 100; height: 40; fontPixelSize: 18; checkable: true; checked: (typeof window !== 'undefined' ? window.sfxVolume === 0.0 : false); onClicked: { if (typeof window !== 'undefined') { window.sfxVolume = 0.0; sfxOffBtn.checked = true; sfxOnBtn.checked = false; sfxSlider.value = Math.round(window.sfxVolume * 100); } persistSystemSettings(); } }
						}
					}

					// 系统音效（用于 UI 按钮悬浮/点击）
					Column { spacing: 3
						Text { text: "SE(系统效果音)"; font.pixelSize: 28; color: "white"; font.bold: true; style: Text.Outline; styleColor: "black"; anchors.left: parent.left; anchors.leftMargin: contentRoot.controlLeftMargin }
						ConfigSlider { id: sysSfxSlider; leftAligned: true; leftMargin: contentRoot.controlLeftMargin; Component.onCompleted: value = Math.round((typeof window !== 'undefined' ? window.sysSfxVolume : 1.0) * 100); onValueChanged: { if (typeof window !== 'undefined') window.sysSfxVolume = value / 100.0; persistSystemSettings(); } }
						Row { anchors.left: parent.left; anchors.leftMargin: contentRoot.controlLeftMargin; spacing: 8
							AppButton { id: sysSfxOnBtn; text: "ON"; width: 100; height: 40; fontPixelSize: 18; checkable: true; checked: (typeof window !== 'undefined' ? window.sysSfxVolume > 0.0 : true); onClicked: { if (typeof window !== 'undefined') { window.sysSfxVolume = 1.0; sysSfxOnBtn.checked = true; sysSfxOffBtn.checked = false; sysSfxSlider.value = Math.round(window.sysSfxVolume * 100); } persistSystemSettings(); } }
							AppButton { id: sysSfxOffBtn; text: "OFF"; width: 100; height: 40; fontPixelSize: 18; checkable: true; checked: (typeof window !== 'undefined' ? window.sysSfxVolume === 0.0 : false); onClicked: { if (typeof window !== 'undefined') { window.sysSfxVolume = 0.0; sysSfxOffBtn.checked = true; sysSfxOnBtn.checked = false; sysSfxSlider.value = Math.round(window.sysSfxVolume * 100); } persistSystemSettings(); } }
							}
						}

			}

			// 右侧第3列：文字显示速度 与 自动模式速度
			Column {
				spacing: 10
					// Ensure the first two columns' labels and sliders left-align within this column

				Column { spacing: 5
					Text { text: "每个文字显示时间 (秒)"; font.pixelSize: 28; color: "white"; font.bold: true; style: Text.Outline; styleColor: "black";
						anchors.left: parent.left; anchors.leftMargin: 0 }
					ConfigSlider { id: textSpeedSlider; leftAligned: true; leftMargin: 0; value: 0.008; minValue: 0.001; maxValue: 0.035; step: 0.001; onValueChanged: { if (typeof window !== 'undefined') window.__textSpeed = value; persistSystemSettings(); } }
				}

				Column { spacing: 5
					Text { text: "自动模式等待时间 (秒)"; font.pixelSize: 28; color: "white"; font.bold: true; style: Text.Outline; styleColor: "black";
						anchors.left: parent.left; anchors.leftMargin: 0 }
					ConfigSlider { id: autoModeSlider; leftAligned: true; leftMargin: 0; value: 3; minValue: 1; maxValue: 10; step: 1; onValueChanged: { if (typeof window !== 'undefined') window.__autoModeWait = value; persistSystemSettings(); } }
				}

				// 文本栏透明度
				Column {
					spacing: 8
					Text { text: "文本栏透明度"; font.pixelSize: 28; color: "white"; font.bold: true; style: Text.Outline; styleColor: "black";
						anchors.left: parent.left; anchors.leftMargin: 0 }
					Row { anchors.left: parent.left; anchors.leftMargin: 0; spacing: 12
						ConfigSlider {
												id: textBoxOpacitySlider;
												leftAligned: true; leftMargin: 0; value: 60; minValue: 0; maxValue: 100; step: 1;
												Component.onCompleted: {
													if (typeof window !== 'undefined' && window.__textBoxOpacity !== undefined) {
														value = Math.round(window.__textBoxOpacity * 100);
													} else {
														value = 60;
													}
												}
												onValueChanged: { if (typeof window !== 'undefined') window.__textBoxOpacity = value / 100.0; persistSystemSettings(); }
											}
					}

					// 测试框：用于实时测试文字速度和文字框透明度
					Rectangle {
						id: textBoxTest
						anchors.left: parent.left
						anchors.leftMargin: 0
						anchors.right: parent.right
						anchors.rightMargin: 14
						height: 180
						color: Qt.rgba(0.96, 0.96, 0.96, (typeof window !== 'undefined' && window.__textBoxOpacity !== undefined ? Number(window.__textBoxOpacity) : 0.6))
						border.color: "#CCCCCC"
						radius: 6
						z: 2
						Column { anchors.fill: parent; anchors.margins: 8; spacing: 6
							
							Text { id: testDisplayedText; color: "#222222"; font.pixelSize: 18; wrapMode: Text.Wrap; width: parent.width; text: textBoxTest.testDisplayed }
							Row { spacing: 10;
								Text { id: speedInfo; text: (typeof window !== 'undefined' ? (Math.round(window.__textSpeed * 1000) + " ms/char") : "") ; color: "#AAAAAA"; font.pixelSize: 12 }
							}
						}
						// local state for typing test: cycle two long paragraphs for auto-mode testing
						property var testParagraphs: [
							"这是测试的第一段示例文本，用来验证逐字显示。",
							"这是第二段测试文本，用于在第一段播放完成后自动切换并继续播放，以便测试连续段落的自动模式和延迟处理。第二段也应足够长，从而验证段落间的停顿与循环重播逻辑。"
						]
						property int testParagraphIndex: 0
						property string testFull: testParagraphs.length > 0 ? testParagraphs[0] : ""
						property int testRevealIndex: 0
						property string testDisplayed: ""
						Timer { id: testTimer; interval: Math.max(1, Math.round((typeof window !== 'undefined' && window.__textSpeed ? window.__textSpeed : 0.008) * 1000)); repeat: true; running: true; onTriggered: {
							try {
								if (textBoxTest.testRevealIndex < textBoxTest.testFull.length) {
									textBoxTest.testRevealIndex = Math.min(textBoxTest.testFull.length, textBoxTest.testRevealIndex + 1);
									textBoxTest.testDisplayed = textBoxTest.testFull.substr(0, textBoxTest.testRevealIndex);
								} else {
									// finished current paragraph: pause briefly, then switch to next paragraph and restart
									testTimer.stop();
									pauseBetweenParagraphs.start();
								}
							} catch(e) {}
						} }
						Timer { id: pauseBetweenParagraphs; interval: 1000; running: false; repeat: false; onTriggered: {
							textBoxTest.testParagraphIndex = (textBoxTest.testParagraphIndex + 1) % textBoxTest.testParagraphs.length;
							textBoxTest.testFull = textBoxTest.testParagraphs[textBoxTest.testParagraphIndex];
							textBoxTest.testRevealIndex = 0;
							textBoxTest.testDisplayed = "";
							testTimer.interval = Math.max(1, Math.round((typeof window !== 'undefined' && window.__textSpeed ? window.__textSpeed : 0.008) * 1000));
							testTimer.start();
						} }

						function restartTest() { pauseBetweenParagraphs.stop(); testTimer.stop(); textBoxTest.testParagraphIndex = 0; textBoxTest.testFull = textBoxTest.testParagraphs[0]; textBoxTest.testDisplayed = ""; textBoxTest.testRevealIndex = 0; testTimer.interval = Math.max(1, Math.round((typeof window !== 'undefined' && window.__textSpeed ? window.__textSpeed : 0.008) * 1000)); testTimer.start(); }
						onVisibleChanged: {
							speedInfo.text = (typeof window !== 'undefined' ? (Math.round(window.__textSpeed * 1000) + " ms/char") : "");
							if (visible) restartTest();
						}
						Connections { target: window
							function on__TextSpeedChanged() { testTimer.interval = Math.max(1, Math.round(window.__textSpeed * 1000)); speedInfo.text = Math.round(window.__textSpeed * 1000) + " ms/char"; restartTest(); }
							function on__TextBoxOpacityChanged() { textBoxTest.color = Qt.rgba(0.96, 0.96, 0.96, (typeof window !== 'undefined' && window.__textBoxOpacity !== undefined ? Number(window.__textBoxOpacity) : 1.0)); }
						}
					}
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

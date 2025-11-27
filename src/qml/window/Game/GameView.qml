import QtQuick 2.15
import QtQuick.Controls 2.15
import QtMultimedia 6.5
// Fix relative imports: Map and Entity are subfolders of Game
import "./Map"
import "./Entity" as EntityQml
// windowState.js is in the parent directory of Game
import "../windowState.js" as WindowState
import GeistZerfall.Game 1.0
// import shared components (AppButton)
import "../../components"

Item {
    id: gameViewRoot
	// 是否显示屏幕触控（左下摇杆 + 右下操作按钮）
	// 默认 NO（显示控件）
	property bool controlsVisible: true
	// 通过context property注入playerObj
	// Backward-compatible global aim coordinates (fallback to avoid ReferenceError from legacy code)
	property real aimX: 0
	property real aimY: 0
	// Whether the player is holding the snipe/space key in this view - used to lock sight while held
	property bool snipeHeld: false
	// Aim mode selection: "mouse" follows cursor, "move" follows player movement direction
	property string aimMode: "move"
	// Cache last normalized move direction for aim fallback when player stops moving
	property real lastMoveAimDirX: 0
	property real lastMoveAimDirY: -1

	// 战斗数据相关
	property string battleId: ""
	property var battleData: null

	// 在组件完成时加载战斗数据
	Component.onCompleted: {
		var candidate = "";
		if (typeof window !== 'undefined' && window.currentBattleId) {
			candidate = window.currentBattleId;
		}

		// (keyboard/controls connections are declared elsewhere - kept out of onCompleted to avoid syntax errors)
		if (!candidate) {
			try {
				if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager && SaveLoadManager.battleId) {
					candidate = SaveLoadManager.battleId;
				}
			} catch (eBattle) { console.log('GameView: fetch battleId from SaveLoadManager failed', eBattle); }
		}
		if (candidate) {
			battleId = candidate;
			if (typeof window !== 'undefined') window.currentBattleId = candidate;
			loadBattleData(battleId);
		}

		// Load persisted controlsVisible state if available
		try {
			if (typeof WindowState !== 'undefined' && WindowState.getControlsVisible) {
				var cv = WindowState.getControlsVisible();
				if (typeof cv !== 'undefined' && cv !== null) {
					controlsVisible = cv;
				} else if (WindowState.setControlsVisible) {
					WindowState.setControlsVisible(controlsVisible);
				}
			}
		} catch(eCV) { console.log('reading controlsVisible from WindowState failed', eCV); }

		// load persisted system settings (aimMode / controlsVisible) if available
		try {
			if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager) {
				var sys = SaveLoadManager.loadSystem();
				if (sys) {
					if (sys.controlsVisible !== undefined) controlsVisible = !!sys.controlsVisible;
					if (sys.aimMode !== undefined) aimMode = (sys.aimMode === 'mouse' ? 'mouse' : 'move');
				}
			}
		} catch (eSys) { console.log('GameView: loadSystem failed', eSys); }

		Qt.callLater(function() {
			if (aimMode === "move") setMoveAimTarget();
		});
	}

	onControlsVisibleChanged: {
		try { if (typeof WindowState !== 'undefined' && WindowState.setControlsVisible) WindowState.setControlsVisible(controlsVisible); } catch(e) { console.log('persist controlsVisible failed', e); }
		try {
			if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager) {
				var s = SaveLoadManager.loadSystem() || {};
				s.controlsVisible = !!controlsVisible;
				SaveLoadManager.saveSystem(s);
			}
		} catch (e2) { console.log('GameView: saveSystem failed', e2); }
	}

	// Global keys mirror: ensure keyboard works even if playerItem didn't get focus
	// (do not force focus here — playerItem should keep focus so its keyDown/keyUp signals fire)
	Keys.onPressed: function(event) {
			try {
				// Movement keys
				if (!playerItem) return;
				if (event.key === Qt.Key_W || event.key === Qt.Key_Up) { playerItem.wDown = true; playerItem.computeAndMove(); joystickArea.updateFromKeyboard(); }
				if (event.key === Qt.Key_S || event.key === Qt.Key_Down) { playerItem.sDown = true; playerItem.computeAndMove(); joystickArea.updateFromKeyboard(); }
				if (event.key === Qt.Key_A || event.key === Qt.Key_Left) { playerItem.aDown = true; playerItem.computeAndMove(); joystickArea.updateFromKeyboard(); }
				if (event.key === Qt.Key_D || event.key === Qt.Key_Right) { playerItem.dDown = true; playerItem.computeAndMove(); joystickArea.updateFromKeyboard(); }

				// Action keys -> delegate to touchControls for consistent handling
				if (touchControls && typeof touchControls.setButtonPressFromKey === "function") {
					switch (event.key) {
					case Qt.Key_Q:
					case Qt.Key_F:
					case Qt.Key_Space:
					case Qt.Key_J:
					case Qt.Key_1:
					case Qt.Key_K:
					case Qt.Key_2:
					case Qt.Key_L:
					case Qt.Key_3:
					case Qt.Key_0:
						touchControls.setButtonPressFromKey(event.key, true);
						break;
					default:
						break;
					}
				}
			} catch(e) {}
		}
	Keys.onReleased: function(event) {
			try {
				if (!playerItem) return;
				if (event.key === Qt.Key_W || event.key === Qt.Key_Up) { playerItem.wDown = false; playerItem.computeAndMove(); joystickArea.updateFromKeyboard(); }
				if (event.key === Qt.Key_S || event.key === Qt.Key_Down) { playerItem.sDown = false; playerItem.computeAndMove(); joystickArea.updateFromKeyboard(); }
				if (event.key === Qt.Key_A || event.key === Qt.Key_Left) { playerItem.aDown = false; playerItem.computeAndMove(); joystickArea.updateFromKeyboard(); }
				if (event.key === Qt.Key_D || event.key === Qt.Key_Right) { playerItem.dDown = false; playerItem.computeAndMove(); joystickArea.updateFromKeyboard(); }

				if (touchControls && typeof touchControls.setButtonPressFromKey === "function") {
					switch (event.key) {
					case Qt.Key_Q:
					case Qt.Key_F:
					case Qt.Key_Space:
					case Qt.Key_J:
					case Qt.Key_1:
					case Qt.Key_K:
					case Qt.Key_2:
					case Qt.Key_L:
					case Qt.Key_3:
					case Qt.Key_0:
						touchControls.setButtonPressFromKey(event.key, false);
						break;
					default:
						break;
					}
				}
			} catch(e) {}
		}

	function engageSnipeHold() {
		try { if (typeof btnSpace !== 'undefined' && btnSpace) btnSpace.pressed = true; } catch(e) {}
		if (!gameViewRoot.snipeHeld) {
			gameViewRoot.snipeHeld = true;
			try { if (playerObj && typeof playerObj.snipeStart === 'function') playerObj.snipeStart(); } catch(e) {}
		}
		tileScale = 1 / 3.0;
		sightMask.radius = sightMask.baseRadius * tileScale;
		try { if (fireTimer && fireTimer.running) fireTimer.stop(); } catch(e) {}
		try { if (playerItem && typeof playerItem.startBulletRecharge === 'function') playerItem.startBulletRecharge(); } catch(e) {}
	}

	function releaseSnipeHold() {
		try { if (typeof btnSpace !== 'undefined' && btnSpace) btnSpace.pressed = false; } catch(e) {}
		var wasHeld = gameViewRoot.snipeHeld;
		gameViewRoot.snipeHeld = false;
		if (wasHeld) {
			try { if (playerObj && typeof playerObj.snipeStop === 'function') playerObj.snipeStop(); } catch(e) {}
		}
		tileScale = 1.0;
		sightMask.radius = sightMask.baseRadius * tileScale;
		try { if (playerItem && typeof playerItem.startBulletRecharge === 'function') playerItem.startBulletRecharge(); } catch(e) {}
	}

	// Top-left player HP/MP display (percentages)
	Item {
		id: hpDisplayRoot
		anchors.top: parent.top
		anchors.left: parent.left
		anchors.topMargin: 12
		anchors.leftMargin: 12
		z: 3000
		Rectangle {
			id: hpBg
			anchors.top: parent.top
			anchors.left: parent.left
			color: "#00000080"
			radius: 6
			width: Math.max(textTime.width, textHp.width, textMp1.width, textMp2.width) + 24
			height: statsColumn.height + 12
		}

		Column {
			id: statsColumn
			anchors.left: hpBg.left
			anchors.leftMargin: 12
			anchors.top: hpBg.top
			anchors.topMargin: 6
			spacing: 2

			// Countdown (when a time limit is configured)
			Text {
				id: textTime
				color: "white"
				font.pixelSize: 28
				font.bold: true
				text: "Timer：" + formatTimeLeft()
				visible: timeLimitSeconds > 0
				horizontalAlignment: Text.AlignLeft
			}

			// smaller font than before per request
			Text {
				id: textHp
				color: "white"
				font.pixelSize: 28
				font.bold: true
				// Show HP as percentage (round to integer). If no data, show '-'.
				text: (playerObj && typeof playerObj.hp !== 'undefined' && typeof playerObj.maxHp !== 'undefined' && playerObj.maxHp > 0) ? ("HP：" + Math.round(playerObj.hp / Math.max(1, playerObj.maxHp) * 100) + "%") : "HP： -"
				horizontalAlignment: Text.AlignLeft
			}

			// MP1 = bulletCd percentage (from playerItem)
			Text {
				id: textMp1
				color: "white"
				font.pixelSize: 28
				font.bold: true
				text: (playerItem && typeof playerItem.bulletCd !== 'undefined' && typeof playerItem.bulletCdMax !== 'undefined' && playerItem.bulletCdMax > 0) ? ("MP1：" + Math.round(playerItem.bulletCd / Math.max(1, playerItem.bulletCdMax) * 100) + "%") : "MP1： -"
				horizontalAlignment: Text.AlignLeft
			}

			// MP2 = laserCd percentage (from playerItem)
			Text {
				id: textMp2
				color: "white"
				font.pixelSize: 28
				font.bold: true
				text: (playerItem && typeof playerItem.laserCd !== 'undefined' && typeof playerItem.laserCdMax !== 'undefined' && playerItem.laserCdMax > 0) ? ("MP2：" + Math.round(playerItem.laserCd / Math.max(1, playerItem.laserCdMax) * 100) + "%") : "MP2： -"
				horizontalAlignment: Text.AlignLeft
			}
		}
	}

	// 加载战斗数据（使用 FileReader 读取 JSON）
	function loadBattleData(id) {
		console.log("GameView: loading battle data", id);
		
	// 构建 JSON 文件路径
	var filePath = ":/qml/window/Game/battles/" + id + ".json";
		console.log("GameView: reading file", filePath);
		
		// 使用 fileReader 读取 JSON
		var jsonObj = fileReader.readJsonFile(filePath);
		
		// 将 QJsonObject 转换为 JavaScript 对象
		battleData = JSON.parse(JSON.stringify(jsonObj));
		
		if (battleData && battleData.mapData) {
			console.log("GameView: loaded battle data", id);
			// 设置地图数据
			tileManager.setMapData(battleData.mapData);
			spawnEnemiesFromMap();
			// Setup optional time-limit rule from battle JSON. Support multiple possible field names for compatibility.
			try {
				var tl = 0;
				if (battleData && battleData.rules) {
					tl = battleData.rules.timeLimitSeconds || battleData.rules.timeLimit || battleData.rules.timeLimitSec || 0;
				}
				if (tl && tl > 0) {
					timeLimitSeconds = tl;
					// Prefer any previously-restored remaining time (from SaveLoadManager or prior state).
					var restored = false;
					try {
						if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager && typeof SaveLoadManager.timeLeftSeconds !== 'undefined' && SaveLoadManager.timeLeftSeconds !== null) {
							// Only restore saved remaining time if the save belongs to this battle and has positive time
							if (SaveLoadManager.battleId === battleId && SaveLoadManager.timeLeftSeconds > 0) {
								timeLeftSeconds = SaveLoadManager.timeLeftSeconds;
								restored = true;
							}
						}
					} catch(e) { /* ignore */ }
					// If nothing restored and current timeLeftSeconds is not set, initialize to full length
					if (!restored && (!timeLeftSeconds || timeLeftSeconds <= 0)) {
						timeLeftSeconds = tl;
						countdownTimer.running = true;
						console.log('GameView: starting countdown, seconds=', tl);
					} else {
						// If restored or existing, ensure timer is running only if positive
						countdownTimer.running = (timeLeftSeconds > 0);
						console.log('GameView: countdown restored or preserved, timeLeftSeconds=', timeLeftSeconds);
					}
				}
			} catch(eTL) { console.log('setup timeLimit failed', eTL); }
			// 播放对应的BGM（通过宿主 window 提供的播放函数）
			if (battleData.meta && battleData.meta.bgm) {
				if (typeof window !== 'undefined' && typeof window.playMusic === 'function') {
					try {
						window.playMusic("qrc:/resource/audio/bgm/" + battleData.meta.bgm);
					} catch (e) { console.log('播放BGM失败', e); }
				}
			}
		} else {
			console.log("GameView: failed to load battle", id);
		}
	}

	// Enemies container and list
	property var enemyBackends: []
	property var enemyVisuals: []
	property var enemySpawnCenters: []
	property var enemyTypes: []

	function isEnemyDead(backend) {
		if (!backend) return true;
		var hpOk = (typeof backend.hp !== 'undefined') ? (backend.hp <= 0) : false;
		var aliveFlag = (typeof backend.alive !== 'undefined') ? backend.alive : !hpOk;
		return hpOk || !aliveFlag;
	}

	function removeEnemyAt(index) {
		if (index < 0 || index >= enemyBackends.length) return;
		var v = enemyVisuals[index];
		var b = enemyBackends[index];
		try { if (v && typeof v.destroy === 'function') v.destroy(); } catch(e) {}
		try { if (b && typeof b.deleteLater === 'function') b.deleteLater(); } catch(e) {}
		enemyVisuals.splice(index, 1);
		enemyBackends.splice(index, 1);
		enemySpawnCenters.splice(index, 1);
		enemyTypes.splice(index, 1);
	}

	function cleanupDeadEnemies() {
		for (var i = enemyBackends.length - 1; i >= 0; --i) {
			var b = enemyBackends[i];
			if (isEnemyDead(b)) {
				removeEnemyAt(i);
			}
		}
		// keep snapshot fresh for save UI
		try { WindowState.setGameEnemies && WindowState.setGameEnemies(serializeEnemies()); } catch(e) {}
	}

	Timer {
		id: enemyCleanupTimer
		interval: 200
		repeat: true
		running: true
		onTriggered: cleanupDeadEnemies()
	}

	// Battle end detection: when player HP reaches 0 (lose) or all enemies dead (win)
	property bool battleEnded: false

	// Optional time-limit rule: if set (>0) counts down every second. When reaches 0 and player HP>0, it's a win.
	property int timeLimitSeconds: 0
	property int timeLeftSeconds: 0
	property bool countdownRunning: false

	function formatTimeLeft() {
		var s = Math.max(0, Math.round(timeLeftSeconds));
		var mm = Math.floor(s/60);
		var ss = s % 60;
		return (mm < 10 ? "0" + mm : mm) + ":" + (ss < 10 ? "0" + ss : ss);
	}

	// Centered overlay to display Win/Lose messages
	Item {
		id: resultOverlayRoot
		anchors.fill: parent
		visible: false
		z: 10000
		Rectangle {
			id: resultOverlayBg
			anchors.centerIn: parent
			color: "#000000cc"
			radius: 8
			width: resultOverlayText.width + 80
			height: resultOverlayText.height + 40
			transformOrigin: Item.Center
			scale: 1.0
			opacity: 1.0
		}
		Text {
			id: resultOverlayText
			anchors.centerIn: resultOverlayBg
			color: "white"
			font.pixelSize: 72
			font.bold: true
			text: ""
			transformOrigin: Item.Center
			scale: 1.0
			opacity: 1.0
		}
	}

	property var resultOverlayCallback: null
	Timer {
		id: resultOverlayTimer
		repeat: false
		running: false
		onTriggered: {
			// start hide animation; callback will be invoked by hideAnim.onFinished
			try { resultHideAnim.start(); } catch(e) { console.log('start hideAnim failed', e); }
		}
	}

	function showResultOverlay(message, durationMs, callback) {
		try {
			resultOverlayText.text = message;
			resultOverlayRoot.visible = true;
			// prepare initial animated state
			resultOverlayBg.scale = 0.6; resultOverlayBg.opacity = 0.0;
			resultOverlayText.scale = 0.6; resultOverlayText.opacity = 0.0;
			resultOverlayCallback = callback || null;
			resultOverlayTimer.stop();
			resultOverlayTimer.interval = durationMs || 1200;
			resultOverlayTimer.running = true;
			// play entry animation
			try { resultShowAnim.start(); } catch(e) { console.log('start showAnim failed', e); }
		} catch (e) { console.log('showResultOverlay failed', e); if (typeof callback === 'function') callback(); }
	}

	// show animation: pop + settle
	SequentialAnimation {
		id: resultShowAnim
		running: false
		ParallelAnimation {
			PropertyAnimation { target: resultOverlayBg; property: "scale"; from: 0.6; to: 1.12; duration: 220; easing.type: Easing.OutBack }
			PropertyAnimation { target: resultOverlayBg; property: "opacity"; from: 0.0; to: 1.0; duration: 220 }
			PropertyAnimation { target: resultOverlayText; property: "scale"; from: 0.6; to: 1.12; duration: 220; easing.type: Easing.OutBack }
			PropertyAnimation { target: resultOverlayText; property: "opacity"; from: 0.0; to: 1.0; duration: 220 }
		}
		PauseAnimation { duration: 100 }
		ParallelAnimation {
			PropertyAnimation { target: resultOverlayBg; property: "scale"; to: 1.0; duration: 140; easing.type: Easing.OutQuad }
			PropertyAnimation { target: resultOverlayText; property: "scale"; to: 1.0; duration: 140; easing.type: Easing.OutQuad }
		}
	}

	// hide animation: shrink & fade
	ParallelAnimation {
		id: resultHideAnim
		running: false
		PropertyAnimation { target: resultOverlayBg; property: "scale"; to: 0.9; duration: 160; easing.type: Easing.InQuad }
		PropertyAnimation { target: resultOverlayBg; property: "opacity"; to: 0.0; duration: 160 }
		PropertyAnimation { target: resultOverlayText; property: "scale"; to: 0.9; duration: 160; easing.type: Easing.InQuad }
		PropertyAnimation { target: resultOverlayText; property: "opacity"; to: 0.0; duration: 160 }
		onFinished: {
			resultOverlayRoot.visible = false;
			if (resultOverlayCallback && typeof resultOverlayCallback === 'function') {
				var cb2 = resultOverlayCallback; resultOverlayCallback = null; try { cb2(); } catch(eCb2) { console.log('result overlay callback failed', eCb2); }
			}
		}
	}

	function applyBattleResult(resultType) {
		if (battleEnded) return;
		battleEnded = true;
		console.log('GameView: applying battle result', resultType);
		// If the battle just ended (win or lose), delete the automatic save so the player
		// won't resume into a finished battle via auto.dat.
		try {
			if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager && typeof SaveLoadManager.removeAuto === 'function') {
				SaveLoadManager.removeAuto();
				console.log('GameView: removed auto.dat due to battle end');
			}
		} catch (eRem) { console.log('GameView: removeAuto failed', eRem); }
		try { if (window && typeof window.stopMusic === 'function') window.stopMusic(); } catch(eStop) {}
		// stop periodic checks to avoid duplicate triggers
		try { battleEndCheckTimer.running = false; } catch(e) {}
		try { enemyCleanupTimer.running = false; } catch(e) {}
		var resObj = null;
		try { if (battleData && battleData.onResult && battleData.onResult[resultType]) resObj = battleData.onResult[resultType]; } catch(eR) { console.log('read onResult failed', eR); }

		// Helper: navigate according to a result object (nextChapter/nextNode preferred, then action nextLevel)
		function navigateByResult(obj) {
			if (!obj) return false;
			try {
				// Support legacy `next` key used in battle JSONs (e.g. { "next": "leap1" })
				if (obj.next) {
					var tgt = obj.next;
					try {
						var testPath = ":/qml/window/Lore/chapters/" + tgt + ".json";
						var testObj = fileReader.readJsonFile(testPath);
						if (testObj && testObj.nodes) {
							try { if (typeof WindowState !== 'undefined' && WindowState.setLoreState) WindowState.setLoreState({ chapter: tgt, node: "", index: 0, mode: "auto", auto: true }); } catch(e) { console.log('GameView: setLoreState for next failed', e); }
							try {
								if (window && typeof window.smoothReplaceSource === 'function') {
									window.smoothReplaceSource("qml/window/Lore/LoreView.qml", 600);
								} else if (window && typeof window.replaceSource === 'function') {
									window.replaceSource("qml/window/Lore/LoreView.qml");
								} else if (window && typeof window.pushSource === 'function') {
									window.pushSource("qml/window/Lore/LoreView.qml");
								}
							} catch(eNav) { console.log('GameView: navigate to Lore failed (next)', eNav); }
							return true;
						}
					} catch(eTest) { /* not a chapter */ }
				}

				if (obj.nextChapter || obj.nextNode) {
					var chap = obj.nextChapter || obj.chapter || "";
					var node = obj.nextNode || obj.node || "";
					try { if (typeof WindowState !== 'undefined' && WindowState.setLoreState) {
						WindowState.setLoreState({ chapter: chap, node: node, index: 0, mode: "auto", auto: true });
					} } catch(e) { console.log('setLoreState failed', e); }
					try {
						if (window && typeof window.smoothReplaceSource === 'function') {
							window.smoothReplaceSource("qml/window/Lore/LoreView.qml", 600);
						} else if (window && typeof window.replaceSource === 'function') {
							window.replaceSource("qml/window/Lore/LoreView.qml");
						} else if (window && typeof window.pushSource === 'function') {
							window.pushSource("qml/window/Lore/LoreView.qml");
						} else {
							console.log('No navigation API found to open LoreView');
						}
					} catch(eNav) { console.log('navigate to Lore failed', eNav); }
					return true;
				} else if (obj.action) {
					if (obj.action === 'nextLevel') {
						try {
							if (window && typeof window.advanceToNextLevel === 'function') { window.advanceToNextLevel(); return true; }
						} catch(e) { console.log('advanceToNextLevel failed', e); }
						// fallback: try replacing source to MainMenu as last resort
						try { if (window && typeof window.replaceSource === 'function') window.replaceSource("qml/window/MainMenu.qml"); } catch(e) {}
						return true;
					}
				}
			} catch(eNavAll) { console.log('navigateByResult failed', eNavAll); }
			return false;
		}

		// Show overlay (Win/Lose) then navigate—always prefer result object; for 'lose' avoid gameOver action
		var overlayText = (resultType === 'win') ? "Win!" : "Lose!";
		showResultOverlay(overlayText, 1200, function() {
			// try using resObj (for lose it may be action:gameOver which we will ignore)
			var used = false;
			if (resObj && resObj.action === 'gameOver') {
				// prefer win target if lose mapping is gameOver
				try { if (battleData && battleData.onResult && battleData.onResult.win) { used = navigateByResult(battleData.onResult.win); } } catch(e) {}
			} else {
				used = navigateByResult(resObj);
			}
			// If not used yet, try win mapping as general fallback
			if (!used) {
				try { if (battleData && battleData.onResult && battleData.onResult.win) { used = navigateByResult(battleData.onResult.win); } } catch(e) {}
			}
			// final fallback: replace to MainMenu
			if (!used) {
				try { if (window && typeof window.replaceSource === 'function') window.replaceSource("qml/window/MainMenu.qml"); } catch(e) { console.log('final fallback navigate failed', e); }
			}
		});
	}

	// Periodic check for battle end conditions
	Timer {
		id: battleEndCheckTimer
		interval: 250
		repeat: true
		running: true
		onTriggered: {
			if (battleEnded) return;
			// lose: player HP <= 0
			try {
				if (playerObj && (typeof playerObj.hp !== 'undefined') && playerObj.hp <= 0) {
					applyBattleResult('lose');
					return;
				}
			} catch(e) { console.log('check player hp failed', e); }
			// win: all enemies dead
			try {
				var aliveCount = 0;
				for (var i = 0; i < enemyBackends.length; ++i) {
					var b = enemyBackends[i];
					if (!isEnemyDead(b)) { aliveCount++; break; }
				}
				if (aliveCount === 0 && enemyBackends.length > 0) {
					applyBattleResult('win');
				}
			} catch(e2) { console.log('check enemies failed', e2); }
		}
	}

	// Countdown timer: ticks every second when a time limit is set.
	Timer {
		id: countdownTimer
		interval: 1000
		repeat: true
		running: false
		onTriggered: {
			if (battleEnded) return;
			try {
				if (timeLeftSeconds > 0) {
					timeLeftSeconds = Math.max(0, timeLeftSeconds - 1);
					// reached zero
					if (timeLeftSeconds <= 0) {
						countdownTimer.running = false;
						console.log('GameView: countdown reached zero');
						// victory if player still alive (hp > 0)
						if (playerObj && typeof playerObj.hp !== 'undefined' && playerObj.hp > 0) {
							console.log('GameView: time-up victory triggered');
							applyBattleResult('win');
						}
					}
				}
			} catch (e) { console.log('countdown onTriggered failed', e); }
		}
	}

	// Right-top small config + toggle controls UI
	Item {
		id: topRightControlPanel
		anchors.top: parent.top
		anchors.right: parent.right
		anchors.topMargin: 12
		// leave a little gap to the right edge (增加一点以避免按钮被裁切)
		anchors.rightMargin: 36
		z: 3000

		Rectangle {
			id: trBg
			anchors.top: parent.top
			anchors.right: parent.right
			color: "#00000080"
			radius: 6
			width: Math.max(cfgBtn.implicitWidth, toggleText.width, (btnYes.implicitWidth + btnNo.implicitWidth + 8)) + 24
			height: contentColumn.height + 12
		}

		Column {
			id: contentColumn
			anchors.left: trBg.left
			anchors.leftMargin: 12
			anchors.top: trBg.top
			anchors.topMargin: 6
			spacing: 6

			// Config button row (use AppButton so style matches project buttons)
			Row {
				anchors.left: trBg.left
				anchors.right: trBg.right
				anchors.leftMargin: 12
				anchors.rightMargin: 12
				AppButton {
					id: cfgBtn
					iconText: "\u2630" // ☰ (menu) — matches LoreView
					text: "Settings"
					height: 44
					fontPixelSize: 18
					onClicked: {
						try {
							if (window && typeof window.pushSource === 'function') {
								window.pushSource("qml/window/Config.qml");
							} else if (window && typeof window.replaceSource === 'function') {
								window.replaceSource("qml/window/Config.qml");
							} else if (typeof gotoConfig === 'function') {
								gotoConfig();
							} else {
								console.log('No navigation API to open Config');
							}
						} catch(e) { console.log('open config failed', e); }
					}
				}
			}

			Text {
				id: toggleText
				color: "white"
				font.pixelSize: 20
				text: "Hide Controls"
				anchors.left: trBg.left
				anchors.right: trBg.right
				anchors.leftMargin: 12
				anchors.rightMargin: 12
				horizontalAlignment: Text.AlignHCenter
			}

			Row {
				id: toggleRow
				// match width to the settings button above so left/right edges align
				width: cfgBtn.width
				anchors.horizontalCenter: cfgBtn.horizontalCenter
				spacing: 6
				// YES button (按用户要求：YES 模式隐藏控件)
				AppButton {
					id: btnYes
					text: "YES"
					// evenly split available width
					width: Math.max(64, Math.round((toggleRow.width - toggleRow.spacing) / 2))
					height: 44
					fontPixelSize: 16
					onClicked: { gameViewRoot.controlsVisible = false }
					// active when controlsVisible == false -> mark checked state to show active color
					checked: !gameViewRoot.controlsVisible
				}

				// NO button (NO 显示控件)
				AppButton {
					id: btnNo
					text: "NO"
					width: Math.max(64, Math.round((toggleRow.width - toggleRow.spacing) / 2))
					height: 44
					fontPixelSize: 16
					onClicked: { gameViewRoot.controlsVisible = true }
					checked: gameViewRoot.controlsVisible
				}
			}

			Text {
				id: aimModeLabel
				color: "white"
				font.pixelSize: 20
				text: "Aim Mode"
				anchors.left: trBg.left
				anchors.right: trBg.right
				anchors.leftMargin: 12
				anchors.rightMargin: 12
				horizontalAlignment: Text.AlignHCenter
			}

			Item {
				width: cfgBtn.width
				height: 44
				anchors.horizontalCenter: cfgBtn.horizontalCenter
				AppButton {
					id: mouseAimBtn
					anchors.fill: parent
					iconText: "\u25CE"
					text: "Mouse Aim"
					fontPixelSize: 16
					checked: aimMode === "mouse"
					onClicked: { aimMode = "mouse" }
				}
			}

			Item {
				width: cfgBtn.width
				height: 44
				anchors.horizontalCenter: cfgBtn.horizontalCenter
				AppButton {
					id: moveAimBtn
					anchors.fill: parent
					iconText: "\u27A4"
					text: "Move Aim"
					fontPixelSize: 16
					checked: aimMode === "move"
					onClicked: {
						if (aimMode !== "move") aimMode = "move";
						setMoveAimTarget();
					}
				}
			}
		}
	}

	

	function clearEnemies() {
		for (var i = 0; i < enemyVisuals.length; ++i) { try { enemyVisuals[i].destroy(); } catch(e){} }
		enemyVisuals = [];
		for (var j = 0; j < enemyBackends.length; ++j) { try { enemyBackends[j].deleteLater(); } catch(e){} }
		enemyBackends = [];
		enemySpawnCenters = [];
		enemyTypes = [];
		if (mapWrapper && mapWrapper.enemyProjectileVisuals) {
			for (var k = mapWrapper.enemyProjectileVisuals.length - 1; k >= 0; --k) {
				var proj = mapWrapper.enemyProjectileVisuals[k];
				try { if (proj && typeof proj.destroy === 'function') proj.destroy(); } catch(e){}
			}
			mapWrapper.enemyProjectileVisuals = [];
		}
		if (mapWrapper && mapWrapper.revealedEnemyVisuals) {
			mapWrapper.revealedEnemyVisuals = [];
			if (sightMask) sightMask.requestPaint();
			if (revealRepaintTimer) revealRepaintTimer.running = false;
		}
	}

	// Return a serializable snapshot of current backend enemies for saving
	function serializeEnemies() {
		var out = [];
		for (var i=0;i<enemyBackends.length;++i) {
			var b = enemyBackends[i];
			if (!b) continue;
			var typeName = (enemyTypes[i] !== undefined) ? enemyTypes[i] : "";
			var posPoint = b.pos ? b.pos : Qt.point(0,0);
			var hpVal = (typeof b.hp !== 'undefined') ? b.hp : 0;
			var maxHpVal = (typeof b.maxHp !== 'undefined') ? b.maxHp : 0;
			var mpVal = (typeof b.mp !== 'undefined') ? b.mp : 0;
			var maxMpVal = (typeof b.maxMp !== 'undefined') ? b.maxMp : 0;
			var aliveVal = (typeof b.alive !== 'undefined') ? b.alive : (hpVal > 0);
			out.push({ type: typeName, x: posPoint.x, y: posPoint.y, hp: hpVal, maxHp: maxHpVal, mp: mpVal, maxMp: maxMpVal, alive: aliveVal });
		}
		return out;
	}

	// Check immediately whether all enemies are already dead and trigger win if appropriate
	function checkVictoryNow() {
		try {
			// Only consider win when rule expects allEnemiesDead (defensive)
			var wantAllDead = !(battleData && battleData.rules && battleData.rules.winCondition) ? true : (battleData.rules.winCondition.type === 'allEnemiesDead');
			if (!wantAllDead) return;
			var anyAlive = false;
			for (var i = 0; i < enemyBackends.length; ++i) {
				if (!isEnemyDead(enemyBackends[i])) { anyAlive = true; break; }
			}
			if (!anyAlive && enemyBackends.length > 0) {
				console.log('checkVictoryNow: no alive enemies -> applying win');
				applyBattleResult('win');
			}
		} catch(e) { console.log('checkVictoryNow failed', e); }
	}

	function spawnEnemiesFromMap() {
		if (!tileManager || !tileManager.curMapData) {
			console.log("spawnEnemiesFromMap: curMapData not ready");
			return;
		}
		if (!playerObj || !playerItem) {
			console.log("spawnEnemiesFromMap: player not ready yet, retrying");
			Qt.callLater(function(){ spawnEnemiesFromMap(); });
			return;
		}
		clearEnemies();
		var rows = tileManager.curMapData.length;
		if (rows <= 0) {
			console.log("spawnEnemiesFromMap: no rows in curMapData");
			return;
		}
		var cols = tileManager.curMapData[0].length;
		console.log("spawnEnemiesFromMap: rows", rows, "cols", cols);
		var w = cols * tileSize;
		var h = rows * tileSize;
		var minSeparation = Math.max(64, tileSize * 0.25);
		var minSeparationSq = minSeparation * minSeparation;
		var spawnOffsets = [
			Qt.point(0, 0),
			Qt.point(minSeparation, 0),
			Qt.point(-minSeparation, 0),
			Qt.point(0, minSeparation),
			Qt.point(0, -minSeparation),
			Qt.point(minSeparation, minSeparation),
			Qt.point(-minSeparation, minSeparation),
			Qt.point(minSeparation, -minSeparation),
			Qt.point(-minSeparation, -minSeparation)
		];
		function clampToMap(pt) {
			var half = tileSize / 2;
			var clampedX = Math.min(Math.max(pt.x, half), w - half);
			var clampedY = Math.min(Math.max(pt.y, half), h - half);
			return Qt.point(clampedX, clampedY);
		}
		function isFarEnough(candidate) {
			for (var idx = 0; idx < enemySpawnCenters.length; ++idx) {
				var existing = enemySpawnCenters[idx];
				var dx = existing.x - candidate.x;
				var dy = existing.y - candidate.y;
				if ((dx * dx + dy * dy) < minSeparationSq) return false;
			}
			return true;
		}

		// chooseSpawn: radial sampling with multiple radii and random angles
		function chooseSpawn(baseX, baseY) {
			// fast check at exact tile center
			var center = clampToMap(Qt.point(baseX, baseY));
			if (isFarEnough(center)) return center;

			var maxRings = 6;
			var attemptsPerRing = 12;
			for (var ring = 1; ring <= maxRings; ++ring) {
				var radius = minSeparation * ring;
				for (var a = 0; a < attemptsPerRing; ++a) {
					var angle = (2 * Math.PI) * (a / attemptsPerRing) + (Math.random() * 0.4 - 0.2);
					var cand = Qt.point(baseX + Math.cos(angle) * radius, baseY + Math.sin(angle) * radius);
					cand = clampToMap(cand);
					if (isFarEnough(cand)) return cand;
				}
			}
			// last resort: try small random jitter around tile until timeout
			var randAttempts = 30;
			for (var i = 0; i < randAttempts; ++i) {
				var jitter = minSeparation * (0.5 + Math.random() * 2.0);
				var ang = Math.random() * 2 * Math.PI;
				var c = Qt.point(baseX + Math.cos(ang) * jitter, baseY + Math.sin(ang) * jitter);
				c = clampToMap(c);
				if (isFarEnough(c)) return c;
			}
			return null;
		}
		for (var r = 0; r < rows; ++r) {
			for (var c = 0; c < cols; ++c) {
				var t = tileManager.getTileType(r, c);
					if (t === 1 || t === 2 || t === 3 || t === 4 || t === 5 || t === 6 || t === 7) {
					var worldX = c * tileSize + tileSize/2;
					var worldY = r * tileSize + tileSize/2;
					console.log("Tile type", t, "converted to world", worldX, worldY, "for tileSize", tileSize);
					if (t === 1) {
						var candidate1 = chooseSpawn(worldX, worldY);
						if (!candidate1) {
							console.log("spawnEnemiesFromMap: unable to place Enemy1 near", worldX, worldY, "due to spacing constraints");
							continue;
						}
						var spawnX1 = candidate1.x;
						var spawnY1 = candidate1.y;
						if (Math.abs(spawnX1 - worldX) > 0.5 || Math.abs(spawnY1 - worldY) > 0.5) {
							console.log("spawnEnemiesFromMap: adjusted Enemy1 spawn from", worldX, worldY, "to", spawnX1, spawnY1);
						}
						var e1 = Qt.createQmlObject('import GeistZerfall.Game 1.0; BackendEnemy1 {}', gameViewRoot);
						if (e1) {
							e1.mapWidth = w; e1.mapHeight = h;
							e1.pos = Qt.point(spawnX1, spawnY1);
							if (playerObj && typeof e1.setPlayerTarget === 'function') e1.setPlayerTarget(playerObj);
							enemyBackends.push(e1);
							enemyTypes.push("Enemy1");
							enemySpawnCenters.push({ x: spawnX1, y: spawnY1 });
							var comp1 = Qt.createComponent("./Entity/Enemy/Enemy1.qml");
							if (comp1.status === Component.Ready) {
								console.log("spawnEnemiesFromMap: creating Enemy1 at row", r, "col", c, "world", spawnX1, spawnY1, "tileScale", tileScale);
								var v1 = comp1.createObject(mapWrapper, { backend: e1, playerObjRef: playerObj, playerItemRef: playerItem, mapWrapperRef: mapWrapper, tileScaleRef: tileScale });
								if (v1) {
									enemyVisuals.push(v1);
									v1.tileScaleRef = Qt.binding(function(){ return tileScale; });
									v1.playerItemRef = playerItem;
									v1.updateScreenPos && v1.updateScreenPos();
								}
							}
						}
					} else if (t === 2) {
						var candidate2 = chooseSpawn(worldX, worldY);
						if (!candidate2) {
							console.log("spawnEnemiesFromMap: unable to place Enemy2 near", worldX, worldY, "due to spacing constraints");
							continue;
						}
						var spawnX2 = candidate2.x;
						var spawnY2 = candidate2.y;
						if (Math.abs(spawnX2 - worldX) > 0.5 || Math.abs(spawnY2 - worldY) > 0.5) {
							console.log("spawnEnemiesFromMap: adjusted Enemy2 spawn from", worldX, worldY, "to", spawnX2, spawnY2);
						}
						var e2 = Qt.createQmlObject('import GeistZerfall.Game 1.0; BackendEnemy2 {}', gameViewRoot);
						if (e2) {
							e2.mapWidth = w; e2.mapHeight = h;
							e2.pos = Qt.point(spawnX2, spawnY2);
							if (playerObj && typeof e2.setPlayerTarget === 'function') e2.setPlayerTarget(playerObj);
							enemyBackends.push(e2);
							enemyTypes.push("Enemy2");
							enemySpawnCenters.push({ x: spawnX2, y: spawnY2 });
							var comp2 = Qt.createComponent("./Entity/Enemy/Enemy2.qml");
							if (comp2.status === Component.Ready) {
								console.log("spawnEnemiesFromMap: creating Enemy2 at row", r, "col", c, "world", spawnX2, spawnY2, "tileScale", tileScale);
								var v2 = comp2.createObject(mapWrapper, { backend: e2, playerObjRef: playerObj, playerItemRef: playerItem, mapWrapperRef: mapWrapper, tileScaleRef: tileScale });
								if (v2) {
									enemyVisuals.push(v2);
									v2.tileScaleRef = Qt.binding(function(){ return tileScale; });
									v2.playerItemRef = playerItem;
									v2.updateScreenPos && v2.updateScreenPos();
								}
							}
						}
					} else if (t === 3) {
						var candidate3 = chooseSpawn(worldX, worldY);
						if (!candidate3) {
							console.log("spawnEnemiesFromMap: unable to place Enemy3 near", worldX, worldY, "due to spacing constraints");
							continue;
						}
						var spawnX3 = candidate3.x;
						var spawnY3 = candidate3.y;
						if (Math.abs(spawnX3 - worldX) > 0.5 || Math.abs(spawnY3 - worldY) > 0.5) {
							console.log("spawnEnemiesFromMap: adjusted Enemy3 spawn from", worldX, worldY, "to", spawnX3, spawnY3);
						}
						var e3 = Qt.createQmlObject('import GeistZerfall.Game 1.0; BackendEnemy3 {}', gameViewRoot);
						if (e3) {
							e3.mapWidth = w; e3.mapHeight = h;
							e3.pos = Qt.point(spawnX3, spawnY3);
							if (playerObj && typeof e3.setPlayerTarget === 'function') e3.setPlayerTarget(playerObj);
							enemyBackends.push(e3);
							enemyTypes.push("Enemy3");
							enemySpawnCenters.push({ x: spawnX3, y: spawnY3 });
							var comp3 = Qt.createComponent("./Entity/Enemy/Enemy3.qml");
							if (comp3.status === Component.Ready) {
								console.log("spawnEnemiesFromMap: creating Enemy3 at row", r, "col", c, "world", spawnX3, spawnY3, "tileScale", tileScale);
								var v3 = comp3.createObject(mapWrapper, { backend: e3, playerObjRef: playerObj, playerItemRef: playerItem, mapWrapperRef: mapWrapper, tileScaleRef: tileScale });
								if (v3) {
									enemyVisuals.push(v3);
									v3.tileScaleRef = Qt.binding(function(){ return tileScale; });
									v3.playerItemRef = playerItem;
									v3.updateScreenPos && v3.updateScreenPos();
								}
							} else {
								console.log("spawnEnemiesFromMap: Enemy3 component not ready:", comp3.status, comp3.errorString ? comp3.errorString() : "");
							}
						}
					} else if (t === 4) {
						var candidate4 = chooseSpawn(worldX, worldY);
						if (!candidate4) {
							console.log("spawnEnemiesFromMap: unable to place Enemy4 near", worldX, worldY, "due to spacing constraints");
							continue;
						}
						var spawnX4 = candidate4.x;
						var spawnY4 = candidate4.y;
						if (Math.abs(spawnX4 - worldX) > 0.5 || Math.abs(spawnY4 - worldY) > 0.5) {
							console.log("spawnEnemiesFromMap: adjusted Enemy4 spawn from", worldX, worldY, "to", spawnX4, spawnY4);
						}
						var e4 = Qt.createQmlObject('import GeistZerfall.Game 1.0; BackendEnemy4 {}', gameViewRoot);
						if (e4) {
							e4.mapWidth = w; e4.mapHeight = h;
							e4.pos = Qt.point(spawnX4, spawnY4);
							if (playerObj && typeof e4.setPlayerTarget === 'function') e4.setPlayerTarget(playerObj);
							enemyBackends.push(e4);
							enemyTypes.push("Enemy4");
							enemySpawnCenters.push({ x: spawnX4, y: spawnY4 });
							var comp4 = Qt.createComponent("./Entity/Enemy/Enemy4.qml");
							if (comp4.status === Component.Ready) {
								console.log("spawnEnemiesFromMap: creating Enemy4 at row", r, "col", c, "world", spawnX4, spawnY4, "tileScale", tileScale);
								var v4 = comp4.createObject(mapWrapper, { backend: e4, playerObjRef: playerObj, playerItemRef: playerItem, mapWrapperRef: mapWrapper, tileScaleRef: tileScale });
								if (v4) {
									enemyVisuals.push(v4);
									v4.tileScaleRef = Qt.binding(function(){ return tileScale; });
									v4.playerItemRef = playerItem;
									v4.updateScreenPos && v4.updateScreenPos();
								}
							}
						}
					} else if (t === 5) {
						var candidate5 = chooseSpawn(worldX, worldY);
						if (!candidate5) {
							console.log("spawnEnemiesFromMap: unable to place Enemy5 near", worldX, worldY, "due to spacing constraints");
							continue;
						}
						var spawnX5 = candidate5.x;
						var spawnY5 = candidate5.y;
						if (Math.abs(spawnX5 - worldX) > 0.5 || Math.abs(spawnY5 - worldY) > 0.5) {
							console.log("spawnEnemiesFromMap: adjusted Enemy5 spawn from", worldX, worldY, "to", spawnX5, spawnY5);
						}
						var e5 = Qt.createQmlObject('import GeistZerfall.Game 1.0; BackendEnemy5 {}', gameViewRoot);
						if (e5) {
							e5.mapWidth = w; e5.mapHeight = h;
							e5.pos = Qt.point(spawnX5, spawnY5);
							if (playerObj && typeof e5.setPlayerTarget === 'function') e5.setPlayerTarget(playerObj);
							enemyBackends.push(e5);
							enemyTypes.push("Enemy5");
							enemySpawnCenters.push({ x: spawnX5, y: spawnY5 });
							var comp5 = Qt.createComponent("./Entity/Enemy/Enemy5.qml");
							if (comp5.status === Component.Ready) {
								console.log("spawnEnemiesFromMap: creating Enemy5 at row", r, "col", c, "world", spawnX5, spawnY5, "tileScale", tileScale);
								var v5 = comp5.createObject(mapWrapper, { backend: e5, playerObjRef: playerObj, playerItemRef: playerItem, mapWrapperRef: mapWrapper, tileScaleRef: tileScale });
								if (v5) {
									enemyVisuals.push(v5);
									v5.tileScaleRef = Qt.binding(function(){ return tileScale; });
									v5.playerItemRef = playerItem;
									v5.updateScreenPos && v5.updateScreenPos();
								}
							}
						}
					} else if (t === 6) {
						var candidate6 = chooseSpawn(worldX, worldY);
						if (!candidate6) {
							console.log("spawnEnemiesFromMap: unable to place Enemy6 near", worldX, worldY, "due to spacing constraints");
							continue;
						}
						var spawnX6 = candidate6.x;
						var spawnY6 = candidate6.y;
						if (Math.abs(spawnX6 - worldX) > 0.5 || Math.abs(spawnY6 - worldY) > 0.5) {
							console.log("spawnEnemiesFromMap: adjusted Enemy6 spawn from", worldX, worldY, "to", spawnX6, spawnY6);
						}
						var e6 = Qt.createQmlObject('import GeistZerfall.Game 1.0; BackendEnemy6 {}', gameViewRoot);
						if (e6) {
							e6.mapWidth = w; e6.mapHeight = h;
							e6.pos = Qt.point(spawnX6, spawnY6);
							if (playerObj && typeof e6.setPlayerTarget === 'function') e6.setPlayerTarget(playerObj);
							enemyBackends.push(e6);
							enemyTypes.push("Enemy6");
							enemySpawnCenters.push({ x: spawnX6, y: spawnY6 });
							var comp6 = Qt.createComponent("./Entity/Enemy/Enemy6.qml");
							if (comp6.status === Component.Ready) {
								console.log("spawnEnemiesFromMap: creating Enemy6 at row", r, "col", c, "world", spawnX6, spawnY6, "tileScale", tileScale);
								var v6 = comp6.createObject(mapWrapper, { backend: e6, playerObjRef: playerObj, playerItemRef: playerItem, mapWrapperRef: mapWrapper, tileScaleRef: tileScale });
								if (v6) {
									enemyVisuals.push(v6);
									v6.tileScaleRef = Qt.binding(function(){ return tileScale; });
									v6.playerItemRef = playerItem;
									v6.updateScreenPos && v6.updateScreenPos();
								}
							}
						}
					} else if (t === 7) {
						var candidate7 = chooseSpawn(worldX, worldY);
						if (!candidate7) {
							console.log("spawnEnemiesFromMap: unable to place Enemy7 near", worldX, worldY, "due to spacing constraints");
							continue;
						}
						var spawnX7 = candidate7.x;
						var spawnY7 = candidate7.y;
						if (Math.abs(spawnX7 - worldX) > 0.5 || Math.abs(spawnY7 - worldY) > 0.5) {
							console.log("spawnEnemiesFromMap: adjusted Enemy7 spawn from", worldX, worldY, "to", spawnX7, spawnY7);
						}
						var e7 = Qt.createQmlObject('import GeistZerfall.Game 1.0; BackendEnemy7 {}', gameViewRoot);
						if (e7) {
							e7.mapWidth = w; e7.mapHeight = h;
							e7.pos = Qt.point(spawnX7, spawnY7);
							if (playerObj && typeof e7.setPlayerTarget === 'function') e7.setPlayerTarget(playerObj);
							enemyBackends.push(e7);
							enemyTypes.push("Enemy7");
							enemySpawnCenters.push({ x: spawnX7, y: spawnY7 });
							var comp7 = Qt.createComponent("./Entity/Enemy/Enemy7.qml");
							if (comp7.status === Component.Ready) {
								console.log("spawnEnemiesFromMap: creating Enemy7 at row", r, "col", c, "world", spawnX7, spawnY7, "tileScale", tileScale);
								var v7 = comp7.createObject(mapWrapper, { backend: e7, playerObjRef: playerObj, playerItemRef: playerItem, mapWrapperRef: mapWrapper, tileScaleRef: tileScale });
								if (v7) {
									enemyVisuals.push(v7);
									v7.tileScaleRef = Qt.binding(function(){ return tileScale; });
									v7.playerItemRef = playerItem;
									v7.updateScreenPos && v7.updateScreenPos();
								}
							}
						}
					}
				}
			}
		}
		// Post-spawn: ensure minimum separation between spawned enemies (nudge pairs apart)
		try {
			for (var i = 0; i < enemyBackends.length; ++i) {
				for (var j = i + 1; j < enemyBackends.length; ++j) {
					var a = enemyBackends[i];
					var b = enemyBackends[j];
					if (!a || !b) continue;
					var ax = (a.pos ? a.pos.x : (enemySpawnCenters[i] ? enemySpawnCenters[i].x : 0));
					var ay = (a.pos ? a.pos.y : (enemySpawnCenters[i] ? enemySpawnCenters[i].y : 0));
					var bx = (b.pos ? b.pos.x : (enemySpawnCenters[j] ? enemySpawnCenters[j].x : 0));
					var by = (b.pos ? b.pos.y : (enemySpawnCenters[j] ? enemySpawnCenters[j].y : 0));
					var dx = bx - ax;
					var dy = by - ay;
					var d2 = dx * dx + dy * dy;
					if (d2 === 0) {
						// perfectly overlapping — pick a small random direction to separate
						var ang = Math.random() * Math.PI * 2;
						dx = Math.cos(ang); dy = Math.sin(ang); d2 = 1.0;
					}
					if (d2 < minSeparationSq) {
						var d = Math.sqrt(d2);
						var need = Math.max(0, minSeparation - d);
						var nx = dx / d;
						var ny = dy / d;
						var shift = need * 0.5;
						var ax2 = ax - nx * shift;
						var ay2 = ay - ny * shift;
						var bx2 = bx + nx * shift;
						var by2 = by + ny * shift;
						// clamp to map bounds
						ax2 = Math.max(0, Math.min(w - 1, ax2));
						ay2 = Math.max(0, Math.min(h - 1, ay2));
						bx2 = Math.max(0, Math.min(w - 1, bx2));
						by2 = Math.max(0, Math.min(h - 1, by2));
						try { a.pos = Qt.point(ax2, ay2); } catch(e) {}
						try { b.pos = Qt.point(bx2, by2); } catch(e) {}
						if (enemySpawnCenters[i]) enemySpawnCenters[i].x = ax2, enemySpawnCenters[i].y = ay2;
						if (enemySpawnCenters[j]) enemySpawnCenters[j].x = bx2, enemySpawnCenters[j].y = by2;
						// update visuals to reflect new backend positions
						try { enemyVisuals[i] && enemyVisuals[i].updateScreenPos && enemyVisuals[i].updateScreenPos(); } catch(e) {}
						try { enemyVisuals[j] && enemyVisuals[j].updateScreenPos && enemyVisuals[j].updateScreenPos(); } catch(e) {}
					}
				}
			}
		} catch (e) {
			console.log('post-spawn separation pass failed', e);
		}
		// If there is saved enemy data, reconcile saved positions/states with the freshly created backends.
		if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager) {
			try {
				var savedEnemies = SaveLoadManager.enemiesAsVariantList();
				if (savedEnemies && savedEnemies.length > 0) {
					var assigned = [];
					for (var i = 0; i < enemyBackends.length; ++i) assigned.push(false);
					for (var si = 0; si < savedEnemies.length; ++si) {
						var s = savedEnemies[si];
						// find nearest unassigned backend of same type
						var bestIdx = -1;
						var bestDist = Number.MAX_VALUE;
						for (var bi = 0; bi < enemyBackends.length; ++bi) {
							if (assigned[bi]) continue;
							var b = enemyBackends[bi];
							if (!b) continue;
							var backendType = (enemyTypes[bi] !== undefined) ? enemyTypes[bi] : "";
							if (backendType !== s.type) continue;
							var dx = (b.pos ? b.pos.x : 0) - s.x;
							var dy = (b.pos ? b.pos.y : 0) - s.y;
							var d2 = dx * dx + dy * dy;
							if (d2 < bestDist) {
								bestDist = d2;
								bestIdx = bi;
							}
						}
						if (bestIdx !== -1) {
							var bb = enemyBackends[bestIdx];
							try { bb.pos = Qt.point(s.x, s.y); } catch(e) {}
							// restore HP/MP if available
							try {
								if (typeof bb.setMaxHp === 'function') bb.setMaxHp(s.maxHp); else bb.maxHp = s.maxHp;
							} catch(e) {}
							try {
								if (typeof bb.setHp === 'function') bb.setHp(s.hp); else bb.hp = s.hp;
							} catch(e) {}
							try {
								if (typeof bb.setMaxMp === 'function') bb.setMaxMp(s.maxMp); else bb.maxMp = s.maxMp;
							} catch(e) {}
							try {
								if (typeof bb.setMp === 'function') bb.setMp(s.mp); else bb.mp = s.mp;
							} catch(e) {}
							try { bb.alive = s.alive; } catch(e) {}
							assigned[bestIdx] = true;
						}
					}
					// update visuals after applying positions
					for (var vi = 0; vi < enemyVisuals.length; ++vi) {
						try { enemyVisuals[vi].updateScreenPos && enemyVisuals[vi].updateScreenPos(); } catch(e) {}
					}
				}
			} catch (e) {
				console.log('apply saved enemies failed', e);
			}
			// restore saved countdown time if present
			try {
				if (typeof SaveLoadManager.timeLeftSeconds !== 'undefined' && SaveLoadManager.timeLeftSeconds !== null) {
					// Only restore if the save is for this battle and saved time is positive
					if (SaveLoadManager.battleId === battleId && SaveLoadManager.timeLeftSeconds > 0) {
						timeLeftSeconds = SaveLoadManager.timeLeftSeconds;
						if (timeLeftSeconds > 0) {
							countdownTimer.running = true;
						}
						console.log('spawnEnemiesFromMap: restored countdown timeLeftSeconds=', timeLeftSeconds);
					}
				}
			} catch (eTL) { console.log('restore saved timeLeftSeconds failed', eTL); }
		}
		console.log("spawnEnemiesFromMap: total enemies", enemyBackends.length);
		// Explicitly update TeleportOverlay's enemy list reference to ensure it sees the populated array
		if (teleportOverlay) teleportOverlay.enemyBackends = enemyBackends;
		
		// after spawning, check if victory condition already met (e.g., enemies restored as dead)
		Qt.callLater(function(){ checkVictoryNow(); });
		// refresh global snapshot of enemies for SaveLoad UI via WindowState
		try {
			WindowState.setGameEnemies && WindowState.setGameEnemies(serializeEnemies());
		} catch(e) {
			console.log('update enemies in state failed', e);
		}
	}

	// 右键点击跳转到设置界面
	MouseArea {
		anchors.fill: parent
		hoverEnabled: true
		acceptedButtons: Qt.RightButton
		onClicked: function(mouse) {
			if (mouse.button === Qt.RightButton) {
				// 通过顶层Window暴露的gotoConfig切换到设置界面
				var win = Qt.binding(function() { return Qt.application.activeWindow || null; });
				if (win && win.gotoConfig) {
					win.gotoConfig();
				} else if (typeof gotoConfig === "function") {
					gotoConfig();
				} else {
					console.log("未找到gotoConfig方法");
				}
			}
		}

		onExited: function() {
			// 鼠标移出视图时，确保按键状态被清理，防止一直移动
			if (playerItem && typeof playerItem.resetKeys === 'function') {
				playerItem.resetKeys();
			}
		}
	}

	// Global Esc shortcut: exit fullscreen like Config.qml
	Shortcut {
		sequence: "Esc"
		onActivated: {
			if (window && window.setFullscreen) window.setFullscreen(false);
			if (typeof fullscreenBtn !== 'undefined') fullscreenBtn.checked = false;
			if (typeof windowBtn !== 'undefined') windowBtn.checked = true;
		}
	}

	// Shortcut 'H' toggles the controls (acts like clicking YES/NO)
	Shortcut {
		sequence: "H"
		onActivated: {
			try {
				if (gameViewRoot.controlsVisible) {
					// controls currently visible -> emulate YES (hide)
					try { if (typeof btnYes !== 'undefined') btnYes.clicked(); else gameViewRoot.controlsVisible = false; } catch(e) { gameViewRoot.controlsVisible = false; }
				} else {
					// controls currently hidden -> emulate NO (show)
					try { if (typeof btnNo !== 'undefined') btnNo.clicked(); else gameViewRoot.controlsVisible = true; } catch(e) { gameViewRoot.controlsVisible = true; }
				}
			} catch(eToggle) { console.log('H shortcut toggle failed', eToggle); }
		}
	}
    
	// Shortcut 'C' toggles Aim Mode between 'mouse' and 'move'
	Shortcut {
		sequence: "C"
		onActivated: {
			try {
				if (gameViewRoot.aimMode === "mouse") {
					gameViewRoot.aimMode = "move";
				} else {
					gameViewRoot.aimMode = "mouse";
				}
			} catch(eToggle) { console.log('C shortcut toggle aimMode failed', eToggle); }
		}
	}
// (Removed shortcut overrides for letter/number keys so physical key events can flow through playerItem for hold behaviour.)

	anchors.fill: parent
	property bool appliedSaveLoad: false
	Component.onDestruction: {
		if (typeof window !== 'undefined' && window.shuttingDown) {
			// 应用正在退出：跳过额外的自动存档和截图，避免资源销毁过程中的竞态
			return;
		}
		if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager && playerObj) {
			// capture a temporary preview image of the current GameView so it can be used by SaveLoad UI
			try { SaveLoadManager.captureTemp(); } catch (e) { console.log('captureTemp failed', e); }
			// 标记来源视图为 game，并清空剧情字段
			try {
				SaveLoadManager.view = "game";
				SaveLoadManager.loreChapter = "";
				SaveLoadManager.loreNode = "";
				SaveLoadManager.loreIndex = 0;
				SaveLoadManager.loreMusic = "";
				SaveLoadManager.loreMusicLoops = -1;
				SaveLoadManager.loreMusicStopped = false;
				SaveLoadManager.battleId = battleId || (typeof window !== 'undefined' && window.currentBattleId ? window.currentBattleId : "");
			} catch (eSet) { console.log('set game view metadata failed', eSet); }
			SaveLoadManager.posX = playerObj.pos.x;
			SaveLoadManager.posY = playerObj.pos.y;
			SaveLoadManager.speed = playerObj.getSpeed ? playerObj.getSpeed() : 0;
			SaveLoadManager.sight = playerObj.getSight ? playerObj.getSight() : 0;
			SaveLoadManager.maxHp = (typeof playerObj.maxHp !== 'undefined') ? playerObj.maxHp : SaveLoadManager.maxHp;
			SaveLoadManager.hp = (typeof playerObj.hp !== 'undefined') ? playerObj.hp : SaveLoadManager.hp;
			// Save remaining countdown time so a resumed battle can continue where it left off
			try { SaveLoadManager.timeLeftSeconds = timeLeftSeconds; } catch(eTime) { console.log('cannot set SaveLoadManager.timeLeftSeconds', eTime); }
			// ensure enemies snapshot is set before saving
			var snapshot = serializeEnemies();
			try { SaveLoadManager.setEnemies(snapshot); } catch (e) { console.log('setEnemies before save failed', e); }
			try { WindowState.setGameEnemies && WindowState.setGameEnemies(snapshot); } catch (e) { console.log('update enemies in state failed', e); }
			// Don't auto-save if the battle has ended (we remove auto.dat on end to avoid resuming a finished battle)
			if (!battleEnded) SaveLoadManager.saveAuto();
		}
		// clear global pointer to player when leaving game view so other pages don't hold stale refs
		try { if (window && window.currentPlayer) window.currentPlayer = undefined; } catch (e) {}
	}

	onVisibleChanged: {
		if (!visible) {
			if (typeof window !== 'undefined' && window.shuttingDown) {
				return; // 退出流程中不进行自动存档
			}
			if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager && playerObj) {
				// capture temp preview whenever leaving the GameView so SaveLoad can show it instantly
				try { SaveLoadManager.captureTemp(); } catch (e) { console.log('captureTemp failed', e); }
				// 标记来源视图为 game，并清空剧情字段
				try {
					SaveLoadManager.view = "game";
					SaveLoadManager.loreChapter = "";
					SaveLoadManager.loreNode = "";
					SaveLoadManager.loreIndex = 0;
					SaveLoadManager.loreMusic = "";
					SaveLoadManager.loreMusicLoops = -1;
					SaveLoadManager.loreMusicStopped = false;
					SaveLoadManager.battleId = battleId || (typeof window !== 'undefined' && window.currentBattleId ? window.currentBattleId : "");
				} catch (eSet) { console.log('set game view metadata failed', eSet); }
				SaveLoadManager.posX = playerObj.pos.x;
				SaveLoadManager.posY = playerObj.pos.y;
				SaveLoadManager.speed = playerObj.getSpeed ? playerObj.getSpeed() : 0;
				SaveLoadManager.sight = playerObj.getSight ? playerObj.getSight() : 0;
				SaveLoadManager.maxHp = (typeof playerObj.maxHp !== 'undefined') ? playerObj.maxHp : SaveLoadManager.maxHp;
				SaveLoadManager.hp = (typeof playerObj.hp !== 'undefined') ? playerObj.hp : SaveLoadManager.hp;
				// Save remaining countdown time so a resumed battle can continue where it left off
				try { SaveLoadManager.timeLeftSeconds = timeLeftSeconds; } catch(eTime) { console.log('cannot set SaveLoadManager.timeLeftSeconds', eTime); }
				// ensure enemies snapshot is set before saving
				var snapshot = serializeEnemies();
				try { SaveLoadManager.setEnemies(snapshot); } catch (e) { console.log('setEnemies before save failed', e); }
				try { WindowState.setGameEnemies && WindowState.setGameEnemies(snapshot); } catch (e) { console.log('update enemies in state failed', e); }
				// Avoid creating an auto save for a finished battle: only save when battle still active
				if (!battleEnded) SaveLoadManager.saveAuto();
			}
		}
	}
	property int tileSize: 512
	// when snipe mode is active we set tileScale to 0.5 to shrink everything visually
	property real tileScale: 1.0
	onTileScaleChanged: {
		if (aimMode === "move") setMoveAimTarget();
	}
	property real teleportRingDistance: Math.max(256, tileSize * 0.75)

	Behavior on tileScale { NumberAnimation { duration: 220; easing.type: Easing.InOutQuad } }
	property int mapRows: tileManager.curMapData ? tileManager.curMapData.length : 0
	property int mapCols: (tileManager.curMapData && tileManager.curMapData.length>0) ? tileManager.curMapData[0].length : 0
	property int mapPixelWidth: Math.round(mapCols * tileSize * tileScale)
	property int mapPixelHeight: Math.round(mapRows * tileSize * tileScale)
	Rectangle {
		id: mapViewport
		anchors.fill: parent
		clip: true
		Item {
			id: mapWrapper
			property var enemyProjectileVisuals: []
			property var revealedEnemyVisuals: []
			function registerEnemyProjectile(obj) {
				if (!obj || enemyProjectileVisuals.indexOf(obj) !== -1) return;
				enemyProjectileVisuals.push(obj);
			}
			function unregisterEnemyProjectile(obj) {
				if (!obj) return;
				var idx = enemyProjectileVisuals.indexOf(obj);
				if (idx !== -1) enemyProjectileVisuals.splice(idx, 1);
			}
			function registerRevealedEnemy(obj) {
				if (!obj || revealedEnemyVisuals.indexOf(obj) !== -1) return;
				revealedEnemyVisuals.push(obj);
				if (revealRepaintTimer) revealRepaintTimer.running = true;
				if (sightMask) sightMask.requestPaint();
			}
			function unregisterRevealedEnemy(obj) {
				if (!obj) return;
				var idx = revealedEnemyVisuals.indexOf(obj);
				if (idx !== -1) revealedEnemyVisuals.splice(idx, 1);
				if (revealedEnemyVisuals.length === 0 && revealRepaintTimer) revealRepaintTimer.running = false;
				if (sightMask) sightMask.requestPaint();
			}
			// 明确设置宽高，避免在缩放或计算偏移时出现未定义边界导致的裁剪/空白
			width: mapPixelWidth
			height: mapPixelHeight
				x: {
					if (!playerObj) return 0;
					// Compute player's center in scaled map pixels (world pos + half width) * tileScale
					var playerCenterX = (playerObj.pos.x + (playerItem.width/2)) * tileScale;
					var centerX = mapViewport.width / 2; // desired screen center for player
					var ox = centerX - playerCenterX;
					// clamp to map bounds so we don't show beyond edges
					if (ox > 0) ox = 0;
					if (ox + mapPixelWidth < mapViewport.width) ox = mapViewport.width - mapPixelWidth;
					return ox;
				}
				y: {
					if (!playerObj) return 0;
					var playerCenterY = (playerObj.pos.y + (playerItem.height/2)) * tileScale;
					var centerY = mapViewport.height / 2;
					var oy = centerY - playerCenterY;
					// clamp to map bounds
					if (oy > 0) oy = 0;
					if (oy + mapPixelHeight < mapViewport.height) oy = mapViewport.height - mapPixelHeight;
					return oy;
				}
			Column {
				id: mapColumn
				spacing: 0
				Repeater {
					model: mapRows
					Row {
						property int r: index
						spacing: 0
						Repeater {
							model: mapCols
							Tile {
								width: Math.round(tileSize * tileScale)
								height: Math.round(tileSize * tileScale)
								tileType: tileManager.getTileType(r, index)
							}
						}
					}
				}
			}
		}
		}
		TileManager {
		id: tileManager
	}

	Connections {
		target: mapWrapper
		onXChanged: { if (gameViewRoot.aimMode === "move") gameViewRoot.setMoveAimTarget(); }
		onYChanged: { if (gameViewRoot.aimMode === "move") gameViewRoot.setMoveAimTarget(); }
	}

	// helper to create/destroy bullets
	function destroyChild(item) {
		if (!item) return;
		try { item.destroy(); } catch (e) { /* ignore */ }
	}

	function createBullet(x, y, dirx, diry) {
		// use path relative to this QML file so component can be found in the project tree
		var comp = Qt.createComponent("./Entity/PlayerBullet.qml");
		if (comp.status === Component.Ready) {
		var obj = comp.createObject(mapWrapper, { x: x - 32, y: y - 32, playerObjRef: playerObj, playerItemRef: playerItem });
			if (obj) {
				// fallback visual-only bullet: start local motion if start exists, otherwise ensure it self-destructs
				try { if (typeof obj.start === 'function') obj.start(dirx, diry); } catch (e) {}
				// ensure any pure-QML bullet gets removed eventually to avoid leaks
				try {
					var destroyTimer = Qt.createQmlObject('import QtQuick 2.0; Timer { interval: 3000; repeat: false; running: true; onTriggered: { try { if (typeof obj.destroy === "function") obj.destroy(); } catch (e) {} } }', obj, 'destroyTimer');
				} catch (e) { /* ignore */ }
			}
		} else {
			console.log("Failed to create bullet component:", comp.errorString());
		}
	}

	onAimModeChanged: {
		if (aimMode === "move") {
			setMoveAimTarget();
		} else {
			try {
				if (aimOverlay) {
					aimOverlay.aimX = -1000;
					aimOverlay.aimY = -1000;
					if (aimCanvas && typeof aimCanvas.requestPaint === 'function') aimCanvas.requestPaint();
				}
			} catch(eAim) { console.log('reset mouse aim failed', eAim); }
		}
		// persist aimMode change
		try {
			if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager) {
				var s = SaveLoadManager.loadSystem() || {};
				s.aimMode = aimMode;
				SaveLoadManager.saveSystem(s);
			}
		} catch(e) { console.log('GameView: saveSystem aimMode failed', e); }
	}

	function updateMouseAimPoint(screenX, screenY) {
		if (aimMode !== "mouse") return;
		if (!aimOverlay) return;
		aimOverlay.aimX = screenX;
		aimOverlay.aimY = screenY;
		try { if (aimCanvas && typeof aimCanvas.requestPaint === 'function') aimCanvas.requestPaint(); } catch(e) {}
	}

	function setMoveAimTarget() {
		if (aimMode !== "move") return;
		if (!playerObj || !playerItem || !mapWrapper || !aimOverlay) return;
		var px = playerObj.pos ? (playerObj.pos.x + (playerItem.width / 2)) : 0;
		var py = playerObj.pos ? (playerObj.pos.y + (playerItem.height / 2)) : 0;
		var centerX = mapWrapper.x + px * tileScale;
		var centerY = mapWrapper.y + py * tileScale;
		var dirX = (typeof playerItem.lastDx === 'number') ? playerItem.lastDx : 0;
		var dirY = (typeof playerItem.lastDy === 'number') ? playerItem.lastDy : 0;
		if (dirX === 0 && dirY === 0) {
			dirX = lastMoveAimDirX;
			dirY = lastMoveAimDirY;
		} else {
			var len = Math.sqrt(dirX * dirX + dirY * dirY);
			if (len > 0) {
				dirX /= len;
				dirY /= len;
				lastMoveAimDirX = dirX;
				lastMoveAimDirY = dirY;
			}
		}
		if (dirX === 0 && dirY === 0) {
			dirX = 0;
			dirY = -1;
		}
		var radius = (typeof sightMask !== 'undefined' && sightMask) ? sightMask.radius : 150;
		aimOverlay.aimX = centerX + dirX * radius;
		aimOverlay.aimY = centerY + dirY * radius;
		try { if (aimCanvas && typeof aimCanvas.requestPaint === 'function') aimCanvas.requestPaint(); } catch(e) {}
	}

	function resolveAimTarget(preferredScreenX, preferredScreenY) {
		if (!playerObj || !playerItem || !mapWrapper) return null;
		var px = playerObj.pos ? (playerObj.pos.x + (playerItem.width / 2)) : 0;
		var py = playerObj.pos ? (playerObj.pos.y + (playerItem.height / 2)) : 0;
		var centerX = mapWrapper.x + px * tileScale;
		var centerY = mapWrapper.y + py * tileScale;
		var targetX;
		var targetY;
		var usePreferred = (aimMode === "mouse" && typeof preferredScreenX === 'number' && typeof preferredScreenY === 'number');
		if (usePreferred) {
			targetX = preferredScreenX;
			targetY = preferredScreenY;
		} else {
			targetX = aimOverlay ? aimOverlay.aimX : undefined;
			targetY = aimOverlay ? aimOverlay.aimY : undefined;
		}
		if (typeof targetX !== 'number' || typeof targetY !== 'number' || targetX < -9000 || targetY < -9000) {
			var fallbackX = (aimMode === "move") ? lastMoveAimDirX : 0;
			var fallbackY = (aimMode === "move") ? lastMoveAimDirY : -1;
			var lenFallback = Math.sqrt(fallbackX * fallbackX + fallbackY * fallbackY);
			if (lenFallback === 0) {
				fallbackX = 0;
				fallbackY = -1;
				lenFallback = 1;
			}
			var baseRadius = (typeof sightMask !== 'undefined' && sightMask) ? sightMask.radius : 150;
			targetX = centerX + (fallbackX / lenFallback) * baseRadius;
			targetY = centerY + (fallbackY / lenFallback) * baseRadius;
		}
		var radius = (typeof sightMask !== 'undefined' && sightMask) ? sightMask.radius : 0;
		var dxs = targetX - centerX;
		var dys = targetY - centerY;
		var dist = Math.sqrt(dxs * dxs + dys * dys);
		if (radius > 0 && dist > radius) {
			var nx = dxs / dist;
			var ny = dys / dist;
			targetX = centerX + nx * radius;
			targetY = centerY + ny * radius;
		}
		var scale = Math.max(0.0001, tileScale);
		var targetWorldX = (targetX - mapWrapper.x) / scale;
		var targetWorldY = (targetY - mapWrapper.y) / scale;
		return {
			screenStartX: centerX,
			screenStartY: centerY,
			screenTargetX: targetX,
			screenTargetY: targetY,
			worldTargetX: targetWorldX,
			worldTargetY: targetWorldY,
			playerWorldX: px,
			playerWorldY: py,
			dirX: targetWorldX - px,
			dirY: targetWorldY - py
		};
	}

	function spawnLaserVisual(startScreenX, startScreenY, endScreenX, endScreenY) {
		if (!mapWrapper) return;
		try {
			var laserQml = 'import QtQuick 2.15; Canvas { id: beam; anchors.fill: parent; z: 2000; property real startX: 0; property real startY: 0; property real endX: 0; property real endY: 0; property real thickness: 24; onPaint: { var ctx = getContext("2d"); ctx.clearRect(0,0,width,height); ctx.strokeStyle = "#66CCFF"; ctx.lineWidth = thickness; ctx.beginPath(); ctx.moveTo(startX, startY); ctx.lineTo(endX, endY); ctx.stroke(); } }';
			var laserObj = Qt.createQmlObject(laserQml, mapWrapper);
			if (laserObj) {
				laserObj.startX = startScreenX - mapWrapper.x;
				laserObj.startY = startScreenY - mapWrapper.y;
				laserObj.endX = endScreenX - mapWrapper.x;
				laserObj.endY = endScreenY - mapWrapper.y;
				laserObj.thickness = 24 * tileScale;
				laserObj.requestPaint();
				Qt.createQmlObject('import QtQuick 2.0; Timer { interval: 120; repeat: false; running: true; onTriggered: { try { parent.destroy(); } catch(e){} } }', laserObj);
			}
		} catch(e) { console.log('spawnLaserVisual failed', e); }
	}

	// Aiming overlay and left-click shooting
	// place this under the sightMask (so it's only visible inside the transparent sight circle)
	Item {
		id: aimOverlay
		anchors.fill: parent
		z: 998
		visible: !(playerObj && playerObj.teleportMode)
		property real aimX: -1000
		property real aimY: -1000

	Canvas {
			id: aimCanvas
			anchors.fill: parent
			onPaint: {
				var ctx = getContext('2d');
				ctx.clearRect(0,0,width,height);
				if (!playerItem) return;
			// compute screen-space center from backend world pos to be robust to scaling
			var sx = mapWrapper.x + (playerObj.pos.x + (playerItem.width/2)) * tileScale;
			var sy = mapWrapper.y + (playerObj.pos.y + (playerItem.height/2)) * tileScale;
	// color changes when snipe (aiming) active; use deeper colors
	var arrowColor = (playerObj && playerObj.snipeActive) ? '#226699' : '#008844';
	ctx.strokeStyle = arrowColor;
		ctx.lineWidth = 15;
				ctx.beginPath();
				// compute target point; if mouse is outside sight, clamp to sight boundary
				var dxA = aimOverlay.aimX - sx;
				var dyA = aimOverlay.aimY - sy;
				var distA = Math.sqrt(dxA*dxA + dyA*dyA);
				var tx = aimOverlay.aimX;
				var ty = aimOverlay.aimY;
				if (distA > sightMask.radius && distA > 0) {
					var nx = dxA / distA;	// normalized
					tx = sx + nx * sightMask.radius;
					ty = sy + (dyA / distA) * sightMask.radius;
				}

				// draw a very faint circle; color switches to blue when snipe active
				var circR = Math.min(distA, sightMask.radius);
				if (circR > 0) {
					ctx.beginPath();
					ctx.arc(sx, sy, circR, 0, Math.PI*2);
					var fillColor = (playerObj && playerObj.snipeActive) ? 'rgba(51,153,204,0.36)' : 'rgba(0,204,102,0.36)';
					var strokeColor = (playerObj && playerObj.snipeActive) ? 'rgba(51,153,204,0.72)' : 'rgba(0,204,102,0.72)';
					ctx.fillStyle = fillColor;
					ctx.fill();
					ctx.lineWidth = 2;
					ctx.strokeStyle = strokeColor;
					ctx.stroke();
				}

				ctx.moveTo(sx, sy);
				ctx.lineTo(tx, ty);
				ctx.stroke();
				// draw arrow head
				var ang = Math.atan2(ty - sy, tx - sx);
				var ah = 28; // arrow head size (increase with thicker line)
				ctx.beginPath();
				ctx.moveTo(tx, ty);
				ctx.lineTo(tx - ah*Math.cos(ang - Math.PI/6), ty - ah*Math.sin(ang - Math.PI/6));
				ctx.lineTo(tx - ah*Math.cos(ang + Math.PI/6), ty - ah*Math.sin(ang + Math.PI/6));
				ctx.closePath();
				ctx.fillStyle = arrowColor;
				ctx.fill();
			}
		}

		MouseArea {
			anchors.fill: parent
			hoverEnabled: true
			enabled: aimOverlay.visible
			acceptedButtons: Qt.LeftButton
			onPositionChanged: function(mouse) {
				gameViewRoot.updateMouseAimPoint(mouse.x, mouse.y);
			}
			onExited: function() {
				if (gameViewRoot.aimMode === "mouse") {
					aimOverlay.aimX = -1000;
					aimOverlay.aimY = -1000;
					aimCanvas.requestPaint();
				}
			}
			onPressed: function(mouse) {
				if (mouse.button !== Qt.LeftButton) return;
				if (!playerObj || !playerItem) return;
				try { if (typeof btnAttack !== 'undefined') btnAttack.pressed = true; } catch(e) {}
				gameViewRoot.updateMouseAimPoint(mouse.x, mouse.y);
				var aimData = gameViewRoot.resolveAimTarget(mouse.x, mouse.y);
				if (!aimData) return;
				if (playerObj.snipeActive || gameViewRoot.snipeHeld) {
					var fired = false;
					try {
						if (typeof playerItem.trySnipe === 'function') fired = playerItem.trySnipe(aimData.playerWorldX, aimData.playerWorldY, aimData.dirX, aimData.dirY);
						else fired = false;
					} catch(e) { console.log('trySnipe call failed', e); fired = false; }
					if (fired) {
						gameViewRoot.spawnLaserVisual(aimData.screenStartX, aimData.screenStartY, aimData.screenTargetX, aimData.screenTargetY);
					}
					return;
				}
				try { if (typeof playerItem.stopBulletRecharge === 'function') playerItem.stopBulletRecharge(); } catch(e) {}
				if (!fireTimer.running) {
					fireTimer.start();
				}
			}
			onReleased: function(mouse) {
					// mirror UI: unset pressed when mouse released
					try { if (typeof btnAttack !== 'undefined') btnAttack.pressed = false; } catch(e) {}
				if (mouse.button !== Qt.LeftButton) return;
				// stop auto-fire and start recharge
				if (fireTimer.running) fireTimer.stop();
				try { if (typeof playerItem.startBulletRecharge === 'function') playerItem.startBulletRecharge(); } catch(e) {}
			}
		}

		// Timer to repeatedly attempt firing while mouse left is held
		Timer {
			id: fireTimer
			interval: 80
			repeat: true
			running: false
			onTriggered: function() {
				if (!playerObj || !playerItem) return;
				if (playerObj.teleportMode) return;
				// compute aim target similar to previous onClicked logic
					var sx = mapWrapper.x + (playerObj.pos.x + (playerItem.width/2)) * tileScale;
					var sy = mapWrapper.y + (playerObj.pos.y + (playerItem.height/2)) * tileScale;
				var ax = aimOverlay.aimX;
				var ay = aimOverlay.aimY;
				var dxs = ax - sx;
				var dys = ay - sy;
				var dists = Math.sqrt(dxs*dxs + dys*dys);
				var tx = ax;
				var ty = ay;
				if (dists > sightMask.radius && dists > 0) {
					var nx = dxs / dists;
					tx = sx + nx * sightMask.radius;
					ty = sy + (dys / dists) * sightMask.radius;
				}
				var targetWorldX = (tx - mapWrapper.x) / tileScale;
				var targetWorldY = (ty - mapWrapper.y) / tileScale;
					var px = playerObj.pos.x + (playerItem.width/2);
					var py = playerObj.pos.y + (playerItem.height/2);
				var dirx = targetWorldX - px;
				var diry = targetWorldY - py;
				// If snipe active, attempt snipe once (do not auto-repeat laser)
				if (playerObj && (playerObj.snipeActive || gameViewRoot.snipeHeld)) {
					// attempt once per trigger
					var fired = false;
					try {
						if (typeof playerItem.trySnipe === 'function') fired = playerItem.trySnipe(px, py, dirx, diry);
						else fired = false;
					} catch(e) { console.log('trySnipe call failed', e); fired = false; }
					if (fired) {
						// create visual as before
						// ... create front-end laser visual for feedback (same as before)
						var laserQml = 'import QtQuick 2.15; Canvas { id: beam; anchors.fill: parent; z: 2000; property real startX: 0; property real startY: 0; property real endX: 0; property real endY: 0; property real thickness: 24; onPaint: { var ctx = getContext("2d"); ctx.clearRect(0,0,width,height); ctx.strokeStyle = "#66CCFF"; ctx.lineWidth = thickness; ctx.beginPath(); ctx.moveTo(startX, startY); ctx.lineTo(endX, endY); ctx.stroke(); } }';
						var laserObj = Qt.createQmlObject(laserQml, mapWrapper);
						if (laserObj) {
							laserObj.startX = sx - mapWrapper.x;
							laserObj.startY = sy - mapWrapper.y;
							laserObj.endX = tx - mapWrapper.x;
							laserObj.endY = ty - mapWrapper.y;
							laserObj.thickness = 24 * tileScale;
							laserObj.requestPaint();
							Qt.createQmlObject('import QtQuick 2.0; Timer { interval: 120; repeat: false; running: true; onTriggered: { try { parent.destroy(); } catch(e){} } }', laserObj);
						}
					}
				} else {
					var firedB = false;
					try {
						if (typeof playerItem.tryShoot === 'function') firedB = playerItem.tryShoot(px, py, dirx, diry);
						else firedB = false;
					} catch(e) { console.log('tryShoot call failed', e); firedB = false; }
					if (firedB) {
						// if backend doesn't provide shoot, create visual fallback
						if (!(playerObj && typeof playerObj.shoot === 'function')) {
							createBullet(px, py, dirx, diry);
						}
					} else {
						// if bullet not ready, still allow continuous clicking but don't create visual
					}
				}
			}
		}
	}

	// While in teleport mode, clicking anywhere on the viewport teleports the player to that world position
	MouseArea {
		id: teleportClickArea
		anchors.fill: parent
		z: 2105
		visible: (playerObj && playerObj.teleportMode)
		enabled: visible
		hoverEnabled: false
		acceptedButtons: Qt.LeftButton
		cursorShape: Qt.PointingHandCursor
		onClicked: function(mouse) {
			if (!playerObj || !mapWrapper || ! teleportOverlay) return;
			var localX = mouse.x - mapWrapper.x;
			var localY = mouse.y - mapWrapper.y;
			var worldX = localX / tileScale;
			var worldY = localY / tileScale;
			var clampedX = Math.max(0, Math.min(worldX, mapCols * tileSize));
			var clampedY = Math.max(0, Math.min(worldY, mapRows * tileSize));
			// Draw persistent teleport line and then (GameView via teleportRequested signal) will start animated move
			try {
				teleportOverlay.handleTeleportClick(Qt.point(clampedX, clampedY));
			} catch (e) { console.log('handleTeleportClick failed', e); }
		}
	}

	// Teleport mover: animates playerObj.pos from current position to target smoothly
	Item {
		id: teleportMover
		visible: false
		width: 1; height: 1
		property bool running: false
		property real px: 0
		property real py: 0
		signal finished()

		ParallelAnimation {
			id: teleportParallel
			running: false
			NumberAnimation { id: animX; target: teleportMover; property: "px" }
			NumberAnimation { id: animY; target: teleportMover; property: "py" }
			onStopped: {
				teleportMover.running = false;
				teleportClickArea.enabled = true;
				try { teleportMover.finished(); } catch(e) {}
			}
		}

		onPxChanged: {
			// update backend player pos (playerObj.pos is top-left in world coords)
			if (!playerObj || !playerItem) return;
			var newWorldX = teleportMover.px - (playerItem.width/2);
			var newWorldY = teleportMover.py - (playerItem.height/2);
			try { playerObj.pos = Qt.point(newWorldX, newWorldY); } catch(e) {}
		}
		onPyChanged: onPxChanged
	}

	// 瞬移音效（受主音量与效果音控制）
	SoundEffect {
		id: teleportSfx
		source: "qrc:/resource/audio/SoundEffect/teleport.wav"
		volume: 0.9 * (typeof window !== 'undefined' ? window.masterVolume * window.sfxVolume : 1.0)
	}

	function startTeleportMove(targetWorldX, targetWorldY) {
		if (!playerObj || !playerItem) return;
		// prevent additional clicks while moving
		teleportClickArea.enabled = false;
		// compute current player center in world coords
		var curCenterX = playerObj.pos.x + (playerItem.width/2);
		var curCenterY = playerObj.pos.y + (playerItem.height/2);
		var dstX = targetWorldX + (playerItem.width/2);
		var dstY = targetWorldY + (playerItem.height/2);
		var dx = dstX - curCenterX; var dy = dstY - curCenterY;
		var dist = Math.sqrt(dx*dx + dy*dy);
		// choose high speed (world units per second)
		var speed = 2400.0; // adjust for "high-speed" feel
		var durationMs = Math.max(80, Math.min(1200, Math.round((dist / speed) * 1000)));

		teleportMover.px = curCenterX;
		teleportMover.py = curCenterY;
		animX.from = curCenterX; animX.to = dstX; animX.duration = durationMs; animX.easing.type = Easing.InOutQuad;
		animY.from = curCenterY; animY.to = dstY; animY.duration = durationMs; animY.easing.type = Easing.InOutQuad;
		teleportMover.running = true;
		// 播放瞬移音效
		try { teleportSfx.play(); } catch(e) {}
		teleportParallel.start();

		teleportMover.finished.connect(function() {
			// ensure final pos set exactly and notify backend via teleportTo so
			// the backend can emit teleported() (and related handlers can run).
			try { playerObj.pos = Qt.point(targetWorldX, targetWorldY); } catch(e) {}
			try { if (typeof playerObj.teleportTo === 'function') playerObj.teleportTo(targetWorldX, targetWorldY); } catch(e) {}
		});
	}

	// Teleport overlay floats above the map so teleport targets remain visible while aim overlay is hidden.
	EntityQml.TeleportOverlay {
		id: teleportOverlay
		// parent it to mapWrapper so overlay coordinates share the same coordinate space
		parent: mapWrapper
		playerObj: playerObj
		tileScale: tileScale
		mapWrapperRef: mapWrapper
		teleportDistance: teleportRingDistance
		// pass reference to dynamic sight mask so overlay uses current visible radius
		sightMaskRef: sightMask
		active: playerObj && playerObj.teleportMode
		// Pass the visual (screen-space) size of the player so the overlay
		// can correctly convert to world units when tileScale != 1.
		playerVisualWidth: playerItem ? (playerItem.width * tileScale) : 0
		playerVisualHeight: playerItem ? (playerItem.height * tileScale) : 0
		mapClamp: ({ width: mapCols * tileSize, height: mapRows * tileSize })
		enemyBackends: enemyBackends
	}

	// Start animated teleport when overlay emits the request (marker clicks or viewport clicks)
	Connections {
		target: teleportOverlay
		enabled: !!teleportOverlay
		function onTeleportRequested(pt) {
			try { startTeleportMove(pt.x, pt.y); } catch(e) { console.log('onTeleportRequested failed', e); }
		}
	}
	Connections {
		target: playerObj
		enabled: !!playerObj
		function onTeleportModeChanged() {
			if (playerObj.teleportMode) {
				if (fireTimer.running) fireTimer.stop();
				try {
					if (typeof playerItem.startBulletRecharge === 'function') playerItem.startBulletRecharge();
				} catch (e) {}
			}
		}
	}
	BackendPlayer {
		id: playerObj
		// Provide backend with world map size (not scaled by tileScale).
		// mapPixelWidth/mapPixelHeight include visual scaling and would
		// shrink when entering snipe mode. Passing those causes the
		// backend to clamp player pos incorrectly when tileScale changes.
		mapWidth: mapCols * tileSize
		mapHeight: mapRows * tileSize
		Component.onCompleted: {
			var tileSizeLocal = tileSize * tileScale;
			var centerCol = tileManager.colCnt / 2;
			var centerRow = tileManager.rowCnt / 2;
			var centerX = centerCol * tileSizeLocal;
			var centerY = centerRow * tileSizeLocal;
			// If navigated here as a new game, create a default auto save at the map center
			try {
				var tm = WindowState.takeTargetMode();
				if (tm === "new") {
					if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager) {
						// reasonable defaults for a new game
						var defaultSpeed = 0;
						var defaultSight = 180;
						// Ensure default auto-save records which battle this belongs to when possible
						try { SaveLoadManager.battleId = battleId || (typeof window !== 'undefined' && window.currentBattleId ? window.currentBattleId : ""); } catch(eBid) {}
						SaveLoadManager.createDefaultAuto("save", centerX, centerY, defaultSpeed, defaultSight);
					}
				} else if (tm === "loadFromSave") {
					// We were navigated here from SaveLoad after loadSlot succeeded. Apply saved player & enemy values.
					if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager) {
						var savedBattleId = "";
						try { savedBattleId = SaveLoadManager.battleId || ""; } catch (eBid) { savedBattleId = ""; }
						if (savedBattleId) {
							var prevBattleId = battleId;
							battleId = savedBattleId;
							if (typeof window !== 'undefined') window.currentBattleId = savedBattleId;
							if (!battleData || prevBattleId !== savedBattleId) {
								try { loadBattleData(savedBattleId); } catch (eLoad) { console.log('GameView: loadBattleData during loadFromSave failed', eLoad); }
							}
						}
						console.log("GameView: detected loadFromSave, applying player+enemies");
						if (!isNaN(SaveLoadManager.posX) && !isNaN(SaveLoadManager.posY)) {
							playerObj.pos = Qt.point(SaveLoadManager.posX, SaveLoadManager.posY);
						}
						if (!isNaN(SaveLoadManager.speed) && SaveLoadManager.speed > 0) playerObj.setSpeed(SaveLoadManager.speed);
						if (!isNaN(SaveLoadManager.sight) && SaveLoadManager.sight > 0) playerObj.setSight(SaveLoadManager.sight);
						if (!isNaN(SaveLoadManager.maxHp) && SaveLoadManager.maxHp > 0) playerObj.maxHp = SaveLoadManager.maxHp;
						if (!isNaN(SaveLoadManager.hp)) {
							var restoredHp = Math.max(0, Math.min(SaveLoadManager.hp, playerObj.maxHp));
							playerObj.hp = restoredHp;
						}
						// Rebuild enemies directly from saved data (skip map-based spawning to preserve exact state)
						try {
							var savedEnemies = SaveLoadManager.enemiesAsVariantList ? SaveLoadManager.enemiesAsVariantList() : [];
							if (savedEnemies && savedEnemies.length > 0) {
								clearEnemies();
								for (var si=0; si<savedEnemies.length; ++si) {
									var s = savedEnemies[si];
									if (!s.type) continue;
									// 跳过已死亡或HP<=0的敌人
									if ((typeof s.alive !== 'undefined' && !s.alive) || (typeof s.hp !== 'undefined' && s.hp <= 0)) {
										continue;
									}
									var backendCode = '';
									if (s.type === 'Enemy1') backendCode = 'import GeistZerfall.Game 1.0; BackendEnemy1 {}';
									else if (s.type === 'Enemy2') backendCode = 'import GeistZerfall.Game 1.0; BackendEnemy2 {}';
									else if (s.type === 'Enemy3') backendCode = 'import GeistZerfall.Game 1.0; BackendEnemy3 {}';
									else if (s.type === 'Enemy4') backendCode = 'import GeistZerfall.Game 1.0; BackendEnemy4 {}';
									else if (s.type === 'Enemy5') backendCode = 'import GeistZerfall.Game 1.0; BackendEnemy5 {}';
									else if (s.type === 'Enemy6') backendCode = 'import GeistZerfall.Game 1.0; BackendEnemy6 {}';
									else if (s.type === 'Enemy7') backendCode = 'import GeistZerfall.Game 1.0; BackendEnemy7 {}';
									else continue; // unknown type skip
									var be = Qt.createQmlObject(backendCode, gameViewRoot);
									if (!be) continue;
									be.mapWidth = mapPixelWidth; be.mapHeight = mapPixelHeight;
									try { be.pos = Qt.point(s.x, s.y); } catch(e) {}
									if (playerObj && typeof be.setPlayerTarget === 'function') be.setPlayerTarget(playerObj);
									// restore stats
									try { if (typeof be.setMaxHp === 'function') be.setMaxHp(s.maxHp); else be.maxHp = s.maxHp; } catch(e){}
									try { if (typeof be.setHp === 'function') be.setHp(s.hp); else be.hp = s.hp; } catch(e){}
									try { if (typeof be.setMaxMp === 'function') be.setMaxMp(s.maxMp); else be.maxMp = s.maxMp; } catch(e){}
									try { if (typeof be.setMp === 'function') be.setMp(s.mp); else be.mp = s.mp; } catch(e){}
									try { be.alive = s.alive; } catch(e){}
									enemyBackends.push(be);
									enemyTypes.push(s.type);
									enemySpawnCenters.push({ x: s.x, y: s.y });
									// create visual
									var compPath = '';
									if (s.type === 'Enemy1') compPath = './Entity/Enemy/Enemy1.qml';
									else if (s.type === 'Enemy2') compPath = './Entity/Enemy/Enemy2.qml';
									else if (s.type === 'Enemy3') compPath = './Entity/Enemy/Enemy3.qml';
									else if (s.type === 'Enemy4') compPath = './Entity/Enemy/Enemy4.qml';
									else if (s.type === 'Enemy5') compPath = './Entity/Enemy/Enemy5.qml';
									else if (s.type === 'Enemy6') compPath = './Entity/Enemy/Enemy6.qml';
									else if (s.type === 'Enemy7') compPath = './Entity/Enemy/Enemy7.qml';
									if (compPath !== '') {
										var comp = Qt.createComponent(compPath);
										if (comp.status === Component.Ready) {
											var v = comp.createObject(mapWrapper, { backend: be, playerObjRef: playerObj, playerItemRef: playerItem, mapWrapperRef: mapWrapper, tileScaleRef: tileScale });
											if (v) {
												enemyVisuals.push(v);
												v.tileScaleRef = Qt.binding(function(){ return tileScale; });
												v.playerItemRef = playerItem;
												v.updateScreenPos && v.updateScreenPos();
											}
										}
									}
								}
								console.log('GameView: restored', enemyBackends.length, 'enemies from save');
								// persist snapshot for SaveLoad UI
								try { WindowState.setGameEnemies && WindowState.setGameEnemies(serializeEnemies()); } catch(eSS) {}
								appliedSaveLoad = true;
								// after restoring enemies from save, ensure we trigger win if all enemies are already dead
								Qt.callLater(function(){ checkVictoryNow(); });
							} else {
								console.log('GameView: no saved enemies list; will spawn from map normally');
							}
						} catch (eEnemies) { console.log('GameView: rebuild enemies error', eEnemies); }
					}
				}
			} catch (e) { /* ignore if windowState not available */ }
			// If we didn't just apply a save load, try loading auto save as before; otherwise default to center
			// Defer the heavy restore/spawn logic so the tile map is reliably available (avoid running
			// this too early which can leave player at 0,0). Using Qt.callLater schedules after
			// object completion & map setup.
			if (!appliedSaveLoad) Qt.callLater(function() {
				// Attempt to apply auto-save restore when present and matching the current battleId.
				// Otherwise fall back to explicit spawn position (from JSON), then scan map for
				// a tile==0 spawn spot, then finally use center as a last resort.
				var handled = false;
				try {
					if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager) {
						if (SaveLoadManager.loadAuto() && (typeof SaveLoadManager.view === 'undefined' || SaveLoadManager.view !== 'lore')) {
							if (SaveLoadManager.battleId === battleId) {
								console.log('Loaded auto save');
								if (!isNaN(SaveLoadManager.posX) && !isNaN(SaveLoadManager.posY) && (SaveLoadManager.posX !== 0 || SaveLoadManager.posY !== 0)) {
									playerObj.pos = Qt.point(SaveLoadManager.posX, SaveLoadManager.posY);
								}
								if (!isNaN(SaveLoadManager.speed) && SaveLoadManager.speed > 0) playerObj.setSpeed(SaveLoadManager.speed);
								if (!isNaN(SaveLoadManager.sight) && SaveLoadManager.sight > 0) playerObj.setSight(SaveLoadManager.sight);
								if (!isNaN(SaveLoadManager.maxHp) && SaveLoadManager.maxHp > 0) playerObj.maxHp = SaveLoadManager.maxHp;
								if (!isNaN(SaveLoadManager.hp)) {
									var autoHp = Math.max(0, Math.min(SaveLoadManager.hp, playerObj.maxHp));
									playerObj.hp = autoHp;
								}
								// restore countdown time from auto-save if present
								try {
									if (typeof SaveLoadManager.timeLeftSeconds !== 'undefined' && !isNaN(SaveLoadManager.timeLeftSeconds)) {
										if (SaveLoadManager.battleId === battleId && SaveLoadManager.timeLeftSeconds > 0) {
											timeLeftSeconds = SaveLoadManager.timeLeftSeconds;
											if (timeLeftSeconds > 0) countdownTimer.running = true;
											console.log('GameView: restored timeLeftSeconds from auto-save', timeLeftSeconds);
										}
									}
								} catch(eTL) { console.log('restore timeLeftSeconds from auto-save failed', eTL); }
								appliedSaveLoad = true;
								handled = true;
							} else {
								console.log('GameView: auto save exists, but belongs to different battle (auto:' + SaveLoadManager.battleId + ' != ' + battleId + '), skipping auto-restore');
								handled = false;
							}
						}
					}
				} catch (e) { console.log('auto-restore check failed', e); }

				if (!handled) {
					// Try explicit spawn coordinate in battle JSON
					var didSpawn = false;
					try {
						if (battleData && battleData.spawn && battleData.spawn.playerPos) {
							var p = battleData.spawn.playerPos;
							var spawnWorldX = (p.x * tileSize) + (tileSize/2) - (playerItem.width/2);
							var spawnWorldY = (p.y * tileSize) + (tileSize/2) - (playerItem.height/2);
							playerObj.pos = Qt.point(spawnWorldX, spawnWorldY);
							didSpawn = true;
						}
					} catch (ePos) { console.log('apply explicit spawn.playerPos failed', ePos); }

					// If no explicit spawn, scan map for a tile==0 and pick its center
					if (!didSpawn) {
						try {
							if (tileManager && tileManager.curMapData) {
								var rows2 = tileManager.curMapData.length;
								var found = false;
								for (var rr = 0; rr < rows2 && !found; ++rr) {
									var cols2 = tileManager.curMapData[rr].length;
									for (var cc = 0; cc < cols2; ++cc) {
										var tt = tileManager.getTileType(rr, cc);
										if (tt === 0) {
											var wx = cc * tileSize + tileSize/2 - (playerItem.width/2);
											var wy = rr * tileSize + tileSize/2 - (playerItem.height/2);
											playerObj.pos = Qt.point(wx, wy);
											found = true;
											didSpawn = true;
											break;
										}
									}
								}
								if (!found) {
									// fallback to center if no tile==0 found
									playerObj.pos = Qt.point(centerX, centerY);
									didSpawn = true;
								}
							} else {
								// no map yet - fallback to map center
								playerObj.pos = Qt.point(centerX, centerY);
								didSpawn = true;
							}
						} catch (eScan) { console.log('scan for tile==0 failed', e); playerObj.pos = Qt.point(centerX, centerY); didSpawn = true; }
					}

					// Mark that we handled spawn/default state so we won't attempt auto-restore again
					appliedSaveLoad = true;
				}
			});
			// expose playerObj to window so SaveLoad UI can read current player state when saving
			try { if (window) window.currentPlayer = playerObj; } catch (e) {}
			// persist enemy snapshot via WindowState for SaveLoad UI
			try { WindowState.setGameEnemies && WindowState.setGameEnemies(serializeEnemies()); } catch (e) { console.log('persist enemies failed', e); }
		}
	}
	EntityQml.Player {
		id: playerItem
		z: 100
		playerObj: playerObj
		// use scale transform to smoothly resize player visual without changing layout geometry
		scale: tileScale
		transformOrigin: Item.Center
		// Position the visual based on mapWrapper offset and backend world coordinates.
		// This ensures when the map is clamped at edges (mapWrapper.x/y adjusted),
		// the player visual remains correctly aligned with world coordinates and
		// the sightMask/aimCanvas calculations which use mapWrapper.x/y.
		x: (playerObj && mapWrapper && playerItem) ? (mapWrapper.x + (playerObj.pos.x + (playerItem.width/2)) * tileScale - (width/2)) : (mapViewport.width / 2 - width / 2)
		y: (playerObj && mapWrapper && playerItem) ? (mapWrapper.y + (playerObj.pos.y + (playerItem.height/2)) * tileScale - (height/2)) : (mapViewport.height / 2 - height / 2)
		focus: true 
		Component.onCompleted: playerItem.forceActiveFocus()

	}

	// When backend player emits playerBulletCreated, create bullet visual and bind to backend
	Connections {
		target: playerObj
		onPlayerBulletCreated: function(bullet) {
			console.log('GameView.qml: playerBulletCreated', bullet);
			// create bullet visual and bind
			var comp = Qt.createComponent("./Entity/PlayerBullet.qml");
				if (comp.status === Component.Ready) {
					var obj = comp.createObject(mapWrapper, { backend: bullet, enemiesRef: enemyBackends, mapWrapperRef: mapWrapper, tileScaleRef: tileScale, playerObjRef: playerObj, playerItemRef: playerItem });
				if (!obj) console.log('Failed to create PlayerBullet visual');
				else {
					obj.tileScaleRef = Qt.binding(function(){ return tileScale; });
						obj.enemiesRef = Qt.binding(function(){ return enemyBackends; });
					obj.mapWrapperRef = mapWrapper;
				}
			} else {
				console.log('Failed to create PlayerBullet component:', comp.errorString());
			}
		}
	}

	// When backend player emits playerLaserCreated, create laser visual and bind to backend
	Connections {
		target: playerObj
		onPlayerLaserCreated: function(laser) {
			console.log('GameView.qml: playerLaserCreated', laser);
			var comp = Qt.createComponent("./Entity/PlayerLaser.qml");
			if (comp.status === Component.Ready) {
				// create the laser visual as a child of the view root (not mapWrapper)
				// and pass a reference to mapWrapper so the visual can compute screen coords
				var obj = comp.createObject(gameViewRoot, {
					backend: laser,
					// pass spreadIndex from backend (if available) to let visual tweak appearance
					spreadIndex: (typeof laser.spreadIndex !== 'undefined') ? laser.spreadIndex : 0,
					thickness: 6,
					mapWrapperRef: mapWrapper,
					tileScaleRef: Qt.binding(function() { return tileScale; }),
					enemiesRef: enemyBackends
				});
				if (!obj) console.log('Failed to create PlayerLaser visual');
				else {
					// ensure initial paint
					try { if (typeof obj.start === 'function') obj.start(); } catch(e) {}
					try { obj.requestPaint(); } catch(e) {}
					obj.enemiesRef = Qt.binding(function(){ return enemyBackends; });
				}
			} else {
				console.log('Failed to create PlayerLaser component:', comp.errorString());
			}
		}
	}

	// When backend player emits playerWaveCreated, create wave visual and bind to backend
	Connections {
		target: playerObj
		onPlayerWaveCreated: function(wave) {
			console.log('GameView.qml: playerWaveCreated', wave);
			var comp = Qt.createComponent("./Entity/PlayerWave.qml");
			if (comp.status === Component.Ready) {
				var obj = comp.createObject(mapWrapper, { backend: wave, enemiesRef: enemyBackends, mapWrapperRef: mapWrapper, tileScaleRef: tileScale });
				if (!obj) console.log('Failed to create PlayerWave visual');
				else {
					obj.tileScaleRef = Qt.binding(function() { return tileScale; });
					obj.enemiesRef = Qt.binding(function() { return enemyBackends; });
				}
			} else { console.log('Failed to create PlayerWave component:', comp.errorString()); }
		}
	}
	// 视野遮罩层（Canvas 实现，避免 Qt6 qsb 要求）
	Canvas {
		id: sightMask
		anchors.fill: parent
		// 遮罩中心直接绑定到 playerItem 的视觉中心，确保跟随移动与缩放
		property real cx: playerItem ? (playerItem.x + playerItem.width/2) : width/2
		property real cy: playerItem ? (playerItem.y + playerItem.height/2) : height/2
		// baseRadius 是默认（原始）视野半径，可调整或从后端读取
		// read sight via Q_PROPERTY exposed as 'sight'
		property real baseRadius: playerObj ? (playerObj.sight ? playerObj.sight : 180) : 180
		// 初始半径按当前 tileScale 缩放，避免进入游戏时出现不一致大小
		property real radius: baseRadius * tileScale
	property color maskColor: Qt.rgba(0,0,0,1.0)
		z: 999

		Behavior on radius {
			NumberAnimation { duration: 600; easing.type: Easing.InOutQuad }
		}

		// 请求在关键属性变化时重绘
		onCxChanged: requestPaint()
		onCyChanged: requestPaint()
		onRadiusChanged: requestPaint()
		onWidthChanged: requestPaint()
		onHeightChanged: requestPaint()
		// 当缩放变化时需要更新半径（若未被移动/狙击逻辑覆盖）
		Connections {
			target: gameViewRoot
			onTileScaleChanged: {
				// 如果当前处于移动或狙击动态调整，保持逻辑不强制覆盖；否则按基础值更新
				if (gameViewRoot.snipeHeld) {
					sightMask.radius = sightMask.baseRadius * tileScale;
				} else if (playerItem && playerItem.moving) {
					sightMask.radius = (sightMask.baseRadius / 2) * tileScale;
				} else {
					sightMask.radius = sightMask.baseRadius * tileScale;
				}
			}
		}

		onPaint: {
			var ctx = getContext('2d');
			// 清空并绘制纯黑遮罩
			ctx.clearRect(0, 0, width, height);
			ctx.globalCompositeOperation = 'source-over';
			ctx.fillStyle = maskColor;
			ctx.fillRect(0, 0, width, height);
			// 在玩家位置打出透明圆（destination-out）
			ctx.globalCompositeOperation = 'destination-out';
			ctx.beginPath();
			ctx.arc(cx, cy, radius, 0, Math.PI * 2);
			ctx.fill();
			if (mapWrapper && mapWrapper.revealedEnemyVisuals && mapWrapper.revealedEnemyVisuals.length > 0) {
				for (var idx = mapWrapper.revealedEnemyVisuals.length - 1; idx >= 0; --idx) {
					var enemy = mapWrapper.revealedEnemyVisuals[idx];
					if (!enemy || !enemy.visible) continue;
					var centerX = mapWrapper.x + enemy.x + enemy.width / 2;
					var centerY = mapWrapper.y + enemy.y + enemy.height / 2;
					var scaleFactor = (enemy.scale !== undefined && enemy.scale > 0) ? enemy.scale : 1.0;
					var radiusHint = Math.max(enemy.width, enemy.height) * scaleFactor * 0.7;
					var revealRadius = Math.max(radiusHint, 60);
					ctx.beginPath();
					ctx.arc(centerX, centerY, revealRadius, 0, Math.PI * 2);
					ctx.fill();
				}
			}
			// 恢复默认合并方式
			ctx.globalCompositeOperation = 'source-over';
		}
	}

		Timer {
			id: revealRepaintTimer
			interval: 120
			repeat: true
			running: false
			onTriggered: sightMask.requestPaint()
		}

		// 监听 playerItem 的 moving 状态，平滑调整视野半径到 baseRadius/2 或 baseRadius
    	Connections {
    		target: playerItem
    		onMovingChanged: {
    			// If the snipe/space key is held, keep sight locked at maximum and ignore moving changes
    			if (gameViewRoot.snipeHeld) {
    				// enforce max sight while held
    				sightMask.radius = sightMask.baseRadius * tileScale;
    				return;
    			}
    			if (playerItem.moving) {
    				// 把 radius 缩小为原来的一半，动画由 Behavior 控制
    				sightMask.radius = (sightMask.baseRadius / 2) * tileScale;
    			} else {
    				sightMask.radius = sightMask.baseRadius * tileScale;
    			}
    		}
    	}

		Connections {
			target: playerItem
			onLastDxChanged: { if (gameViewRoot.aimMode === "move") gameViewRoot.setMoveAimTarget(); }
			onLastDyChanged: { if (gameViewRoot.aimMode === "move") gameViewRoot.setMoveAimTarget(); }
			onMovingChanged: { if (gameViewRoot.aimMode === "move") gameViewRoot.setMoveAimTarget(); }
			onXChanged: { if (gameViewRoot.aimMode === "move") gameViewRoot.setMoveAimTarget(); }
			onYChanged: { if (gameViewRoot.aimMode === "move") gameViewRoot.setMoveAimTarget(); }
		}

	// On-screen controls
	Item {
		id: touchControls
		anchors.fill: parent
		z: 5000 // Ensure it's on top
		property var keyHoldState: ({})

		function ensurePlayerFocus() {
			try {
				if (playerItem && !playerItem.activeFocus) {
					playerItem.forceActiveFocus();
				}
			} catch(e) {}
		}

		// Left-bottom Joystick (WASD)
		Item {
			id: joystick
			visible: gameViewRoot.controlsVisible
			width: 200; height: 200
				anchors.bottom: parent.bottom
				anchors.left: parent.left
				anchors.leftMargin: 8
				anchors.bottomMargin: 8

			Rectangle {
				id: joystickBg
				anchors.fill: parent
				radius: width / 2
				color: "#80000000"
				border.color: "white"
				border.width: 2
			}

			Rectangle {
				id: joystickKnob
				width: 80; height: 80
				radius: 40
				color: "white"
				x: (parent.width - width) / 2
				y: (parent.height - height) / 2
			}

				MouseArea {
					id: joystickArea
				anchors.fill: parent
				preventStealing: true
				
				property real centerX: width / 2
				property real centerY: height / 2
				property real maxDist: width / 2 - joystickKnob.width / 2

				onPressed: {
					touchControls.ensurePlayerFocus()
					dragging = true
					updatePosition(mouse)
				}
				onPositionChanged: updatePosition(mouse)
				onReleased: {
					joystickKnob.x = (parent.width - joystickKnob.width) / 2
					joystickKnob.y = (parent.height - joystickKnob.height) / 2
					dragging = false
					// settle knob based on keyboard state if keys are held
					updateFromKeyboard()
					resetMovement()
				}

				function updatePosition(mouse) {
					var dx = mouse.x - centerX
					var dy = mouse.y - centerY
					var dist = Math.sqrt(dx*dx + dy*dy)
					
					if (dist > maxDist) {
						var ratio = maxDist / dist
						dx *= ratio
						dy *= ratio
					}

					joystickKnob.x = centerX + dx - joystickKnob.width / 2
					joystickKnob.y = centerY + dy - joystickKnob.height / 2

					// Map to WASD
					var threshold = 20
					
					if (playerItem) {
						playerItem.wDown = (dy < -threshold)
						playerItem.sDown = (dy > threshold)
						playerItem.aDown = (dx < -threshold)
						playerItem.dDown = (dx > threshold)
						playerItem.computeAndMove()
					}
				}

				function resetMovement() {
					if (playerItem) {
						playerItem.wDown = false
						playerItem.sDown = false
						playerItem.aDown = false
						playerItem.dDown = false
						playerItem.computeAndMove()
					}
				}

				// When keyboard controls change, animate or update knob position
				property bool dragging: false
				function updateFromKeyboard() {
					if (dragging) return; // don't override when user is dragging
					if (!playerItem) return;
					var cx = centerX; var cy = centerY; var m = maxDist * 0.75;
					var kx = cx + (playerItem.lastDx * m);
					var ky = cy + (playerItem.lastDy * m);
					joystickKnob.x = kx - joystickKnob.width / 2
					joystickKnob.y = ky - joystickKnob.height / 2
				}

				// React to playerItem keyboard state changes
				Connections {
					target: playerItem
					onLastDxChanged: updateFromKeyboard()
					onLastDyChanged: updateFromKeyboard()
				}
			}
		}

		// Right-bottom Controls
		Item {
			id: actionButtons
			width: 250; height: 250
				anchors.bottom: parent.bottom
				anchors.right: parent.right
				anchors.rightMargin: 8
				anchors.bottomMargin: 8

			// radius from ATK center to small buttons
			property real buttonRadius: btnAttack ? (btnAttack.width/2 + 36) : 96

				visible: gameViewRoot.controlsVisible

				// Big Circle (LMB / Attack)
			Rectangle {
				id: btnAttack
				width: 120; height: 120
				radius: 60
				property bool pressed: false
				color: pressed ? "black" : "white"
				border.color: pressed ? "white" : "black"
				border.width: 2
				anchors.bottom: parent.bottom
				anchors.right: parent.right

				Canvas {
					anchors.centerIn: parent
					width: parent.width * 0.6
					height: parent.height * 0.6
					property bool buttonPressed: parent.pressed
					Component.onCompleted: requestPaint()
					onButtonPressedChanged: requestPaint()
					onPaint: {
						var ctx = getContext('2d');
						ctx.clearRect(0,0,width,height);
						var fg = parent.pressed ? 'white' : 'black';
						ctx.strokeStyle = fg; ctx.fillStyle = fg;
						var cx = width/2, cy = height/2;
						var r = Math.min(width, height)/2 - 2;
						// outer dot
						ctx.beginPath(); ctx.arc(cx, cy, r*0.28, 0, Math.PI*2); ctx.fill();
						// crosshair lines
						ctx.lineWidth = Math.max(2, r*0.12);
						ctx.beginPath(); ctx.moveTo(cx - r, cy); ctx.lineTo(cx + r, cy); ctx.moveTo(cx, cy - r); ctx.lineTo(cx, cy + r); ctx.stroke();
					}
				}

				MouseArea {
					anchors.fill: parent
					onPressed: {
						touchControls.ensurePlayerFocus()
						btnAttack.pressed = true
						if (!playerObj || !playerItem) return;

						// Snipe mode logic
						if (playerObj.snipeActive || gameViewRoot.snipeHeld) {
							try {
								var sx = mapWrapper.x + (playerObj.pos.x + (playerItem.width/2)) * tileScale;
								var sy = mapWrapper.y + (playerObj.pos.y + (playerItem.height/2)) * tileScale;
								var ax = aimOverlay.aimX;
								var ay = aimOverlay.aimY;
								var dxs = ax - sx;
								var dys = ay - sy;
								var dists = Math.sqrt(dxs*dxs + dys*dys);
								var tx = ax;
								var ty = ay;
								if (dists > sightMask.radius && dists > 0) {
									var nx = dxs / dists;
									tx = sx + nx * sightMask.radius;
									ty = sy + (dys / dists) * sightMask.radius;
								}
								var targetWorldX = (tx - mapWrapper.x) / tileScale;
								var targetWorldY = (ty - mapWrapper.y) / tileScale;
								var px = playerObj.pos.x + (playerItem.width/2);
								var py = playerObj.pos.y + (playerItem.height/2);
								var dirx = targetWorldX - px;
								var diry = targetWorldY - py;
								var fired = false;
								try {
									if (typeof playerItem.trySnipe === 'function') fired = playerItem.trySnipe(px, py, dirx, diry);
									else fired = false;
								} catch(e) { console.log('trySnipe call failed', e); fired = false; }
								if (fired) {
									var laserQml = 'import QtQuick 2.15; Canvas { id: beam; anchors.fill: parent; z: 2000; property real startX: 0; property real startY: 0; property real endX: 0; property real endY: 0; property real thickness: 24; onPaint: { var ctx = getContext("2d"); ctx.clearRect(0,0,width,height); ctx.strokeStyle = "#66CCFF"; ctx.lineWidth = thickness; ctx.beginPath(); ctx.moveTo(startX, startY); ctx.lineTo(endX, endY); ctx.stroke(); } }';
									var laserObj = Qt.createQmlObject(laserQml, mapWrapper);
									if (laserObj) {
										laserObj.startX = sx - mapWrapper.x;
										laserObj.startY = sy - mapWrapper.y;
										laserObj.endX = tx - mapWrapper.x;
										laserObj.endY = ty - mapWrapper.y;
										laserObj.thickness = 24 * tileScale;
										laserObj.requestPaint();
										Qt.createQmlObject('import QtQuick 2.0; Timer { interval: 120; repeat: false; running: true; onTriggered: { try { parent.destroy(); } catch(e){} } }', laserObj);
									}
								}
							} catch(e) { console.log('snipe onPressed failed', e); }
							return;
						}

						// Auto-fire logic
						try { if (typeof playerItem.stopBulletRecharge === 'function') playerItem.stopBulletRecharge(); } catch(e) {}
						if (fireTimer && !fireTimer.running) {
							fireTimer.start();
						}
					}
					onReleased: {
						btnAttack.pressed = false
						if (fireTimer && fireTimer.running) fireTimer.stop();
						try { if (playerItem && typeof playerItem.startBulletRecharge === 'function') playerItem.startBulletRecharge(); } catch(e) {}
					}
				}
			}

			// F Button (Left of Attack) - placed radially around ATK
			Rectangle {
				id: btnF
				width: 60; height: 60
				radius: 30
				property bool pressed: false
				color: pressed ? "black" : "white"
				border.color: pressed ? "white" : "black"
				border.width: 2
				// angle: 180 degrees (left)
				x: (btnAttack.x + btnAttack.width/2) + Math.cos(Math.PI) * actionButtons.buttonRadius - width/2
				y: (btnAttack.y + btnAttack.height/2) - Math.sin(Math.PI) * actionButtons.buttonRadius - height/2

				Canvas {
					anchors.centerIn: parent
					width: parent.width * 0.6
					height: parent.height * 0.6
					property bool buttonPressed: parent.pressed
					Component.onCompleted: requestPaint()
					onButtonPressedChanged: requestPaint()
					onPaint: {
						var ctx = getContext('2d'); ctx.clearRect(0,0,width,height);
						var fg = parent.pressed ? 'white' : 'black'; ctx.strokeStyle = fg; ctx.fillStyle = fg;
						var cx = width/2, cy = height/2; var r = Math.min(width,height)/2 - 2;
						// simple teleport icon: circle with an inward arrow
						ctx.lineWidth = Math.max(2, r*0.12);
						ctx.beginPath(); ctx.arc(cx, cy, r*0.6, 0, Math.PI*2); ctx.stroke();
						// arrow
						ctx.beginPath(); ctx.moveTo(cx + r*0.15, cy - r*0.05); ctx.lineTo(cx - r*0.05, cy - r*0.05); ctx.lineTo(cx - r*0.05, cy - r*0.25); ctx.stroke();
						ctx.beginPath(); ctx.moveTo(cx - r*0.05, cy - r*0.25); ctx.lineTo(cx - r*0.15, cy - r*0.15); ctx.stroke();
					}
				}

				MouseArea {
					anchors.fill: parent
					onPressed: {
						touchControls.ensurePlayerFocus()
						btnF.pressed = true
					}
					onReleased: { btnF.pressed = false }
					onClicked: {
						if (playerObj && typeof playerObj.toggleTeleportMode === 'function') {
							playerObj.toggleTeleportMode();
						}
						if (playerItem) playerItem.resetKeys();
					}
				}
			}

			// Q Button (Top-Left of Attack) - placed radially around ATK
			Rectangle {
				id: btnQ
				width: 60; height: 60
				radius: 30
				property bool pressed: false
				color: pressed ? "black" : "white"
				border.color: pressed ? "white" : "black"
				border.width: 2
				// angle: 135 degrees (top-left)
				x: (btnAttack.x + btnAttack.width/2) + Math.cos(3 * Math.PI / 4) * actionButtons.buttonRadius - width/2
				y: (btnAttack.y + btnAttack.height/2) - Math.sin(3 * Math.PI / 4) * actionButtons.buttonRadius - height/2

				Canvas {
					anchors.centerIn: parent
					width: parent.width * 0.7
					height: parent.height * 0.7
					property bool buttonPressed: parent.pressed
					Component.onCompleted: requestPaint()
					onButtonPressedChanged: requestPaint()
					onPaint: {
						var ctx = getContext('2d'); ctx.clearRect(0,0,width,height);
						var fg = parent.pressed ? 'white' : 'black'; ctx.strokeStyle = fg; ctx.lineWidth = Math.max(2, Math.min(width,height)*0.06);
						// draw a stylized wave
						ctx.beginPath();
						for (var i=0;i<=width;i++) {
							var x = i;
							var y = height/2 + Math.sin((i/width)*Math.PI*2) * (height*0.18);
							if (i===0) ctx.moveTo(x,y); else ctx.lineTo(x,y);
						}
						ctx.stroke();
					}
				}

				MouseArea {
					anchors.fill: parent
					onPressed: {
						touchControls.ensurePlayerFocus()
						btnQ.pressed = true
					}
					onReleased: { btnQ.pressed = false }
					onClicked: {
						if (!playerObj || !playerItem) return;
						var curCenterX = playerObj.pos.x + (playerItem.width/2);
						var curCenterY = playerObj.pos.y + (playerItem.height/2);
						if (typeof aimOverlay === 'undefined' || aimOverlay.aimX === undefined) return;
						var worldX = (aimOverlay.aimX - mapWrapper.x) / Math.max(0.0001, tileScale);
						var worldY = (aimOverlay.aimY - mapWrapper.y) / Math.max(0.0001, tileScale);
						var dx = worldX - curCenterX;
						var dy = worldY - curCenterY;
						var len = Math.sqrt(dx*dx + dy*dy);
						if (len === 0) { dx = 0; dy = -1; } else { dx /= len; dy /= len; }
						try {
							var fired = false;
							if (playerItem && typeof playerItem.tryWave === 'function') {
								fired = playerItem.tryWave(curCenterX, curCenterY, dx, dy);
							} else {
								if (playerItem && typeof playerItem.laserCd !== 'undefined' && typeof playerItem.laserCdMax !== 'undefined') {
									var cost = Math.round(playerItem.laserCdMax * 0.9);
									if (playerItem.laserCd >= cost) {
										playerItem.laserCd -= cost;
										fired = true;
									}
								}
								if (fired) {
									if (playerObj && typeof playerObj.createPlayerWave === 'function') {
										playerObj.createPlayerWave(curCenterX, curCenterY, dx, dy);
									}
								}
							}
						} catch(e) { console.log('Q button failed', e); }
					}
				}
			}

			// Space Button (Top of Attack) - placed radially around ATK
			Rectangle {
				id: btnSpace
				width: 60; height: 60
				radius: 30
				property bool pressed: false
				color: pressed ? "black" : "white"
				border.color: pressed ? "white" : "black"
				border.width: 2
				// angle: 90 degrees (top)
				x: (btnAttack.x + btnAttack.width/2) + Math.cos(Math.PI/2) * actionButtons.buttonRadius - width/2
				y: (btnAttack.y + btnAttack.height/2) - Math.sin(Math.PI/2) * actionButtons.buttonRadius - height/2

				Canvas {
					anchors.centerIn: parent
					width: parent.width * 0.7
					height: parent.height * 0.7
					property bool buttonPressed: parent.pressed
					Component.onCompleted: requestPaint()
					onButtonPressedChanged: requestPaint()
					onPaint: {
						var ctx = getContext('2d'); ctx.clearRect(0,0,width,height);
						var fg = parent.pressed ? 'white' : 'black'; ctx.strokeStyle = fg; ctx.fillStyle = fg;
						var cx = width/2, cy = height/2; var r = Math.min(width,height)/2 - 2;
						// reticle circle
						ctx.lineWidth = Math.max(2, r*0.12);
						ctx.beginPath(); ctx.arc(cx, cy, r*0.6, 0, Math.PI*2); ctx.stroke();
						// center dot
						ctx.beginPath(); ctx.arc(cx, cy, r*0.12, 0, Math.PI*2); ctx.fill();
						// crosshairs
						ctx.beginPath(); ctx.moveTo(cx - r*0.9, cy); ctx.lineTo(cx - r*0.28, cy); ctx.moveTo(cx + r*0.28, cy); ctx.lineTo(cx + r*0.9, cy);
						ctx.moveTo(cx, cy - r*0.9); ctx.lineTo(cx, cy - r*0.28); ctx.moveTo(cx, cy + r*0.28); ctx.lineTo(cx, cy + r*0.9);
						ctx.stroke();
					}
				}

				MouseArea {
					anchors.fill: parent
					onPressed: {
						touchControls.ensurePlayerFocus()
						engageSnipeHold()
					}
					onReleased: releaseSnipeHold()
				}
			}
		}

		function setButtonPressFromKey(key, isDown) {
			try {
					if (isDown) {
						if (!touchControls.keyHoldState) touchControls.keyHoldState = ({});
						if (touchControls.keyHoldState[key]) {
							return;
						}
						touchControls.keyHoldState[key] = true;
					} else if (touchControls.keyHoldState && touchControls.keyHoldState[key]) {
						delete touchControls.keyHoldState[key];
					}
					if (key === Qt.Key_Q || key === Qt.Key_K || key === Qt.Key_2) {
							btnQ.pressed = isDown;
							if (isDown) {
								// on press, trigger Q action (single fire) to match keyboard behaviour
								try {
									if (!playerObj || !playerItem) return;
									var curCenterX = playerObj.pos.x + (playerItem.width/2);
									var curCenterY = playerObj.pos.y + (playerItem.height/2);
									if (typeof aimOverlay === 'undefined' || aimOverlay.aimX === undefined) return;
									var worldX = (aimOverlay.aimX - mapWrapper.x) / Math.max(0.0001, tileScale);
									var worldY = (aimOverlay.aimY - mapWrapper.y) / Math.max(0.0001, tileScale);
									var dx = worldX - curCenterX; var dy = worldY - curCenterY; var len = Math.sqrt(dx*dx + dy*dy);
									if (len === 0) { dx = 0; dy = -1; } else { dx /= len; dy /= len; }
									var fired = false;
									if (playerItem && typeof playerItem.tryWave === 'function') fired = playerItem.tryWave(curCenterX, curCenterY, dx, dy);
									else {
										if (playerItem && typeof playerItem.laserCd !== 'undefined' && typeof playerItem.laserCdMax !== 'undefined') {
											var cost = Math.round(playerItem.laserCdMax * 0.9);
											if (playerItem.laserCd >= cost) { playerItem.laserCd = Math.max(0, playerItem.laserCd - cost); fired = true; }
										} else {
											try { if (typeof playerObj.wave === 'function') { playerObj.wave(curCenterX, curCenterY, dx, dy); fired = true; } } catch(e) { console.log('playerObj.wave failed', e); }
										}
										if (fired) try { if (playerObj && typeof playerObj.createPlayerWave === 'function') playerObj.createPlayerWave(curCenterX, curCenterY, dx, dy); } catch(e) {}
									}
								} catch(e) { console.log('setButtonPressFromKey Q/K/2 handler failed', e); }
							}
						} else if (key === Qt.Key_F || key === Qt.Key_L || key === Qt.Key_3) {
							btnF.pressed = isDown;
							if (isDown) try { if (playerObj && typeof playerObj.toggleTeleportMode === 'function') playerObj.toggleTeleportMode(); } catch(e) {}
						} else if (key === Qt.Key_Space || key === Qt.Key_0) {
							// Space / 0 behave same
							if (isDown) engageSnipeHold();
							else releaseSnipeHold();
						} else if (key === Qt.Key_J || key === Qt.Key_1) {
							// Attack
							try { if (typeof btnAttack !== 'undefined') btnAttack.pressed = isDown; } catch(e) {}
							if (isDown) {
								// mimic mouse press behaviour
								try {
									if (!playerObj || !playerItem) return;
									if (playerObj.snipeActive || gameViewRoot.snipeHeld) {
										var sx = mapWrapper.x + (playerObj.pos.x + (playerItem.width/2)) * tileScale;
										var sy = mapWrapper.y + (playerObj.pos.y + (playerItem.height/2)) * tileScale;
										var ax = aimOverlay ? aimOverlay.aimX : sx;
										var ay = aimOverlay ? aimOverlay.aimY : sy - sightMask.radius;
										var dxs = ax - sx; var dys = ay - sy; var dists = Math.sqrt(dxs*dxs + dys*dys);
										var tx = ax; var ty = ay;
										if (dists > sightMask.radius && dists > 0) { var nx = dxs / dists; tx = sx + nx * sightMask.radius; ty = sy + (dys / dists) * sightMask.radius; }
										var targetWorldX = (tx - mapWrapper.x) / tileScale;
										var targetWorldY = (ty - mapWrapper.y) / tileScale;
										var px = playerObj.pos.x + (playerItem.width/2);
										var py = playerObj.pos.y + (playerItem.height/2);
										try { if (typeof playerItem.trySnipe === 'function') playerItem.trySnipe(px, py, targetWorldX-px, targetWorldY-py); } catch(e) { console.log('trySnipe via key failed', e); }
									} else {
										try { if (typeof playerItem.stopBulletRecharge === 'function') playerItem.stopBulletRecharge(); } catch(e) {}
										if (!fireTimer.running) fireTimer.start();
									}
								} catch(e) { console.log('J/1 press via setButtonPressFromKey failed', e); }
							} else {
								try { if (fireTimer && fireTimer.running) fireTimer.stop(); } catch(e) {}
								try { if (playerItem && typeof playerItem.startBulletRecharge === 'function') playerItem.startBulletRecharge(); } catch(e) {}
							}
						}
			} catch(e) {}
		}

		Connections {
			target: playerItem
			onKeyDown: function(key) { setButtonPressFromKey(key, true); }
			onKeyUp: function(key) { setButtonPressFromKey(key, false); }
		}
	}
}

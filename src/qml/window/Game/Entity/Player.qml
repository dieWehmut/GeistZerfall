import QtQuick

Item {
	id: playerRoot
	width: 96; height: 96
	property var playerObj: null

	onPlayerObjChanged: {
		console.log("Player.qml: playerObj changed ->", playerObj ? ("hp="+playerObj.hp+", maxHp="+playerObj.maxHp) : "null");
		try {
			if (playerObj && typeof playerObj.hpChanged !== 'undefined') {
				playerObj.hpChanged.connect(function(){ console.log('Player.qml: hpChanged ->', playerObj.hp); });
			}
		} catch(e) { }
	}
	focus: true
	activeFocusOnTab: true
	Component.onCompleted: playerRoot.forceActiveFocus()
	// 清理按键状态当失去焦点或窗口不再活跃时，防止按键长按状态遗留
	onActiveFocusChanged: {
		if (!playerRoot.activeFocus) {
			wDown = false; aDown = false; sDown = false; dDown = false;
			lastDx = 0; lastDy = 0;
			computeAndMove();
		}
	}

	// 另外监听顶层窗口的激活变化（例如鼠标移出或切换窗口）
	// 直接绑定 activeWindow 并监听其 active 属性变化
	property var topWindow: Qt.application && Qt.application.activeWindow ? Qt.application.activeWindow : null
	property bool windowActive: Qt.application && Qt.application.activeWindow ? Qt.application.activeWindow.active : true
	onWindowActiveChanged: {
		if (!windowActive) {
			wDown = false; aDown = false; sDown = false; dDown = false;
			lastDx = 0; lastDy = 0;
			computeAndMove();
		}
	}
	property bool wDown: false
	property bool aDown: false
	property bool sDown: false
	property bool dDown: false
	property int lastDx: 0
	property int lastDy: 0
	property bool moving: false



	function computeAndMove() {
		if (!playerObj) return;
		var dx = 0; var dy = 0;
		if (wDown) dy -= 1;
		if (sDown) dy += 1;
		if (aDown) dx -= 1;
		if (dDown) dx += 1;
	if (dx === lastDx && dy === lastDy) return;
	lastDx = dx; lastDy = dy;
	playerObj.move(dx, dy);
		moving = (dx !== 0 || dy !== 0); // Update moving state
	}

	// 可被外部调用以重置所有按键状态（例如鼠标移出窗口时）
	function resetKeys() {
		wDown = false; aDown = false; sDown = false; dDown = false;
		lastDx = 0; lastDy = 0;
		computeAndMove();
		// ensure moving state cleared when keys reset
		if (moving) moving = false;
	}

	Keys.onPressed: function(event) {
		if (!playerObj) return;
		if (event.key === Qt.Key_W||event.key === Qt.Key_Up) wDown = true;
		if (event.key === Qt.Key_S||event.key === Qt.Key_Down) sDown = true;
		if (event.key === Qt.Key_A||event.key === Qt.Key_Left) aDown = true;
		if (event.key === Qt.Key_D||event.key === Qt.Key_Right) dDown = true;
		computeAndMove();
	}

	Keys.onReleased: function(event) {
		if (!playerObj) return;
		if (event.key === Qt.Key_W||event.key === Qt.Key_Up) wDown = false;
		if (event.key === Qt.Key_S||event.key === Qt.Key_Down) sDown = false;
		if (event.key === Qt.Key_A||event.key === Qt.Key_Left) aDown = false;
		if (event.key === Qt.Key_D||event.key === Qt.Key_Right) dDown = false;
		computeAndMove();
	}
	Image {
		id: playerImg
		anchors.fill: parent
		source: "qrc:/resource/image/entity/playerNormal.png"
	}

	// HUD bars displayed above player
	Item {
		id: hudRoot
		width: playerRoot.width
		height: 28
		x: 0
		y: -hudRoot.height - 6
		anchors.horizontalCenter: parent.horizontalCenter

		// 背景条（用于对齐）
		Rectangle {
			anchors.fill: parent
			color: "transparent"
		}

		// HP bar (top, deep red)
		Rectangle {
			id: hpBarBg
			x: 4; y: 0
			width: parent.width - 8
			height: 8
			radius: 3
			color: "#3a0b0b"
			border.color: "#000000"
			Rectangle {
				id: hpBar
				anchors.left: parent.left
				anchors.leftMargin: 0
				y: 0
				height: parent.height
				width: (function(){
					return playerObj ? (hpBarBg.width * Math.max(0, playerObj.hp) / Math.max(1, playerObj.maxHp)) : 0;
				})()
				color: "#ff3333"
				radius: 3
			}
		}

		// Bullet CD bar (middle, deep yellow)
		Rectangle {
			id: bulletCdBg
			x: 4; y: 10
			width: parent.width - 8
			height: 6
			radius: 3
			color: "#2b2400"
			Rectangle {
				id: bulletCdBar
				anchors.left: parent.left
				anchors.leftMargin: 0
				y: 0
				height: parent.height
				width: Math.max(0, (bulletCd / bulletCdMax) * bulletCdBg.width)
				color: "#c89b00"
				radius: 3
			}
		}

		// Laser CD bar (bottom, deep blue)
		Rectangle {
			id: laserCdBg
			x: 4; y: 18
			width: parent.width - 8
			height: 6
			radius: 3
			color: "#071028"
			Rectangle {
				id: laserCdBar
				anchors.left: parent.left
				anchors.leftMargin: 0
				y: 0
				height: parent.height
				width: Math.max(0, (laserCd / laserCdMax) * laserCdBg.width)
				color: "#174a8a"
				radius: 3
			}
		}


		Connections {
			id: playerConnections
			target: playerObj
			onHpChanged: {
				console.log("Player.qml: onHpChanged ->", playerObj ? playerObj.hp : "null");
				hpDebugText.text = playerObj ? (playerObj.hp + "/" + playerObj.maxHp) : "hp: ?";
			}
			onMaxHpChanged: {
				console.log("Player.qml: onMaxHpChanged ->", playerObj ? playerObj.maxHp : "null");
				hpDebugText.text = playerObj ? (playerObj.hp + "/" + playerObj.maxHp) : "hp: ?";
			}
		}
	}

	// CD properties and timers (client-side visual & guard)
	property int bulletCd: 3000
	property int bulletCdMax: 3000
	property int laserCd: 2000
	property int laserCdMax: 2000
	property int bulletRechargeStep: 10 // amount to add per tick
	property int laserRechargeStep: 100
	property bool bulletRecharging: false
	property bool laserRecharging: false

	Timer {
		id: bulletCdTimer
		interval: 80
		repeat: true
		running: false
		onTriggered: {
			if (bulletCd < bulletCdMax) {
				bulletCd = Math.min(bulletCdMax, bulletCd + bulletRechargeStep);
				if (bulletCd >= bulletCdMax) {
					bulletCd = bulletCdMax;
					bulletCdTimer.stop(); bulletRecharging = false;
				}
			} else {
				bulletCdTimer.stop(); bulletRecharging = false;
			}
		}
	}

	Timer {
		id: laserCdTimer
		interval: 120
		repeat: true
		running: false
		onTriggered: {
			if (laserCd < laserCdMax) {
				laserCd = Math.min(laserCdMax, laserCd + laserRechargeStep);
				if (laserCd >= laserCdMax) {
					laserCd = laserCdMax;
					laserCdTimer.stop(); laserRecharging = false;
					// snipe ended, notify backend to restore speed
					try { if (typeof playerObj.snipeStop === 'function') playerObj.snipeStop(); } catch(e) {}
				}
			} else {
				laserCdTimer.stop(); laserRecharging = false;
				try { if (typeof playerObj.snipeStop === 'function') playerObj.snipeStop(); } catch(e) {}
			}
		}
	}

	// Attempt to shoot a bullet; returns true if fired. Only fires when bulletCd is full.
	function tryShoot(px, py, dirx, diry) {
		// New behaviour: bulletCd is a continuous firing resource.
		// You can fire as long as bulletCd > 0. Each shot consumes a small amount.
		if (!playerObj) return false;
		if (bulletCd <= 0) {
			return false;
		}
		// consume a per-shot cost (tunable). While firing, stop recharge timer.
		var shotCost = 10; // how much bulletCd is consumed per shot
		bulletCd = Math.max(0, bulletCd - shotCost);
		bulletRecharging = false; bulletCdTimer.stop();
		// notify backend that shooting started (reduce speed)
		try { if (typeof playerObj.shootStart === 'function') playerObj.shootStart(); } catch(e) {}
		// call backend shoot method
		try {
			if (typeof playerObj.shoot === 'function') {
				playerObj.shoot(px, py, dirx, diry);
			} else {
				// try emitting via context if different API
				playerObj.shoot(px, py, dirx, diry);
			}
		} catch (e) { console.log('tryShoot backend call failed', e); }
		return true;
	}

	// Called by view when firing stops so we begin recharging bullets
	function startBulletRecharge() {
		if (bulletCd >= bulletCdMax) { bulletCd = bulletCdMax; bulletRecharging = false; bulletCdTimer.stop(); return; }
		bulletRecharging = true;
		// stop shooting state when recharge starts
		try { if (typeof playerObj.shootStop === 'function') playerObj.shootStop(); } catch(e) {}
		if (!bulletCdTimer.running) bulletCdTimer.start();
	}

	// Called by view when firing begins/stops to force stop of recharge
	function stopBulletRecharge() {
		bulletRecharging = false;
		if (bulletCdTimer.running) bulletCdTimer.stop();
	}

	// Attempt to fire snipe/laser; returns true if fired. Only fires when laserCd is full.
	function trySnipe(px, py, dirx, diry) {
		if (!playerObj) return false;
		if (laserCd < laserCdMax) return false;
		laserCd = 0; laserRecharging = true; laserCdTimer.start();
		// notify backend snipe start (halves speed already in C++)
		try { if (typeof playerObj.snipeStart === 'function') playerObj.snipeStart(); } catch(e) {}
		try {
			if (typeof playerObj.snipe === 'function') {
				playerObj.snipe(px, py, dirx, diry);
			} else {
				playerObj.snipe(px, py, dirx, diry);
			}
		} catch (e) { console.log('trySnipe backend call failed', e); }
		return true;
	}
}

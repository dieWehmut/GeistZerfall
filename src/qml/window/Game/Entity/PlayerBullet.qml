import QtQuick 2.15
import QtMultimedia 6.5

Item {
	id: bulletRoot
	property int baseSize: 64
	property var backend: null
	property var playerObjRef: null
	property var playerItemRef: null
	property var enemiesRef: null
	property var mapWrapperRef: null
	property real tileScaleRef: 1.0
	property string expectedVisual: "bullet"
	property real thickness: 24
	property int damage: backend && backend.damage !== undefined ? backend.damage : 20
	property real collisionRadius: baseSize * 0.35
	property real knockbackDistance: 50

	width: baseSize * tileScaleRef
	height: baseSize * tileScaleRef
	transformOrigin: Item.Center
	property real pulsateScale: 1.0
	// make bullet pulse faster
	property int pulsateDuration: 600
	scale: pulsateScale

	function updateScreenPos() {
		if (!backend || !backend.pos) return;
		bulletRoot.x = backend.pos.x * tileScaleRef - bulletRoot.width / 2;
		bulletRoot.y = backend.pos.y * tileScaleRef - bulletRoot.height / 2;
	}

	onTileScaleRefChanged: updateScreenPos()

	Image {
		id: img
		anchors.centerIn: parent
		source: "qrc:/resource/image/entity/playerBullet.png"
		width: parent.width
		height: parent.height
	}

	// blue square border slightly larger than the bullet, rotates together with the root
	Rectangle {
		id: blueBorder
		anchors.centerIn: parent
		width: parent.width * 1.14
		height: parent.height * 1.14
		color: "transparent"
		border.color: "#3399FF"
		border.width: Math.max(2, 4 * tileScaleRef)
		radius: 0
		z: img.z + 1
	}

	// safe global SFX volume helper — avoids NaN when global properties are absent
	property real _globalSfxVolume: (typeof window !== 'undefined' && typeof window.masterVolume === 'number' ? window.masterVolume : 1.0) * (typeof window !== 'undefined' && typeof window.sfxVolume === 'number' ? window.sfxVolume : 1.0)

	SoundEffect {
		id: bulletSfx
		source: "qrc:/resource/audio/SoundEffect/playerBullet.wav"
		// 本地基础音量 * 全局主音量 * 全局 SFX 音量（使用安全 helper）
		volume: 0.8 * _globalSfxVolume
		// 当任一全局音量为 0 时静音；若属性不存在则不强制静音
		muted: (typeof window !== 'undefined' && typeof window.masterVolume === 'number' && typeof window.sfxVolume === 'number') ? (window.masterVolume === 0 || window.sfxVolume === 0) : false
	}

	function handleBackendAssigned() {
		updateScreenPos();
		console.log('PlayerBullet: handleBackendAssigned backend:', backend, 'playerObjRef:', playerObjRef, 'playerItemRef:', playerItemRef);
		try { backend.posChanged.connect(updateScreenPos); } catch(e){}
		try {
			backend.destroyed.connect(function() {
				try { bulletRoot.destroy(); } catch(err){}
			});
		} catch(e){}
		try {
			if (typeof backend.backendDestroyed === 'function' || backend.hasOwnProperty('backendDestroyed')) {
				backend.backendDestroyed.connect(function() {
					try { bulletRoot.destroy(); } catch(err){}
				});
			}
		} catch(e){}
		try {
			var isLaser = false;
			try { isLaser = (backend.visualType === 'laser' || expectedVisual === 'laser'); } catch(err) { isLaser = false; }
			// 只有在未被静音时才播放声效（SoundEffect.muted 可能随设置变化）
			if (!isLaser && !bulletSfx.muted) bulletSfx.play();
		} catch(e){}
		if (!collisionTimer.running) collisionTimer.start();
	}

	onBackendChanged: {
		if (!backend) {
			collisionTimer.stop();
			return;
		}
		handleBackendAssigned();
	}

	Timer {
		id: collisionTimer
		interval: 16
		repeat: true
		running: false
		onTriggered: checkCollision()
	}

	function checkCollision() {
		if (!backend || !backend.pos) return;
		var bpos = backend.pos;
		var bx = bpos.x;
		var by = bpos.y;
		var bulletRadius = collisionRadius;
		if (enemiesRef && enemiesRef.length > 0) {
			for (var i = 0; i < enemiesRef.length; ++i) {
				var enemy = enemiesRef[i];
				if (!enemy || enemy.alive === false || !enemy.pos) continue;
				var enemyPos = enemy.pos;
				var ex = enemyPos.x;
				var ey = enemyPos.y;
				var enemyRadius = enemy.collisionRadius !== undefined ? enemy.collisionRadius : 28;
				var dx = ex - bx;
				var dy = ey - by;
				var combined = enemyRadius + bulletRadius;
				if ((dx * dx + dy * dy) <= (combined * combined)) {
					// 要求：按敌人当前移动方向的相反方向击退
					// 这里仅传入击退距离，让 C++ 侧用 -dirX/-dirY 自动计算
					try { if (typeof enemy.receiveDamage === 'function') enemy.receiveDamage(damage, 0, 0, knockbackDistance); } catch(e){}
					// heal player on hit: +500 HP, cap at maxHp
					try {
						if (playerObjRef) {
							// compute current and max (try property read first)
							var cur = (typeof playerObjRef.hp === 'number') ? playerObjRef.hp : (playerObjRef.getHp ? playerObjRef.getHp() : 0);
							var maxv = (typeof playerObjRef.maxHp === 'number') ? playerObjRef.maxHp : (playerObjRef.getMaxHp ? playerObjRef.getMaxHp() : cur + 500);
							var newHp = Math.min(maxv, cur + 500);
							// attempt direct assignment first (calls Q_PROPERTY setter when available)
							try { playerObjRef.hp = newHp; console.log('PlayerBullet: healed backend player to', newHp); }
							catch(e) {
								// fallback to calling setter if exposed
								try { if (typeof playerObjRef.setHp === 'function') { playerObjRef.setHp(newHp); console.log('PlayerBullet: called setHp, healed to', newHp); } }
								catch(e) { /* ignore */ }
							}
						} else if (playerItemRef && playerItemRef.playerObj) {
							// as last resort update the front-end player's playerObj if present
							try { var pcur = typeof playerItemRef.playerObj.hp === 'number' ? playerItemRef.playerObj.hp : 0; var pmax = typeof playerItemRef.playerObj.maxHp === 'number' ? playerItemRef.playerObj.maxHp : pcur + 500; playerItemRef.playerObj.hp = Math.min(pmax, pcur + 500); console.log('PlayerBullet: healed front-end playerObj to', playerItemRef.playerObj.hp); } catch(e) {}
						}
					} catch(e) { console.log('PlayerBullet: heal failed', e); }
					try { if (typeof backend.deleteLater === 'function') backend.deleteLater(); } catch(e){}
					collisionTimer.stop();
					return;
				}
			}
		}
		handleEnemyProjectileCollisions(bx, by, bulletRadius);
	}

	function handleEnemyProjectileCollisions(bx, by, bulletRadius) {
		if (!mapWrapperRef || !mapWrapperRef.enemyProjectileVisuals || mapWrapperRef.enemyProjectileVisuals.length === 0) return;
		var list = mapWrapperRef.enemyProjectileVisuals;
		for (var j = list.length - 1; j >= 0; --j) {
			var enemyProj = list[j];
			if (!enemyProj) continue;
			var backendObj = enemyProj.backend;
			if (!backendObj || !backendObj.pos) continue;
			var ex = backendObj.pos.x;
			var ey = backendObj.pos.y;
			var enemyRadius = enemyProj.collisionRadius !== undefined ? enemyProj.collisionRadius : (enemyProj.baseSize ? enemyProj.baseSize * 0.35 : 24);
			var dxp = ex - bx;
			var dyp = ey - by;
			var combinedRadius = enemyRadius + bulletRadius;
			if ((dxp * dxp + dyp * dyp) <= (combinedRadius * combinedRadius)) {
				neutralizeEnemyProjectile(enemyProj);
				try { if (typeof backend.deleteLater === 'function') backend.deleteLater(); } catch(e){}
				collisionTimer.stop();
				return;
			}
		}
	}

	function neutralizeEnemyProjectile(enemyProj) {
		if (!enemyProj) return;
		try {
			if (enemyProj.backend && typeof enemyProj.backend.deleteLater === 'function') {
				enemyProj.backend.deleteLater();
			}
		} catch(e) {}
		try {
			if (typeof enemyProj.destroy === 'function') enemyProj.destroy();
		} catch(e) {}
	}

	Component.onDestruction: collisionTimer.stop()

	NumberAnimation {
		target: bulletRoot
		property: "rotation"
		from: 0
		to: 360
		duration: 180
		loops: Animation.Infinite
		running: true
	}

	Component.onCompleted: {
		// assign a pseudo-unique duration different from enemy pulsate (1600)
		try {
			// faster, shorter random period
			var d = 100 + Math.floor(Math.random() * 400);
			if (d === 1600) d += 137;
			pulsateDuration = d;
			if (pulseAnimBullets.running) pulseAnimBullets.stop();
			pulseAnimBullets.start();
		} catch(e) {}
	}

	SequentialAnimation {
		id: pulseAnimBullets
		loops: Animation.Infinite
		NumberAnimation { target: bulletRoot; property: "pulsateScale"; from: 1.0; to: 1.5; duration: pulsateDuration; easing.type: Easing.InOutSine }
		NumberAnimation { target: bulletRoot; property: "pulsateScale"; from: 1.5; to: 1.0; duration: pulsateDuration; easing.type: Easing.InOutSine }
	}
}
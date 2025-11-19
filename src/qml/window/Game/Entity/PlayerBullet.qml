import QtQuick 2.15
import QtMultimedia 6.5

Item {
	id: bulletRoot
	property int baseSize: 64
	property var backend: null
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

	SoundEffect {
		id: bulletSfx
		source: "qrc:/resource/audio/SoundEffect/playerBullet.wav"
		volume: 0.8
	}

	function handleBackendAssigned() {
		updateScreenPos();
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
			if (!isLaser) bulletSfx.play();
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
		duration: 360
		loops: Animation.Infinite
		running: true
	}
}
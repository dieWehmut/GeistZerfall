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
		if (!backend || !backend.pos || !enemiesRef || enemiesRef.length === 0) return;
		var bpos = backend.pos;
		var bx = bpos.x;
		var by = bpos.y;
		var bulletRadius = collisionRadius;
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

	Component.onDestruction: collisionTimer.stop()
}
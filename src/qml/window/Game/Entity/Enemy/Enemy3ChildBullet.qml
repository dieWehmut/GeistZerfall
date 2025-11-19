import QtQuick 2.15
import QtMultimedia 6.5

Item {
	id: root
	property int baseSize: 96
	width: baseSize * tileScaleRef
	height: baseSize * tileScaleRef
	transformOrigin: Item.Center
	property var backend: null
	property var playerItemRef: null
	property var playerObjRef: null
	property var mapWrapperRef: null
	property real tileScaleRef: 1.0
	property int damage: 300
	property real collisionRadius: baseSize * 0.35
	z: 130

	// 16 种子弹图，优先使用后端 spriteIndex；否则在前端随机一个
	property int localIndex: Math.floor(Math.random() * 16) + 1
	property int spriteIndex: (backend && backend.spriteIndex !== undefined)
							  ? Math.max(1, Math.min(16, backend.spriteIndex))
							  : localIndex

	Image {
		anchors.centerIn: parent
		source: "qrc:/resource/image/entity/enemy3ChildBullet" + spriteIndex + ".png"
		width: parent.width; height: parent.height
	}

	SoundEffect {
		id: hitSfx
		source: "qrc:/resource/audio/SoundEffect/playerHit.wav"
		volume: 0.8
	}

	function updateScreenPos() {
		if (!backend) return;
		root.x = backend.pos.x * tileScaleRef - root.width/2;
		root.y = backend.pos.y * tileScaleRef - root.height/2;
	}

	onBackendChanged: {
		if (!backend) return;
		try { backend.posChanged.connect(updateScreenPos); } catch(e){}
		try { backend.destroyed.connect(function(){ try { root.destroy(); } catch(e){} }); } catch(e){}
		try { if (backend.backendDestroyed) backend.backendDestroyed.connect(function(){ try { root.destroy(); } catch(e){} }); } catch(e){}
		updateScreenPos();
	}

	onTileScaleRefChanged: updateScreenPos()

	// 碰撞检测：AABB 与玩家矩形
	Timer {
		interval: 16; running: true; repeat: true
		onTriggered: {
			if (!backend || !playerItemRef || !playerObjRef) return;
			var bulletRect = root.mapRectToItem ? root.mapRectToItem(null, Qt.rect(0, 0, root.width, root.height))
									 : Qt.rect(root.x + (mapWrapperRef ? mapWrapperRef.x : 0),
										  root.y + (mapWrapperRef ? mapWrapperRef.y : 0),
										  root.width,
										  root.height);
			var playerRect = playerItemRef.mapRectToItem ? playerItemRef.mapRectToItem(null, Qt.rect(0, 0, playerItemRef.width, playerItemRef.height))
									   : Qt.rect(playerItemRef.x, playerItemRef.y, playerItemRef.width, playerItemRef.height);
			var intersects = bulletRect.x < playerRect.x + playerRect.width &&
							 bulletRect.x + bulletRect.width > playerRect.x &&
							 bulletRect.y < playerRect.y + playerRect.height &&
							 bulletRect.y + bulletRect.height > playerRect.y;
			if (intersects) {
				try {
					if (typeof playerObjRef.receiveDamage === 'function') playerObjRef.receiveDamage(damage);
					hitSfx.play();
				} catch(e){}
				try { backend.deleteLater(); } catch(e){}
			}
		}
	}

	NumberAnimation {
		target: root
		property: "rotation"
		from: 0
		to: 360
		duration: 420
		loops: Animation.Infinite
		running: true
	}

	Component.onCompleted: {
		if (mapWrapperRef && typeof mapWrapperRef.registerEnemyProjectile === 'function') {
			mapWrapperRef.registerEnemyProjectile(root);
		}
	}

	Component.onDestruction: {
		if (mapWrapperRef && typeof mapWrapperRef.unregisterEnemyProjectile === 'function') {
			mapWrapperRef.unregisterEnemyProjectile(root);
		}
	}
}


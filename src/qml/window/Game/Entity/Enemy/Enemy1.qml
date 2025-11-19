import QtQuick 2.15
import GeistZerfall.Game 1.0

Item {
	id: enemy1Root
	property int baseSize: 128
	width: baseSize * tileScaleRef
	height: baseSize * tileScaleRef
	property var backend: null      // BackendEnemy1 instance
	property var playerObjRef: null // BackendPlayer
	property var playerItemRef: null // front-end player item for collisions
	property var mapWrapperRef: null
	property real tileScaleRef: 1.0
	z: 120
	transformOrigin: Item.Center
	property real pulsateScale: 1.0
	property real impactScale: 1.0
	property int pulsateDuration: 1600
	scale: pulsateScale * impactScale

	Image {
		id: sprite
		anchors.centerIn: parent
		source: "qrc:/resource/image/entity/enemy1.png"
		width: parent.width; height: parent.height
	}

	// HP/MP bars
	Item {
		id: hudRoot
		width: enemy1Root.width
		height: 20
		anchors.horizontalCenter: parent.horizontalCenter
		y: -hudRoot.height - 6

		Rectangle { anchors.fill: parent; color: "transparent" }

		Rectangle {
			id: hpBarBg
			x: 4; y: 0
			width: parent.width - 8
			height: 8
			radius: 3
			color: "#3a0b0b"
			border.color: "#000000"
			Rectangle {
				anchors.left: parent.left
				width: backend ? (hpBarBg.width * Math.max(0, backend.hp) / Math.max(1, backend.maxHp)) : 0
				height: parent.height
				color: "#ff3333"
				radius: parent.radius
			}
		}

		Rectangle {
			id: mpBarBg
			x: 4; y: 10
			width: parent.width - 8
			height: 6
			radius: 3
			color: "#071028"
			Rectangle {
				anchors.left: parent.left
				width: backend ? (mpBarBg.width * Math.max(0, backend.mp) / Math.max(1, backend.maxMp)) : 0
				height: parent.height
				color: "#3399ff"
				radius: parent.radius
			}
		}
	}

	// Bind position to backend world coordinates -> screen coords
	function updateScreenPos() {
		if (!backend) return;
		enemy1Root.x = backend.pos.x * tileScaleRef - enemy1Root.width/2;
		enemy1Root.y = backend.pos.y * tileScaleRef - enemy1Root.height/2;
	}

	function syncForcedRevealRegistration() {
		if (!mapWrapperRef) return;
		if (backend && backend.forcedReveal) {
			if (typeof mapWrapperRef.registerRevealedEnemy === 'function') {
				mapWrapperRef.registerRevealedEnemy(enemy1Root);
			}
		} else if (typeof mapWrapperRef.unregisterRevealedEnemy === 'function') {
			mapWrapperRef.unregisterRevealedEnemy(enemy1Root);
		}
	}

	onTileScaleRefChanged: updateScreenPos()

	onBackendChanged: {
		if (!backend) return;
		try { backend.setProperty("collisionRadius", baseSize * 0.45); } catch(e){}
		try { backend.posChanged.connect(updateScreenPos); } catch(e){}
		// connect projectile/laser creation to spawn visuals
		try { backend.enemyProjectileCreated.connect(function(pr){
			var comp = Qt.createComponent("./Enemy1Bullet.qml");
			if (comp.status === Component.Ready) {
				var bullet = comp.createObject(mapWrapperRef, { backend: pr, playerItemRef: playerItemRef, playerObjRef: playerObjRef, tileScaleRef: tileScaleRef, mapWrapperRef: mapWrapperRef });
				if (bullet) bullet.tileScaleRef = Qt.binding(function(){ return tileScaleRef; });
			}
			});
		} catch(e){}
		try { backend.enemyLaserCreated.connect(function(ls){
			var comp = Qt.createComponent("./Enemy2Laser.qml");
			if (comp.status === Component.Ready) {
				var laser = comp.createObject(mapWrapperRef, { backend: ls, playerItemRef: playerItemRef, playerObjRef: playerObjRef, tileScaleRef: tileScaleRef, mapWrapperRef: mapWrapperRef });
				if (laser) laser.tileScaleRef = Qt.binding(function(){ return tileScaleRef; });
			}
			});
		} catch(e){}
		updateScreenPos();
		syncForcedRevealRegistration();
	}

	// When enemy dies, remove visual
	SequentialAnimation {
		id: pulsateAnim
		loops: Animation.Infinite
		running: false
		NumberAnimation { target: enemy1Root; property: "pulsateScale"; from: 1.0; to: 2.0; duration: pulsateDuration; easing.type: Easing.InOutSine }
		NumberAnimation { target: enemy1Root; property: "pulsateScale"; from: 2.0; to: 1.0; duration: pulsateDuration; easing.type: Easing.InOutSine }
	}

	Timer { id: pulsateStarter; interval: 0; repeat: false; onTriggered: pulsateAnim.start() }

	Component.onCompleted: {
		try {
			var d = 1200 + Math.floor(Math.random() * 1000); // 1200..2199ms
			pulsateDuration = d;
			var offset = Math.floor(Math.random() * pulsateDuration);
			pulsateStarter.interval = offset;
			pulsateStarter.start();
		} catch(e) {}
		syncForcedRevealRegistration();
	}

	Component.onDestruction: {
		if (mapWrapperRef && typeof mapWrapperRef.unregisterRevealedEnemy === 'function') {
			mapWrapperRef.unregisterRevealedEnemy(enemy1Root);
		}
	}
	Connections {
		target: backend
		onAliveChanged: { if (backend && !backend.alive) { try { enemy1Root.destroy(); } catch(e){} } }
		onForcedRevealChanged: syncForcedRevealRegistration()
	}
}

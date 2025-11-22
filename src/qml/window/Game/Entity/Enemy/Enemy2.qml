import QtQuick 2.15
import GeistZerfall.Game 1.0

Item {
	id: enemy2Root
	property int baseSize: 128
	width: baseSize * tileScaleRef
	height: baseSize * tileScaleRef
	property var backend: null
	property var playerObjRef: null
	property var playerItemRef: null
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
		source: "qrc:/resource/image/entity/enemy2.png"
		width: parent.width; height: parent.height
	}

	/* Vision circle (red) centered on the enemy. Width/height = sight * 2 */
	Rectangle {
		id: visionCircle
		anchors.centerIn: parent
		width: backend ? backend.sight * 2 * tileScaleRef : 0
		height: width
		color: "transparent"
		border.color: "#ff0000"
		border.width: 4
		opacity: 0.35
		radius: width/2
		z: 100
		visible: backend ? backend.sight > 0 : false
	}

	/* Line from enemy center to player when player is in sight. Implemented as a Canvas for continuous drawing. */
	Canvas {
		id: sightLine
		anchors.fill: parent
		z: 125
		visible: false

		property real dx: (function(){
			if (!playerItemRef) return 0;
			try {
				var pt = playerItemRef.mapToItem(enemy2Root, playerItemRef.width/2, playerItemRef.height/2);
				return pt.x - enemy2Root.width/2;
			} catch(e) { return 0; }
		})()
		property real dy: (function(){
			if (!playerItemRef) return 0;
			try {
				var pt = playerItemRef.mapToItem(enemy2Root, playerItemRef.width/2, playerItemRef.height/2);
				return pt.y - enemy2Root.height/2;
			} catch(e) { return 0; }
		})()
		property real dist: Math.sqrt(dx*dx + dy*dy)

		onPaint: {
			var ctx = getContext('2d');
			ctx.clearRect(0, 0, width, height);
			try {
				if (!backend || !playerItemRef || !mapWrapperRef) return;
				var sx = enemy2Root.width / 2;
				var sy = enemy2Root.height / 2;
				var tx = sx + dx;
				var ty = sy + dy;
				// glow layers for red line
				for (var g = 6; g >= 1; --g) {
					ctx.beginPath();
					ctx.strokeStyle = 'rgba(255,0,0,' + (0.10 * g).toFixed(3) + ')';
					ctx.lineWidth = 3 * g;
					ctx.lineCap = 'round';
					ctx.moveTo(sx, sy);
					ctx.lineTo(tx, ty);
					ctx.stroke();
				}
				// solid core
				ctx.beginPath();
				ctx.strokeStyle = 'rgba(255,0,0,1.0)';
				ctx.lineWidth = 8;
				ctx.lineCap = 'round';
				ctx.moveTo(sx, sy);
				ctx.lineTo(tx, ty);
				ctx.stroke();
			} catch(e) {}
		}

		Timer {
			id: linePainter
			interval: 50
			repeat: true
			running: false
			onTriggered: sightLine.requestPaint()
		}
	}

	// Periodic drain timer. Interval chosen small for smooth continuous drain.
	Timer {
		id: auraTimer
		interval: 200
		repeat: true
		running: false
		onTriggered: {
			if (!playerObjRef) return;
			var intervalSec = auraTimer.interval / 1000.0;
			var dps = 20;
			try {
				if (backend) {
					if (typeof backend.auraDPS === 'function') dps = backend.auraDPS();
					else if (backend.hasOwnProperty('auraDPS')) dps = backend.auraDPS;
				}
			} catch(e){}
			var damage = Math.max(1, Math.round(dps * intervalSec));
			try {
				if (typeof playerObjRef.receiveDamage === 'function') playerObjRef.receiveDamage(damage);
				else if (typeof playerObjRef.takeDamage === 'function') playerObjRef.takeDamage(damage);
				else if (typeof playerObjRef.setProperty === 'function') {
					// fallback: try decrementing hp property if exposed
					try { playerObjRef.setProperty('hp', Math.max(0, (playerObjRef.hp || 0) - damage)); } catch(e){}
				}
			} catch(e){}
		}
	}

	// update sightLine visibility based on computed distance
	Binding {
		target: sightLine
		property: "visible"
		value: (backend && playerItemRef) ? (sightLine.dist <= (backend.sight * tileScaleRef)) : false
	}

	// start/stop line painter together with sightLine visibility
	Binding {
		target: sightLine.linePainter
		property: "running"
		value: sightLine.visible
	}

	Connections {
		target: sightLine
		onVisibleChanged: if (sightLine.visible) sightLine.requestPaint()
	}

	// start/stop aura timer together with sightLine visibility
	// keep aura timer running while player is in sight
	Binding {
		target: auraTimer
		property: "running"
		value: sightLine.visible
	}


	Item {
		id: hudRoot
		width: enemy2Root.width
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
				color: "#174a8a"
				radius: parent.radius
			}
		}
	}

	function updateScreenPos() {
		if (!backend) return;
		enemy2Root.x = backend.pos.x * tileScaleRef - enemy2Root.width/2;
		enemy2Root.y = backend.pos.y * tileScaleRef - enemy2Root.height/2;
	}

	function syncForcedRevealRegistration() {
		if (!mapWrapperRef) return;
		if (backend && backend.forcedReveal) {
			if (typeof mapWrapperRef.registerRevealedEnemy === 'function') {
				mapWrapperRef.registerRevealedEnemy(enemy2Root);
			}
		} else if (typeof mapWrapperRef.unregisterRevealedEnemy === 'function') {
			mapWrapperRef.unregisterRevealedEnemy(enemy2Root);
		}
	}
	onTileScaleRefChanged: updateScreenPos()

	onBackendChanged: {
		if (!backend) return;
		try { backend.setProperty("collisionRadius", baseSize * 0.45); } catch(e){}
		try { backend.posChanged.connect(updateScreenPos); } catch(e){}
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

	Connections {
		target: backend
		onAliveChanged: { if (backend && !backend.alive) { try { enemy2Root.destroy(); } catch(e){} } }
		onForcedRevealChanged: syncForcedRevealRegistration()
	}

	SequentialAnimation {
		id: pulsateAnim
		loops: Animation.Infinite
		running: false
		NumberAnimation { target: enemy2Root; property: "pulsateScale"; from: 1.0; to: 2.0; duration: pulsateDuration; easing.type: Easing.InOutSine }
		NumberAnimation { target: enemy2Root; property: "pulsateScale"; from: 2.0; to: 1.0; duration: pulsateDuration; easing.type: Easing.InOutSine }
	}

	Timer { id: pulsateStarter; interval: 0; repeat: false; onTriggered: pulsateAnim.start() }

	Component.onCompleted: {
		try {
			var d = 1200 + Math.floor(Math.random() * 1000);
			pulsateDuration = d;
			var offset = Math.floor(Math.random() * pulsateDuration);
			pulsateStarter.interval = offset;
			pulsateStarter.start();
		} catch(e) {}
		syncForcedRevealRegistration();
	}

	Component.onDestruction: {
		if (mapWrapperRef && typeof mapWrapperRef.unregisterRevealedEnemy === 'function') {
			mapWrapperRef.unregisterRevealedEnemy(enemy2Root);
		}
	}
}

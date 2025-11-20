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
		try { if (warnOverlay && typeof warnOverlay.requestPaint === 'function') warnOverlay.requestPaint(); } catch(e) {}
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
		// Ensure the persistent warning overlay exists for this enemy
		try { if (!warnOverlay) createWarnOverlay(); } catch(e) {}
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
		// create persistent warn overlay if backend already assigned
		try { if (!warnOverlay && backend) createWarnOverlay(); } catch(e) {}
	}

	Component.onDestruction: {
		if (mapWrapperRef && typeof mapWrapperRef.unregisterRevealedEnemy === 'function') {
			mapWrapperRef.unregisterRevealedEnemy(enemy1Root);
		}
		// destroy persistent warn overlay when this visual is torn down
		try { if (warnOverlay) { warnOverlay.destroy(); warnOverlay = null; } } catch(e) {}
	}
	// Teleport warning visual (rendered on the mapWrapper so it's not clipped)
	property var warnOverlay: null
	function createWarnOverlay() {
		try {
			if (!mapWrapperRef) return null;
			// remove any existing overlay
			if (warnOverlay) { try { warnOverlay.destroy(); } catch(e) {} warnOverlay = null; }
			var qml = "import QtQuick 2.15\nCanvas { anchors.fill: parent; z: 3000; property var backendProp: null; property var playerItemProp: null; property var mapWrapperProp: null; property real tileScaleProp: 1.0; visible: true; onPaint: { var ctx = getContext('2d'); ctx.clearRect(0,0,width,height); try { if (!backendProp || !playerItemProp || !mapWrapperProp) { console.log('warnOverlay: missing props'); return; } var sx = mapWrapperProp.x + backendProp.pos.x * tileScaleProp; var sy = mapWrapperProp.y + backendProp.pos.y * tileScaleProp; var tx = playerItemProp.x + (playerItemProp.width * 0.5); var ty = playerItemProp.y + (playerItemProp.height * 0.5); console.log('warnOverlay: drawing from', sx, sy, 'to', tx, ty); // debug endpoints: draw small solid circles at endpoints
				ctx.beginPath(); ctx.fillStyle = 'rgba(255,0,0,0.9)'; ctx.arc(sx, sy, 8, 0, Math.PI*2); ctx.fill(); ctx.beginPath(); ctx.fillStyle = 'rgba(0,255,0,0.9)'; ctx.arc(tx, ty, 8, 0, Math.PI*2); ctx.fill();
				// debug banner
				ctx.beginPath(); ctx.fillStyle = 'rgba(255,0,0,0.2)'; ctx.fillRect(10,10,110,28); ctx.fillStyle = '#ffffff'; ctx.font = '18px sans-serif'; ctx.fillText('ENEMY1 WARN', 16, 30);
				// glow layers
				for (var g = 6; g >= 1; --g) { ctx.beginPath(); ctx.strokeStyle = 'rgba(255,200,50,' + (0.10 * g).toFixed(3) + ')'; ctx.lineWidth = 3 * g; ctx.lineCap = 'round'; ctx.moveTo(sx, sy); ctx.lineTo(tx, ty); ctx.stroke(); }
				// solid core
				ctx.beginPath(); ctx.strokeStyle = 'rgba(255,255,0,1.0)'; ctx.lineWidth = 8; ctx.lineCap = 'round'; ctx.moveTo(sx, sy); ctx.lineTo(tx, ty); ctx.stroke(); } catch(e){ console.log('warnOverlay paint error:', e); } } 
				Timer { id: __painter; interval: 50; repeat: true; running: true; onTriggered: requestPaint(); }
			}";
			var obj = Qt.createQmlObject(qml, mapWrapperRef.parent, "enemyWarnOverlay");
			if (!obj) { console.log('createWarnOverlay: failed to create object'); return null; }
			console.log('createWarnOverlay: created overlay');
			obj.backendProp = backend;
			obj.playerItemProp = playerItemRef;
			obj.mapWrapperProp = mapWrapperRef;
			obj.tileScaleProp = tileScaleRef;
			obj.visible = true;
			obj.opacity = 1.0;
			obj.z = 9999;
			try { obj.requestPaint(); } catch(e) { console.log('requestPaint error:', e); }
			warnOverlay = obj;
			return warnOverlay;
		} catch(e) { console.log('createWarnOverlay failed', e); return null; }
	}
	Connections {
		target: backend
		onAliveChanged: { 
			if (backend && !backend.alive) {
				// remove warn overlay first
				try { if (warnOverlay) { warnOverlay.destroy(); warnOverlay = null; } } catch(e) {}
				try { enemy1Root.destroy(); } catch(e){}
			}
		}
		onForcedRevealChanged: syncForcedRevealRegistration()
	}

	// connect teleport warning signals
	Connections {
		target: backend
		enabled: !!backend
		function onAboutToTeleport(pt) {
			try {
				if (warnOverlay) warnOverlay.requestPaint();
			} catch(e) {}
		}
		function onTeleported(p) {
			try {
				if (warnOverlay) warnOverlay.requestPaint();
				// update screen pos immediately
				updateScreenPos();
			} catch(e) {}
		}
	}
}

import QtQuick 2.15
import QtMultimedia 6.5

Item {
	id: root
	// fill parent (mapWrapper) so Canvas has proper width/height to draw across the map
	anchors.fill: parent
	x: 0; y: 0
	// Laser visual and logic can be implemented here. For now include sound effect.
	SoundEffect {
		id: laserSfx
		source: "qrc:/resource/audio/SoundEffect/playerLaser.wav"
		volume: 0.9 * (typeof window !== 'undefined' ? window.masterVolume * window.sfxVolume : 1.0)
		// 与效果音绑定：任一为 0 时静音
		muted: (typeof window !== 'undefined') ? (window.masterVolume === 0 || window.sfxVolume === 0) : false
	}

	property var backend: null
	// optional refs passed from GameView so the visual can draw in screen coords
	property var mapWrapperRef: null
	property real tileScaleRef: 1.0
	// visual thickness in pixels (can be passed from creator, e.g. 24 * tileScale)
	property real thickness: 15
	property var enemiesRef: null
	property int damage: backend && backend.damage !== undefined ? backend.damage : 800
	// How far the laser should knock enemies back (in world units)
	property real knockbackDistance: 300
	// Track per-enemy knockback timestamps and whether they were damaged already
	// Elements: { enemy: <backendEnemy>, last: <ms-since-epoch>, damaged: <bool> }
	property var knockMap: []
	// animated end point (used to gradually extend the beam)
	property real endX: 0
	property real endY: 0
	// opacity for the beam (keep fully visible by default)
	property real beamOpacity: 1.0
	// debug helper (disabled by default)
	property bool debugLaser: false
	// spreadIndex: -2 .. 0 .. 2 (outer beams have higher abs index)
	property int spreadIndex: 0

	function distanceSqToSegment(px, py, sx, sy, ex, ey) {
		var dx = ex - sx;
		var dy = ey - sy;
		if (dx === 0 && dy === 0) {
			var ddx = px - sx;
			var ddy = py - sy;
			return ddx * ddx + ddy * ddy;
		}
		var invLenSq = dx * dx + dy * dy;
		var t = ((px - sx) * dx + (py - sy) * dy) / invLenSq;
		if (t < 0) t = 0;
		else if (t > 1) t = 1;
		var projX = sx + t * dx;
		var projY = sy + t * dy;
		var diffX = px - projX;
		var diffY = py - projY;
		return diffX * diffX + diffY * diffY;
	}

	// Top-level visual canvas - placed above map children to avoid being occluded
	Canvas {
		id: beamCanvas
		anchors.fill: parent
		z: 5000
		opacity: beamOpacity

		onPaint: {
			var ctx = getContext('2d');
			// use additive blending to make glow more intense
			try { ctx.globalCompositeOperation = 'lighter'; } catch(e){}
			ctx.clearRect(0,0,width,height);
			if (!backend) return;
			// Use backend.startX/startY as start point and animated endX/endY
			// fallback to backend.pos when startX/startY are not provided to avoid NaN
			var sx = (backend.startX !== undefined && backend.startX !== null) ? backend.startX : (backend.pos ? backend.pos.x : 0);
			var sy = (backend.startY !== undefined && backend.startY !== null) ? backend.startY : (backend.pos ? backend.pos.y : 0);
			var ex = (endX !== 0 && endX !== undefined && endX !== null) ? endX : (backend.pos ? backend.pos.x : sx);
			var ey = (endY !== 0 && endY !== undefined && endY !== null) ? endY : (backend.pos ? backend.pos.y : sy);

			// if a mapWrapperRef is provided, convert world/map-local coords to screen coords
			if (mapWrapperRef) {
				var msx = mapWrapperRef.x + sx * tileScaleRef;
				var msy = mapWrapperRef.y + sy * tileScaleRef;
				var mex = mapWrapperRef.x + ex * tileScaleRef;
				var mey = mapWrapperRef.y + ey * tileScaleRef;
				sx = msx; sy = msy; ex = mex; ey = mey;
			}

			// coerce to numbers and bail out if invalid
			sx = Number(sx); sy = Number(sy); ex = Number(ex); ey = Number(ey);
			if (!isFinite(sx) || !isFinite(sy) || !isFinite(ex) || !isFinite(ey)) return;

			// stronger glow: more layers, larger widths and higher alpha
			// base glow color - deeper blue (#3399CC) for stronger contrast
			var baseColor = '51,153,204'; // rgb for #3399CC
			// slightly reduce intensity for outer beams using spreadIndex
			var alphaMul = 1.0 - Math.min(0.7, Math.abs(spreadIndex) * 0.18);
			// increase layers and make inner layers brighter
			var glowLayers = 14;
			for (var i = glowLayers; i >= 1; --i) {
				ctx.beginPath();
				// stronger alpha for inner layers and scale with i
				var a = 0.03 * (i + 2) * alphaMul;
				ctx.strokeStyle = 'rgba(' + baseColor + ',' + Math.min(a, 0.95).toFixed(3) + ')';
				ctx.lineWidth = thickness * (i * 0.6);
				ctx.lineCap = 'round';
				ctx.moveTo(sx, sy);
				ctx.lineTo(ex, ey);
				ctx.stroke();
			}

			// bright core line
			ctx.beginPath();
			// brighten the core for center beam; dim slightly for outer beams
			var coreAlpha = 1.0 * alphaMul;
			ctx.strokeStyle = 'rgba(234,255,255,' + coreAlpha.toFixed(3) + ')';
			ctx.lineWidth = Math.max(3, thickness * 0.6);
			ctx.lineCap = 'round';
			ctx.moveTo(sx, sy);
			ctx.lineTo(ex, ey);
			ctx.stroke();

			// debug: draw a high-contrast yellow core so it's visible on any background
			if (debugLaser) {
				ctx.beginPath();
				ctx.strokeStyle = 'rgba(255,255,0,1)';
				ctx.lineWidth = Math.max(6, thickness * 0.25);
				ctx.lineCap = 'round';
				ctx.moveTo(sx, sy);
				ctx.lineTo(ex, ey);
				ctx.stroke();
			}

			// endpoint glow: larger, brighter radial gradient to mark the hit point
			try {
				var r = Math.max(16, thickness * 1.2);
				var grad = ctx.createRadialGradient(ex, ey, 0, ex, ey, r * 3);
				grad.addColorStop(0.0, 'rgba(255,255,255,1.0)');
				grad.addColorStop(0.12, 'rgba(200,240,255,0.95)');
				grad.addColorStop(0.28, 'rgba(51,153,204,0.95)');
				grad.addColorStop(0.5, 'rgba(51,153,204,0.7)');
				grad.addColorStop(1.0, 'rgba(34,102,153,0.18)');
				ctx.beginPath();
				ctx.fillStyle = grad;
				ctx.arc(ex, ey, r * 2.0, 0, Math.PI * 2);
				ctx.fill();
				// small bright core dot
				ctx.beginPath();
				ctx.fillStyle = 'rgba(255,255,255,0.95)';
				ctx.arc(ex, ey, Math.max(4, thickness * 0.08), 0, Math.PI * 2);
				ctx.fill();
			} catch(e) { /* ignore gradient errors on some platforms */ }
		}
	}

	// When backend reports pos changes, animate end point gradually toward backend.pos
	// slower extension to make it more visible
	NumberAnimation on endX { duration: 1000; easing.type: Easing.OutQuad }
	NumberAnimation on endY { duration: 1000; easing.type: Easing.OutQuad }
	Behavior on beamOpacity { NumberAnimation { duration: 80 } }

	function start(dirx, diry) {
		console.log('PlayerLaser.start called, dir:', dirx, diry, 'backend?', backend);
		try { console.log('PlayerLaser: attempting to play laserSfx'); laserSfx.play(); console.log('PlayerLaser: laserSfx.play() returned'); } catch (e) { console.log('laserSfx play failed', e); }
		// trigger a short pulse to make the beam pop when fired
		try { if (typeof pulsate === 'function') pulsate(); } catch(e) { console.log('pulsate failed', e); }
	}

	// quick pulse animation to briefly increase beam opacity and then settle
	function pulsate() {
		// start the pulse animation (stop first if already running)
		try { if (pulseAnim.running) pulseAnim.stop(); pulseAnim.start(); } catch(e) { console.log('pulseAnim start failed', e); }
	}

	SequentialAnimation {
		id: pulseAnim
		loops: 1
		NumberAnimation { target: root; property: "beamOpacity"; from: 1.0; to: 1.6; duration: 60 }
		NumberAnimation { target: root; property: "beamOpacity"; from: 1.6; to: 1.0; duration: 220; easing.type: Easing.InOutQuad }
	}

	function checkLaserCollisions() {
		if (!backend || !backend.pos) return;
		var sx = (backend.startX !== undefined && backend.startX !== null) ? backend.startX : (backend.pos ? backend.pos.x : 0);
		var sy = (backend.startY !== undefined && backend.startY !== null) ? backend.startY : (backend.pos ? backend.pos.y : 0);
		var ex = (endX !== 0 && endX !== undefined && endX !== null) ? endX : (backend.pos ? backend.pos.x : sx);
		var ey = (endY !== 0 && endY !== undefined && endY !== null) ? endY : (backend.pos ? backend.pos.y : sy);
		var scale = tileScaleRef <= 0 ? 1.0 : tileScaleRef;
		var beamHalfWidth = (thickness / scale) * 0.5;
		// prune stale entries and removed enemies from knockMap
		for (var ki = knockMap.length - 1; ki >= 0; --ki) {
			var ke = knockMap[ki];
			if (!ke || !ke.enemy || ke.enemy.alive === false) knockMap.splice(ki, 1);
		}

		if (enemiesRef && enemiesRef.length > 0) {
			for (var idx = 0; idx < enemiesRef.length; ++idx) {
				var enemy = enemiesRef[idx];
				if (!enemy || enemy.alive === false || !enemy.pos) continue;
				var enemyPos = enemy.pos;
				var enemyRadius = enemy.collisionRadius !== undefined ? enemy.collisionRadius : 28;
				var distSq = distanceSqToSegment(enemyPos.x, enemyPos.y, sx, sy, ex, ey);
				var limit = enemyRadius + beamHalfWidth;
				if (distSq <= limit * limit) {
					// find per-enemy entry
					var entryIndex = -1;
					for (var j = 0; j < knockMap.length; ++j) if (knockMap[j].enemy === enemy) { entryIndex = j; break; }
					var now = Date.now();
					// compute knock direction (prefer radial from beam start toward enemy)
					var kdx = enemyPos.x - sx;
					var kdy = enemyPos.y - sy;
					var klen = Math.sqrt(kdx*kdx + kdy*kdy);
					if (klen === 0) { kdx = ex - sx; kdy = ey - sy; klen = Math.sqrt(kdx*kdx + kdy*kdy); }
					if (klen !== 0) { kdx /= klen; kdy /= klen; } else { kdx = 0; kdy = 0; }

					// first contact: apply damage + knockback and record timestamp
					if (entryIndex === -1) {
						try { if (typeof enemy.receiveDamage === 'function') enemy.receiveDamage(damage, kdx, kdy, knockbackDistance); } catch(e){}
						knockMap.push({ enemy: enemy, last: now, damaged: true });
					} else {
						// subsequent contacts: only apply knockback at interval
						var entry = knockMap[entryIndex];
						var interval = (backend && backend.knockIntervalMs !== undefined) ? backend.knockIntervalMs : 1000;
						if (!entry.last || (now - entry.last >= interval)) {
							try { if (typeof enemy.receiveDamage === 'function') enemy.receiveDamage(0, kdx, kdy, knockbackDistance); } catch(e){}
							entry.last = now;
						}
						// otherwise we skip until interval passes
					}
				}
			}
		}
		neutralizeEnemyProjectilesAlongBeam(sx, sy, ex, ey, beamHalfWidth);
	}

	function neutralizeEnemyProjectilesAlongBeam(sx, sy, ex, ey, beamHalfWidth) {
		if (!mapWrapperRef || !mapWrapperRef.enemyProjectileVisuals || mapWrapperRef.enemyProjectileVisuals.length === 0) return;
		var list = mapWrapperRef.enemyProjectileVisuals;
		for (var i = list.length - 1; i >= 0; --i) {
			var enemyProj = list[i];
			if (!enemyProj || !enemyProj.backend || !enemyProj.backend.pos) continue;
			var px = enemyProj.backend.pos.x;
			var py = enemyProj.backend.pos.y;
			var enemyRadius = enemyProj.collisionRadius !== undefined ? enemyProj.collisionRadius : (enemyProj.baseSize ? enemyProj.baseSize * 0.35 : 24);
			var limit = enemyRadius + beamHalfWidth;
			if (distanceSqToSegment(px, py, sx, sy, ex, ey) <= limit * limit) {
				destroyEnemyProjectile(enemyProj);
			}
		}
	}

	function destroyEnemyProjectile(enemyProj) {
		if (!enemyProj) return;
		try {
			if (enemyProj.backend && typeof enemyProj.backend.deleteLater === 'function') enemyProj.backend.deleteLater();
		} catch(e) {}
		try {
			if (typeof enemyProj.destroy === 'function') enemyProj.destroy();
		} catch(e) {}
	}

	Timer {
		id: laserDamageTimer
		interval: 16
		repeat: true
		running: backend !== null
		onTriggered: checkLaserCollisions()
	}

	onBackendChanged: {
		knockMap = [];
		if (!backend) return;
		if (debugLaser) {
			try { console.log('PlayerLaser.onPaint coords: start', backend.startX, backend.startY, 'pos', backend.pos ? backend.pos.x + ',' + backend.pos.y : 'no pos'); } catch(e) {}
		}
			if (debugLaser) console.log('PlayerLaser.onBackendChanged: backend pos', backend.pos ? backend.pos.x + ',' + backend.pos.y : 'no pos', 'startX', backend.startX, 'startY', backend.startY);
		try {
				backend.posChanged.connect(function() { try { beamCanvas.requestPaint(); console.log('PlayerLaser: backend.posChanged -> requestPaint; pos=', backend.pos.x, backend.pos.y); } catch(e){} });
		} catch(e) {}
		try { backend.destroyed.connect(function() { try { root.destroy(); } catch(e){} }); } catch(e) {}
		try { if (typeof backend.backendDestroyed === 'function' || backend.hasOwnProperty('backendDestroyed')) backend.backendDestroyed.connect(function() { try { root.destroy(); } catch(e){} }); } catch(e) {}
		// ensure we play laser sound and paint at least once when backend is assigned
		try { if (typeof start === 'function') start(); } catch(e) { console.log('PlayerLaser: start() call failed', e); }
		// initial paint to draw any initial beam
		try {
			// initialize animated end at start to allow visible extension
			endX = backend.startX !== undefined ? backend.startX : backend.pos.x;
			endY = backend.startY !== undefined ? backend.startY : backend.pos.y;
			// keep fully visible
			beamOpacity = 1.0;
			beamCanvas.requestPaint();
			// extend toward current backend.pos (animated)
			endX = backend.pos.x;
			endY = backend.pos.y;
		} catch(e) { console.log('PlayerLaser: initial requestPaint failed', e); }
	}

	// debug marker removed (was here for development)
	Component.onDestruction: laserDamageTimer.stop()
}
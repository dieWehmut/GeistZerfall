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
		volume: 0.9
	}

	property var backend: null
	// optional refs passed from GameView so the visual can draw in screen coords
	property var mapWrapperRef: null
	property real tileScaleRef: 1.0
	// visual thickness in pixels (can be passed from creator, e.g. 24 * tileScale)
	property real thickness: 15
	// animated end point (used to gradually extend the beam)
	property real endX: 0
	property real endY: 0
	// opacity for the beam (keep fully visible by default)
	property real beamOpacity: 1.0
	// debug helper (disabled by default)
	property bool debugLaser: false

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
			// increase layers and make inner layers brighter
			var glowLayers = 14;
			for (var i = glowLayers; i >= 1; --i) {
				ctx.beginPath();
				// stronger alpha for inner layers and scale with i
				var a = 0.03 * (i + 2);
				ctx.strokeStyle = 'rgba(' + baseColor + ',' + Math.min(a, 0.95).toFixed(3) + ')';
				ctx.lineWidth = thickness * (i * 0.6);
				ctx.lineCap = 'round';
				ctx.moveTo(sx, sy);
				ctx.lineTo(ex, ey);
				ctx.stroke();
			}

			// bright core line
			ctx.beginPath();
			ctx.strokeStyle = '#eaffff';
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

	onBackendChanged: {
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
}
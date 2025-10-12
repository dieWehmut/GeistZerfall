import QtQuick 2.15
import QtMultimedia 6.5

Item {
	id: bulletRoot
	width: 64; height: 64
	// backend projectile object created by C++
	property var backend: null
	// optional hint from creator to indicate visual type expected (e.g. 'laser')
	property string expectedVisual: "bullet"
	// optional thickness hint (ignored for bullets but accepted so createObject doesn't fail)
	property real thickness: 24

	Image {
		id: img
		anchors.centerIn: parent
		source: "qrc:/resource/image/playerBullet.png"
		width: parent.width; height: parent.height
	}

	// Sound effect for bullet firing
	SoundEffect {
		id: bulletSfx
		source: "qrc:/resource/audio/SoundEffect/playerBullet.wav"
		volume: 0.8
	}

	// When backend is assigned, bind visual position to backend.pos and play sound once
	onBackendChanged: {
		if (backend && backend.pos) {
			// initial placement
			bulletRoot.x = backend.pos.x - bulletRoot.width/2;
			bulletRoot.y = backend.pos.y - bulletRoot.height/2;
			// listen for pos changes
			try {
				backend.posChanged.connect(function() {
					bulletRoot.x = backend.pos.x - bulletRoot.width/2;
					bulletRoot.y = backend.pos.y - bulletRoot.height/2;
				});
			} catch (e) { /* ignore if already connected */ }
			try {
				// when backend C++ object is destroyed, remove this visual to avoid orphaned visuals
				backend.destroyed.connect(function() {
					console.log('PlayerBullet.qml: backend.destroyed received');
					try { if (typeof bulletRoot.destroy === 'function') bulletRoot.destroy(); } catch (e) { console.log('destroy failed', e); }
				});
			} catch (e) { /* ignore if already connected */ }
			try {
				// also listen for backend's custom signal as a fallback
				if (typeof backend.backendDestroyed === 'function' || backend.hasOwnProperty('backendDestroyed')) {
					backend.backendDestroyed.connect(function() {
						console.log('PlayerBullet.qml: backend.backendDestroyed received');
						try { if (typeof bulletRoot.destroy === 'function') bulletRoot.destroy(); } catch (e) { console.log('destroy failed', e); }
					});
				}
			} catch (e) { /* ignore if already connected */ }
			try {
				// Determine whether to play bullet sound. If creator explicitly marked expectedVisual as 'laser', don't play.
				var isLaser = false;
				try { isLaser = (backend.visualType === 'laser' || expectedVisual === 'laser'); } catch(e) { isLaser = false; }
				if (!isLaser) try { bulletSfx.play(); } catch (e) { console.log('bulletSfx play failed', e); }
			} catch (e) { console.log('bulletSfx check failed', e); }
		}
	}

	// destroy when backend is deleted (backend may call deleteLater)
	Component.onDestruction: {
		// nothing specific here; QML object will be destroyed by owner
	}
}
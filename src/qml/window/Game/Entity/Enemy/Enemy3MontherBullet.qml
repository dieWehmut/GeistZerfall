import QtQuick 2.15
import QtMultimedia 6.5

Item {
	id: root
	property int baseSize: 96
	width: baseSize * tileScaleRef
	height: baseSize * tileScaleRef
	property var backend: null
	property var playerItemRef: null
	property var playerObjRef: null
	property var mapWrapperRef: null
	property real tileScaleRef: 1.0
	property int damage: 15
	z: 130

	Image {
		anchors.centerIn: parent
		source: "qrc:/resource/image/entity/enemy3MontherBullet.png"
		width: parent.width; height: parent.height
	}

	SoundEffect { id: hitSfx; source: "qrc:/resource/audio/SoundEffect/playerHit.wav"; volume: 0.9 }

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
		// 监听母弹分裂时创建的小弹
		try {
			if (backend.childBulletsCreated) backend.childBulletsCreated.connect(function(childObj){
				var comp = Qt.createComponent("./Enemy3ChildBullet.qml");
				if (comp.status === Component.Ready) {
					var bullet = comp.createObject(mapWrapperRef, {
						backend: childObj,
						playerItemRef: playerItemRef,
						playerObjRef: playerObjRef,
						tileScaleRef: tileScaleRef,
						mapWrapperRef: mapWrapperRef
					});
					if (bullet) bullet.tileScaleRef = Qt.binding(function(){ return tileScaleRef; });
				}
			});
		} catch(e){}
		updateScreenPos();
	}

	onTileScaleRefChanged: updateScreenPos()

	// 碰撞检测：AABB 与玩家矩形（母弹也会造成伤害）
	Timer {
		interval: 16; running: true; repeat: true
		onTriggered: {
			if (!backend || !playerItemRef || !playerObjRef) return;
			var bx = root.x + (mapWrapperRef ? mapWrapperRef.x : 0);
			var by = root.y + (mapWrapperRef ? mapWrapperRef.y : 0);
			var bw = root.width;
			var bh = root.height;
			var px = playerItemRef.x;
			var py = playerItemRef.y;
			var pw = playerItemRef.width;
			var ph = playerItemRef.height;
			if (bx < px + pw && bx + bw > px && by < py + ph && by + bh > py) {
				try { if (typeof playerObjRef.receiveDamage === 'function') playerObjRef.receiveDamage(damage); hitSfx.play(); } catch(e){}
				try { backend.deleteLater(); } catch(e){}
			}
		}
	}
}


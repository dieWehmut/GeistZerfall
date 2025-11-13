import QtQuick 2.15
import GeistZerfall.Game 1.0

Item {
	id: enemy3Root
	property int baseSize: 128
	width: baseSize * tileScaleRef
	height: baseSize * tileScaleRef
	property var backend: null
	property var playerObjRef: null
	property var playerItemRef: null
	property var mapWrapperRef: null
	property real tileScaleRef: 1.0
	z: 120

	Image {
		id: sprite
		anchors.centerIn: parent
		source: "qrc:/resource/image/entity/enemy3.png"
		width: parent.width; height: parent.height
	}

	// HP/MP HUD
	Item {
		id: hudRoot
		width: enemy3Root.width
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

	function updateScreenPos() {
		if (!backend) return;
		enemy3Root.x = backend.pos.x * tileScaleRef - enemy3Root.width/2;
		enemy3Root.y = backend.pos.y * tileScaleRef - enemy3Root.height/2;
	}
	onTileScaleRefChanged: updateScreenPos()

	onBackendChanged: {
		if (!backend) return;
		try { backend.setProperty("collisionRadius", baseSize * 0.45); } catch(e){}
		try { backend.posChanged.connect(updateScreenPos); } catch(e){}
		// 敌人3发射母弹
		try { backend.enemyProjectileCreated.connect(function(pr){
			var comp = Qt.createComponent("./Enemy3MontherBullet.qml");
			if (comp.status === Component.Ready) {
				var bullet = comp.createObject(mapWrapperRef, { backend: pr, playerItemRef: playerItemRef, playerObjRef: playerObjRef, tileScaleRef: tileScaleRef, mapWrapperRef: mapWrapperRef });
				if (bullet) bullet.tileScaleRef = Qt.binding(function(){ return tileScaleRef; });
			}
		}); } catch(e){}
		updateScreenPos();
	}

	Connections {
		target: backend
		onAliveChanged: { if (backend && !backend.alive) { try { enemy3Root.destroy(); } catch(e){} } }
	}
}


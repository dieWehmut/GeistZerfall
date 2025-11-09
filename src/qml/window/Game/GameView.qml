import QtQuick 2.15
import QtQuick.Controls 2.15
// Fix relative imports: Map and Entity are subfolders of Game
import "./Map"
import "./Entity" as EntityQml
// windowState.js is in the parent directory of Game
import "../windowState.js" as WindowState
import GeistZerfall.Game 1.0

Item {
	id: gameViewRoot
	// 通过context property注入playerObj
	// Backward-compatible global aim coordinates (fallback to avoid ReferenceError from legacy code)
	property real aimX: 0
	property real aimY: 0
	// Whether the player is holding the snipe/space key in this view - used to lock sight while held
	property bool snipeHeld: false

	// 战斗数据相关
	property string battleId: ""
	property var battleData: null

	// 在组件完成时加载战斗数据
	Component.onCompleted: {
		// 从 window 获取当前战斗 ID
		if (typeof window !== 'undefined' && window.currentBattleId) {
			battleId = window.currentBattleId;
			loadBattleData(battleId);
		}
	}

	// 加载战斗数据（使用 FileReader 读取 JSON）
	function loadBattleData(id) {
		console.log("GameView: loading battle data", id);
		
	// 构建 JSON 文件路径
	var filePath = ":/qml/window/Game/battles/" + id + ".json";
		console.log("GameView: reading file", filePath);
		
		// 使用 fileReader 读取 JSON
		var jsonObj = fileReader.readJsonFile(filePath);
		
		// 将 QJsonObject 转换为 JavaScript 对象
		battleData = JSON.parse(JSON.stringify(jsonObj));
		
		if (battleData && battleData.mapData) {
			console.log("GameView: loaded battle data", id);
			// 设置地图数据
			tileManager.setMapData(battleData.mapData);
			spawnEnemiesFromMap();
		} else {
			console.log("GameView: failed to load battle", id);
		}
	}

	// Enemies container and list
	property var enemyBackends: []
	property var enemyVisuals: []
	property var enemySpawnCenters: []

	function clearEnemies() {
		for (var i = 0; i < enemyVisuals.length; ++i) { try { enemyVisuals[i].destroy(); } catch(e){} }
		enemyVisuals = [];
		for (var j = 0; j < enemyBackends.length; ++j) { try { enemyBackends[j].deleteLater(); } catch(e){} }
		enemyBackends = [];
		enemySpawnCenters = [];
	}

	function spawnEnemiesFromMap() {
		if (!tileManager || !tileManager.curMapData) {
			console.log("spawnEnemiesFromMap: curMapData not ready");
			return;
		}
		if (!playerObj || !playerItem) {
			console.log("spawnEnemiesFromMap: player not ready yet, retrying");
			Qt.callLater(function(){ spawnEnemiesFromMap(); });
			return;
		}
		clearEnemies();
		var rows = tileManager.curMapData.length;
		if (rows <= 0) {
			console.log("spawnEnemiesFromMap: no rows in curMapData");
			return;
		}
		var cols = tileManager.curMapData[0].length;
		console.log("spawnEnemiesFromMap: rows", rows, "cols", cols);
		var w = cols * tileSize;
		var h = rows * tileSize;
		var minSeparation = Math.max(64, tileSize * 0.25);
		var minSeparationSq = minSeparation * minSeparation;
		var spawnOffsets = [
			Qt.point(0, 0),
			Qt.point(minSeparation, 0),
			Qt.point(-minSeparation, 0),
			Qt.point(0, minSeparation),
			Qt.point(0, -minSeparation),
			Qt.point(minSeparation, minSeparation),
			Qt.point(-minSeparation, minSeparation),
			Qt.point(minSeparation, -minSeparation),
			Qt.point(-minSeparation, -minSeparation)
		];
		function clampToMap(pt) {
			var half = tileSize / 2;
			var clampedX = Math.min(Math.max(pt.x, half), w - half);
			var clampedY = Math.min(Math.max(pt.y, half), h - half);
			return Qt.point(clampedX, clampedY);
		}
		function isFarEnough(candidate) {
			for (var idx = 0; idx < enemySpawnCenters.length; ++idx) {
				var existing = enemySpawnCenters[idx];
				var dx = existing.x - candidate.x;
				var dy = existing.y - candidate.y;
				if ((dx * dx + dy * dy) < minSeparationSq) return false;
			}
			return true;
		}
		function chooseSpawn(baseX, baseY) {
			for (var o = 0; o < spawnOffsets.length; ++o) {
				var offset = spawnOffsets[o];
				var candidate = clampToMap(Qt.point(baseX + offset.x, baseY + offset.y));
				if (isFarEnough(candidate)) return candidate;
			}
			return null;
		}
		for (var r = 0; r < rows; ++r) {
			for (var c = 0; c < cols; ++c) {
				var t = tileManager.getTileType(r, c);
					if (t === 1 || t === 2) {
					var worldX = c * tileSize + tileSize/2;
					var worldY = r * tileSize + tileSize/2;
					console.log("Tile type", t, "converted to world", worldX, worldY, "for tileSize", tileSize);
					if (t === 1) {
						var candidate1 = chooseSpawn(worldX, worldY);
						if (!candidate1) {
							console.log("spawnEnemiesFromMap: unable to place Enemy1 near", worldX, worldY, "due to spacing constraints");
							continue;
						}
						var spawnX1 = candidate1.x;
						var spawnY1 = candidate1.y;
						if (Math.abs(spawnX1 - worldX) > 0.5 || Math.abs(spawnY1 - worldY) > 0.5) {
							console.log("spawnEnemiesFromMap: adjusted Enemy1 spawn from", worldX, worldY, "to", spawnX1, spawnY1);
						}
						var e1 = Qt.createQmlObject('import GeistZerfall.Game 1.0; BackendEnemy1 {}', gameViewRoot);
						if (e1) {
							e1.mapWidth = w; e1.mapHeight = h;
							e1.pos = Qt.point(spawnX1, spawnY1);
							if (playerObj && typeof e1.setPlayerTarget === 'function') e1.setPlayerTarget(playerObj);
							enemyBackends.push(e1);
							enemySpawnCenters.push({ x: spawnX1, y: spawnY1 });
							var comp1 = Qt.createComponent("./Entity/Enemy/Enemy1.qml");
							if (comp1.status === Component.Ready) {
								console.log("spawnEnemiesFromMap: creating Enemy1 at row", r, "col", c, "world", spawnX1, spawnY1, "tileScale", tileScale);
								var v1 = comp1.createObject(mapWrapper, { backend: e1, playerObjRef: playerObj, playerItemRef: playerItem, mapWrapperRef: mapWrapper, tileScaleRef: tileScale });
								if (v1) {
									enemyVisuals.push(v1);
									v1.tileScaleRef = Qt.binding(function(){ return tileScale; });
									v1.playerItemRef = playerItem;
									v1.updateScreenPos && v1.updateScreenPos();
								}
							}
						}
					} else if (t === 2) {
						var candidate2 = chooseSpawn(worldX, worldY);
						if (!candidate2) {
							console.log("spawnEnemiesFromMap: unable to place Enemy2 near", worldX, worldY, "due to spacing constraints");
							continue;
						}
						var spawnX2 = candidate2.x;
						var spawnY2 = candidate2.y;
						if (Math.abs(spawnX2 - worldX) > 0.5 || Math.abs(spawnY2 - worldY) > 0.5) {
							console.log("spawnEnemiesFromMap: adjusted Enemy2 spawn from", worldX, worldY, "to", spawnX2, spawnY2);
						}
						var e2 = Qt.createQmlObject('import GeistZerfall.Game 1.0; BackendEnemy2 {}', gameViewRoot);
						if (e2) {
							e2.mapWidth = w; e2.mapHeight = h;
							e2.pos = Qt.point(spawnX2, spawnY2);
							if (playerObj && typeof e2.setPlayerTarget === 'function') e2.setPlayerTarget(playerObj);
							enemyBackends.push(e2);
							enemySpawnCenters.push({ x: spawnX2, y: spawnY2 });
							var comp2 = Qt.createComponent("./Entity/Enemy/Enemy2.qml");
							if (comp2.status === Component.Ready) {
								console.log("spawnEnemiesFromMap: creating Enemy2 at row", r, "col", c, "world", spawnX2, spawnY2, "tileScale", tileScale);
								var v2 = comp2.createObject(mapWrapper, { backend: e2, playerObjRef: playerObj, playerItemRef: playerItem, mapWrapperRef: mapWrapper, tileScaleRef: tileScale });
								if (v2) {
									enemyVisuals.push(v2);
									v2.tileScaleRef = Qt.binding(function(){ return tileScale; });
									v2.playerItemRef = playerItem;
									v2.updateScreenPos && v2.updateScreenPos();
								}
							}
						}
					}
				}
			}
		}
		console.log("spawnEnemiesFromMap: total enemies", enemyBackends.length);
	}

	Connections {
		target: tileManager
		onCurMapDataChanged: spawnEnemiesFromMap()
	}

	// 右键点击跳转到设置界面
	MouseArea {
		anchors.fill: parent
		hoverEnabled: true
		acceptedButtons: Qt.RightButton
		onClicked: function(mouse) {
			if (mouse.button === Qt.RightButton) {
				// 通过顶层Window暴露的gotoConfig切换到设置界面
				var win = Qt.binding(function() { return Qt.application.activeWindow || null; });
				if (win && win.gotoConfig) {
					win.gotoConfig();
				} else if (typeof gotoConfig === "function") {
					gotoConfig();
				} else {
					console.log("未找到gotoConfig方法");
				}
			}
		}

		onExited: function() {
			// 鼠标移出视图时，确保按键状态被清理，防止一直移动
			if (playerItem && typeof playerItem.resetKeys === 'function') {
				playerItem.resetKeys();
			}
		}
	}

	// Global Esc shortcut: exit fullscreen like Config.qml
	Shortcut {
		sequence: "Esc"
		onActivated: {
			if (window && window.showNormal) window.showNormal();
			if (typeof fullscreenBtn !== 'undefined') fullscreenBtn.checked = false;
			if (typeof windowBtn !== 'undefined') windowBtn.checked = true;
		}
	}
	anchors.fill: parent
	property bool appliedSaveLoad: false
	Component.onDestruction: {
		if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager && playerObj) {
			// capture a temporary preview image of the current GameView so it can be used by SaveLoad UI
			try { SaveLoadManager.captureTemp(); } catch (e) { console.log('captureTemp failed', e); }
			SaveLoadManager.posX = playerObj.pos.x;
			SaveLoadManager.posY = playerObj.pos.y;
			SaveLoadManager.speed = playerObj.getSpeed ? playerObj.getSpeed() : 0;
			SaveLoadManager.sight = playerObj.getSight ? playerObj.getSight() : 0;
			SaveLoadManager.saveAuto();
		}
		// clear global pointer to player when leaving game view so other pages don't hold stale refs
		try { if (window && window.currentPlayer) window.currentPlayer = undefined; } catch (e) {}
	}

	onVisibleChanged: {
		if (!visible) {
			if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager && playerObj) {
				// capture temp preview whenever leaving the GameView so SaveLoad can show it instantly
				try { SaveLoadManager.captureTemp(); } catch (e) { console.log('captureTemp failed', e); }
				SaveLoadManager.posX = playerObj.pos.x;
				SaveLoadManager.posY = playerObj.pos.y;
				SaveLoadManager.speed = playerObj.getSpeed ? playerObj.getSpeed() : 0;
				SaveLoadManager.sight = playerObj.getSight ? playerObj.getSight() : 0;
				SaveLoadManager.saveAuto();
			}
		}
	}
	property int tileSize: 512
	// when snipe mode is active we set tileScale to 0.5 to shrink everything visually
	property real tileScale: 1.0

	Behavior on tileScale { NumberAnimation { duration: 220; easing.type: Easing.InOutQuad } }
	property int mapRows: tileManager.curMapData ? tileManager.curMapData.length : 0
	property int mapCols: (tileManager.curMapData && tileManager.curMapData.length>0) ? tileManager.curMapData[0].length : 0
	property int mapPixelWidth: Math.round(mapCols * tileSize * tileScale)
	property int mapPixelHeight: Math.round(mapRows * tileSize * tileScale)
	Rectangle {
		id: mapViewport
		anchors.fill: parent
		clip: true
		Item {
			id: mapWrapper
			// 明确设置宽高，避免在缩放或计算偏移时出现未定义边界导致的裁剪/空白
			width: mapPixelWidth
			height: mapPixelHeight
				x: {
					if (!playerObj) return 0;
					// Compute player's center in scaled map pixels (world pos + half width) * tileScale
					var playerCenterX = (playerObj.pos.x + (playerItem.width/2)) * tileScale;
					var centerX = mapViewport.width / 2; // desired screen center for player
					var ox = centerX - playerCenterX;
					// clamp to map bounds so we don't show beyond edges
					if (ox > 0) ox = 0;
					if (ox + mapPixelWidth < mapViewport.width) ox = mapViewport.width - mapPixelWidth;
					return ox;
				}
				y: {
					if (!playerObj) return 0;
					var playerCenterY = (playerObj.pos.y + (playerItem.height/2)) * tileScale;
					var centerY = mapViewport.height / 2;
					var oy = centerY - playerCenterY;
					// clamp to map bounds
					if (oy > 0) oy = 0;
					if (oy + mapPixelHeight < mapViewport.height) oy = mapViewport.height - mapPixelHeight;
					return oy;
				}
			Column {
				id: mapColumn
				spacing: 0
				Repeater {
					model: mapRows
					Row {
						property int r: index
						spacing: 0
						Repeater {
							model: mapCols
							Tile {
								width: Math.round(tileSize * tileScale)
								height: Math.round(tileSize * tileScale)
								tileType: tileManager.getTileType(r, index)
							}
						}
					}
				}
			}
		}
		}
		TileManager {
		id: tileManager
	}

	// helper to create/destroy bullets
	function destroyChild(item) {
		if (!item) return;
		try { item.destroy(); } catch (e) { /* ignore */ }
	}

	function createBullet(x, y, dirx, diry) {
		// use path relative to this QML file so component can be found in the project tree
		var comp = Qt.createComponent("./Entity/PlayerBullet.qml");
		if (comp.status === Component.Ready) {
		var obj = comp.createObject(mapWrapper, { x: x - 32, y: y - 32 });
			if (obj) {
				// fallback visual-only bullet: start local motion if start exists, otherwise ensure it self-destructs
				try { if (typeof obj.start === 'function') obj.start(dirx, diry); } catch (e) {}
				// ensure any pure-QML bullet gets removed eventually to avoid leaks
				try {
					var destroyTimer = Qt.createQmlObject('import QtQuick 2.0; Timer { interval: 3000; repeat: false; running: true; onTriggered: { try { if (typeof obj.destroy === "function") obj.destroy(); } catch (e) {} } }', obj, 'destroyTimer');
				} catch (e) { /* ignore */ }
			}
		} else {
			console.log("Failed to create bullet component:", comp.errorString());
		}
	}

	// Aiming overlay and left-click shooting
	// place this under the sightMask (so it's only visible inside the transparent sight circle)
	Item {
		id: aimOverlay
		anchors.fill: parent
		z: 998
		property real aimX: 0
		property real aimY: 0

	Canvas {
			id: aimCanvas
			anchors.fill: parent
			onPaint: {
				var ctx = getContext('2d');
				ctx.clearRect(0,0,width,height);
				if (!playerItem) return;
			// compute screen-space center from backend world pos to be robust to scaling
			var sx = mapWrapper.x + (playerObj.pos.x + (playerItem.width/2)) * tileScale;
			var sy = mapWrapper.y + (playerObj.pos.y + (playerItem.height/2)) * tileScale;
	// color changes when snipe (aiming) active; use deeper colors
	var arrowColor = (playerObj && playerObj.snipeActive) ? '#226699' : '#008844';
	ctx.strokeStyle = arrowColor;
		ctx.lineWidth = 15;
				ctx.beginPath();
				// compute target point; if mouse is outside sight, clamp to sight boundary
				var dxA = aimOverlay.aimX - sx;
				var dyA = aimOverlay.aimY - sy;
				var distA = Math.sqrt(dxA*dxA + dyA*dyA);
				var tx = aimOverlay.aimX;
				var ty = aimOverlay.aimY;
				if (distA > sightMask.radius && distA > 0) {
					var nx = dxA / distA;	// normalized
					tx = sx + nx * sightMask.radius;
					ty = sy + (dyA / distA) * sightMask.radius;
				}

				// draw a very faint circle; color switches to blue when snipe active
				var circR = Math.min(distA, sightMask.radius);
				if (circR > 0) {
					ctx.beginPath();
					ctx.arc(sx, sy, circR, 0, Math.PI*2);
					var fillColor = (playerObj && playerObj.snipeActive) ? 'rgba(51,153,204,0.36)' : 'rgba(0,204,102,0.36)';
					var strokeColor = (playerObj && playerObj.snipeActive) ? 'rgba(51,153,204,0.72)' : 'rgba(0,204,102,0.72)';
					ctx.fillStyle = fillColor;
					ctx.fill();
					ctx.lineWidth = 2;
					ctx.strokeStyle = strokeColor;
					ctx.stroke();
				}

				ctx.moveTo(sx, sy);
				ctx.lineTo(tx, ty);
				ctx.stroke();
				// draw arrow head
				var ang = Math.atan2(ty - sy, tx - sx);
				var ah = 28; // arrow head size (increase with thicker line)
				ctx.beginPath();
				ctx.moveTo(tx, ty);
				ctx.lineTo(tx - ah*Math.cos(ang - Math.PI/6), ty - ah*Math.sin(ang - Math.PI/6));
				ctx.lineTo(tx - ah*Math.cos(ang + Math.PI/6), ty - ah*Math.sin(ang + Math.PI/6));
				ctx.closePath();
				ctx.fillStyle = arrowColor;
				ctx.fill();
			}
		}

		MouseArea {
			anchors.fill: parent
			hoverEnabled: true
			acceptedButtons: Qt.LeftButton
			onPositionChanged: function(mouse) {
				// compute world coords relative to mapWrapper
				aimOverlay.aimX = mouse.x;
				aimOverlay.aimY = mouse.y;
				aimCanvas.requestPaint();
			}
			onExited: function() { aimOverlay.aimX = -1000; aimOverlay.aimY = -1000; aimCanvas.requestPaint(); }
				onPressed: function(mouse) {
					if (mouse.button !== Qt.LeftButton) return;
					if (!playerObj || !playerItem) return;
					// If snipe (laser) mode is active, fire once immediately on click and do NOT start auto-fire
					if (playerObj.snipeActive || gameViewRoot.snipeHeld) {
						try {
							var sx = mapWrapper.x + (playerObj.pos.x + (playerItem.width/2)) * tileScale;
							var sy = mapWrapper.y + (playerObj.pos.y + (playerItem.height/2)) * tileScale;
							var ax = mouse.x;
							var ay = mouse.y;
							var dxs = ax - sx;
							var dys = ay - sy;
							var dists = Math.sqrt(dxs*dxs + dys*dys);
							var tx = ax;
							var ty = ay;
							if (dists > sightMask.radius && dists > 0) {
								var nx = dxs / dists;
								tx = sx + nx * sightMask.radius;
								ty = sy + (dys / dists) * sightMask.radius;
							}
							var targetWorldX = (tx - mapWrapper.x) / tileScale;
							var targetWorldY = (ty - mapWrapper.y) / tileScale;
							var px = playerObj.pos.x + (playerItem.width/2);
							var py = playerObj.pos.y + (playerItem.height/2);
							var dirx = targetWorldX - px;
							var diry = targetWorldY - py;
							var fired = false;
							try {
								if (typeof playerItem.trySnipe === 'function') fired = playerItem.trySnipe(px, py, dirx, diry);
								else fired = false;
							} catch(e) { console.log('trySnipe call failed', e); fired = false; }
							if (fired) {
								var laserQml = 'import QtQuick 2.15; Canvas { id: beam; anchors.fill: parent; z: 2000; property real startX: 0; property real startY: 0; property real endX: 0; property real endY: 0; property real thickness: 24; onPaint: { var ctx = getContext("2d"); ctx.clearRect(0,0,width,height); ctx.strokeStyle = "#66CCFF"; ctx.lineWidth = thickness; ctx.beginPath(); ctx.moveTo(startX, startY); ctx.lineTo(endX, endY); ctx.stroke(); } }';
								var laserObj = Qt.createQmlObject(laserQml, mapWrapper);
								if (laserObj) {
									laserObj.startX = sx - mapWrapper.x;
									laserObj.startY = sy - mapWrapper.y;
									laserObj.endX = tx - mapWrapper.x;
									laserObj.endY = ty - mapWrapper.y;
									laserObj.thickness = 24 * tileScale;
									laserObj.requestPaint();
									Qt.createQmlObject('import QtQuick 2.0; Timer { interval: 120; repeat: false; running: true; onTriggered: { try { parent.destroy(); } catch(e){} } }', laserObj);
								}
							}
						} catch(e) { console.log('snipe onPressed failed', e); }
						return;
					}
					// begin auto-fire for bullets
					try { if (typeof playerItem.stopBulletRecharge === 'function') playerItem.stopBulletRecharge(); } catch(e) {}
					if (!fireTimer.running) {
						fireTimer.start();
					}
				}
			onReleased: function(mouse) {
				if (mouse.button !== Qt.LeftButton) return;
				// stop auto-fire and start recharge
				if (fireTimer.running) fireTimer.stop();
				try { if (typeof playerItem.startBulletRecharge === 'function') playerItem.startBulletRecharge(); } catch(e) {}
			}
		}

		// Timer to repeatedly attempt firing while mouse left is held
		Timer {
			id: fireTimer
			interval: 80
			repeat: true
			running: false
			onTriggered: function() {
				if (!playerObj || !playerItem) return;
				// compute aim target similar to previous onClicked logic
					var sx = mapWrapper.x + (playerObj.pos.x + (playerItem.width/2)) * tileScale;
					var sy = mapWrapper.y + (playerObj.pos.y + (playerItem.height/2)) * tileScale;
				var ax = aimOverlay.aimX;
				var ay = aimOverlay.aimY;
				var dxs = ax - sx;
				var dys = ay - sy;
				var dists = Math.sqrt(dxs*dxs + dys*dys);
				var tx = ax;
				var ty = ay;
				if (dists > sightMask.radius && dists > 0) {
					var nx = dxs / dists;
					tx = sx + nx * sightMask.radius;
					ty = sy + (dys / dists) * sightMask.radius;
				}
				var targetWorldX = (tx - mapWrapper.x) / tileScale;
				var targetWorldY = (ty - mapWrapper.y) / tileScale;
					var px = playerObj.pos.x + (playerItem.width/2);
					var py = playerObj.pos.y + (playerItem.height/2);
				var dirx = targetWorldX - px;
				var diry = targetWorldY - py;
				// If snipe active, attempt snipe once (do not auto-repeat laser)
				if (playerObj && (playerObj.snipeActive || gameViewRoot.snipeHeld)) {
					// attempt once per trigger
					var fired = false;
					try {
						if (typeof playerItem.trySnipe === 'function') fired = playerItem.trySnipe(px, py, dirx, diry);
						else fired = false;
					} catch(e) { console.log('trySnipe call failed', e); fired = false; }
					if (fired) {
						// create visual as before
						// ... create front-end laser visual for feedback (same as before)
						var laserQml = 'import QtQuick 2.15; Canvas { id: beam; anchors.fill: parent; z: 2000; property real startX: 0; property real startY: 0; property real endX: 0; property real endY: 0; property real thickness: 24; onPaint: { var ctx = getContext("2d"); ctx.clearRect(0,0,width,height); ctx.strokeStyle = "#66CCFF"; ctx.lineWidth = thickness; ctx.beginPath(); ctx.moveTo(startX, startY); ctx.lineTo(endX, endY); ctx.stroke(); } }';
						var laserObj = Qt.createQmlObject(laserQml, mapWrapper);
						if (laserObj) {
							laserObj.startX = sx - mapWrapper.x;
							laserObj.startY = sy - mapWrapper.y;
							laserObj.endX = tx - mapWrapper.x;
							laserObj.endY = ty - mapWrapper.y;
							laserObj.thickness = 24 * tileScale;
							laserObj.requestPaint();
							Qt.createQmlObject('import QtQuick 2.0; Timer { interval: 120; repeat: false; running: true; onTriggered: { try { parent.destroy(); } catch(e){} } }', laserObj);
						}
					}
				} else {
					var firedB = false;
					try {
						if (typeof playerItem.tryShoot === 'function') firedB = playerItem.tryShoot(px, py, dirx, diry);
						else firedB = false;
					} catch(e) { console.log('tryShoot call failed', e); firedB = false; }
					if (firedB) {
						// if backend doesn't provide shoot, create visual fallback
						if (!(playerObj && typeof playerObj.shoot === 'function')) {
							createBullet(px, py, dirx, diry);
						}
					} else {
						// if bullet not ready, still allow continuous clicking but don't create visual
					}
				}
			}
		}
	}
	BackendPlayer {
		id: playerObj
		// Provide backend with world map size (not scaled by tileScale).
		// mapPixelWidth/mapPixelHeight include visual scaling and would
		// shrink when entering snipe mode. Passing those causes the
		// backend to clamp player pos incorrectly when tileScale changes.
		mapWidth: mapCols * tileSize
		mapHeight: mapRows * tileSize
		Component.onCompleted: {
			var tileSizeLocal = tileSize * tileScale;
			var centerCol = tileManager.colCnt / 2;
			var centerRow = tileManager.rowCnt / 2;
			var centerX = centerCol * tileSizeLocal;
			var centerY = centerRow * tileSizeLocal;
			// If navigated here as a new game, create a default auto save at the map center
			try {
				var tm = WindowState.takeTargetMode();
				if (tm === "new") {
					if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager) {
						// reasonable defaults for a new game
						var defaultSpeed = 0;
						var defaultSight = 180;
						SaveLoadManager.createDefaultAuto("save", centerX, centerY, defaultSpeed, defaultSight);
					}
				} else if (tm === "loadFromSave") {
					// We were navigated here from SaveLoad after loadSlot succeeded. Apply saved values if present.
					if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager) {
						console.log("GameView: detected loadFromSave, SaveLoadManager pos:", SaveLoadManager.posX, SaveLoadManager.posY, "speed", SaveLoadManager.speed, "sight", SaveLoadManager.sight);
						if (!isNaN(SaveLoadManager.posX) && !isNaN(SaveLoadManager.posY) && (SaveLoadManager.posX !== 0 || SaveLoadManager.posY !== 0)) {
							playerObj.pos = Qt.point(SaveLoadManager.posX, SaveLoadManager.posY);
						}
						if (!isNaN(SaveLoadManager.speed) && SaveLoadManager.speed > 0) playerObj.setSpeed(SaveLoadManager.speed);
						if (!isNaN(SaveLoadManager.sight) && SaveLoadManager.sight > 0) playerObj.setSight(SaveLoadManager.sight);
						appliedSaveLoad = true;
					}
				}
			} catch (e) { /* ignore if windowState not available */ }
			// If we didn't just apply a save load, try loading auto save as before; otherwise default to center
			if (!appliedSaveLoad) {
				if (typeof SaveLoadManager !== 'undefined' && SaveLoadManager) {
					if (SaveLoadManager.loadAuto()) {
						console.log('Loaded auto save');
						if (!isNaN(SaveLoadManager.posX) && !isNaN(SaveLoadManager.posY) && (SaveLoadManager.posX !== 0 || SaveLoadManager.posY !== 0)) {
							playerObj.pos = Qt.point(SaveLoadManager.posX, SaveLoadManager.posY);
						}
						if (!isNaN(SaveLoadManager.speed) && SaveLoadManager.speed > 0) playerObj.setSpeed(SaveLoadManager.speed);
						if (!isNaN(SaveLoadManager.sight) && SaveLoadManager.sight > 0) playerObj.setSight(SaveLoadManager.sight);
					} else {
						playerObj.pos = Qt.point(centerX, centerY);
					}
				} else {
					playerObj.pos = Qt.point(centerX, centerY);
				}
			}
			// 尝试切换到游戏音乐;若不存在则回退到主菜单音乐
			if (typeof window !== 'undefined' && typeof window.playMusic === 'function') {
				try {
					window.playMusic("qrc:/resource/audio/bgm/fight.mp3");
				} catch (e) {
					console.log("切换到游戏音乐失败,使用主菜单音乐作为回退", e);
					window.playMusic("qrc:/resource/audio/bgm/mainmenu.mp3");
				}
			}
			// expose playerObj to window so SaveLoad UI can read current player state when saving
			try { if (window) window.currentPlayer = playerObj; } catch (e) {}
		}
	}
	EntityQml.Player {
		id: playerItem
		z: 100
		// use scale transform to smoothly resize player visual without changing layout geometry
		scale: tileScale
		transformOrigin: Item.Center
		// Position the visual based on mapWrapper offset and backend world coordinates.
		// This ensures when the map is clamped at edges (mapWrapper.x/y adjusted),
		// the player visual remains correctly aligned with world coordinates and
		// the sightMask/aimCanvas calculations which use mapWrapper.x/y.
		x: (playerObj && mapWrapper && playerItem) ? (mapWrapper.x + (playerObj.pos.x + (playerItem.width/2)) * tileScale - (width/2)) : (mapViewport.width / 2 - width / 2)
		y: (playerObj && mapWrapper && playerItem) ? (mapWrapper.y + (playerObj.pos.y + (playerItem.height/2)) * tileScale - (height/2)) : (mapViewport.height / 2 - height / 2)
		focus: true 
		Component.onCompleted: playerItem.forceActiveFocus()

		Keys.onPressed: function(event) {
			if (event.key === Qt.Key_Space) {
				// mark that snipe key is held so other logic (moving) won't change the sight while held
				gameViewRoot.snipeHeld = true;
				if (playerObj && typeof playerObj.snipeStart === 'function') playerObj.snipeStart();
				tileScale = 1.0 / 2.0;
				// ensure sightMask radius is updated to match scaled view
				sightMask.radius = sightMask.baseRadius * tileScale;
				// pressing space should stop bullet auto-fire if it was active
				try { if (fireTimer && fireTimer.running) fireTimer.stop(); } catch(e) {}
				try { if (playerItem && typeof playerItem.startBulletRecharge === 'function') playerItem.startBulletRecharge(); } catch(e) {}
			}
		}
		Keys.onReleased: function(event) {
			if (event.key === Qt.Key_Space) {
				// release lock first so moving logic can resume
				gameViewRoot.snipeHeld = false;
				if (playerObj && typeof playerObj.snipeStop === 'function') playerObj.snipeStop();
				// restore scale
				tileScale = 1.0;
				sightMask.radius = sightMask.baseRadius * tileScale;
				// releasing space: ensure recharge resumes
				try { if (playerItem && typeof playerItem.startBulletRecharge === 'function') playerItem.startBulletRecharge(); } catch(e) {}
			}
		}
	}

	// When backend player emits playerBulletCreated, create bullet visual and bind to backend
	Connections {
		target: playerObj
		onPlayerBulletCreated: function(bullet) {
			console.log('GameView.qml: playerBulletCreated', bullet);
			// create bullet visual and bind
			var comp = Qt.createComponent("./Entity/PlayerBullet.qml");
				if (comp.status === Component.Ready) {
					var obj = comp.createObject(mapWrapper, { backend: bullet, enemiesRef: enemyBackends, mapWrapperRef: mapWrapper, tileScaleRef: tileScale });
				if (!obj) console.log('Failed to create PlayerBullet visual');
				else {
					obj.tileScaleRef = Qt.binding(function(){ return tileScale; });
						obj.enemiesRef = Qt.binding(function(){ return enemyBackends; });
					obj.mapWrapperRef = mapWrapper;
				}
			} else {
				console.log('Failed to create PlayerBullet component:', comp.errorString());
			}
		}
	}

	// When backend player emits playerLaserCreated, create laser visual and bind to backend
	Connections {
		target: playerObj
		onPlayerLaserCreated: function(laser) {
			console.log('GameView.qml: playerLaserCreated', laser);
			var comp = Qt.createComponent("./Entity/PlayerLaser.qml");
			if (comp.status === Component.Ready) {
				// create the laser visual as a child of the view root (not mapWrapper)
				// and pass a reference to mapWrapper so the visual can compute screen coords
				var obj = comp.createObject(gameViewRoot, {
					backend: laser,
					thickness: 6,
					mapWrapperRef: mapWrapper,
					tileScaleRef: Qt.binding(function() { return tileScale; }),
					enemiesRef: enemyBackends
				});
				if (!obj) console.log('Failed to create PlayerLaser visual');
				else {
					// ensure initial paint
					try { if (typeof obj.start === 'function') obj.start(); } catch(e) {}
					try { obj.requestPaint(); } catch(e) {}
					obj.enemiesRef = Qt.binding(function(){ return enemyBackends; });
				}
			} else {
				console.log('Failed to create PlayerLaser component:', comp.errorString());
			}
		}
	}
	// 视野遮罩层（Canvas 实现，避免 Qt6 qsb 要求）
	Canvas {
		id: sightMask
		anchors.fill: parent
		// 遮罩中心直接绑定到 playerItem 的视觉中心，确保跟随移动与缩放
		property real cx: playerItem ? (playerItem.x + playerItem.width/2) : width/2
		property real cy: playerItem ? (playerItem.y + playerItem.height/2) : height/2
		// baseRadius 是默认（原始）视野半径，可调整或从后端读取
		// read sight via Q_PROPERTY exposed as 'sight'
		property real baseRadius: playerObj ? (playerObj.sight ? playerObj.sight : 180) : 180
		// 初始半径按当前 tileScale 缩放，避免进入游戏时出现不一致大小
		property real radius: baseRadius * tileScale
	property color maskColor: Qt.rgba(0,0,0,1.0)
		z: 999

		Behavior on radius {
			NumberAnimation { duration: 600; easing.type: Easing.InOutQuad }
		}

		// 请求在关键属性变化时重绘
		onCxChanged: requestPaint()
		onCyChanged: requestPaint()
		onRadiusChanged: requestPaint()
		onWidthChanged: requestPaint()
		onHeightChanged: requestPaint()
		// 当缩放变化时需要更新半径（若未被移动/狙击逻辑覆盖）
		Connections {
			target: gameViewRoot
			onTileScaleChanged: {
				// 如果当前处于移动或狙击动态调整，保持逻辑不强制覆盖；否则按基础值更新
				if (gameViewRoot.snipeHeld) {
					sightMask.radius = sightMask.baseRadius * tileScale;
				} else if (playerItem && playerItem.moving) {
					sightMask.radius = (sightMask.baseRadius / 2) * tileScale;
				} else {
					sightMask.radius = sightMask.baseRadius * tileScale;
				}
			}
		}

		onPaint: {
			var ctx = getContext('2d');
			// 清空并绘制纯黑遮罩
			ctx.clearRect(0, 0, width, height);
			ctx.globalCompositeOperation = 'source-over';
			ctx.fillStyle = maskColor;
			ctx.fillRect(0, 0, width, height);
			// 在玩家位置打出透明圆（destination-out）
			ctx.globalCompositeOperation = 'destination-out';
			ctx.beginPath();
			ctx.arc(cx, cy, radius, 0, Math.PI * 2);
			ctx.fill();
			// 恢复默认合并方式
			ctx.globalCompositeOperation = 'source-over';
		}
	}

	// 监听 playerItem 的 moving 状态，平滑调整视野半径到 baseRadius/2 或 baseRadius
    	Connections {
    		target: playerItem
    		onMovingChanged: {
    			// If the snipe/space key is held, keep sight locked at maximum and ignore moving changes
    			if (gameViewRoot.snipeHeld) {
    				// enforce max sight while held
    				sightMask.radius = sightMask.baseRadius * tileScale;
    				return;
    			}
    			if (playerItem.moving) {
    				// 把 radius 缩小为原来的一半，动画由 Behavior 控制
    				sightMask.radius = (sightMask.baseRadius / 2) * tileScale;
    			} else {
    				sightMask.radius = sightMask.baseRadius * tileScale;
    			}
    		}
    	}
}

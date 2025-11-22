import QtQuick 2.15
import "."

Item {
    id: teleportOverlay
    property var playerObj: null
    property real tileScale: 1.0
    property bool active: false
    property real teleportDistance: 300
    // If a sightMaskRef is provided, prefer its current radius (screen px) converted to world units.
    property var sightMaskRef: null
    readonly property real effectiveTeleportDistance: (
        sightMaskRef && typeof sightMaskRef.radius !== 'undefined'
    ) ? (sightMaskRef.radius / tileScale) : ((playerObj && typeof playerObj.sight !== 'undefined') ? playerObj.sight : teleportDistance)
    property var mapWrapperRef: null
    property var mapClamp: ({ width: 0, height: 0 })
    property string teleportSprite: "qrc:/resource/image/entity/playerNormal.png"
    property real playerSpriteSize: 96
    property real playerVisualWidth: 0
    property real playerVisualHeight: 0
    property var directions: [
        Qt.point(0, -1),
        Qt.point(0, 1),
        Qt.point(-1, 0),
        Qt.point(1, 0),
        Qt.point(-1, -1),
        Qt.point(1, -1),
        Qt.point(-1, 1),
        Qt.point(1, 1)
    ]
        property real rotationAngle: 0

    visible: active && playerObj
    z: 2090
    x: (mapWrapperRef && parent === mapWrapperRef) ? 0 : (mapWrapperRef ? mapWrapperRef.x : 0)
    y: (mapWrapperRef && parent === mapWrapperRef) ? 0 : (mapWrapperRef ? mapWrapperRef.y : 0)
    width: mapWrapperRef ? mapWrapperRef.width : (parent ? parent.width : 0)
    height: mapWrapperRef ? mapWrapperRef.height : (parent ? parent.height : 0)

    onTileScaleChanged: forceUpdate()
    onActiveChanged: forceUpdate()
    onPlayerVisualWidthChanged: forceUpdate()
    onPlayerVisualHeightChanged: forceUpdate()

    function clampPoint(pt) {
        var maxW = playerObj && playerObj.mapWidth ? playerObj.mapWidth : mapClamp.width;
        var maxH = playerObj && playerObj.mapHeight ? playerObj.mapHeight : mapClamp.height;
        var x = pt.x;
        var y = pt.y;
        if (maxW > 0) {
            if (x < 0) x = 0;
            if (x > maxW) x = maxW;
        }
        if (maxH > 0) {
            if (y < 0) y = 0;
            if (y > maxH) y = maxH;
        }
        return Qt.point(x, y);
    }

    function worldPointForDirection(dir) {
        if (!playerObj) return Qt.point(0, 0);
        var base = playerObj.pos ? Qt.point(playerObj.pos.x, playerObj.pos.y) : Qt.point(0, 0);
        // playerVisualWidth/Height are provided from the visual (screen pixels).
        // Convert to world units by dividing by tileScale so the center computation remains correct
        // regardless of zoom/scale.
        var halfWWorld = 0.5 * ((tileScale > 0 && playerVisualWidth) ? (playerVisualWidth / tileScale) : playerSpriteSize);
        var halfHWorld = 0.5 * ((tileScale > 0 && playerVisualHeight) ? (playerVisualHeight / tileScale) : playerSpriteSize);
        base.x += halfWWorld;
        base.y += halfHWorld;
        var normLen = Math.sqrt(dir.x * dir.x + dir.y * dir.y);
        var mul = (normLen > 0) ? (effectiveTeleportDistance / normLen) : effectiveTeleportDistance;
        return clampPoint(Qt.point(base.x + dir.x * mul, base.y + dir.y * mul));
    }

        // Compute a world point from an angle in degrees (0 = right, positive clockwise)
        function worldPointForAngle(deg) {
            // convert to radians and invert to make positive degrees rotate clockwise on screen
            var rad = -deg * Math.PI / 180.0;
            var dx = Math.cos(rad);
            var dy = Math.sin(rad);
            return worldPointForDirection(Qt.point(dx, dy));
        }

    Repeater {
        id: markerRepeater
        model: teleportOverlay.directions.length
        delegate: TeleportCircle {
                // compute angle per-index using current rotationAngle; keep them evenly spaced
                worldPoint: teleportOverlay.worldPointForAngle(teleportOverlay.rotationAngle + index * (360.0 / teleportOverlay.directions.length))
            radius: 46
            visible: teleportOverlay.active
            spriteSource: teleportOverlay.teleportSprite
            spriteSize: teleportOverlay.playerSpriteSize
            tileScale: teleportOverlay.tileScale
            x: worldPoint.x * teleportOverlay.tileScale - width / 2
            y: worldPoint.y * teleportOverlay.tileScale - height / 2
            onClicked: function(pt) {
                if (!teleportOverlay.playerObj || typeof teleportOverlay.playerObj.teleportTo !== 'function') return;
                teleportOverlay.playerObj.teleportTo(pt.x, pt.y);
            }
        }
    }

        // Rotation animation: runs while overlay is active
        NumberAnimation {
            id: rotAnim
            target: teleportOverlay
            property: "rotationAngle"
            from: 0; to: 360
            duration: 6000
            loops: Animation.Infinite
            running: teleportOverlay.active
        }

    Connections {
        target: playerObj
        enabled: !!playerObj
        function onPosChanged() { teleportOverlay.forceUpdate(); }
        function onTeleportModeChanged() { teleportOverlay.forceUpdate(); }
        function onSightChanged() { teleportOverlay.forceUpdate(); }
    }

    // Watch dynamic sight mask radius when provided so markers follow the visible circle
    Connections {
        target: sightMaskRef
        enabled: !!sightMaskRef
        function onRadiusChanged() { teleportOverlay.forceUpdate(); }
    }

    function forceUpdate() {
        for (var i = 0; i < markerRepeater.count; ++i) {
            var item = markerRepeater.itemAt(i);
            if (item) {
                var angle = rotationAngle + i * (360.0 / markerRepeater.count);
                item.worldPoint = worldPointForAngle(angle);
            }
        }
    }

    // If parent or mapWrapperRef changes (e.g. mapWrapper x/y or scale changed), update markers
    onParentChanged: forceUpdate()
    onMapWrapperRefChanged: forceUpdate()
}

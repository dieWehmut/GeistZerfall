import QtQuick 2.15
import GeistZerfall 1.0

Item {
    // 统一游戏内 UI 缩放（Android 缩小以适配手机屏幕）
    GameUiScale { id: gameUiScale }
    property real uiScale: gameUiScale.uiScale
    property int tileSize: 512  
    id: tileRoot
    property int tileType: 0
    width: tileSize
    height: tileSize
    // 地图单元整体缩放（跟随全局）
    scale: uiScale

    Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        source: {
            switch (tileType) {
            case -1: return "qrc:/resource/image/bg/battle/default.png"
            case 0: return "qrc:/resource/image/bg/battle/playerSpawn.png"
            case 1: return "qrc:/resource/image/bg/battle/enemy1Spawn.png"
            case 2: return "qrc:/resource/image/bg/battle/enemy2Spawn.png"
            case 3: return "qrc:/resource/image/bg/battle/enemy3Spawn.png"
            case 4: return "qrc:/resource/image/bg/battle/enemy4Spawn.png"
            case 5: return "qrc:/resource/image/bg/battle/enemy5Spawn.png"
            case 6: return "qrc:/resource/image/bg/battle/enemy6Spawn.png"
            case 7: return "qrc:/resource/image/bg/battle/enemy7Spawn.png"
            default: return "qrc:/resource/image/bg/battle/default.png"
            }
        }
    }
}

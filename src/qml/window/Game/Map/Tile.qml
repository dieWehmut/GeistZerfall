import QtQuick 2.15

Item {
    // 统一每格像素大小，默认 64（可根据资源修改）
    property int tileSize: 512  
    id: tileRoot
    property int tileType: 0
    width: tileSize
    height: tileSize

    Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        source: {
            switch (tileType) {
            case -1: return "qrc:/resource/image/bg/battle/default.png"
            case 0: return "qrc:/resource/image/bg/battle/playerSpawn.png"
            case 1: return "qrc:/resource/image/bg/battle/enemy1Spawn.png"
            case 2: return "qrc:/resource/image/bg/battle/enemy2Spawn.png"
            default: return "qrc:/resource/image/bg/battle/default.png"
            }
        }
    }
}

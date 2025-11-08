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
            case -3: return "qrc:/resource/image/mazeExit.png"
            case -2: return "qrc:/resource/image/portalEnd.png"
            case -1: return "qrc:/resource/image/portalStart.png"
            case 0: return "qrc:/resource/image/ruins.png"
            case 1: return "qrc:/resource/image/flame.png"
            case 2: return "qrc:/resource/image/fog.png"
            case 3: return "qrc:/resource/image/flamePhantomBase.png"
            case 4: return "qrc:/resource/image/lurkPhantomBase.png"
            default: return "qrc:/resource/image/ruins.png"
            }
        }
    }
}

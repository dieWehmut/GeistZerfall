import QtQuick

// Shared UI scaling helper for Game view/components
Item {
    id: gameUiScaleRoot
    readonly property bool isAndroid: (Qt.platform && Qt.platform.os ? (Qt.platform.os.toLowerCase() === 'android') : false)
    // Default scale: Android slightly smaller to fit mobile screens; desktop stays 1.0
    readonly property real uiScale: isAndroid ? 0.5 : 1.0
}

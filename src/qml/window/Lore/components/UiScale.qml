import QtQuick

// Shared UI scaling helper for Lore components
// Import this and bind: `property real uiScale: UiScale.uiScale`
// Keeps Android at smaller scale; desktop at 1.0
Item {
    id: uiScaleRoot
    // Detect Android once and expose a stable flag
    readonly property bool isAndroid: (Qt.platform && Qt.platform.os ? (Qt.platform.os.toLowerCase() === 'android') : false)
    // Global scale used by Lore UI components
    // Adjust here to change scale for all components consistently
    readonly property real uiScale: isAndroid ? 0.6 : 1.0
}

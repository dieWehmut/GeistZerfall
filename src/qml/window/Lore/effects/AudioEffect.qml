import QtQuick
import QtMultimedia

// AudioEffect.qml - 音频效果组件
Item {
    id: root

    property string audioSource: ""
    property bool autoPlay: false
    property real volume: 1.0

    MediaPlayer {
        id: player
        source: root.audioSource
        audioOutput: AudioOutput {
            volume: root.volume
        }
        onErrorOccurred: {
            console.log("AudioEffect: error", errorString);
        }
    }

    Component.onCompleted: {
        if (autoPlay && audioSource) {
            player.play();
        }
    }

    function play() {
        player.play();
    }

    function stop() {
        player.stop();
    }
}

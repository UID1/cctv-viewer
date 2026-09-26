import QtQml
import QtQuick
import QtMultimedia
import CCTV_Viewer.Multimedia 1.0

// A wrapper component for QmlAVPlayer used by StreamPool.
// This keeps the player running independently of viewport visibility.
Item {
    id: root
    
    // Make invisible - this just hosts the player
    visible: false
    width: 0
    height: 0

    property alias source: player.source
    property alias avOptions: player.avOptions
    property alias autoPlay: player.autoPlay
    property alias loops: player.loops
    property alias muted: player.muted
    property alias volume: player.volume
    property alias hasAudio: player.hasAudio
    property alias hasVideo: player.hasVideo
    property alias status: player.status
    property alias playbackState: player.playbackState
    property alias bufferProgress: player.bufferProgress

    // The actual player - with multi-sink mode for shared usage
    QmlAVPlayer {
        id: player

        autoLoad: false  // Don't auto-load, we control this via timer
        multiSinkMode: true  // Qt6: Enable multi-sink support for pool sharing

        onStatusChanged: {
            // Qt6: InvalidMedia=7, StalledMedia=3
            if (status === 7 || status === 3) {
                restartTimer.start();
            }
        }
        
        onVideoSinkCountChanged: {
            console.log("StreamPoolPlayer: Sink count changed to", videoSinkCount, "for", source);
        }
    }

    // Delay autoPlay to allow proper initialization (same pattern as original Player.qml)
    Timer {
        id: startTimer
        interval: 50
        repeat: false
        running: true  // Start immediately when component is created
        onTriggered: {
            if (player.source.toString() !== "") {
                player.autoPlay = true;
            }
        }
    }

    Timer {
        id: restartTimer
        interval: 5000
        repeat: false
        onTriggered: {
            if (player.source.toString() !== "") {
                console.log("StreamPoolPlayer: Attempting to restart stream", player.source);
                player.stop();
                player.play();
            }
        }
    }

    function play() { player.play(); }
    function stop() { player.stop(); }
    function pause() { player.pause(); }

    // Expose the player for VideoOutput source binding
    readonly property alias mediaObject: player
}

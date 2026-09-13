import QtQml 2.12
import QtQuick 2.12
import QtMultimedia 5.12
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
    property alias status: player.status
    property alias bufferProgress: player.bufferProgress

    // The actual player - with multi-surface mode for shared usage
    QmlAVPlayer {
        id: player

        autoLoad: false  // Don't auto-load, we control this via timer
        multiSurfaceMode: true  // Enable multi-surface support for pool sharing

        onStatusChanged: {
            // Auto-restart on errors after a delay
            if (status === MediaPlayer.InvalidMedia || status === MediaPlayer.Stalled) {
                restartTimer.start();
            }
        }
        
        onVideoSurfaceCountChanged: {
            console.log("StreamPoolPlayer: Surface count changed to", videoSurfaceCount, "for", source);
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

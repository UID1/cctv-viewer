import QtQml 2.12
import QtQuick 2.12
import QtMultimedia 5.12
import CCTV_Viewer.Multimedia 1.0

FocusScope {
    id: root

    property string color: "black"
    property var avOptions: ({})

    // Stream pool support - when enabled, uses shared players from pool
    property var streamPool: null
    property bool usePool: streamPool !== null && streamPool.enabled
    
    // Source URL for the video
    property url source: ""
    
    // Properties that work with both modes
    property int loops: MediaPlayer.Infinite
    property bool muted: false
    property real volume: 1.0
    readonly property bool hasAudio: _activePlayer ? _activePlayer.hasAudio : false
    
    // Internal: the active player (either pooled or local)
    property var _activePlayer: usePool ? _pooledPlayer : localPlayer
    property var _pooledPlayer: null
    property url _lastPooledSource: ""
    property var _lastPooledOptions: null

    // Acquire pooled player when source changes and pool is enabled
    onSourceChanged: _updatePooledPlayer()
    onAvOptionsChanged: _updatePooledPlayer()
    onUsePoolChanged: _updatePooledPlayer()

    function _updatePooledPlayer() {
        if (usePool && source.toString() !== "") {
            // Release previous pooled player if source changed
            if (_pooledPlayer && (_lastPooledSource.toString() !== source.toString())) {
                streamPool.releasePlayer(_lastPooledSource, _lastPooledOptions);
                _pooledPlayer = null;
            }
            
            // Acquire new player from pool
            if (!_pooledPlayer) {
                var defaultOpts = layoutsCollectionSettings.toJSValue("defaultAVFormatOptions");
                _pooledPlayer = streamPool.acquirePlayer(source, avOptions, defaultOpts);
                _lastPooledSource = source;
                _lastPooledOptions = avOptions;
                
                if (_pooledPlayer) {
                    console.log("Player: Using pooled player for", source);
                }
            }
        } else if (_pooledPlayer) {
            // Pool disabled or no source - release pooled player
            streamPool.releasePlayer(_lastPooledSource, _lastPooledOptions);
            _pooledPlayer = null;
            _lastPooledSource = "";
            _lastPooledOptions = null;
        }
    }

    onVisibleChanged: {
        if (!usePool) {
            // Local player mode - original behavior
            if (visible) {
                if (!timer.running) {
                    timer.start();
                }
            } else {
                timer.stop();
                localPlayer.autoPlay = false;
                localPlayer.stop();
            }
        }
        // In pool mode, visibility doesn't affect playback - pool manages it
    }

    Component.onCompleted: {
        _updatePooledPlayer();
        if (visible && !usePool) {
            timer.start();
        }
    }
    
    Component.onDestruction: {
        // Release pooled player on destruction
        if (_pooledPlayer && streamPool) {
            streamPool.releasePlayer(_lastPooledSource, _lastPooledOptions);
        }
    }

    Timer {
        id: timer
        interval: 50
        onTriggered: {
            if (root.visible && !root.usePool) {
                localPlayer.autoPlay = true;
            }
        }
    }

    Rectangle {
        color: root.color
        border.color: "#101010"
        anchors.fill: parent

        VideoOutput {
            id: videoOutput
            // Source is either the pooled player's mediaObject or local player
            source: root._activePlayer ? (root.usePool ? root._activePlayer.mediaObject : root._activePlayer) : null
            anchors.fill: parent
        }

        Text {
            id: message
            color: "white"
            visible: root._activePlayer ? root._activePlayer.status !== MediaPlayer.Buffered : true
            anchors.centerIn: parent
            text: {
                if (!root._activePlayer) return qsTr("No media");
                switch (root._activePlayer.status) {
                case MediaPlayer.NoMedia:
                    return qsTr("No media");
                case MediaPlayer.Loading:
                    return qsTr("Loading...");
                case MediaPlayer.Loaded:
                    return qsTr("Loaded");
                case MediaPlayer.Stalled:
                    return qsTr("Stalled");
                case MediaPlayer.EndOfMedia:
                    return qsTr("End of media");
                case MediaPlayer.InvalidMedia:
                    return qsTr("Error!");
                default:
                    return "";
                }
            }
        }

        // Local player - only used when pool is disabled
        QmlAVPlayer {
            id: localPlayer

            autoLoad: false
            source: root.usePool ? "" : root.source
            loops: root.loops
            muted: root.muted
            volume: root.volume

            avOptions: {
                var opts = root.avOptions;
                Object.assignDefault(opts, layoutsCollectionSettings.toJSValue("defaultAVFormatOptions"));
                return opts;
            }
        }
        
        // Buffer progress display
        Connections {
            target: root._activePlayer
            function onBufferProgressChanged() {
                if (root._activePlayer && root._activePlayer.status === MediaPlayer.Buffering) {
                    message.text = qsTr("Buffering %1\%").arg(Math.round(root._activePlayer.bufferProgress * 100));
                }
            }
        }
    }

    function play() {
        if (_activePlayer) {
            if (usePool && _activePlayer.mediaObject) {
                _activePlayer.mediaObject.play();
            } else {
                _activePlayer.play();
            }
        }
    }
    
    function stop() {
        if (_activePlayer) {
            if (usePool && _activePlayer.mediaObject) {
                _activePlayer.mediaObject.stop();
            } else {
                _activePlayer.stop();
            }
        }
    }
}

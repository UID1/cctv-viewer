import QtQml
import QtQuick
import QtQuick.Controls
import QtMultimedia
import Qt5Compat.GraphicalEffects  // Qt6: GraphicalEffects moved to Qt5Compat
import CCTV_Viewer.Multimedia 1.0

FocusScope {
    id: root

    property string color: "black"
    property var avOptions: ({})
    
    // Status overlay colors
    property color loadingIconColor: "#21576b"  // RGB(33, 87, 107) - dark teal
    property color errorIconColor: "#993025"    // RGB(153, 48, 37) - reddish
    property color logTextColor: "#666666"      // Dark grey for log text
    property color scrollbarColor: "#444444"    // Dark grey for scrollbar
    
    // Log buffer for this viewport (using ListModel to avoid memory leaks)
    property int maxLogLines: 100
    
    ListModel {
        id: logModel
    }
    
    function addLogEntry(message) {
        var timestamp = Qt.formatTime(new Date(), "hh:mm:ss");
        logModel.append({"text": timestamp + " " + message});
        while (logModel.count > maxLogLines) {
            logModel.remove(0);  // Remove oldest entry
        }
    }
    
    function clearLog() {
        logModel.clear();
    }

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
    onSourceChanged: {
        if (source.toString() !== "") {
            addLogEntry("Source set: " + source.toString());
        }
        _updatePooledPlayer();
    }
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
            // Qt6: No source property - we bind player's videoSink to this output's videoSink
            anchors.fill: parent
        }
        
        // Qt6: Bind pooled player's videoSink to VideoOutput when pool is active
        Binding {
            target: root._pooledPlayer ? root._pooledPlayer.mediaObject : null
            property: "videoSink"
            value: root.usePool && root.visible ? videoOutput.videoSink : null
            when: root.usePool && root._pooledPlayer && root._pooledPlayer.mediaObject
        }

        // Status overlay - visible when not playing
        Item {
            id: statusOverlay
            anchors.fill: parent
            // Qt6: Check playbackState for reliable "is playing" detection
            visible: root._activePlayer ? root._activePlayer.playbackState !== MediaPlayer.PlayingState : true
            
            // Determine if this is an error state
            readonly property bool isError: root._activePlayer && 
                root._activePlayer.status === MediaPlayer.InvalidMedia
            
            // Buffer progress for display
            readonly property int bufferPercent: root._activePlayer ? 
                Math.round(root._activePlayer.bufferProgress * 100) : 0
            
            // Status message text
            readonly property string statusText: {
                if (!root._activePlayer) return qsTr("No media");
                switch (root._activePlayer.status) {
                case MediaPlayer.NoMedia:
                    return qsTr("No media");
                case MediaPlayer.Loading:
                    return qsTr("Opening stream");
                case MediaPlayer.Loaded:
                    return qsTr("Loaded");
                case MediaPlayer.Buffering:
                    return qsTr("Buffering %1%").arg(statusOverlay.bufferPercent);
                case MediaPlayer.Stalled:
                    return qsTr("Stalled");
                case MediaPlayer.EndOfMedia:
                    return qsTr("End of media");
                case MediaPlayer.InvalidMedia:
                    return qsTr("Error");
                default:
                    return "";
                }
            }
            
            Column {
                anchors.centerIn: parent
                spacing: 8
                width: parent.width * 0.8
                
                // Icon
                Item {
                    width: 96
                    height: 96
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    Image {
                        id: statusIcon
                        anchors.fill: parent
                        source: statusOverlay.isError ? "qrc:/images/error.svg" : "qrc:/images/loading.svg"
                        fillMode: Image.PreserveAspectFit
                        visible: false  // Hidden, used as source for ColorOverlay
                    }
                    
                    ColorOverlay {
                        anchors.fill: statusIcon
                        source: statusIcon
                        color: statusOverlay.isError ? root.errorIconColor : root.loadingIconColor
                    }
                }
                
                // Message text
                Text {
                    id: message
                    color: "white"
                    text: statusOverlay.statusText
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.pixelSize: 28
                }
                
                // Spacer
                Item { width: 1; height: 8 }
                
                // Log textbox (using ListView with ListModel for memory efficiency)
                Rectangle {
                    id: logContainer
                    width: parent.width
                    height: Math.min(parent.parent.height * 0.4, 150)
                    color: "black"
                    border.color: root.scrollbarColor
                    border.width: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: logModel.count > 0
                    
                    ListView {
                        id: logListView
                        anchors.fill: parent
                        anchors.margins: 6
                        anchors.leftMargin: 16  // Space for scrollbar
                        clip: true
                        model: logModel
                        boundsBehavior: Flickable.StopAtBounds
                        
                        delegate: Text {
                            width: logListView.width
                            wrapMode: Text.Wrap
                            color: root.logTextColor
                            font.family: "monospace"
                            font.pixelSize: 10
                            text: model.text
                        }
                        
                        // Auto-scroll to bottom when new items added
                        onCountChanged: {
                            Qt.callLater(function() {
                                logListView.positionViewAtEnd();
                            });
                        }
                    }
                    
                    // Custom scrollbar
                    Rectangle {
                        id: scrollbarTrack
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 4
                        width: 8
                        radius: 4
                        color: Qt.rgba(0.2, 0.2, 0.2, 0.5)  // Subtle dark background
                        
                        Rectangle {
                            id: scrollbarHandle
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 6
                            radius: 3
                            color: root.scrollbarColor
                            
                            // Calculate handle height proportional to visible area
                            property real contentRatio: (logListView.contentHeight > 0) 
                                ? Math.min(1, logListView.height / logListView.contentHeight) 
                                : 1
                            height: Math.max(20, (parent.height - 4) * contentRatio)
                            
                            // Calculate handle position  
                            property real scrollRange: Math.max(1, logListView.contentHeight - logListView.height)
                            property real posRatio: logListView.contentY / scrollRange
                            y: 2 + (parent.height - height - 4) * Math.min(1, Math.max(0, posRatio))
                        }
                    }
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
            
            // Qt6: Bind videoSink to VideoOutput's videoSink when this player is active
            videoSink: (!root.usePool && root.visible) ? videoOutput.videoSink : null

            avOptions: {
                var opts = root.avOptions;
                Object.assignDefault(opts, layoutsCollectionSettings.toJSValue("defaultAVFormatOptions"));
                return opts;
            }
        }
        
        // Player event connections for logging
        Connections {
            target: root._activePlayer
            
            function onStatusChanged() {
                if (!root._activePlayer) return;
                var status = root._activePlayer.status;
                var url = root.source.toString();
                
                switch (status) {
                case MediaPlayer.Loading:
                    root.addLogEntry("Connecting: " + url);
                    break;
                case MediaPlayer.Loaded:
                    root.addLogEntry("Stream loaded: " + url);
                    break;
                case MediaPlayer.Buffered:
                    root.addLogEntry("Playing: " + url);
                    break;
                case MediaPlayer.Stalled:
                    root.addLogEntry("Stream stalled: " + url);
                    break;
                case MediaPlayer.EndOfMedia:
                    root.addLogEntry("End of stream: " + url);
                    break;
                case MediaPlayer.InvalidMedia:
                    root.addLogEntry("Invalid media: " + url);
                    break;
                case MediaPlayer.NoMedia:
                    root.addLogEntry("No media source configured");
                    break;
                }
            }
            
            function onBufferProgressChanged() {
                if (root._activePlayer && root._activePlayer.status === MediaPlayer.Buffering) {
                    var percent = Math.round(root._activePlayer.bufferProgress * 100);
                    if (percent % 25 === 0 && percent > 0) {  // Log at 25%, 50%, 75%, 100%
                        root.addLogEntry("Buffering: " + percent + "%");
                    }
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

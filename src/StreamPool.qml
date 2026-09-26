import QtQml
import QtQuick
import QtMultimedia
import CCTV_Viewer.Multimedia 1.0

// StreamPool manages a collection of persistent video streams that remain active
// across preset switches. Streams are identified by their URL and AVFormatOptions.
// Using Item (invisible) instead of QtObject so it can properly parent the player Items.
Item {
    id: root
    
    // Make invisible - this is just a container for player objects
    visible: false
    width: 0
    height: 0

    // Whether the pool is enabled. When disabled, acquirePlayer returns null
    // and viewports should create their own players.
    property bool enabled: false

    // Internal storage for players and their reference counts
    property var _players: ({})      // key -> { player: QmlAVPlayer, refCount: int, component: Component }
    property var _playerComponent: null

    // Generate a unique key for a stream based on URL and options
    function _generateKey(url, avOptions) {
        if (!url || url.toString() === "") {
            return "";
        }
        
        // Sort options keys for consistent key generation
        var optionsStr = "";
        if (avOptions && typeof avOptions === "object") {
            var keys = Object.keys(avOptions).sort();
            for (var i = 0; i < keys.length; i++) {
                optionsStr += keys[i] + "=" + avOptions[keys[i]] + ";";
            }
        }
        return url.toString() + "|" + optionsStr;
    }

    // Acquire a player for the given URL and options.
    // Returns the QmlAVPlayer instance, or null if pool is disabled or URL is empty.
    // Caller must call releasePlayer when done.
    function acquirePlayer(url, avOptions, defaultAVOptions) {
        if (!enabled) {
            return null;
        }

        var key = _generateKey(url, avOptions);
        if (key === "") {
            return null;
        }

        if (_players[key]) {
            // Player exists, increment reference count
            _players[key].refCount++;
            console.log("StreamPool: Reusing player for", url, "refCount:", _players[key].refCount);
            return _players[key].player;
        }

        // Create new player
        if (!_playerComponent) {
            _playerComponent = Qt.createComponent("StreamPoolPlayer.qml");
            if (_playerComponent.status !== Component.Ready) {
                console.error("StreamPool: Failed to create player component:", _playerComponent.errorString());
                return null;
            }
        }

        var mergedOptions = {};
        // Apply default options first
        if (defaultAVOptions && typeof defaultAVOptions === "object") {
            for (var defKey in defaultAVOptions) {
                mergedOptions[defKey] = defaultAVOptions[defKey];
            }
        }
        // Override with specific options
        if (avOptions && typeof avOptions === "object") {
            for (var optKey in avOptions) {
                mergedOptions[optKey] = avOptions[optKey];
            }
        }

        var player = _playerComponent.createObject(root, {
            "source": url,
            "avOptions": mergedOptions,
            "loops": MediaPlayer.Infinite
            // Note: autoPlay is handled by StreamPoolPlayer's internal timer
        });

        if (!player) {
            console.error("StreamPool: Failed to create player instance for", url);
            return null;
        }

        _players[key] = {
            player: player,
            refCount: 1,
            url: url
        };

        console.log("StreamPool: Created new player for", url);
        return player;
    }

    // Release a player. Decrements reference count and destroys player when count reaches 0.
    function releasePlayer(url, avOptions) {
        var key = _generateKey(url, avOptions);
        if (key === "" || !_players[key]) {
            return;
        }

        _players[key].refCount--;
        console.log("StreamPool: Released player for", url, "refCount:", _players[key].refCount);

        if (_players[key].refCount <= 0) {
            // Delay destruction slightly to handle rapid URL changes
            var playerEntry = _players[key];
            delete _players[key];
            
            // Use a timer to delay destruction, allowing for re-acquisition
            Qt.callLater(function() {
                if (playerEntry.player) {
                    console.log("StreamPool: Destroying player for", playerEntry.url);
                    playerEntry.player.stop();
                    playerEntry.player.destroy();
                }
            });
        }
    }

    // Get a player without incrementing reference count (for checking existence)
    function getPlayer(url, avOptions) {
        var key = _generateKey(url, avOptions);
        if (key === "" || !_players[key]) {
            return null;
        }
        return _players[key].player;
    }

    // Get the number of active streams in the pool
    function streamCount() {
        return Object.keys(_players).length;
    }

    // Debug: list all active streams
    function listStreams() {
        var streams = [];
        for (var key in _players) {
            streams.push({
                url: _players[key].url,
                refCount: _players[key].refCount
            });
        }
        return streams;
    }

    // Clean up all players (call on application shutdown or when disabling pool)
    function clear() {
        for (var key in _players) {
            if (_players[key].player) {
                _players[key].player.stop();
                _players[key].player.destroy();
            }
        }
        _players = {};
        console.log("StreamPool: Cleared all players");
    }

    Component.onDestruction: {
        clear();
    }
}

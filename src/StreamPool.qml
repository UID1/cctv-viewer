import QtQml
import QtQuick
import QtMultimedia
import CCTV_Viewer.Core 1.0
import CCTV_Viewer.Multimedia 1.0
import CCTV_Viewer.Utils 1.0

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

    property bool memoryWatchdogEnabled: true
    property int memoryWatchdogIntervalMs: 60000
    property int memoryBudgetAnonKb: 49152
    property int memoryWarmupMs: 180000

    // Internal storage for players and their reference counts
    property var _players: ({})      // key -> { player, refCount, url, createdAt }
    property var _playerComponent: null
    property real _warmupStartedAt: 0
    property int _baselineAnonKb: 0
    property bool _loggedReadFail: false
    property bool _exitRequested: false
    property bool _trimmedWhileOver: false

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
            url: url,
            createdAt: Date.now()
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

    onEnabledChanged: {
        _warmupStartedAt = 0;
        _baselineAnonKb = 0;
        _loggedReadFail = false;
        _exitRequested = false;
        _trimmedWhileOver = false;
        if (enabled && memoryWatchdogEnabled)
            console.log("StreamPool: memory watchdog on, interval", memoryWatchdogIntervalMs,
                        "ms, warmup", memoryWarmupMs, "ms, budget", memoryBudgetAnonKb, "KB",
                        Context.config.exitOnMemoryTrip ? "exit-on-trip" : "log-only");
    }

    Timer {
        id: memoryWatchdogTimer
        interval: root.memoryWatchdogIntervalMs
        repeat: true
        running: root.enabled && root.memoryWatchdogEnabled
        onTriggered: root._watchMemory()
    }

    function _watchMemory() {
        if (!root.enabled || !root.memoryWatchdogEnabled)
            return;

        var anon = SystemInfo.rssAnonKb();
        var vm = SystemInfo.vmRssKb();
        if (anon <= 0) {
            if (!root._loggedReadFail) {
                console.log("StreamPool: memory RssAnon read failed (got", anon,
                            "KB). Watchdog idle until /proc/self/status is readable.");
                root._loggedReadFail = true;
            }
            return;
        }
        root._loggedReadFail = false;

        if (root._warmupStartedAt === 0) {
            root._warmupStartedAt = Date.now();
            console.log("StreamPool: memory warmup start. RssAnon", anon, "KB VmRSS", vm, "KB",
                        "for", root.memoryWarmupMs / 1000, "s");
        }

        var warmed = Date.now() - root._warmupStartedAt;
        if (warmed < root.memoryWarmupMs) {
            console.log("StreamPool: memory warmup", Math.round(warmed / 1000), "/",
                        root.memoryWarmupMs / 1000, "s. RssAnon", anon, "KB VmRSS", vm, "KB");
            return;
        }

        if (root._baselineAnonKb <= 0) {
            root._baselineAnonKb = anon;
            console.log("StreamPool: memory baseline RssAnon=" + anon + " KB VmRSS=" + vm
                        + " KB budget=" + root.memoryBudgetAnonKb + " KB tripwire="
                        + (anon + root.memoryBudgetAnonKb) + " KB");
        }

        var trip = root._baselineAnonKb + root.memoryBudgetAnonKb;
        var delta = anon - root._baselineAnonKb;
        if (Context.config.memoryLog) {
            console.log("StreamPool: memory RssAnon=" + anon + " KB baseline=" + root._baselineAnonKb
                        + " KB delta=" + delta + " KB tripwire=" + trip + " KB VmRSS=" + vm + " KB");
            console.log("StreamPool: memory heap " + SystemInfo.mallocHeapInfo());
        }

        if (anon <= trip) {
            root._trimmedWhileOver = false;
            return;
        }

        console.log("StreamPool: memory tripwire RssAnon=" + anon + " KB baseline="
                    + root._baselineAnonKb + " KB tripwire=" + trip + " KB");

        if (!root._trimmedWhileOver) {
            root._trimmedWhileOver = true;
            var released = SystemInfo.trimMallocHeap();
            anon = SystemInfo.rssAnonKb();
            vm = SystemInfo.vmRssKb();
            delta = anon - root._baselineAnonKb;
            console.log("StreamPool: memory trim malloc_trim=" + released
                        + " RssAnon=" + anon + " KB baseline=" + root._baselineAnonKb
                        + " KB delta=" + delta + " KB tripwire=" + trip
                        + " KB VmRSS=" + vm + " KB");
            if (anon <= trip) {
                root._trimmedWhileOver = false;
                return;
            }
            console.log("StreamPool: memory mallinfo2 " + SystemInfo.mallocHeapInfo());
        }

        if (!Context.config.exitOnMemoryTrip)
            return;
        if (root._exitRequested)
            return;
        root._exitRequested = true;
        console.log("StreamPool: memory tripwire, exiting 75 for systemd restart");
        Qt.exit(75);
    }

    Component.onDestruction: {
        clear();
    }
}

import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtMultimedia

Window {
    id: root
    width: 1280
    height: 720
    visible: true
    title: "RTMP persistent streams + carousel RSS repro"

    // More live streams than visible tiles. Decode stays running when hidden;
    // the carousel only attaches/detaches VideoOutput (single sink per MediaPlayer).
    readonly property var urls: [
        (typeof streamUrl0 !== "undefined") ? streamUrl0 : "rtmp://live.a71.ru/demo/0",
        (typeof streamUrl1 !== "undefined") ? streamUrl1 : "rtmp://live.a71.ru/demo/1"
    ]
    property int preset: 0
    property int rssMinute: 0

    function logRss(reason) {
        if (typeof ProcessRss === "undefined" || !ProcessRss) {
            console.log("RSS: ProcessRss not available (build and run ./rssrepro, not qml6)")
            return
        }
        console.log("RSS min", rssMinute, "/" + reason + "/", ProcessRss.snapshot())
    }

    function outputForStream(index) {
        if (!tiles.count)
            return null
        var shown = (preset === 0 && index < 3) || (preset === 1 && index >= 3)
        return shown ? tiles.itemAt(index % 3) : null
    }

    // Six players always Playing (three copies of each URL).
    Repeater {
        model: 6
        Item {
            width: 0
            height: 0
            MediaPlayer {
                source: root.urls[index % 2]
                audioOutput: AudioOutput { muted: true }
                loops: MediaPlayer.Infinite
                autoPlay: true
                videoOutput: root.outputForStream(index)
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        Repeater {
            id: tiles
            model: 3
            VideoOutput {
                Layout.fillWidth: true
                Layout.fillHeight: true
                fillMode: VideoOutput.PreserveAspectCrop
            }
        }
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: {
            root.preset = 1 - root.preset
            root.logRss("carousel preset=" + root.preset)
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: false
        onTriggered: root.logRss("start")
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            root.rssMinute += 1
            root.logRss("tick")
        }
    }
}

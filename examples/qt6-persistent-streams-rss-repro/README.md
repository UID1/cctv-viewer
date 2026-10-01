Qt 6 RSS reproducer: persistent RTMP streams + carousel
=======================================================

What this models
----------------
More live cameras than on-screen tiles. Decode must stay running when a
tile is hidden. A 15 s carousel only attaches or detaches
MediaPlayer.videoOutput.

Stock MediaPlayer has a single sink, so this uses one player per tile
(three copies of each source).

How to run
----------
  cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
  cmake --build build
  ./build/rssrepro 2>&1 | tee rssrepro.log

With no arguments it uses rtmp://live.a71.ru/demo/0 and .../demo/1.
Needs `ffmpeg` on PATH. Distro Qt FFmpeg cannot open those URLs as a
client (it sets avformat "timeout", which implies RTMP listen —
QTBUG-144996; ffplay is fine). This binary remuxes each RTMP URL to a
local multicast MPEG-TS and MediaPlayer reads that.

  Relaying rtmp://live.a71.ru/demo/0 -> udp://239.1.71.1:18901?...

Then you should see video (not a white window) and RSS lines:

  qml: RSS min 12 /tick/ pid=12345  VmRSS=... kB  RssAnon=... kB  RssFile=... kB

Local files skip the relay:

  ./build/rssrepro /path/to/a.mp4 /path/to/b.mp4

Do not set QT_MEDIA_BACKEND=gstreamer unless that plugin is installed.
The FFmpeg Qt multimedia backend is what this was built against.

`qml6 main.qml` has no /proc reader and no RTMP relay.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

# CCTV Viewer

This is a fork of [CCTV Viewer](https://github.com/iEvgeny/cctv-viewer) by iEvgeny, licensed under GPL v3. It views several camera streams at once and is meant to stay up as a fullscreen kiosk.

The fork adds a stream pool so carousel switches reuse an open connection which makes videostream switches seamless without having to wait for cameras to reconnect, custom aspect ratios, panel locks, a graphical per-viewport status overlay with useful information for troubleshooting, a Debian package, and a systemd user service that restarts the process after a crash for reliable 24/7 operation. It builds with Qt 6 and jemalloc with improved memory management. The feature list and the items left out of this release are in [CHANGELOG.md](CHANGELOG.md).

## Build

Install the compiler, Qt 6, FFmpeg, and jemalloc development packages:

```bash
sudo apt install build-essential cmake pkg-config \
  qt6-base-dev qt6-declarative-dev qt6-multimedia-dev qt6-tools-dev qt6-5compat-dev \
  libavformat-dev libavcodec-dev libavutil-dev libswscale-dev libswresample-dev libavdevice-dev \
  libjemalloc-dev
```

CMake requires Qt 6. Configure and build out of tree:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
./build/cctv-viewer
```

`--full-screen` starts in fullscreen. `--exit-on-memory-trip` makes the memory watchdog exit with status 75 when a purge does not bring anonymous memory back under budget. This is an extra safety measure put in place to protect against uncontrolled memory leaks that may accumulate over longer time-frames. `--memory-log` prints the per-minute RssAnon and heap lines. The service passes that flag; a desktop launch without it stays quiet.

## Debian package

From the repository root, with the build dependencies in `debian/control` installed:

```bash
sudo apt install devscripts debhelper
dpkg-buildpackage -us -uc -b
sudo apt install ../cctv-viewer_*.deb
```

The package installs `/usr/bin/cctv-viewer`, a desktop entry, the icon, and a systemd user unit. It does not enable the service.

## Run as a service

The unit starts after the graphical session, runs fullscreen, and restarts on failure, including the watchdog exit status 75.

```bash
systemctl --user enable --now cctv-viewer.service
systemctl --user status cctv-viewer.service
```

Application output goes to the user journal:

```bash
journalctl --user -u cctv-viewer.service -f
```

## Configuration

Settings are stored in `~/.config/CCTV Viewer/CCTV Viewer.conf`. The package ships an example:

```bash
mkdir -p ~/.config/CCTV\ Viewer
cp /usr/share/doc/cctv-viewer/examples/cctv-viewer.conf \
   ~/.config/CCTV\ Viewer/CCTV\ Viewer.conf
```

## Custom aspect ratios

A ratio such as 32:27 is a property of the tile. This aspect ratio will fill up the viewport in a 3x2 grid of 6 viewports in a standard 16:9 aspect ratio screen. The picture can be given that display aspect ratio before it reaches the viewer, so the grid tile and the stream agree. One way is a third go2rtc stream that leaves the camera's main and sub streams unchanged for Frigate.

go2rtc keeps `max` and `max_sub` as the camera publishes them, and adds `max_cctv`. The `raw=-aspect 32:27` flag sets the display aspect ratio on that stream:

```yaml
go2rtc:
  rtsp:
    listen: ":8554"
  streams:
    max:
      - rtsp://admin:YOUR_PASSWORD_HERE@169.254.202.101:554/cam/realmonitor?channel=1&subtype=0
    max_sub:
      - rtsp://admin:YOUR_PASSWORD_HERE@169.254.202.101:554/cam/realmonitor?channel=1&subtype=1
    max_cctv:
      - "ffmpeg:max_sub#video=h264#audio=copy#raw=-aspect 32:27"
```

Frigate records from `max` and runs detection on `max_sub`:

```yaml
max:
  enabled: false # Keep false until installed and password is set
  friendly_name: Dahua IPC-HFW2431T-ZS - River View Camera
  birdseye:
    enabled: false
  ffmpeg:
    inputs:
      # High resolution main stream
      - path:
          rtsp://127.0.0.1:8554/max
        roles:
          - record
      # Low resolution sub stream for object detection
      - path:
          rtsp://127.0.0.1:8554/max_sub
        roles:
          - detect
```

Point cctv-viewer at the aspect-ratio stream: `rtsp://127.0.0.1:8554/max_cctv`.

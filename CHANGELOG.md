# Changelog

This file describes this fork of [CCTV Viewer](https://github.com/iEvgeny/cctv-viewer). The version in the tree is 0.2.1. Entries below are included in that tree and are not a new release number.

## Unreleased

### Stream layout

- A stream pool keeps one player open per stream. Carousel and preset changes attach viewports to that player, so a switch does not wait for the camera to reconnect.
- The same URL shares one decoder across every viewport that shows it.
- Aspect ratios can be edited in the sidebar. The built-in set includes 32:27, for six tiles on a 16:9 screen.
- Panel locks and edit-mode protection keep a kiosk from changing layouts or presets by accident.
- Clicking a viewport still opens that tile on its own. That zoomed view is separate from the grid aspect ratio.

### Kiosk operation

- A systemd user service starts the viewer with the graphical session, in fullscreen. It restarts the process after a crash.
- A memory watchdog inside the viewer reads `RssAnon` once a minute. Past its budget it asks jemalloc to purge arenas. With `--exit-on-memory-trip`, if usage is still over budget, the process exits 75 and systemd starts a new one. The service unit passes that flag.
- `--memory-log` prints the per-minute RssAnon and heap lines. The service passes it. Without the flag those samples stay out of the log; the tripwire lines still print.
- A Debian package installs the program, the desktop entry, the icon, and the user service.

### Viewport status

- Each viewport has a status overlay: an icon and a text box for that camera's log. The panel is translucent. The icon and the text stay opaque.

### Platform

- The application builds against Qt 6. Qt 5 is not a supported configuration of this tree.
- The binary links jemalloc so long runs can return freed pages. The watchdog purge uses that allocator.

### Sidebar

- The sidebar header shows an avatar and `username@hostname`, and a logo above the collapse control.
- A Recordings panel has a Review button that opens a browser.

## Deferred

These are not in this release.

- Crop a 16:9 frame to a 32:27 tile in the grid, and show the whole frame in the zoomed view. Streams that are already cropped to the tile shape, for example by Frigate go2rtc, do not need this.
- More detail in the status text box than the current media-status line. The journal already has the detail used to investigate a camera.
- Motion events and alarms from a Frigate server drawn in the GUI. This viewer stays a display; those events are reported elsewhere.

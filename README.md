# DynaNotch

A feature-rich macOS notch utility that transforms your MacBook's notch (or any Mac's menu bar) into a dynamic, interactive hub.

**DynaNotch** is a GPL v3 fork of [Boring.Notch](https://github.com/TheBoredTeam/boring.notch) with additional features and enhancements.

## Features

### Core (from Boring.Notch)
- **Now Playing** — Album art, playback controls, music visualizer, shuffle/repeat
- **File Shelf** — Drag & drop files into the notch for quick access
- **Calendar & Reminders** — Upcoming events and reminders at a glance
- **Battery Indicator** — Live battery status with charging notifications
- **HUD Replacement** — Custom volume/brightness HUD overlays
- **Mirror** — Quick camera preview from the notch
- **Download Progress** — Safari/Chrome download tracking
- **Multi-Display** — Show on all displays simultaneously

### DynaNotch Additions
- **External Display Support** — Floating tab mode for monitors without a notch
- **Live Lyrics** — Synced lyrics from Apple Music and LRCLIB
- **Pomodoro Timer** — Focus timer with work/break cycles, weekly stats, and notifications
- **Quick Notes** — Jot down notes directly from the notch
- **Weather Widget** — Current temperature and conditions in the header
- **System Monitor** — CPU, RAM, network, and disk usage indicators
- **Animation Styles** — Classic, Spring, or Snappy animation presets
- **Configurable Tab Persistence** — Notch remembers your last active tab

## Installation

### Requirements
- macOS **14 Sonoma** or later
- Apple Silicon or Intel Mac

### Download
Download the latest release from the [Releases](https://github.com/BogacUlker/DynaNotch/releases) page.

### Build from Source
```bash
git clone https://github.com/BogacUlker/DynaNotch.git
cd DynaNotch
open boringNotch.xcodeproj
```
Build and run with Xcode 15+.

## Attribution

DynaNotch is built on top of [Boring.Notch](https://github.com/TheBoredTeam/boring.notch) by The Bored Team. Huge thanks to the original creators and contributors.

### Notable Projects
- **[MediaRemoteAdapter](https://github.com/ungive/mediaremote-adapter)** — Now Playing source support for macOS 15.4+
- **[NotchDrop](https://github.com/Lakr233/NotchDrop)** — Inspiration for the Shelf feature

### Third-Party Libraries
- [Defaults](https://github.com/sindresorhus/Defaults) — User defaults wrapper
- [Sparkle](https://sparkle-project.org/) — Auto-update framework
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) — Global keyboard shortcuts
- [LRCLIB](https://lrclib.net/) — Open-source lyrics API

## License

This project is licensed under the **GNU General Public License v3.0** — see the [LICENSE](LICENSE) file for details.

DynaNotch is a fork of Boring.Notch, which is also GPL v3 licensed. All modifications and additions are released under the same license.

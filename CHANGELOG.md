# Changelog

All notable changes to this project will be documented in this file.

## [1.1] - 2026-02-18

### Final HTML Version
This release marks the final version of the HTML5-based implementation of Douluo Bridge, wrapped in an iOS project.

### Added
- **Core Game Engine**: HTML5 Canvas implementation of the game (`douluo_ios.html`).
- **Audio System**: JavaScript-based audio engine (`audio_engine.js`) and MIDI data (`midi_data.js`).
- **iOS Wrapper**: Basic `WKWebView` integration to run the HTML game on iOS devices.
- **Assets**: Basic game assets and MIDI files.

### Note
- Future versions (1.2+) are rewritten as pure native iOS apps using SpriteKit and Swift. This branch (`v1.1`) preserves the legacy HTML implementation.

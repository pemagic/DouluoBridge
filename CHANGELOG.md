# Changelog

All notable changes to this project will be documented in this file.

## [1.2] - 2026-02-18

### Added
- **Visuals**:
    - Integrated 10 distinct level-specific ink-wash style backgrounds (`bg_level_1` to `bg_level_10`).
    - Added "Pause" button (⏸) to the top-right UI for gameplay suspension.
- **Audio**:
    - Expanded BGM tracks from short loops to full-length guzheng compositions (60-80 notes each).
    - Implemented per-level BGM with distinct BPMs (Range: 80-145 BPM) and styles (Heroic, Tragic, Ethereal, etc.).
    - Ensured seamless BGM transition upon level completion.
- **Gameplay**:
    - **Enemy AI**: Added random jumping behavior (1% chance when grounded) to navigate platforms.
    - **Enemy Combat**: Implemented 360° aimed shooting for Scout, Heavy, and Sniper enemies (projectiles now track player position).
    - Added cooldown visualization to the Dash (杀) button.

### Changed
- **UI Improvements**:
    - Repositioned Level Name label below Weapon Level for better readability and darkened text color.
    - Moved "KILLS" counter to avoid overlap with top-right control buttons.
    - Increased opacity of virtual control buttons (0.25 -> 0.7) for better visibility against backgrounds.
    - Removed circular styling (border/background) from Pause and Home buttons for a cleaner look.
    - Hid SpriteKit debug statistics (node count, FPS) by default.
- **Camera**:
    - Adjusted camera Y-offset (+200) to keep the player character visible while maintaining a cinematic view of the new backgrounds.
- **Platforming**:
    - Adjusted platform generation height to align better with the new camera perspective.

### Removed
- Removed the dedicated "Ultimate" (必) button (Ultimate is now triggered automatically or via other mechanics).
- Removed temporary "Cheat" (☠️) button used for testing.
- Fixed bug where BGM would not switch correctly between levels.

# Changelog
## [1.0.8] - 2026-04-21
### Fixed
- Fixed a load error that occurred on addon reload and when entering the world

## [1.0.7] - 2026-04-20
### Added
- Minimap button — appears in the standard minimap addon button list; left-click opens the config panel
- Lock/Unlock button in the config panel — toggles frame drag mode without needing slash commands; label reflects the current state when the panel opens

## [1.0.6] - 2026-04-13
### Added
- Addon icon is now shown in the addon list

### Changed
- Button colors now always match the player's own chat color settings from Interface Options
- Changing chat colors in Interface Options instantly repaints the buttons without requiring a reload

## [1.0.5] - 2026-04-13
### Added
- Vertical layout option: new "Vertical layout" checkbox in the config panel to switch the button bar orientation

### Changed
- Config panel is now always shown in Blizzard Interface Options, regardless of whether ElvUI is loaded

## [1.0.4] - 2026-04-09
### Added
- Config UI opened with `/ecb` or `/ecb config`
- Bubble Size and Bubble Spacing sliders with live preview
- OK saves, Cancel restores previous values, Defaults resets to addon defaults
- Config panel available in Interface Options for non-ElvUI users
- Existing settings are preserved automatically when upgrading from older versions

### Changed
- Channel buttons are now clean circular dots with no visible square frame behind them
- Config window restyled to a dark minimal look on both ElvUI and standard clients
- Sliders and action buttons (OK, Cancel, Defaults) now use the same dark flat style

## [1.0.3] - 2026-04-08
### Added
- ElvUI visual integration: buttons automatically adopt a flat, minimal style when ElvUI is loaded

## [1.0.2] - 2026-04-08
### Fixed
- Buttons now render as perfect circles with no visible square edges

## [1.0.1] - 2026-04-07
### Added
- Movable frame — drag the button bar anywhere on screen
- `/ecb lock` and `/ecb unlock` slash commands to toggle drag mode
- Yellow tint overlay visible while frame is unlocked

## [1.0.0] - 2026-04-07
### Added
- Initial release
- Circular chat channel shortcut buttons next to the chat tab
- Support for Say, Guild, Officer, Party, Raid, Instance Chat channels
- Buttons auto-hide when channel is unavailable
- ElvUI compatibility

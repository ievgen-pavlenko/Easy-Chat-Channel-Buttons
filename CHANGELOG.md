# Changelog

## [1.1.0] - 2026-08-15
### Added
- Account-wide Favorites for numbered zone and player-created chats such as General, Trade, Services, and LocalDefense; Community chats are not included
- Numbered-channel buttons that keep the correct `/N` after zone changes, use the player's chat colors, and return automatically when a favorite becomes available again
- `Custom Channels` manager for adding favorites from channels available in the current location or by entering a channel name or active `/N`; it prevents duplicates, confirms changes, and supports Settings `Cancel`
- Automatic first-time setup that adds available numbered channels and waits until later if none are available
- Optional button labels showing built-in chat letters, current channel numbers, or the first character of a Prepared Phrase tooltip, including non-English text and emoji
- Optional larger click areas for small bubbles without changing the visible circle size

### Changed
- Active highlighting now follows the exact numbered channel when switching between Favorites
- Built-in chats, numbered-channel Favorites, and Prepared Phrases are now separated into clear groups using `Group Spacing`, while existing spacing preferences are preserved
- Reorganized Settings into compact `Appearance` and `Accessibility` sections plus a two-column `Built-in Buttons` list where checked means visible and labels are clickable
- Unified `Custom Channels` and Import/Export window controls with `X`, `Close`, and `Escape` behavior
- Empty phrase and channel lists now show clear guidance, and button tooltips now include consistent action hints
- Made long Prepared Phrase import and export text vertically scrollable

## [1.0.16] - 2026-08-14
### Added
- Configurable prepared phrase bubbles with custom text, tooltip, and color
- Phrase insertion at the current chat cursor without automatically sending the message
- Configurable phrase group position before/after channel bubbles
- Configurable 10–60 px spacing between phrase and channel groups
- Prepared phrase export/import with validation and replacement confirmation

## [1.0.15] - 2026-08-01
- Added support for World of Warcraft Retail 12.1.0
- Improved drag and positioning usability for the button bar
- Added "Reset Position" option in settings to restore the bar to its default location

## [1.0.14] - 2026-05-17
### Fixed
- Added support for WoW interface version 12.0.7

## [1.0.13] - 2026-05-12
- Fix version

## [1.0.12] - 2026-05-10
### Fixed
- Button size and spacing settings are now saved correctly and no longer reset after logging out or reloading the UI

## [1.0.11] - 2026-05-10
### Added
- Active channel indicator: while the chat box is open, the button for the currently active channel is highlighted with a bright ring; other buttons dim slightly. The highlight updates instantly when cycling through channels and disappears when the chat box closes.

## [1.0.10] - 2026-04-27
### Added
- Right-clicking the minimap button now shows or hides the button bar; the state is remembered across sessions
- Two new channel buttons: **Emote** (`/em`) and **Battleground** (`/bg`)
- Per-channel visibility overrides: a "Hide Channels" section in the config panel lets players permanently suppress any individual channel button (e.g. Yell, Officer) regardless of game state

## [1.0.9] - 2026-04-22
### Changed
- Added support for WoW interface version 12.0.5

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

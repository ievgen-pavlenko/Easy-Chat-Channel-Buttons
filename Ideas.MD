# Ideas for Easy Chat Channel Buttons

## Completed in 1.1.0

- Account-wide Favorites for numbered zone and player-created channels.
- A `Custom Channels` manager for adding and removing Favorites.
- Automatic first-time setup using the channels available to the player.
- Numbered-channel buttons that follow channel-number changes and return when a Favorite becomes available again.
- Separate visual groups for built-in chats, numbered-channel Favorites, and Prepared Phrases.
- Optional labels for built-in chats, numbered channels, and Prepared Phrases.
- Optional larger click areas for small bubbles.
- Consistent empty-state guidance, tooltips, and window controls across the settings interface.

## Completed for the Next Release

- A `Button Group Order` setting for arranging the Built-ins, Numbered Channels, and Prepared Phrases groups.
- A `Duplicate` control for quickly copying an existing Prepared Phrase.
- A preferred `Channel` for each Prepared Phrase, with `Current` as the default and configurable handling for existing chat drafts.
- Arrow controls for arranging individual Prepared Phrases in the settings editor.

## Priority Features

### 1. Enhanced Prepared Phrases

- Support placeholders such as `{target}`, `{player}`, and `{zone}`.
- Add themed phrase sets such as Dungeon, Raid, Guild, and PvP.

### 2. Custom Button Order

- Add drag-and-drop sorting for individual channel buttons within their group.
- Provide an option to restore the default order.

### 3. Multiple Rows or Columns

- Configure the maximum number of buttons per row or column.
- Select the bar growth direction: right, left, up, or down.
- Automatically wrap buttons when the bar becomes too long.

This would be particularly useful for large prepared phrase collections: imports already support up to 200 phrases, while the bar currently uses a single linear layout.

### 4. Expanded Labels and Icons

- Provide icons as an alternative to text labels.
- Allow a custom short label for each Prepared Phrase.
- Configure label size and color separately.
- Add a high-contrast mode for improved accessibility.

Basic text labels shipped in version 1.1.0. This feature now covers additional visual choices and customization.

### 5. Additional System Buttons

- Raid Warning.
- Reply to the last whisper sender.
- Whisper the current target when the target is a player.
- Return to the previously used channel.
- Optional Communities channel support.

### 6. Key Bindings

- Bind the primary channels through WoW's standard Key Bindings interface.
- Add bindings for the first prepared phrases.
- Add a binding to show or hide the button bar.

### 7. Profiles and Contextual Sets

- Support separate configurations for different characters.
- Support shared account-wide profiles.
- Automatically switch between Solo, Dungeon, Raid, and PvP profiles.
- Allow each profile to use a different prepared phrase set.

### 8. Advanced Bar Behavior

- Configurable opacity.
- Fade out the bar when it is not being hovered.
- Show the bar only while a chat edit box is open.
- Optionally hide the bar during combat.
- Anchor the bar to a selected chat window instead of always using `ChatFrame1`.

### 9. Complete Profile Export and Import

- Export all addon settings instead of prepared phrases only.
- Include button order, hidden channels, sizes, spacing, orientation, colors, and profiles.
- Validate the transfer format version and request confirmation before replacing settings.

### 10. Localization

- Move all user-facing strings into locale files.
- Start with enUS, deDE, frFR, esES, and ruRU.
- Make it easy to add translations without changing the core logic.

## Recommended Roadmap

### Next Release

- Expanded label customization and optional button icons.
- Reordering for individual channel buttons.
- Multiple-row or multiple-column layouts.
- Raid Warning and Reply buttons.

### Next Major Release

- Prepared phrase sets.
- `{target}`, `{player}`, and `{zone}` placeholders.

### Future Development

- Character profiles and contextual configurations.
- Key bindings.
- Complete settings export and import.
- Localization and additional accessibility options.

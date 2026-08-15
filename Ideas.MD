# Ideas for Easy Chat Channel Buttons

## Priority Features

### 1. Custom Channels

- Add buttons for General, Trade, Services, LocalDefense, and user-created channels.
- Store the channel name instead of its number (`/1`, `/2`), because channel numbers can change depending on the zone and connection order.
- Automatically hide a button when the character is not connected to its channel.

### 2. Enhanced Prepared Phrases

- Let each phrase target a specific channel: Current, Say, Party, Raid, Guild, or Instance Chat.
- Support placeholders such as `{target}`, `{player}`, and `{zone}`.
- Allow phrases to be duplicated.
- Allow phrases to be reordered.
- Add themed phrase sets such as Dungeon, Raid, Guild, and PvP.

### 3. Custom Button Order

- Add drag-and-drop sorting for channel buttons.
- Manage prepared phrase order separately.
- Provide an option to restore the default order.

### 4. Multiple Rows or Columns

- Configure the maximum number of buttons per row or column.
- Select the bar growth direction: right, left, up, or down.
- Automatically wrap buttons when the bar becomes too long.

This would be particularly useful for large prepared phrase collections: imports already support up to 200 phrases, while the bar currently uses a single linear layout.

### 5. Labels or Icons Inside Buttons

- Optionally display channel abbreviations such as `S`, `G`, `P`, and `R`.
- Provide icons as an alternative to text labels.
- Configure label size and color separately.
- Add a high-contrast mode for improved accessibility.

The channel definitions already contain a `label` field that is not currently rendered, so a basic version of this feature should be relatively straightforward to implement.

### 6. Additional System Buttons

- Raid Warning.
- Reply to the last whisper sender.
- Whisper the current target when the target is a player.
- Return to the previously used channel.
- Optional Communities channel support.

### 7. Key Bindings

- Bind the primary channels through WoW's standard Key Bindings interface.
- Add bindings for the first prepared phrases.
- Add a binding to show or hide the button bar.

### 8. Profiles and Contextual Sets

- Support separate configurations for different characters.
- Support shared account-wide profiles.
- Automatically switch between Solo, Dungeon, Raid, and PvP profiles.
- Allow each profile to use a different prepared phrase set.

### 9. Advanced Bar Behavior

- Configurable opacity.
- Fade out the bar when it is not being hovered.
- Show the bar only while a chat edit box is open.
- Optionally hide the bar during combat.
- Anchor the bar to a selected chat window instead of always using `ChatFrame1`.

### 10. Complete Profile Export and Import

- Export all addon settings instead of prepared phrases only.
- Include button order, hidden channels, sizes, spacing, orientation, colors, and profiles.
- Validate the transfer format version and request confirmation before replacing settings.

### 11. Localization

- Move all user-facing strings into locale files.
- Start with enUS, deDE, frFR, esES, and ruRU.
- Make it easy to add translations without changing the core logic.

## Recommended Roadmap

### Next Release

- Labels inside channel buttons.
- Reordering for channels and prepared phrases.
- Multiple-row or multiple-column layouts.
- Raid Warning and Reply buttons.

### Next Major Release

- Custom channels.
- Prepared phrase sets.
- A target channel for each prepared phrase.
- `{target}`, `{player}`, and `{zone}` placeholders.

### Future Development

- Character profiles and contextual configurations.
- Key bindings.
- Complete settings export and import.
- Localization and additional accessibility options.

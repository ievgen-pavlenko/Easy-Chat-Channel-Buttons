# Easy Chat Channel Buttons

A World of Warcraft addon that adds small colored circular chat channel buttons next to the chat tab for quick channel switching.

## Features

- Circular color-coded buttons anchored above the chat tab
- Supports: **Say**, **Yell**, **Guild**, **Officer**, **Party**, **Raid**, and **Instance Chat**
- Buttons are shown/hidden automatically based on your current group and guild status:
  - **Guild** and **Officer** — visible only when in a guild (Officer requires officer permissions)
  - **Party** — visible only when in a party (not a raid)
  - **Raid** — visible only when in a raid
  - **Instance Chat** — visible only when in an instance group
- Clicking a button opens the chat box pre-filled with the correct slash command (e.g. `/g `)
- Favorite numbered text channels (`/1` through `/20`), including zone and player-created channels
- Custom channel favorites follow changing channel numbers automatically and hide while unavailable
- Prepared phrase bubbles with custom text, tooltip, and color
- Clicking a phrase bubble inserts its text at the chat cursor without sending it
- Prepared Phrases can keep the current chat or switch to a preferred built-in channel before inserting their text
- Configurable handling for existing non-empty chat drafts when a phrase prefers another channel
- Built-in chats, numbered channel Favorites, and Prepared Phrases are separated by a shared configurable 10–60 px group gap
- Built-in chats, numbered channel Favorites, and Prepared Phrases can be arranged in any group order
- Optional button labels identify built-in chats, current numbered channels, and prepared phrases by their tooltip initial
- Optional comfortable click targets provide a minimum 20 px interaction area without enlarging the colored circles
- Colors match WoW's built-in `ChatTypeInfo` theme
- **Movable frame** — drag the button bar anywhere on screen; position is saved across sessions
- Compatible with **ElvUI**

## Moving the Button Bar

The bar is locked by default. Use these slash commands to reposition it:

| Command | Effect |
|---------|--------|
| `/ecb unlock` | Unlocks the frame for dragging (yellow tint visible) |
| `/ecb lock` | Locks the frame and saves its position |

Position is stored in `ECB_DB` and restored automatically on login.

## Settings and Accessibility

Open the addon settings with `/ecb`. Appearance controls adjust bubble size, spacing, group spacing, and bar orientation. **Button Group Order** arranges Built-ins, Numbered Channels, and Prepared Phrases from left to right in horizontal layout or top to bottom in vertical layout. The **Built-in Buttons** grid uses checked boxes for buttons that should be shown whenever their chat type is available.

**Show Button Labels** is disabled by default. When enabled, built-in chats show their abbreviation, numbered channels show their current local number, and Prepared Phrases show the first character of their explicit Tooltip. Phrases without an explicit Tooltip remain unlabeled. **Comfortable Click Targets** is also disabled by default and gives small bubbles a non-overlapping minimum 20 px click area.

## Custom Channels

Open the addon settings with `/ecb`, then click **Manage Custom Channels**. The manager lists saved favorites and currently available numbered text channels. Add an available channel directly or enter a channel name or active `/N` manually.

On the first launch with this feature, the addon adds all currently available numbered text channels to Favorites once. If the first discovery happens in an instance or another location with no available supported channels, initialization waits and retries after the next channel or zone update. Favorites are stored by channel name and stable zone-channel identity rather than by their temporary number. If a channel becomes unavailable after changing zones or characters, its button is hidden but the favorite remains saved and returns automatically when the channel is available again. Community streams are not included, and the addon never joins or leaves channels.

## Prepared Phrases

Open the addon settings with `/ecb`, then use **Add Phrase** in the **Prepared Phrases** section. Each phrase has editable text, its own hover tooltip, an individual color, and a **Channel** dropdown. **Current** keeps the active chat type; Say, Yell, Emote, Guild, Officer, Party, Raid, Instance Chat, and Battleground switch the chat before inserting the phrase without sending it. If a preferred channel is unavailable, the phrase silently uses **Current**.

**When Chat Has Text** controls phrases used with an existing non-empty draft: **Use Preferred Channel** preserves the draft and switches it, **Keep Current Channel** inserts without switching, and **Do Not Insert** leaves a draft for another channel unchanged. Use **Duplicate** to create an editable copy directly after a phrase with the same text, tooltip, color, and preferred channel. The arrow buttons beside each phrase number move the phrase up or down and immediately update its position on the button bar. **Button Group Order** under **Appearance** can place Prepared Phrases before, between, or after the chat-button groups. The shared **Group Spacing** slider controls the gaps between Prepared Phrases, built-in chats, and numbered channel Favorites.

**Export Phrases** includes the ordered phrase list, preferred channels, and **When Chat Has Text** selection. **Import Phrases** accepts current and older exports, validates them, and asks for confirmation before replacing the transferred settings. Older exports assign **Current** to every imported phrase and leave the local **When Chat Has Text** selection unchanged.

## Installation

1. Download and extract the `EasyChatChannelButtons` folder.
2. Place it in your WoW addons directory:
   `World of Warcraft\_retail_\Interface\AddOns\EasyChatChannelButtons`
3. Enable the addon in the in-game AddOns menu.

## Compatibility

- **WoW Version:** 12.0.1+ (Interface 120001)
- **ElvUI:** Compatible — uses the standard slash-command chat path that ElvUI hooks into

## Author

Ievgen Pavlenko

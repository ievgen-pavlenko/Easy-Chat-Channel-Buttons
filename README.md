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
- Colors match WoW's built-in `ChatTypeInfo` theme
- **Movable frame** — drag the button bar anywhere on screen; position is saved across sessions
- Compatible with **ElvUI**

## Moving the Button Bar

The bar is locked by default. Use these slash commands to reposition it:

| Command | Effect |
|---------|--------|
| `/ecb unlock` | Unlocks the frame for dragging (yellow tint visible) |
| `/ecb lock` | Locks the frame and saves its position |

Position is stored in `EasyChatChannelButtonsDB` and restored automatically on login.

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

# Easy Chat Channel Buttons

**Easy Chat Channel Buttons** adds a lightweight, movable bar of colored circular buttons for switching chat channels, opening favorite numbered channels, and inserting prepared phrases.

Instead of typing `/s`, `/y`, `/em`, `/g`, `/o`, `/p`, `/raid`, `/i`, `/bg`, or a changing numbered-channel command, you can choose the right chat with one click without losing anything you have already typed.

Create reusable phrase buttons for group instructions, greetings, recruitment messages, Mythic+ notes, roleplay, and other frequently used text. A phrase can keep the current chat or switch to a preferred channel before inserting its text at the cursor — it is never sent automatically.

The addon integrates cleanly with both the default World of Warcraft UI and **ElvUI**.

***

# Features

* Small colored circular buttons on a freely movable bar
* One-click access to built-in chats and favorite numbered channels
* Prepared Phrase buttons with custom text, tooltip, color, and preferred channel
* Existing chat text is preserved when changing channels or inserting phrases
* Active channel highlighting and dimmed inactive buttons while chat is open
* Button colors match your personal chat color settings
* Unavailable buttons hide automatically without leaving empty gaps
* Individual built-in chat visibility controls
* Horizontal or vertical layout
* Any ordering of Built-ins, Numbered Channels, and Prepared Phrases
* Adjustable button size, button spacing, and group spacing
* Optional text labels for easier button identification
* Optional comfortable click targets for very small bubbles
* Saved bar position and visibility state
* Lock, unlock, and reset-position controls
* Minimap button:
  * Left-click opens settings
  * Right-click shows or hides the button bar
* Compatible with the default UI and **ElvUI**
* Lightweight and performance-friendly

***

# Prepared Phrase Buttons

Each Prepared Phrase can have:

* Custom text
* Custom hover tooltip
* Individual button color
* A preferred chat channel
* A custom position in the phrase list

**Current** is the default preferred channel. A phrase can also target Say, Yell, Emote, Guild, Officer, Party, Raid, Instance Chat, or Battleground. If the selected channel is unavailable, the phrase silently keeps the current chat instead.

Clicking a phrase inserts its text at the current cursor position without automatically sending the message. If chat is closed, the addon opens it first.

Use **When Chat Has Text** to control what happens when a non-empty draft is already open in another channel:

* **Use Preferred Channel** — preserve the draft, switch its channel, and insert the phrase
* **Keep Current Channel** — insert the phrase without switching the draft
* **Do Not Insert** — leave a draft for another channel unchanged

Use **Duplicate** to copy a phrase together with its text, tooltip, color, and preferred channel. Arrow controls move individual phrases up or down, and the button bar updates immediately.

***

# Favorite Numbered Channels

Save numbered zone and player-created chats such as General, Trade, Services, LocalDefense, or other active `/N` channels as account-wide Favorites.

* Favorites follow channel-number changes automatically
* Unavailable Favorites hide temporarily and return when the channel is available again
* Button labels can show the current local channel number
* **Manage Custom Channels** can add an available channel directly or by channel name or active `/N`
* First-time setup adds the supported numbered channels available to the player once
* The addon never joins or leaves channels
* Community streams are not included

***

# Phrase Export and Import

Prepared phrases can be transferred between characters, accounts, or installations.

* **Export Phrases** creates a copyable export string
* **Import Phrases** validates pasted data and asks for confirmation before replacing settings
* Phrase order, text, tooltips, colors, preferred channels, and **When Chat Has Text** are preserved
* Older phrase exports remain supported

***

# Supported Built-in Chat Channels

* **Say** — always available
* **Yell** — always available
* **Emote** — always available
* **Guild** — available while you are in a guild
* **Officer** — available when you have officer chat access
* **Party** — available while you are in a party but not a raid
* **Raid** — available while you are in a raid
* **Instance Chat** — available while you are in an instance group
* **Battleground** — available while you are in an instance group

Built-in buttons appear only when their chat type is available and enabled in settings. Hiding a normal channel button does not prevent a Prepared Phrase from using that otherwise available channel.

***

# Layout and Accessibility

The settings panel lets you configure:

* Button size from 10 to 32 px
* Spacing between buttons
* Group spacing from 10 to 60 px
* Horizontal or vertical layout
* **Button Group Order** for Built-ins, Numbered Channels, and Prepared Phrases
* Optional button labels
* Optional comfortable click targets
* Built-in channel visibility
* Prepared Phrases and favorite numbered channels
* Bar lock state and position reset

Group order runs from left to right in horizontal layout and from top to bottom in vertical layout.

***

# Slash Commands

```
/ecb or /ecb config  — open the settings panel
/ecb lock            — lock the button bar
/ecb unlock          — unlock the button bar for moving
```

***

# Compatibility

* **World of Warcraft Retail / Midnight**
* **Default World of Warcraft UI**
* **ElvUI**

The addon does not modify ElvUI. When ElvUI is loaded, button edges receive a subtle glow that matches its visual style.

***

# Lightweight Design

The addon is intentionally focused:

* No heavy frameworks
* No unnecessary background processing
* Simple configuration
* Minimal performance overhead

***

# Author

Created by **Ievgen Pavlenko**.

local addonName, ns = ...

-------------------------------------------------------------------------------
-- EasyChatChannelButtons – Constants
-- All static data: addon identity, default settings, slider ranges, textures,
-- channel definitions, and tooltip strings.
-- Loaded after Core.lua.
-------------------------------------------------------------------------------

local C = {}
ns.Constants = C

-------------------------------------------------------------------------------
-- Addon identity
-------------------------------------------------------------------------------
C.ADDON_NAME    = addonName
C.ADDON_DISPLAY = "Easy Chat Channel Buttons"

-------------------------------------------------------------------------------
-- Slider settings
-------------------------------------------------------------------------------
C.SLIDER = {
    bubbleSize = {
        label = "Bubble Size",
        min   = 10,
        max   = 32,
        step  = 1,
    },
    bubbleSpacing = {
        label = "Bubble Spacing",
        min   = 0,
        max   = 12,
        step  = 1,
    },
    phraseGroupSpacing = {
        -- The SavedVariables key retains its original name for compatibility,
        -- but the value now separates every logical button group.
        label = "Group Spacing",
        min   = 10,
        max   = 60,
        step  = 1,
    },
}

-- New phrases cycle through this palette.  Every phrase keeps its own copy of
-- the selected colour in SavedVariables and can be changed in the config UI.
C.PHRASE_COLORS = {
    { r = 0.20, g = 0.65, b = 1.00 },
    { r = 0.35, g = 0.85, b = 0.45 },
    { r = 1.00, g = 0.65, b = 0.20 },
    { r = 0.85, g = 0.35, b = 0.85 },
    { r = 1.00, g = 0.35, b = 0.40 },
}

-------------------------------------------------------------------------------
-- Textures
-------------------------------------------------------------------------------
C.CIRCLE_MASK_TEX = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

-------------------------------------------------------------------------------
-- Tooltip strings
-------------------------------------------------------------------------------
C.TOOLTIPS = {
    SAY           = "Say",
    YELL          = "Yell",
    EMOTE         = "Emote",
    GUILD         = "Guild",
    OFFICER       = "Officer",
    PARTY         = "Party",
    RAID          = "Raid",
    INSTANCE_CHAT = "Instance Chat",
    BATTLEGROUND  = "Battleground",
}

-------------------------------------------------------------------------------
-- Channel slash commands
-------------------------------------------------------------------------------
C.CHANNEL_SLASH = {
    SAY           = "/s",
    YELL          = "/y",
    EMOTE         = "/em",
    GUILD         = "/g",
    OFFICER       = "/o",
    PARTY         = "/p",
    RAID          = "/raid",
    INSTANCE_CHAT = "/i",
    BATTLEGROUND  = "/bg",
}

-------------------------------------------------------------------------------
-- Prepared phrase channel choices
-- CURRENT deliberately has no slash command: it preserves the chat type that
-- the player is already using.  Persisted values use stable chat type keys.
-------------------------------------------------------------------------------
C.DEFAULT_PHRASE_CHANNEL = "CURRENT"
C.PHRASE_CHANNEL_OPTIONS = {
    { key = "CURRENT",       label = "Current" },
    { key = "SAY",           label = "Say (/s)" },
    { key = "YELL",          label = "Yell (/y)" },
    { key = "EMOTE",         label = "Emote (/em)" },
    { key = "GUILD",         label = "Guild (/g)" },
    { key = "OFFICER",       label = "Officer (/o)" },
    { key = "PARTY",         label = "Party (/p)" },
    { key = "RAID",          label = "Raid (/raid)" },
    { key = "INSTANCE_CHAT", label = "Instance Chat (/i)" },
    { key = "BATTLEGROUND",  label = "Battleground (/bg)" },
}

C.PHRASE_CHANNEL_BY_KEY = {}
for _, option in ipairs(C.PHRASE_CHANNEL_OPTIONS) do
    C.PHRASE_CHANNEL_BY_KEY[option.key] = option
end

function C.NormalizePhraseChannel(value)
    if type(value) == "string" and C.PHRASE_CHANNEL_BY_KEY[value] then
        return value
    end
    return C.DEFAULT_PHRASE_CHANNEL
end

function C.GetPhraseChannelOption(value)
    return C.PHRASE_CHANNEL_BY_KEY[C.NormalizePhraseChannel(value)]
end

-------------------------------------------------------------------------------
-- Runtime channel availability
-- Kept separate from button visibility so hiding a built-in button never
-- prevents a Prepared Phrase from targeting that otherwise available channel.
-------------------------------------------------------------------------------
C.CHANNEL_AVAILABLE = {
    SAY = function() return true end,
    YELL = function() return true end,
    EMOTE = function() return true end,
    GUILD = function() return IsInGuild() end,
    OFFICER = function()
        return IsInGuild()
           and (CanEditOfficerNote and CanEditOfficerNote() or false)
    end,
    PARTY = function()
        return IsInGroup(LE_PARTY_CATEGORY_HOME)
           and not IsInRaid(LE_PARTY_CATEGORY_HOME)
    end,
    RAID = function()
        return IsInRaid(LE_PARTY_CATEGORY_HOME)
    end,
    INSTANCE_CHAT = function()
        return IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
    end,
    BATTLEGROUND = function()
        return IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
    end,
}

function C.IsChannelAvailable(chatType)
    local predicate = C.CHANNEL_AVAILABLE[chatType]
    return predicate and predicate() == true or false
end

-------------------------------------------------------------------------------
-- Channel definitions
-- Each entry drives one button in the bar.
--   key      – unique identifier, matches CHANNEL_SLASH and ChatTypeInfo keys
--   label    – single-letter abbreviation shown if text labels are used
--   tooltip  – human-readable name shown in the GameTooltip
--   chatType – value passed to SwitchChatType / ChatTypeInfo
--   visible  – predicate returning true when this channel should be shown
-- Color is read at runtime from ChatTypeInfo to match the player's game settings.
-------------------------------------------------------------------------------

-- Returns true when the player has manually hidden this channel key.
-- Reads ECB.db.hiddenChannels which is populated after PLAYER_LOGIN;
-- safe to call earlier (returns nil/false before the DB is ready).
local function isUserHidden(key)
    local ECB = ns.ECB
    return ECB and ECB.db and ECB.db.hiddenChannels and ECB.db.hiddenChannels[key]
end

C.CHANNELS = {
    {
        key      = "SAY",
        label    = "S",
        tooltip  = C.TOOLTIPS.SAY,
        chatType = "SAY",
        visible  = function()
            return C.IsChannelAvailable("SAY") and not isUserHidden("SAY")
        end,
    },
    {
        key      = "YELL",
        label    = "Y",
        tooltip  = C.TOOLTIPS.YELL,
        chatType = "YELL",
        visible  = function()
            return C.IsChannelAvailable("YELL") and not isUserHidden("YELL")
        end,
    },
    {
        key      = "EMOTE",
        label    = "E",
        tooltip  = C.TOOLTIPS.EMOTE,
        chatType = "EMOTE",
        visible  = function()
            return C.IsChannelAvailable("EMOTE") and not isUserHidden("EMOTE")
        end,
    },
    {
        key      = "GUILD",
        label    = "G",
        tooltip  = C.TOOLTIPS.GUILD,
        chatType = "GUILD",
        visible  = function()
            return C.IsChannelAvailable("GUILD") and not isUserHidden("GUILD")
        end,
    },
    {
        key      = "OFFICER",
        label    = "O",
        tooltip  = C.TOOLTIPS.OFFICER,
        chatType = "OFFICER",
        visible  = function()
            return C.IsChannelAvailable("OFFICER")
               and not isUserHidden("OFFICER")
        end,
    },
    {
        key      = "PARTY",
        label    = "P",
        tooltip  = C.TOOLTIPS.PARTY,
        chatType = "PARTY",
        visible  = function()
            return C.IsChannelAvailable("PARTY")
               and not isUserHidden("PARTY")
        end,
    },
    {
        key      = "RAID",
        label    = "R",
        tooltip  = C.TOOLTIPS.RAID,
        chatType = "RAID",
        visible  = function()
            return C.IsChannelAvailable("RAID")
               and not isUserHidden("RAID")
        end,
    },
    {
        key      = "INSTANCE_CHAT",
        label    = "I",
        tooltip  = C.TOOLTIPS.INSTANCE_CHAT,
        chatType = "INSTANCE_CHAT",
        visible  = function()
            return C.IsChannelAvailable("INSTANCE_CHAT")
               and not isUserHidden("INSTANCE_CHAT")
        end,
    },
    {
        key      = "BATTLEGROUND",
        label    = "B",
        tooltip  = C.TOOLTIPS.BATTLEGROUND,
        chatType = "BATTLEGROUND",
        visible  = function()
            return C.IsChannelAvailable("BATTLEGROUND")
               and not isUserHidden("BATTLEGROUND")
        end,
    },
}

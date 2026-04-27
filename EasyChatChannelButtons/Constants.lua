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
        visible  = function() return not isUserHidden("SAY") end,
    },
    {
        key      = "YELL",
        label    = "Y",
        tooltip  = C.TOOLTIPS.YELL,
        chatType = "YELL",
        visible  = function() return not isUserHidden("YELL") end,
    },
    {
        key      = "EMOTE",
        label    = "E",
        tooltip  = C.TOOLTIPS.EMOTE,
        chatType = "EMOTE",
        visible  = function() return not isUserHidden("EMOTE") end,
    },
    {
        key      = "GUILD",
        label    = "G",
        tooltip  = C.TOOLTIPS.GUILD,
        chatType = "GUILD",
        visible  = function()
            return IsInGuild() and not isUserHidden("GUILD")
        end,
    },
    {
        key      = "OFFICER",
        label    = "O",
        tooltip  = C.TOOLTIPS.OFFICER,
        chatType = "OFFICER",
        visible  = function()
            return IsInGuild()
               and (CanEditOfficerNote and CanEditOfficerNote() or false)
               and not isUserHidden("OFFICER")
        end,
    },
    {
        key      = "PARTY",
        label    = "P",
        tooltip  = C.TOOLTIPS.PARTY,
        chatType = "PARTY",
        visible  = function()
            return IsInGroup(LE_PARTY_CATEGORY_HOME)
               and not IsInRaid(LE_PARTY_CATEGORY_HOME)
               and not isUserHidden("PARTY")
        end,
    },
    {
        key      = "RAID",
        label    = "R",
        tooltip  = C.TOOLTIPS.RAID,
        chatType = "RAID",
        visible  = function()
            return IsInRaid(LE_PARTY_CATEGORY_HOME)
               and not isUserHidden("RAID")
        end,
    },
    {
        key      = "INSTANCE_CHAT",
        label    = "I",
        tooltip  = C.TOOLTIPS.INSTANCE_CHAT,
        chatType = "INSTANCE_CHAT",
        visible  = function()
            return IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
               and not isUserHidden("INSTANCE_CHAT")
        end,
    },
    {
        key      = "BATTLEGROUND",
        label    = "B",
        tooltip  = C.TOOLTIPS.BATTLEGROUND,
        chatType = "BATTLEGROUND",
        visible  = function()
            return IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
               and not isUserHidden("BATTLEGROUND")
        end,
    },
}

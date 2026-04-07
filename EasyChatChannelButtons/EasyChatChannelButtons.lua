-------------------------------------------------------------------------------
-- EasyChatChannelButtons
-- Adds circular chat channel shortcut buttons to the right of ChatFrame1Tab.
-- Works standalone; integrates lightly with ElvUI when present.
-------------------------------------------------------------------------------

local BUTTON_SIZE    = 10   -- diameter in pixels
local BUTTON_SPACING = 7    -- gap between buttons
local ANCHOR_OFFSET  = 10    -- horizontal gap from ChatFrame1Tab

-- Circular alpha mask built into the WoW client (no external files needed).
local CIRCLE_MASK = "Interface\\Minimap\\UI-Minimap-Background"

local mainFrame = nil
local buttons   = {}

-------------------------------------------------------------------------------
-- Channel definitions
-- visible()    : returns true when the button should be shown
-- color        : fallback RGB circle colour (used if ChatTypeInfo unavailable)
-- textColor    : RGB for the letter label (chosen for contrast on the circle)
-------------------------------------------------------------------------------
local channels = {
    {
        key       = "SAY",
        label     = "S",
        tooltip   = "Say",
        chatType  = "SAY",
        color     = { 1,    1,    1    },
        textColor = { 0,    0,    0    },   -- black on white
        visible   = function() return true end,
    },
    {
        key       = "GUILD",
        label     = "G",
        tooltip   = "Guild",
        chatType  = "GUILD",
        color     = { 0.25, 1,    0.25 },
        textColor = { 0,    0,    0    },   -- black on light green
        visible   = function() return IsInGuild() end,
    },
    {
        key       = "OFFICER",
        label     = "O",
        tooltip   = "Officer",
        chatType  = "OFFICER",
        color     = { 0.1,  0.55, 0.1  },
        textColor = { 1,    1,    1    },   -- white on dark green
        visible   = function()
            return IsInGuild() and (CanEditOfficerNote and CanEditOfficerNote() or false)
        end,
    },
    {
        key       = "PARTY",
        label     = "P",
        tooltip   = "Party",
        chatType  = "PARTY",
        color     = { 0.45, 0.67, 1    },
        textColor = { 1,    1,    1    },   -- white on blue
        visible   = function()
            return IsInGroup(LE_PARTY_CATEGORY_HOME)
               and not IsInRaid(LE_PARTY_CATEGORY_HOME)
        end,
    },
    {
        key       = "RAID",
        label     = "R",
        tooltip   = "Raid",
        chatType  = "RAID",
        color     = { 1,    0.49, 0.04 },
        textColor = { 0,    0,    0    },   -- black on orange
        visible   = function()
            return IsInRaid(LE_PARTY_CATEGORY_HOME)
        end,
    },
    {
        key       = "INSTANCE_CHAT",
        label     = "I",
        tooltip   = "Instance Chat",
        chatType  = "INSTANCE_CHAT",
        color     = { 1,    0.84, 0    },
        textColor = { 0,    0,    0    },   -- black on yellow
        visible   = function()
            return IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
        end,
    },
    {
        key       = "YELL",
        label     = "Y",
        tooltip   = "Yell",
        chatType  = "YELL",
        color     = { 1,    0.25, 0.25 },
        textColor = { 1,    1,    1    },   -- white on red
        visible   = function() return true end,
    },
}

-------------------------------------------------------------------------------
-- FindActiveEditBox
-- Searches every known location for a visible chat edit box.
-- ChatEdit_GetActiveWindow() returns nil when the box is closed, and ElvUI
-- may arrange frames differently from the vanilla layout, so we probe all
-- possible references to be safe.
-------------------------------------------------------------------------------
-- Slash commands that trigger WoW's ChatEdit_ParseText to switch channels.
-- This is the same code path as a player typing "/g " manually, so it works
-- with both vanilla UI and ElvUI's chat module.
local CHANNEL_SLASH = {
    SAY           = "/s",
    YELL          = "/y",
    GUILD         = "/g",
    OFFICER       = "/o",
    PARTY         = "/p",
    RAID          = "/raid",
    INSTANCE_CHAT = "/i",
}

-------------------------------------------------------------------------------
-- SwitchChatType
-- Opens the chat edit box pre-filled with the slash command for the requested
-- channel.  OnTextChanged → ChatEdit_ParseText does the rest: it recognises
-- the command, sets chatType, clears the slash text, and updates the header.
-- This path is identical to the user typing "/g " themselves, so ElvUI's own
-- header/hook logic is fully satisfied.
-------------------------------------------------------------------------------
local function SwitchChatType(chatType)
    local slash = CHANNEL_SLASH[chatType]
    if not slash then return end

    -- If the box is already open and has typed text, preserve it:
    -- open a fresh box with the slash command (which switches channel and
    -- clears to empty), then restore the typed text on the next frame.
    local activeBox = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
    local savedText = activeBox and activeBox:IsVisible() and activeBox:GetText() or ""
    savedText = savedText ~= "" and savedText or nil

    -- Open/switch via slash command — works with vanilla and ElvUI.
    ChatFrame_OpenChat(slash .. " ", ChatFrame1)

    if savedText then
        -- Restore the typed text after ParseText has processed the slash cmd.
        C_Timer.After(0, function()
            local box = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
            if box and box:IsVisible() then
                box:SetText(savedText)
                box:SetCursorPosition(#savedText)
            end
        end)
    end
end

-------------------------------------------------------------------------------
-- GetChannelColor
-- Prefers WoW's ChatTypeInfo table so colours always match the client theme.
-------------------------------------------------------------------------------
local function GetChannelColor(channelDef)
    local info = ChatTypeInfo and ChatTypeInfo[channelDef.chatType]
    if info and info.r then
        return info.r, info.g, info.b
    end
    return channelDef.color[1], channelDef.color[2], channelDef.color[3]
end

-------------------------------------------------------------------------------
-- RefreshLayout
-- Reflows all visible buttons left-to-right with no gaps for hidden ones.
-------------------------------------------------------------------------------
local function RefreshLayout()
    local prevBtn = nil
    local count   = 0

    for _, btn in ipairs(buttons) do
        if btn:IsShown() then
            btn:ClearAllPoints()
            if prevBtn == nil then
                btn:SetPoint("LEFT", mainFrame, "LEFT", 0, 0)
            else
                btn:SetPoint("LEFT", prevBtn, "RIGHT", BUTTON_SPACING, 0)
            end
            prevBtn = btn
            count   = count + 1
        end
    end

    -- Resize the container to exactly fit the visible buttons.
    local totalWidth = count > 0
        and (count * BUTTON_SIZE + (count - 1) * BUTTON_SPACING)
        or 1
    mainFrame:SetSize(totalWidth, BUTTON_SIZE)
end

-------------------------------------------------------------------------------
-- UpdateButtonVisibility
-- Shows/hides each button according to its visibility rule, then reflows.
-------------------------------------------------------------------------------
local function UpdateButtonVisibility()
    for i, btn in ipairs(buttons) do
        -- pcall guards against errors from guild API before roster loads.
        local ok, shouldShow = pcall(channels[i].visible)
        if ok and shouldShow then
            btn:Show()
        else
            btn:Hide()
        end
    end
    RefreshLayout()
end

-------------------------------------------------------------------------------
-- CreateChannelButton
-- Builds one circular button for the given channel definition.
-------------------------------------------------------------------------------
local function CreateChannelButton(parent, channelDef)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)

    -- Strip ALL four default Button frame textures. Without this, WoW renders
    -- the normal/pushed/highlight/disabled slots as plain rectangles, which
    -- would make the button look square no matter what custom textures we add.
    btn:SetNormalTexture("")
    btn:SetPushedTexture("")
    btn:SetHighlightTexture("")
    btn:SetDisabledTexture("")

    local r, g, b = GetChannelColor(channelDef)

    -- ── Dark circular border ────────────────────────────────────────────────
    local border = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
    border:SetPoint("TOPLEFT",     btn, "TOPLEFT",      -1,  1)
    border:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT",   1, -1)
    border:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    border:SetVertexColor(0, 0, 0, 0.55)
    border:SetMask(CIRCLE_MASK)

    -- ── Coloured circle fill (macOS-style dot, no text) ─────────────────────
    local bg = btn:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetAllPoints()
    bg:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    bg:SetVertexColor(r, g, b, 1)
    bg:SetMask(CIRCLE_MASK)
    btn._bg = bg

    -- ── Hover highlight ─────────────────────────────────────────────────────
    local hl = btn:CreateTexture(nil, "HIGHLIGHT", nil, 0)
    hl:SetAllPoints()
    hl:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    hl:SetVertexColor(1, 1, 1, 0.25)
    hl:SetMask(CIRCLE_MASK)

    -- ── Tooltip ─────────────────────────────────────────────────────────────
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(channelDef.tooltip, 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- ── Click: switch channel ────────────────────────────────────────────────
    btn:SetScript("OnClick", function()
        SwitchChatType(channelDef.chatType)
    end)

    return btn
end

-------------------------------------------------------------------------------
-- CreateMainFrame
-- Builds the container and all buttons; anchors to ChatFrame1Tab.
-------------------------------------------------------------------------------
local function CreateMainFrame()
    if mainFrame then return end
    if not ChatFrame1Tab then return end   -- safety: requires default UI

    mainFrame = CreateFrame("Frame", "EasyChatChannelButtonsFrame", UIParent)
    mainFrame:SetSize(1, BUTTON_SIZE)
    mainFrame:SetPoint("BOTTOMLEFT", ChatFrame1Tab, "TOPLEFT", 25, BUTTON_SPACING)
    mainFrame:SetFrameStrata("HIGH")
    mainFrame:SetFrameLevel(100)

    for i, channelDef in ipairs(channels) do
        buttons[i] = CreateChannelButton(mainFrame, channelDef)
    end

    UpdateButtonVisibility()
end

-------------------------------------------------------------------------------
-- Event handler
-------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        CreateMainFrame()
    else
        if mainFrame then
            UpdateButtonVisibility()
        end
    end
end)
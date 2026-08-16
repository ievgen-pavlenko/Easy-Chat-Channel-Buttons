local addonName, ns = ...
local ECB = ns.ECB
local C = ns.Constants

-------------------------------------------------------------------------------
-- EasyChatChannelButtons – Chat
-- Chat edit box detection, channel switching with text preservation, and
-- channel colour helpers.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- ECB:GetActiveEditBox
-- Returns the currently active and visible chat edit box, or nil if none is
-- open.
-------------------------------------------------------------------------------
function ECB:GetActiveEditBox()
    if not ChatEdit_GetActiveWindow then return nil end
    local box = ChatEdit_GetActiveWindow()
    if box and box:IsVisible() then return box end
    return nil
end

local function InsertIntoEditBox(box, text)
    -- Clicking an addon button can deactivate an empty edit box before its
    -- OnClick handler runs.  Reactivate and focus the captured box before
    -- inserting so the text is written to the visible chat input.
    local activeBox = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() or nil
    if activeBox ~= box or not box:IsVisible() then
        if ChatEdit_ActivateChat then
            ChatEdit_ActivateChat(box)
        elseif box.Show then
            box:Show()
        end
    end
    box:SetFocus()

    if box.Insert then
        box:Insert(text)
    else
        -- Defensive fallback for clients whose edit box does not expose
        -- Insert(); retail EditBox normally always provides it.
        box:SetText((box:GetText() or "") .. text)
    end
end

local function OpenChatWithPhrase(text, target)
    local slash = target ~= C.DEFAULT_PHRASE_CHANNEL
        and C.CHANNEL_SLASH[target] or nil
    ChatFrame_OpenChat(slash and (slash .. " " .. text) or text, ChatFrame1)
end

-------------------------------------------------------------------------------
-- ECB:SwitchChatType(chatType)
-- Changes the active chat channel.
--
-- Two cases:
--   1. Edit box is already open – switch its chatType in-place so any text the
--      player has typed is preserved.  ChatEdit_UpdateHeader refreshes the
--      channel indicator without closing/reopening the box.
--   2. Edit box is closed – open it directly into the requested channel via
--      ChatFrame_OpenChat with the matching slash command.
-------------------------------------------------------------------------------
function ECB:SwitchChatType(chatType)
    local slash = C.CHANNEL_SLASH[chatType]
    if not slash then return end

    local box = self:GetActiveEditBox()

    if box then
        -- Edit box is open: switch channel without touching the typed text.
        box:SetAttribute("chatType", chatType)
        ChatEdit_UpdateHeader(box)
    else
        -- Edit box is closed: open it in the requested channel.
        ChatFrame_OpenChat(slash .. " ", ChatFrame1)
    end
end

-------------------------------------------------------------------------------
-- ECB:GetEditBoxChannelTarget
-- Returns the resolved local channel ID for a chat edit box.  Retail mixins
-- expose GetChannelTarget(); the attribute fallback keeps this defensive.
-------------------------------------------------------------------------------
function ECB:GetEditBoxChannelTarget(box)
    if not box then return nil end
    local target
    if box.GetChannelTarget then
        target = box:GetChannelTarget()
    else
        target = box:GetAttribute("channelTarget")
        if target and GetChannelName then target = GetChannelName(target) end
    end
    target = tonumber(target)
    return target and target > 0 and target or nil
end

-------------------------------------------------------------------------------
-- ECB:SwitchCustomChannel
-- Resolves the favorite immediately before switching so a zone transition can
-- never leave a button pointing at the wrong numbered channel.
-------------------------------------------------------------------------------
function ECB:SwitchCustomChannel(favorite)
    self:RefreshCustomChannels(false)
    local channel = self:ResolveCustomChannel(favorite)
    if not channel then
        print("|cff00ff00Easy Chat Channel Buttons:|r Channel is not available.")
        return
    end

    local box = self:GetActiveEditBox()
    if box then
        if box.SetChannelTarget then
            box:SetChannelTarget(channel.localID)
        else
            box:SetAttribute("channelTarget", channel.localID)
        end
        if box.SetChatType then
            box:SetChatType("CHANNEL")
        else
            box:SetAttribute("chatType", "CHANNEL")
        end
        if box.UpdateHeader then
            box:UpdateHeader()
        elseif ChatEdit_UpdateHeader then
            ChatEdit_UpdateHeader(box)
        end
        self.activeChatType = "CHANNEL"
        self.activeChannelTarget = channel.localID
        self:UpdateActiveIndicator()
    else
        ChatFrame_OpenChat("/" .. channel.localID .. " ", ChatFrame1)
    end
end

-------------------------------------------------------------------------------
-- ECB:InsertPhrase(text, preferredChannel)
-- Inserts a prepared phrase at the cursor without sending it.  CURRENT keeps
-- the existing behavior.  A supported preferred channel switches the edit box
-- first, subject to the global non-empty-draft rule.  Unavailable channels
-- silently fall back to CURRENT so a phrase can still be used anywhere.
-------------------------------------------------------------------------------
function ECB:InsertPhrase(text, preferredChannel)
    if type(text) ~= "string" or text == "" then return end

    local target = C.NormalizePhraseChannel(preferredChannel)
    if target ~= C.DEFAULT_PHRASE_CHANNEL and not C.IsChannelAvailable(target) then
        target = C.DEFAULT_PHRASE_CHANNEL
    end

    local box = self:GetActiveEditBox()
    if not box then
        OpenChatWithPhrase(text, target)
        return
    end

    local existingText = box:GetText() or ""
    if existingText == "" then
        if target == C.DEFAULT_PHRASE_CHANNEL then
            InsertIntoEditBox(box, text)
        else
            -- Open the channel and phrase in one operation.  A separate switch
            -- followed by Insert() can lose the phrase when clicking the addon
            -- button deactivates an otherwise empty edit box.
            OpenChatWithPhrase(text, target)
        end
        return
    end

    if target ~= C.DEFAULT_PHRASE_CHANNEL then
        local currentChatType = box:GetAttribute("chatType")
        if currentChatType ~= target then
            local behavior = self:NormalizePhraseDraftBehavior(
                self.db.phraseDraftBehavior)
            if behavior == "current" then
                target = C.DEFAULT_PHRASE_CHANNEL
            elseif behavior == "block" then
                return
            end

            if target ~= C.DEFAULT_PHRASE_CHANNEL then
                self:SwitchChatType(target)
                box = self:GetActiveEditBox() or box
            end
        end
    end

    InsertIntoEditBox(box, text)
end

-------------------------------------------------------------------------------
-- ECB:GetChannelColor(channelDef)
-- Returns r, g, b from the game's live ChatTypeInfo so colors always match
-- the player's own chat color settings.  Falls back to white if ChatTypeInfo
-- is unavailable (e.g. very early load order edge cases).
-------------------------------------------------------------------------------
function ECB:GetChannelColor(channelDef)
    local info = ChatTypeInfo and ChatTypeInfo[channelDef.chatType]
    if info and info.r then return info.r, info.g, info.b end
    return 1, 1, 1  -- neutral fallback; ChatTypeInfo is always present at PLAYER_LOGIN
end

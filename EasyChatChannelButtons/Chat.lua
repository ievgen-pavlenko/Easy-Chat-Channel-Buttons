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
-- ECB:GetChannelColor(channelDef)
-- Returns r, g, b for a channel definition.  Prefers the live ChatTypeInfo
-- values so colours respect the player's own chat settings.
-------------------------------------------------------------------------------
function ECB:GetChannelColor(channelDef)
    local info = ChatTypeInfo and ChatTypeInfo[channelDef.chatType]
    if info and info.r then return info.r, info.g, info.b end
    return channelDef.color[1], channelDef.color[2], channelDef.color[3]
end

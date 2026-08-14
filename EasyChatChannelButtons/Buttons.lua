local addonName, ns = ...
local ECB = ns.ECB
local C = ns.Constants

-------------------------------------------------------------------------------
-- EasyChatChannelButtons – Buttons
-- Container frame construction, circular channel button creation, layout/reflow,
-- visibility management, settings application, and frame lock/unlock.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Position persistence (module-private)
-------------------------------------------------------------------------------
local function SavePosition()
    local x, y = ECB.mainFrame:GetLeft(), ECB.mainFrame:GetBottom()
    if x and y then
        ECB_DB.x = x
        ECB_DB.y = y
    end
end

-------------------------------------------------------------------------------
-- ApplyLockState (module-private)
-- Enables or disables dragging and shows/hides the drag highlight.
-------------------------------------------------------------------------------
local function ApplyLockState(locked)
    local f = ECB.mainFrame
    if locked then
        f:SetMovable(false)
        f:EnableMouse(false)
        f:SetScript("OnDragStart", nil)
        f:SetScript("OnDragStop",  nil)
        if f._dragBg then f._dragBg:Hide() end
    else
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function(self) self:StartMoving() end)
        f:SetScript("OnDragStop",  function(self)
            self:StopMovingOrSizing()
            SavePosition()
        end)
        if f._dragBg then f._dragBg:Show() end
    end
end

-------------------------------------------------------------------------------
-- ECB:LockFrame / ECB:UnlockFrame
-- Called from slash commands in Core.lua.
-------------------------------------------------------------------------------
function ECB:LockFrame()
    ECB_DB.locked = true
    SavePosition()
    ApplyLockState(true)
    print("|cff00ff00EasyChatChannelButtons:|r Frame locked.")
end

function ECB:UnlockFrame()
    ECB_DB.locked = false
    ApplyLockState(false)
    print("|cff00ff00EasyChatChannelButtons:|r Frame unlocked \226\128\147 drag to reposition, then /ecb lock.")
end

-------------------------------------------------------------------------------
-- AddCircleMask (module-private)
-- Attaches the circle mask texture to a given texture layer so it is clipped
-- to a perfect circle regardless of the button size.
-------------------------------------------------------------------------------
local function AddCircleMask(tex, parent)
    local mask = parent:CreateMaskTexture()
    mask:SetTexture(C.CIRCLE_MASK_TEX)
    mask:SetAllPoints(tex)
    tex:AddMaskTexture(mask)
end

-------------------------------------------------------------------------------
-- CreateChannelButton (module-private)
-- Builds one circular button for the given channel definition.
--
-- Visual structure (both paths — no templates, no square backdrops):
--
--   Button  (plain Frame, alpha 0, completely transparent — no art, no border)
--    └─ bg   BACKGROUND texture  SetColorTexture(r,g,b,1)  + circle mask
--    └─ hl   HIGHLIGHT  texture  SetColorTexture(1,1,1,.22) + circle mask
--
-- The button frame itself is never painted; only the two masked textures are
-- visible.  This produces a clean circular dot with zero square edges.
--
-- If ElvUI is loaded, a very subtle outer glow ring is added behind the fill
-- to soften the circle edge — still fully circular (masked), no squares.
-------------------------------------------------------------------------------
local function CreateChannelButton(parent, channelDef)
    local size = ECB.db.bubbleSize
    local btn  = CreateFrame("Button", nil, parent)
    btn:SetSize(size, size)

    -- The frame itself must be fully transparent — no Blizzard art at all.
    btn:SetNormalTexture("")
    btn:SetPushedTexture("")
    btn:SetHighlightTexture("")
    btn:SetDisabledTexture("")

    local r, g, b = ECB:GetChannelColor(channelDef)

    -- Optional subtle glow ring when ElvUI is present.
    -- Still circular (masked) — never a square.
    if ECB:IsElvUILoaded() then
        local glow = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
        glow:SetPoint("TOPLEFT",     btn, "TOPLEFT",     -2,  2)
        glow:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT",  2, -2)
        glow:SetColorTexture(r, g, b, 0.35)
        AddCircleMask(glow, btn)
        btn._glow = glow
    end

    -- Active-channel indicator ring.
    -- Sits at the same BACKGROUND sub-level as the glow but is created after
    -- it, so it renders on top of the glow within that sub-level.
    -- The ring is 4 px wider/taller than the button; the opaque bg circle
    -- (at sub-level 0) covers its centre, leaving a 2 px bright white rim
    -- that peeks out around the edge.  Hidden until this channel is active.
    local ring = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
    ring:SetPoint("TOPLEFT",     btn, "TOPLEFT",     -2,  2)
    ring:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT",  2, -2)
    ring:SetColorTexture(1, 1, 1, 0.9)
    AddCircleMask(ring, btn)
    ring:Hide()
    btn._ring = ring

    -- Main fill: the only opaque art layer.
    local bg = btn:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetAllPoints()
    bg:SetColorTexture(r, g, b, 1)
    AddCircleMask(bg, btn)
    btn._bg = bg
    btn._channelDef  = channelDef

    -- Hover highlight — circular, low opacity.
    local hl = btn:CreateTexture(nil, "HIGHLIGHT", nil, 0)
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.22)
    AddCircleMask(hl, btn)

    -- Tooltip.
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(channelDef.tooltip, 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Click handler.
    btn:SetScript("OnClick", function() ECB:SwitchChatType(channelDef.chatType) end)

    return btn
end

-------------------------------------------------------------------------------
-- CreatePhraseButton (module-private)
-- Builds a circular button whose colour, tooltip, and inserted text are read
-- from btn._phraseDef.  Reading the current definition at interaction time lets
-- the config editor update buttons in place without leaking frames.
-------------------------------------------------------------------------------
local function CreatePhraseButton(parent)
    local size = ECB.db.bubbleSize
    local btn  = CreateFrame("Button", nil, parent)
    btn:SetSize(size, size)
    btn:SetNormalTexture("")
    btn:SetPushedTexture("")
    btn:SetHighlightTexture("")
    btn:SetDisabledTexture("")

    if ECB:IsElvUILoaded() then
        local glow = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
        glow:SetPoint("TOPLEFT",     btn, "TOPLEFT",     -2,  2)
        glow:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT",  2, -2)
        AddCircleMask(glow, btn)
        btn._glow = glow
    end

    local bg = btn:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetAllPoints()
    AddCircleMask(bg, btn)
    btn._bg = bg

    local hl = btn:CreateTexture(nil, "HIGHLIGHT", nil, 0)
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.22)
    AddCircleMask(hl, btn)

    btn:SetScript("OnEnter", function(self)
        local phrase = self._phraseDef
        if not phrase then return end
        local tooltip = phrase.tooltip
        if type(tooltip) ~= "string" or tooltip == "" then
            tooltip = phrase.text
        end
        if type(tooltip) ~= "string" or tooltip == "" then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(tooltip, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:SetScript("OnClick", function(self)
        local phrase = self._phraseDef
        if phrase then ECB:InsertPhrase(phrase.text) end
    end)

    return btn
end

local function GetPhraseColor(phrase)
    local color = phrase and type(phrase.color) == "table" and phrase.color or nil
    local r = color and tonumber(color.r) or 0.20
    local g = color and tonumber(color.g) or 0.65
    local b = color and tonumber(color.b) or 1.00
    return math.max(0, math.min(1, r)),
           math.max(0, math.min(1, g)),
           math.max(0, math.min(1, b))
end

-------------------------------------------------------------------------------
-- ECB:SyncPhraseButtons
-- Reuses existing phrase button frames, creating only when the configured list
-- grows.  Empty phrases remain editable in settings but do not appear in the
-- live bar.
-------------------------------------------------------------------------------
function ECB:SyncPhraseButtons()
    if not self.mainFrame then return end

    local phrases = type(self.db.phrases) == "table" and self.db.phrases or {}
    for i, phrase in ipairs(phrases) do
        if type(phrase) ~= "table" then phrase = {} end
        local btn = self.phraseButtons[i]
        if not btn then
            btn = CreatePhraseButton(self.mainFrame)
            self.phraseButtons[i] = btn
        end

        btn._phraseDef = phrase
        local r, g, b = GetPhraseColor(phrase)
        btn._bg:SetColorTexture(r, g, b, 1)
        if btn._glow then btn._glow:SetColorTexture(r, g, b, 0.35) end

        if type(phrase.text) == "string" and phrase.text ~= "" then
            btn:Show()
        else
            btn:Hide()
        end
    end

    for i = #phrases + 1, #self.phraseButtons do
        self.phraseButtons[i]._phraseDef = nil
        self.phraseButtons[i]:Hide()
    end
end

-------------------------------------------------------------------------------
-- ECB:RefreshButtons
-- Resizes every button to the current bubbleSize, then reflows only the
-- visible buttons horizontally (hidden buttons leave no gap).  The container
-- frame is resized to match the visible content exactly.
-------------------------------------------------------------------------------
function ECB:RefreshButtons()
    local size     = self.db.bubbleSize
    local spacing  = self.db.bubbleSpacing
    local vertical = self.db.vertical
    local groupGap = self.db.phraseGroupSpacing or 20
    local prev     = nil
    local prevGroup = nil
    local count    = 0
    local total    = 0

    local function AddGroup(buttons, groupName)
        for _, btn in ipairs(buttons) do
            btn:SetSize(size, size)
            if btn:IsShown() then
                btn:ClearAllPoints()
                local gap = spacing
                if prev and prevGroup ~= groupName then gap = groupGap end

                if prev == nil then
                    if vertical then
                        btn:SetPoint("TOP", self.mainFrame, "TOP", 0, 0)
                    else
                        btn:SetPoint("LEFT", self.mainFrame, "LEFT", 0, 0)
                    end
                elseif vertical then
                    btn:SetPoint("TOP", prev, "BOTTOM", 0, -gap)
                else
                    btn:SetPoint("LEFT", prev, "RIGHT", gap, 0)
                end

                if count > 0 then total = total + gap end
                total = total + size
                prev      = btn
                prevGroup = groupName
                count     = count + 1
            end
        end
    end

    if self.db.phrasePosition == "before" then
        AddGroup(self.phraseButtons, "phrases")
        AddGroup(self.buttons, "channels")
    else
        AddGroup(self.buttons, "channels")
        AddGroup(self.phraseButtons, "phrases")
    end

    if count == 0 then total = 1 end
    if vertical then
        self.mainFrame:SetSize(size, total)
    else
        self.mainFrame:SetSize(total, size)
    end
end

-------------------------------------------------------------------------------
-- ECB:ToggleBarVisibility
-- Shows or hides the main button bar and persists the state so it survives
-- reloads.  Bound to right-click on the minimap button.
-------------------------------------------------------------------------------
function ECB:ToggleBarVisibility()
    if not self.mainFrame then return end
    if self.mainFrame:IsShown() then
        self.mainFrame:Hide()
        ECB_DB.barHidden = true
        self.db.barHidden = true
    else
        self.mainFrame:Show()
        ECB_DB.barHidden = false
        self.db.barHidden = false
    end
end

-------------------------------------------------------------------------------
-- ECB:UpdateButtonVisibility
-- Evaluates each channel's visible predicate and shows/hides the matching
-- button, then reflows the layout so there are no gaps.
-------------------------------------------------------------------------------
function ECB:UpdateButtonVisibility()
    for i, btn in ipairs(self.buttons) do
        if C.CHANNELS[i].visible() then btn:Show() else btn:Hide() end
    end
    self:RefreshButtons()
end

-------------------------------------------------------------------------------
-- ECB:UpdateButtonColors
-- Re-reads ChatTypeInfo for every button and applies the current game colors
-- to the background (and optional glow) textures.  Call this whenever the
-- player changes chat colors in Interface Options (UPDATE_CHAT_COLOR event).
-------------------------------------------------------------------------------
function ECB:UpdateButtonColors()
    for _, btn in ipairs(self.buttons) do
        if btn._channelDef and btn._bg then
            local r, g, b = self:GetChannelColor(btn._channelDef)
            btn._bg:SetColorTexture(r, g, b, 1)
            if btn._glow then btn._glow:SetColorTexture(r, g, b, 0.35) end
        end
    end
    self:SyncPhraseButtons()
end

-------------------------------------------------------------------------------
-- ECB:UpdateActiveIndicator
-- Shows the bright ring on the button whose chatType matches the currently
-- active edit-box channel, and hides it on all others.  Safe to call when
-- no edit box is open (activeChatType is nil → all rings hidden).
-------------------------------------------------------------------------------
function ECB:UpdateActiveIndicator()
    local activeChatType = self.activeChatType  -- plain field read, no method call
    local chatBoxOpen    = activeChatType ~= nil
    local inactiveAlpha  = chatBoxOpen and 0.5 or 1.0
    local buttons        = self.buttons
    for i = 1, #buttons do
        local btn      = buttons[i]
        local isActive = chatBoxOpen
                      and btn._channelDef
                      and btn._channelDef.chatType == activeChatType

        -- Ring texture: visible only on the active button.
        if btn._ring then
            if isActive then btn._ring:Show() else btn._ring:Hide() end
        end

        -- Alpha: active button stays at full opacity; others dim slightly
        -- while the chat box is open so the active channel stands out.
        btn:SetAlpha(isActive and 1.0 or inactiveAlpha)
    end
end

-------------------------------------------------------------------------------
-- ECB:ApplySettings(settings)
-- The single entry point for applying any settings table to the live UI.
-- Accepts ECB.db, ECB.workingCopy, ECB.savedBeforeEdit, or a defaults table.
--
-- Steps:
--   1. Write bubbleSize and bubbleSpacing into ECB.db so all layout code reads
--      the new values immediately.
--   2. Re-evaluate every channel visibility predicate so buttons that should
--      appear or disappear react to the new size/spacing.
--   3. Reflow the layout: resize buttons, reanchor visible ones, resize the
--      container frame.  Hidden buttons leave no gap.
--
-- Does NOT write to ECB_DB — persistence is the caller's responsibility.
-------------------------------------------------------------------------------
function ECB:ApplySettings(settings)
    self.db.bubbleSize     = settings.bubbleSize
    self.db.bubbleSpacing  = settings.bubbleSpacing
    self.db.vertical       = settings.vertical
    self.db.hiddenChannels = settings.hiddenChannels or {}
    self.db.phrases        = type(settings.phrases) == "table" and settings.phrases or {}
    self.db.phraseGroupSpacing = math.max(
        C.SLIDER.phraseGroupSpacing.min,
        math.min(C.SLIDER.phraseGroupSpacing.max,
            tonumber(settings.phraseGroupSpacing) or self.defaults.phraseGroupSpacing))
    self.db.phrasePosition = settings.phrasePosition == "before" and "before" or "after"
    self:SyncPhraseButtons()
    -- UpdateButtonVisibility re-checks show/hide predicates and then calls
    -- RefreshButtons, so size, spacing, visibility, and layout are all updated
    -- in one pass.
    self:UpdateButtonVisibility()
end

-------------------------------------------------------------------------------
-- ECB:InitializeButtons
-- Creates every channel button and attaches them to the container frame.
-- Safe to call only once; guarded by ECB.mainFrame existence check.
-------------------------------------------------------------------------------
function ECB:InitializeButtons()
    for i, channelDef in ipairs(C.CHANNELS) do
        self.buttons[i] = CreateChannelButton(self.mainFrame, channelDef)
    end
    self:SyncPhraseButtons()
    self:UpdateButtonVisibility()
end

-------------------------------------------------------------------------------
-- ECB:CreateMainFrame
-- Creates the container frame anchored above the first chat tab, builds all
-- buttons, restores a saved position if one exists, and applies the lock state.
-- Called once from OnLogin() in Core.lua.
-------------------------------------------------------------------------------
function ECB:CreateMainFrame()
    if self.mainFrame then return end
    if not ChatFrame1Tab then return end

    local f = CreateFrame("Frame", "EasyChatChannelButtonsFrame", UIParent)
    f:SetSize(1, self.db.bubbleSize)
    f:SetPoint("BOTTOMLEFT", ChatFrame1Tab, "TOPLEFT", 25, self.db.bubbleSpacing)
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel(100)

    -- Semi-transparent yellow background visible only when the frame is unlocked.
    local padding = 6
    local dragBg = f:CreateTexture(nil, "BACKGROUND", nil, -2)
    dragBg:SetPoint("TOPLEFT", f, "TOPLEFT", -padding, padding)
    dragBg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", padding, -padding)
    dragBg:SetColorTexture(1, 0.8, 0, 0.25)
    dragBg:Hide()
    f._dragBg = dragBg

    -- Make the visible drag background handle mouse dragging as a fallback
    -- for clients or UI setups where the frame itself does not receive drag.
    -- Enabled only when the background is shown (ApplyLockState controls visibility).
    dragBg:EnableMouse(true)
    dragBg:SetScript("OnMouseDown", function(self, button)
        if ECB_DB.locked ~= false then return end
        local parent = self:GetParent()
        parent:StartMoving()
    end)
    dragBg:SetScript("OnMouseUp", function(self, button)
        local parent = self:GetParent()
        parent:StopMovingOrSizing()
        -- Persist new position
        local x, y = parent:GetLeft(), parent:GetBottom()
        if x and y then
            ECB_DB.x = x
            ECB_DB.y = y
        end
    end)

    -- Create an invisible drag handle frame that expands the clickable area
    -- so the user can drag even when the main frame is small or empty.
    local dragHandle = CreateFrame("Frame", nil, f)
    dragHandle:SetPoint("TOPLEFT", f, "TOPLEFT", -padding, padding)
    dragHandle:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", padding, -padding)
    dragHandle:Hide()
    dragHandle:EnableMouse(true)
    dragHandle:SetScript("OnMouseDown", function(self, button)
        if ECB_DB.locked ~= false then return end
        if self:GetParent()._dragBg then
            self:GetParent()._dragBg:SetColorTexture(1, 0.8, 0, 0.45)
            self:GetParent()._dragBg:Show()
        end
        self:GetParent():StartMoving()
    end)
    dragHandle:SetScript("OnMouseUp", function(self, button)
        local parent = self:GetParent()
        parent:StopMovingOrSizing()
        if parent._dragBg then
            parent._dragBg:SetColorTexture(1, 0.8, 0, 0.25)
        end
        SavePosition()
    end)
    f._dragHandle = dragHandle

    self.mainFrame = f

    self:InitializeButtons()

    -- Restore saved position (overrides the default anchor above ChatFrame1Tab).
    if ECB_DB.x and ECB_DB.y then
        f:ClearAllPoints()
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", ECB_DB.x, ECB_DB.y)
    end

    ApplyLockState(ECB_DB.locked ~= false)
end

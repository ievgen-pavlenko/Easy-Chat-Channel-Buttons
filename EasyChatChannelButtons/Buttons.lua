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
    print("|cff00ff00Easy Chat Channel Buttons:|r Frame locked.")
end

function ECB:UnlockFrame()
    ECB_DB.locked = false
    ApplyLockState(false)
    print("|cff00ff00Easy Chat Channel Buttons:|r Frame unlocked \226\128\147 drag to reposition, then /ecb lock.")
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

local function GetButtonSlotSize()
    local size = tonumber(ECB.db.bubbleSize) or ECB.defaults.bubbleSize
    if ECB.db.comfortableClickTargets then return math.max(20, size) end
    return size
end

local function FirstUTF8Character(value)
    if type(value) ~= "string" then return "" end
    value = strtrim(value)
    if value == "" then return "" end

    local first = string.byte(value, 1)
    if not first then return "" end

    local length
    if first < 0x80 then
        length = 1
    elseif first >= 0xC2 and first < 0xE0 then
        length = 2
    elseif first >= 0xE0 and first < 0xF0 then
        length = 3
    elseif first >= 0xF0 and first < 0xF5 then
        length = 4
    else
        return ""
    end

    if #value < length then return "" end
    for index = 2, length do
        local continuation = string.byte(value, index)
        if not continuation or continuation < 0x80 or continuation >= 0xC0 then
            return ""
        end
    end
    return string.sub(value, 1, length)
end

local function UpdateCircularButtonGeometry(btn, visualSize, slotSize)
    btn:SetSize(slotSize, slotSize)
    if btn._visual then btn._visual:SetSize(visualSize, visualSize) end

    local label = btn._bubbleLabel
    if not label then return end

    local fontPath = btn._bubbleLabelFont
    if not fontPath and GameFontNormalSmall and GameFontNormalSmall.GetFont then
        fontPath = GameFontNormalSmall:GetFont()
        btn._bubbleLabelFont = fontPath
    end
    if fontPath then
        local fontSize = math.max(6, math.min(12, math.floor(visualSize * 0.55 + 0.5)))
        label:SetFont(fontPath, fontSize, "OUTLINE")
    end

    label:SetText(btn._buttonLabelText or "")
    if ECB.db.showButtonLabels and btn._buttonLabelText
        and btn._buttonLabelText ~= "" then
        label:Show()
    else
        label:Hide()
    end
end

local function CreateCircularButtonBase(parent)
    local visualSize = tonumber(ECB.db.bubbleSize) or ECB.defaults.bubbleSize
    local slotSize = GetButtonSlotSize()
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(slotSize, slotSize)
    btn:SetNormalTexture("")
    btn:SetPushedTexture("")
    btn:SetHighlightTexture("")
    btn:SetDisabledTexture("")

    local visual = CreateFrame("Frame", nil, btn)
    visual:SetPoint("CENTER")
    visual:SetSize(visualSize, visualSize)
    visual:EnableMouse(false)
    btn._visual = visual

    if ECB:IsElvUILoaded() then
        local glow = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
        glow:SetPoint("TOPLEFT", visual, "TOPLEFT", -2, 2)
        glow:SetPoint("BOTTOMRIGHT", visual, "BOTTOMRIGHT", 2, -2)
        AddCircleMask(glow, btn)
        btn._glow = glow
    end

    local ring = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
    ring:SetPoint("TOPLEFT", visual, "TOPLEFT", -2, 2)
    ring:SetPoint("BOTTOMRIGHT", visual, "BOTTOMRIGHT", 2, -2)
    ring:SetColorTexture(1, 1, 1, 0.9)
    AddCircleMask(ring, btn)
    ring:Hide()
    btn._ring = ring

    local bg = btn:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetAllPoints(visual)
    AddCircleMask(bg, btn)
    btn._bg = bg

    local highlight = btn:CreateTexture(nil, "HIGHLIGHT", nil, 0)
    highlight:SetAllPoints(visual)
    highlight:SetColorTexture(1, 1, 1, 0.22)
    AddCircleMask(highlight, btn)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetAllPoints(visual)
    label:SetJustifyH("CENTER")
    label:SetJustifyV("MIDDLE")
    label:SetTextColor(1, 1, 1, 1)
    label:SetShadowColor(0, 0, 0, 1)
    label:SetShadowOffset(1, -1)
    label:Hide()
    btn._bubbleLabel = label

    UpdateCircularButtonGeometry(btn, visualSize, slotSize)
    return btn
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
    local btn = CreateCircularButtonBase(parent)
    local r, g, b = ECB:GetChannelColor(channelDef)
    btn._bg:SetColorTexture(r, g, b, 1)
    if btn._glow then btn._glow:SetColorTexture(r, g, b, 0.35) end
    btn._channelDef = channelDef
    btn._buttonLabelText = channelDef.label

    -- Tooltip.
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(channelDef.tooltip, 1, 1, 1)
        GameTooltip:AddLine("Click to switch chat.", 0.75, 0.75, 0.75)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Click handler.
    btn:SetScript("OnClick", function() ECB:SwitchChatType(channelDef.chatType) end)

    return btn
end

-------------------------------------------------------------------------------
-- CreateCustomChannelButton (module-private)
-- Uses the same visual language as built-in channels, but reads its saved
-- favorite and current runtime resolution from fields updated during sync.
-------------------------------------------------------------------------------
local function CreateCustomChannelButton(parent)
    local btn = CreateCircularButtonBase(parent)

    btn:SetScript("OnEnter", function(self)
        local channel = self._customChannelRuntime
        if not channel then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(channel.name, 1, 1, 1)
        GameTooltip:AddLine("Channel /" .. channel.localID, 0.75, 0.75, 0.75)
        GameTooltip:AddLine("Click to switch chat.", 0.75, 0.75, 0.75)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:SetScript("OnClick", function(self)
        if self._customChannelDef then
            ECB:SwitchCustomChannel(self._customChannelDef)
        end
    end)
    return btn
end

-------------------------------------------------------------------------------
-- CreatePhraseButton (module-private)
-- Builds a circular button whose colour, tooltip, and inserted text are read
-- from btn._phraseDef.  Reading the current definition at interaction time lets
-- the config editor update buttons in place without leaking frames.
-------------------------------------------------------------------------------
local function CreatePhraseButton(parent)
    local btn = CreateCircularButtonBase(parent)

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
        local preferredChannel = C.NormalizePhraseChannel(phrase.preferredChannel)
        if preferredChannel ~= C.DEFAULT_PHRASE_CHANNEL then
            local option = C.GetPhraseChannelOption(preferredChannel)
            GameTooltip:AddLine("Channel: " .. option.label, 0.75, 0.75, 0.75)
        end
        GameTooltip:AddLine("Click to insert phrase.", 0.75, 0.75, 0.75)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:SetScript("OnClick", function(self)
        local phrase = self._phraseDef
        if phrase then ECB:InsertPhrase(phrase.text, phrase.preferredChannel) end
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
        btn._buttonLabelText = FirstUTF8Character(phrase.tooltip)
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

local function GetCustomChannelColor(channel)
    local info = channel and ChatTypeInfo
        and ChatTypeInfo["CHANNEL" .. tostring(channel.localID)]
    if not info and ChatTypeInfo then info = ChatTypeInfo.CHANNEL end
    if info and info.r then return info.r, info.g, info.b end
    return 1, 1, 1
end

-------------------------------------------------------------------------------
-- ECB:SyncCustomChannelButtons
-- Keeps one reusable frame per saved favorite.  Unavailable favorites retain
-- their frame and settings entry but remain hidden until discovery resolves
-- them again.
-------------------------------------------------------------------------------
function ECB:SyncCustomChannelButtons()
    if not self.mainFrame then return end

    local favorites = self:NormalizeCustomChannelFavorites(self.db.customChannels)
    for i, favorite in ipairs(favorites) do
        local btn = self.customChannelButtons[i]
        if not btn then
            btn = CreateCustomChannelButton(self.mainFrame)
            self.customChannelButtons[i] = btn
        end

        local channel = self:ResolveCustomChannel(favorite)
        btn._customChannelDef = favorite
        btn._customChannelRuntime = channel
        btn._buttonLabelText = channel and tostring(channel.localID) or ""
        if channel then
            local r, g, b = GetCustomChannelColor(channel)
            btn._bg:SetColorTexture(r, g, b, 1)
            if btn._glow then btn._glow:SetColorTexture(r, g, b, 0.35) end
            btn:Show()
        else
            btn:Hide()
        end
    end

    for i = #favorites + 1, #self.customChannelButtons do
        local btn = self.customChannelButtons[i]
        btn._customChannelDef = nil
        btn._customChannelRuntime = nil
        btn:Hide()
    end
end

-------------------------------------------------------------------------------
-- ECB:RefreshButtons
-- Resizes every button to the current bubbleSize, then reflows only the
-- visible buttons horizontally (hidden buttons leave no gap).  The container
-- frame is resized to match the visible content exactly.
-------------------------------------------------------------------------------
function ECB:RefreshButtons()
    local visualSize = self.db.bubbleSize
    local size     = GetButtonSlotSize()
    local spacing  = self.db.bubbleSpacing
    local vertical = self.db.vertical
    local groupGap = self.db.phraseGroupSpacing or 20
    local prev     = nil
    local prevGroup = nil
    local count    = 0
    local total    = 0

    local function AddGroup(buttons, groupName)
        for _, btn in ipairs(buttons) do
            UpdateCircularButtonGeometry(btn, visualSize, size)
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

    -- Built-in chat types, numbered channel Favorites, and prepared phrases
    -- are distinct visual groups.  AddGroup only inserts groupGap when both
    -- adjacent groups contain at least one visible button, so unavailable or
    -- empty groups never leave redundant whitespace.
    local groups = {
        builtins = self.buttons,
        numbered = self.customChannelButtons,
        phrases = self.phraseButtons,
    }
    local order = self:GetGroupOrderOption(
        self.db.groupOrder, self.db.phrasePosition)
    for _, groupName in ipairs(order.groups) do
        AddGroup(groups[groupName], groupName)
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
    self:SyncCustomChannelButtons()
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
    local activeChannelTarget = self.activeChannelTarget
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

    local customButtons = self.customChannelButtons
    for i = 1, #customButtons do
        local btn = customButtons[i]
        local channel = btn._customChannelRuntime
        local isActive = chatBoxOpen
            and activeChatType == "CHANNEL"
            and channel
            and channel.localID == activeChannelTarget
        if btn._ring then
            if isActive then btn._ring:Show() else btn._ring:Hide() end
        end
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
    self.db.customChannels = self:NormalizeCustomChannelFavorites(settings.customChannels)
    self.db.phrases        = type(settings.phrases) == "table" and settings.phrases or {}
    self.db.phraseGroupSpacing = math.max(
        C.SLIDER.phraseGroupSpacing.min,
        math.min(C.SLIDER.phraseGroupSpacing.max,
            tonumber(settings.phraseGroupSpacing) or self.defaults.phraseGroupSpacing))
    self.db.groupOrder = self:NormalizeGroupOrder(
        settings.groupOrder, settings.phrasePosition)
    self.db.phrasePosition = self:GetLegacyPhrasePosition(self.db.groupOrder)
    self.db.phraseDraftBehavior = self:NormalizePhraseDraftBehavior(
        settings.phraseDraftBehavior)
    self.db.showButtonLabels = settings.showButtonLabels == true
    self.db.comfortableClickTargets = settings.comfortableClickTargets == true
    self:SyncCustomChannelButtons()
    self:SyncPhraseButtons()
    -- UpdateButtonVisibility re-checks show/hide predicates and then calls
    -- RefreshButtons, so size, spacing, visibility, and layout are all updated
    -- in one pass.
    self:UpdateButtonVisibility()
    self:UpdateActiveIndicator()
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
    self:SyncCustomChannelButtons()
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

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
-- ECB:RefreshButtons
-- Resizes every button to the current bubbleSize, then reflows only the
-- visible buttons horizontally (hidden buttons leave no gap).  The container
-- frame is resized to match the visible content exactly.
-------------------------------------------------------------------------------
function ECB:RefreshButtons()
    local size     = self.db.bubbleSize
    local spacing  = self.db.bubbleSpacing
    local vertical = self.db.vertical
    local prev     = nil
    local count    = 0

    for _, btn in ipairs(self.buttons) do
        btn:SetSize(size, size)
        if btn:IsShown() then
            btn:ClearAllPoints()
            if prev == nil then
                if vertical then
                    btn:SetPoint("TOP", self.mainFrame, "TOP", 0, 0)
                else
                    btn:SetPoint("LEFT", self.mainFrame, "LEFT", 0, 0)
                end
            else
                if vertical then
                    btn:SetPoint("TOP", prev, "BOTTOM", 0, -spacing)
                else
                    btn:SetPoint("LEFT", prev, "RIGHT", spacing, 0)
                end
            end
            prev  = btn
            count = count + 1
        end
    end

    local total = count > 0 and (count * size + (count - 1) * spacing) or 1
    if vertical then
        self.mainFrame:SetSize(size, total)
    else
        self.mainFrame:SetSize(total, size)
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
    self.db.bubbleSize    = settings.bubbleSize
    self.db.bubbleSpacing = settings.bubbleSpacing
    self.db.vertical      = settings.vertical
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
    local dragBg = f:CreateTexture(nil, "BACKGROUND", nil, -2)
    dragBg:SetAllPoints()
    dragBg:SetColorTexture(1, 0.8, 0, 0.25)
    dragBg:Hide()
    f._dragBg = dragBg

    self.mainFrame = f

    self:InitializeButtons()

    -- Restore saved position (overrides the default anchor above ChatFrame1Tab).
    if ECB_DB.x and ECB_DB.y then
        f:ClearAllPoints()
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", ECB_DB.x, ECB_DB.y)
    end

    ApplyLockState(ECB_DB.locked ~= false)
end

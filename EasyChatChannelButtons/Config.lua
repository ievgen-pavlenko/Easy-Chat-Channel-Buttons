local addonName, ns = ...
local ECB = ns.ECB
local C = ns.Constants

-- Guard: set to true while sliders are being synchronised programmatically
-- (ApplyDefaults, OnShow, OpenConfig).  Prevents OnValueChanged from writing
-- into ECB.workingCopy or calling ECB:ApplySettings for values that have not
-- actually changed as a result of user interaction.
local updating = false

-------------------------------------------------------------------------------
-- EasyChatChannelButtons – Config
-- Configuration UI: Blizzard settings canvas panel (default) and a standalone
-- draggable ElvUI-styled frame.
--
-- Data model:
--   ECB.defaults        – original default values, never mutated
--   ECB.db              – active runtime settings (mirrors ECB_DB keys)
--   ECB.workingCopy     – values being edited; modified by user slider gestures
--   ECB.savedBeforeEdit – snapshot of ECB.db taken when the panel opens;
--                         restored when the user clicks Cancel / X
--
-- Contract (enforced by code structure):
--   OnValueChanged  → ECB.workingCopy + live visual (ECB.db); never ECB_DB
--   OK / panel.okay → CommitWorkingCopy() → persists to ECB_DB and ECB.db
--   Cancel / X      → CancelEditing()     → restores ECB.savedBeforeEdit
--   Defaults        → ECB.workingCopy only; no ECB_DB write until OK
--
-- Programmatic SetValue calls (ApplyDefaults, OnShow, OpenConfig) set the
-- 'updating' guard so OnValueChanged only refreshes the readout label and
-- skips the workingCopy / ApplySettings pipeline.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CreateDarkButton (module-private)
-- Creates a flat dark button with no Blizzard chrome.
-- Uses manual textures so it looks minimal and ElvUI-like regardless of
-- whether ElvUI is actually loaded.
-- If ElvUI is loaded, ApplyElvUIButtonStyle() is called afterwards to apply
-- ElvUI's own backdrop and highlight on top.
-------------------------------------------------------------------------------
local function CreateDarkButton(parent, w, h, label)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(w, h)

    -- Background: dark fill.
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.10, 0.10, 0.12, 0.95)

    -- Border: thin 1px lighter edge drawn as an inset overlay.
    local border = btn:CreateTexture(nil, "BORDER")
    border:SetAllPoints()
    border:SetColorTexture(0.30, 0.30, 0.35, 0.8)

    -- Inner body sits above the border at 1px inset so the border shows.
    local body = btn:CreateTexture(nil, "ARTWORK")
    body:SetPoint("TOPLEFT",     btn, "TOPLEFT",      1, -1)
    body:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT",  -1,  1)
    body:SetColorTexture(0.10, 0.10, 0.12, 0.95)

    -- Hover highlight.
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)

    -- Label.
    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetAllPoints()
    fs:SetJustifyH("CENTER")
    fs:SetJustifyV("MIDDLE")
    fs:SetText(label)
    btn._label = fs

    -- If ElvUI is present, layer its backdrop and highlight on top.
    if ECB:IsElvUILoaded() then
        ECB:ApplyElvUIButtonStyle(btn)
    end

    return btn
end

-------------------------------------------------------------------------------
-- CreateLabeledSlider (module-private)
-- Returns a plain Slider (no Blizzard OptionsSliderTemplate chrome) with:
--   • a dark track texture
--   • a clean thumb
--   • a title label above it
--   • a numeric readout to its right
-- anchorFrame / offsetY position the title relative to a previous widget.
-------------------------------------------------------------------------------
local function CreateLabeledSlider(parent, cfg, anchorFrame, offsetY, width)
    width = width or 220

    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, offsetY)
    title:SetText(cfg.label)

    -- Plain slider: no template, so no Blizzard Low/High/Text children.
    local slider = CreateFrame("Slider", nil, parent)
    slider:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    slider:SetWidth(width)
    slider:SetHeight(14)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(cfg.min, cfg.max)
    slider:SetValueStep(cfg.step)
    slider:SetObeyStepOnDrag(true)

    -- Dark track background.
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT",  slider, "LEFT",  0,  0)
    track:SetPoint("RIGHT", slider, "RIGHT", 0,  0)
    track:SetHeight(4)
    track:SetColorTexture(0.08, 0.08, 0.10, 0.95)

    -- Track border.
    local trackBorder = slider:CreateTexture(nil, "BORDER")
    trackBorder:SetPoint("LEFT",  slider, "LEFT",  0,  0)
    trackBorder:SetPoint("RIGHT", slider, "RIGHT", 0,  0)
    trackBorder:SetHeight(6)
    trackBorder:SetColorTexture(0.28, 0.28, 0.32, 0.85)

    -- Thumb: small bright rectangle.
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(10, 18)
    thumb:SetColorTexture(0.65, 0.65, 0.70, 1)
    slider:SetThumbTexture(thumb)

    -- min / max range labels (plain FontStrings — no template children).
    local lowLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lowLabel:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
    lowLabel:SetText(tostring(cfg.min))

    local highLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    highLabel:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
    highLabel:SetText(tostring(cfg.max))

    -- Current value readout to the right of the slider.
    local valueLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueLabel:SetPoint("LEFT", slider, "RIGHT", 8, 0)
    slider._valueLabel = valueLabel

    return slider
end

-------------------------------------------------------------------------------
-- OnValueChanged handlers (module-private)
-- Fired by user slider gestures AND by programmatic SetValue calls.
--
-- The value-readout label is always updated (it only reflects the thumb
-- position, not any data model state).
--
-- ECB.workingCopy and ECB:ApplySettings are only reached when the user is
-- actually dragging the slider ('updating' is false).  Programmatic SetValue
-- callers set the guard to avoid spurious intermediate layout passes.
--
-- ECB_DB is never touched here.
-------------------------------------------------------------------------------
local function OnSizeChanged(self, rawVal)
    local val = math.floor(rawVal + 0.5)
    self._valueLabel:SetText(tostring(val))  -- always keep readout in sync
    if updating then return end
    ECB.workingCopy.bubbleSize = val
    ECB:ApplySettings(ECB.workingCopy)
end

local function OnSpacingChanged(self, rawVal)
    local val = math.floor(rawVal + 0.5)
    self._valueLabel:SetText(tostring(val))  -- always keep readout in sync
    if updating then return end
    ECB.workingCopy.bubbleSpacing = val
    ECB:ApplySettings(ECB.workingCopy)
end

-------------------------------------------------------------------------------
-- ApplyDefaults (module-private)
-- Resets ECB.workingCopy to the addon defaults and shows a live preview.
-- ECB_DB is NOT written; the change is not committed until the user presses OK.
-- Slider thumbs and readout labels are synced under the 'updating' guard so
-- the per-slider OnValueChanged handlers don't each trigger a layout pass.
-- A single ECB:ApplySettings call at the end applies all values at once.
-------------------------------------------------------------------------------
local function ApplyDefaults(sizeSlider, spacingSlider)
    local d = ECB:GetDefaults()   -- fresh CopyTable of ECB.defaults
    ECB.workingCopy = d
    updating = true
    sizeSlider:SetValue(d.bubbleSize)       -- updates thumb + label; skips pipeline
    spacingSlider:SetValue(d.bubbleSpacing) -- updates thumb + label; skips pipeline
    updating = false
    ECB:ApplySettings(ECB.workingCopy)      -- single layout pass with all values
end

-------------------------------------------------------------------------------
-- CommitWorkingCopy (module-private)
-- Persists ECB.workingCopy to ECB_DB and ECB.db, then applies the committed
-- settings visually.  Called on OK / panel.okay.
-------------------------------------------------------------------------------
local function CommitWorkingCopy()
    for k, v in pairs(ECB.workingCopy) do
        ECB_DB[k] = v
    end
    ECB.db = ECB:CopyTable(ECB.workingCopy)
    -- Re-apply from the now-committed ECB.db so the visual state is always in
    -- sync with persisted values, even if live preview was never triggered.
    ECB:ApplySettings(ECB.db)
end

-------------------------------------------------------------------------------
-- CancelEditing (module-private)
-- Restores the pre-open snapshot and reapplies it live.  Called on Cancel / X.
-------------------------------------------------------------------------------
local function CancelEditing()
    ECB.workingCopy = ECB:CopyTable(ECB.savedBeforeEdit)
    ECB:ApplySettings(ECB.savedBeforeEdit)
end

-------------------------------------------------------------------------------
-- ECB:CreateBlizzardConfig
-- Builds and registers the Blizzard Interface Options canvas panel.
-- The panel frame itself is a Blizzard canvas (required for Settings API
-- registration).  All controls inside it use the same dark flat styling as
-- the ElvUI standalone frame.
-- Called once; subsequent calls return the cached panel.
-------------------------------------------------------------------------------
function ECB:CreateBlizzardConfig()
    if self._blizzPanel then return self._blizzPanel end

    local panel = CreateFrame("Frame")
    panel.name  = C.ADDON_DISPLAY

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(C.ADDON_DISPLAY)

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    subtitle:SetText("Configure button appearance")

    local sizeSlider = CreateLabeledSlider(
        panel, C.SLIDER.bubbleSize, subtitle, -20, 220)
    local spacingSlider = CreateLabeledSlider(
        panel, C.SLIDER.bubbleSpacing, sizeSlider, -34, 220)

    sizeSlider:SetScript("OnValueChanged",    OnSizeChanged)
    spacingSlider:SetScript("OnValueChanged", OnSpacingChanged)

    local defaultsBtn = CreateDarkButton(panel, 90, 22, "Defaults")
    defaultsBtn:SetPoint("TOPLEFT", spacingSlider, "BOTTOMLEFT", 0, -24)
    defaultsBtn:SetScript("OnClick", function()
        ApplyDefaults(sizeSlider, spacingSlider)
    end)

    panel._sizeSlider    = sizeSlider
    panel._spacingSlider = spacingSlider

    -- OnShow: seed model and sync sliders under the updating guard.
    panel:SetScript("OnShow", function()
        ECB.savedBeforeEdit = ECB:CopyTable(ECB.db)
        ECB.workingCopy     = ECB:CopyTable(ECB.db)
        updating = true
        sizeSlider:SetValue(ECB.workingCopy.bubbleSize)
        spacingSlider:SetValue(ECB.workingCopy.bubbleSpacing)
        updating = false
    end)

    -- Blizzard panel lifecycle callbacks (called by the game, not by us).
    panel.okay    = function() CommitWorkingCopy() end
    panel.cancel  = function() CancelEditing()     end
    panel.default = function() ApplyDefaults(sizeSlider, spacingSlider) end

    -- Register with the Retail / Midnight Settings API; fall back for older clients.
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        panel._category = category
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end

    self._blizzPanel = panel
    return panel
end

-------------------------------------------------------------------------------
-- ECB:CreateElvUIConfig
-- Builds a standalone draggable frame styled to match ElvUI's visual language:
--   • Full-frame backdrop via ECB:ApplyElvUIFrameStyle (CreateBackdrop)
--   • Dark header band + 1px separator
--   • Dark flat buttons and sliders (CreateDarkButton / CreateLabeledSlider)
--   • OnShow always seeds the data model
-- Called once; subsequent calls return the cached frame.
-------------------------------------------------------------------------------
function ECB:CreateElvUIConfig()
    if self._elvFrame then return self._elvFrame end

    local FRAME_W  = 320
    local FRAME_H  = 225
    local HEADER_H = 24

    local f = CreateFrame("Frame", "ECBConfigFrame", UIParent)
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(200)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)

    -- Full-frame backdrop via ElvUI's injected CreateBackdrop.
    ECB:ApplyElvUIFrameStyle(f)

    -- Header band.
    local headerBg = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    headerBg:SetPoint("TOPLEFT",  f, "TOPLEFT",  2, -2)
    headerBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    headerBg:SetHeight(HEADER_H - 4)
    headerBg:SetColorTexture(0.08, 0.08, 0.10, 0.95)

    -- Separator.
    local separator = f:CreateTexture(nil, "BACKGROUND", nil, 2)
    separator:SetPoint("TOPLEFT",  f, "TOPLEFT",  2, -HEADER_H)
    separator:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -HEADER_H)
    separator:SetHeight(1)
    separator:SetColorTexture(0.30, 0.30, 0.35, 0.8)

    -- Title in the header band.
    local titleText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -6)
    titleText:SetText(C.ADDON_DISPLAY)

    -- Close (X): Cancel behaviour.
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetSize(HEADER_H, HEADER_H)
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function()
        CancelEditing()
        f:Hide()
    end)

    -- Content anchor just below the separator.
    local contentAnchor = f:CreateFontString(nil, "OVERLAY")
    contentAnchor:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -(HEADER_H + 12))

    local sizeSlider    = CreateLabeledSlider(f, C.SLIDER.bubbleSize,    contentAnchor, 0,  240)
    local spacingSlider = CreateLabeledSlider(f, C.SLIDER.bubbleSpacing, sizeSlider,   -34, 240)

    sizeSlider:SetScript("OnValueChanged",    OnSizeChanged)
    spacingSlider:SetScript("OnValueChanged", OnSpacingChanged)

    f._sizeSlider    = sizeSlider
    f._spacingSlider = spacingSlider

    -- Action buttons.
    local okBtn = CreateDarkButton(f, 60, 22, "OK")
    okBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 14)
    okBtn:SetScript("OnClick", function()
        CommitWorkingCopy()
        f:Hide()
    end)

    local cancelBtn = CreateDarkButton(f, 60, 22, "Cancel")
    cancelBtn:SetPoint("LEFT", okBtn, "RIGHT", 6, 0)
    cancelBtn:SetScript("OnClick", function()
        CancelEditing()
        f:Hide()
    end)

    local defaultsBtn = CreateDarkButton(f, 70, 22, "Defaults")
    defaultsBtn:SetPoint("LEFT", cancelBtn, "RIGHT", 6, 0)
    defaultsBtn:SetScript("OnClick", function()
        ApplyDefaults(sizeSlider, spacingSlider)
    end)

    -- OnShow: seed model and sync sliders under the updating guard.
    f:SetScript("OnShow", function()
        ECB.savedBeforeEdit = ECB:CopyTable(ECB.db)
        ECB.workingCopy     = ECB:CopyTable(ECB.db)
        updating = true
        sizeSlider:SetValue(ECB.workingCopy.bubbleSize)
        spacingSlider:SetValue(ECB.workingCopy.bubbleSpacing)
        updating = false
    end)

    f:Hide()
    self._elvFrame = f
    return f
end

-------------------------------------------------------------------------------
-- ECB:CreateConfigUI
-- Lazily creates the appropriate config UI depending on whether ElvUI is
-- loaded.  Returns the Blizzard panel or the ElvUI frame.
-- Safe to call multiple times; each branch is guarded by a cached reference.
-------------------------------------------------------------------------------
function ECB:CreateConfigUI()
    if self:IsElvUILoaded() then
        return self:CreateElvUIConfig()
    else
        return self:CreateBlizzardConfig()
    end
end

-------------------------------------------------------------------------------
-- ECB:InitializeConfig
-- Called once from Core.lua's OnLogin() after the database is ready.
-- Eagerly builds and registers the config UI so the Blizzard options panel
-- appears in Interface > AddOns without the player needing to type /ecb first.
-- For ElvUI users the standalone frame is created but kept hidden until opened.
-------------------------------------------------------------------------------
function ECB:InitializeConfig()
    self:CreateConfigUI()
end

-------------------------------------------------------------------------------
-- ECB:OpenConfig
-- Entry point called by the /ecb and /ecb config slash commands.
--
-- 1. Snapshots ECB.db into both ECB.savedBeforeEdit and ECB.workingCopy so
--    Cancel can always restore the exact pre-open state.
-- 2. Syncs slider positions to the current workingCopy values.
-- 3. Shows the appropriate UI.
-------------------------------------------------------------------------------
function ECB:OpenConfig()
    if not self.mainFrame then return end

    -- Snapshot current settings so Cancel can restore them exactly.
    self.savedBeforeEdit = self:CopyTable(self.db)
    self.workingCopy     = self:CopyTable(self.db)

    local ui = self:CreateConfigUI()

    -- Sync slider thumbs and readout labels to the freshly seeded workingCopy.
    -- The guard prevents OnValueChanged from treating this as a user gesture.
    updating = true
    if ui._sizeSlider    then ui._sizeSlider:SetValue(self.workingCopy.bubbleSize)       end
    if ui._spacingSlider then ui._spacingSlider:SetValue(self.workingCopy.bubbleSpacing) end
    updating = false

    if self:IsElvUILoaded() then
        -- Toggle the standalone ElvUI frame.
        -- On close, CancelEditing restores ECB.db to its pre-open state so
        -- a live-previewed but uncommitted value never leaks into ECB.db.
        if ui:IsShown() then
            CancelEditing()
            ui:Hide()
        else
            ui:Show()
        end
    else
        -- Open Blizzard Interface Options to this addon's panel.
        -- Settings.OpenToCategory expects the numeric ID, not the category object.
        if ui._category and Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(ui._category:GetID())
        elseif InterfaceOptionsFrame_OpenToCategory then
            InterfaceOptionsFrame_OpenToCategory(ui)
        end
    end
end

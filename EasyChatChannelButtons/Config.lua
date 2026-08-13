local addonName, ns = ...
local ECB = ns.ECB
local C = ns.Constants
local floor = math.floor

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
-- CreateLabeledCheckbox (module-private)
-- Returns a CheckButton with a title label to its right.
-- anchorFrame / offsetY position the checkbox relative to a previous widget.
-------------------------------------------------------------------------------
local function CreateLabeledCheckbox(parent, label, anchorFrame, offsetY)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(20, 20)
    cb:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, offsetY)

    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    lbl:SetText(label)

    return cb
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
-- ECB_DB is also written here so that settings persist even when the new
-- Settings API (Settings.RegisterCanvasLayoutCategory) does not call panel.okay.
-------------------------------------------------------------------------------
local function OnSizeChanged(self, rawVal)
    local val = floor(rawVal + 0.5)
    self._valueLabel:SetText(tostring(val))  -- always keep readout in sync
    if updating then return end
    ECB.workingCopy.bubbleSize = val
    ECB_DB.bubbleSize = val
    ECB:ApplySettings(ECB.workingCopy)
end

local function OnSpacingChanged(self, rawVal)
    local val = floor(rawVal + 0.5)
    self._valueLabel:SetText(tostring(val))  -- always keep readout in sync
    if updating then return end
    ECB.workingCopy.bubbleSpacing = val
    ECB_DB.bubbleSpacing = val
    ECB:ApplySettings(ECB.workingCopy)
end

local function OnTagSpacingChanged(self, rawVal)
    local val = floor(rawVal + 0.5)
    self._valueLabel:SetText(tostring(val))
    if updating then return end
    ECB.workingCopy.tagSpacing = val
    ECB_DB.tagSpacing = val
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
local function ApplyDefaults(sizeSlider, spacingSlider, tagSpacingSlider, verticalCheck, tagsBeforeCheck, channelCheckboxes)
    local d = ECB:GetDefaults()   -- fresh CopyTable of ECB.defaults
    ECB.workingCopy = d
    updating = true
    sizeSlider:SetValue(d.bubbleSize)
    spacingSlider:SetValue(d.bubbleSpacing)
    tagSpacingSlider:SetValue(d.tagSpacing)
    verticalCheck:SetChecked(d.vertical)
    tagsBeforeCheck:SetChecked(d.tagsBeforeChannels)
    for _, cb in pairs(channelCheckboxes) do
        cb:SetChecked(false)
    end
    updating = false
    ECB:ApplySettings(ECB.workingCopy)
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
    -- Restore ECB_DB to the pre-open snapshot so that any changes written
    -- by the auto-save handlers above are rolled back on Cancel.
    for k, v in pairs(ECB.savedBeforeEdit) do
        if type(v) == "table" then
            ECB_DB[k] = ECB:CopyTable(v)
        else
            ECB_DB[k] = v
        end
    end
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
    local tagSpacingSlider = CreateLabeledSlider(
        panel, C.SLIDER.tagSpacing, spacingSlider, -34, 220)

    sizeSlider:SetScript("OnValueChanged",    OnSizeChanged)
    spacingSlider:SetScript("OnValueChanged", OnSpacingChanged)
    tagSpacingSlider:SetScript("OnValueChanged", OnTagSpacingChanged)

    local verticalCheck = CreateLabeledCheckbox(panel, "Vertical layout", tagSpacingSlider, -30)
    verticalCheck:SetScript("OnClick", function(self)
        if updating then return end
        local checked = self:GetChecked()
        ECB.workingCopy.vertical = checked
        ECB_DB.vertical = checked
        ECB:ApplySettings(ECB.workingCopy)
    end)

    local tagsBeforeCheck = CreateLabeledCheckbox(panel, "Quick tags before channels", verticalCheck, -8)
    tagsBeforeCheck:SetScript("OnClick", function(self)
        if updating then return end
        local checked = self:GetChecked()
        ECB.workingCopy.tagsBeforeChannels = checked
        ECB_DB.tagsBeforeChannels = checked
        ECB:ApplySettings(ECB.workingCopy)
    end)

    -- Channel visibility section
    local visHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    visHeader:SetPoint("TOPLEFT", verticalCheck, "BOTTOMLEFT", 0, -22)
    visHeader:SetText("Hide Channels")

    local channelCheckboxes = {}
    local prevCbAnchor  = visHeader
    local prevCbOffsetY = -8
    for _, ch in ipairs(C.CHANNELS) do
        local cb = CreateLabeledCheckbox(panel, ch.tooltip, prevCbAnchor, prevCbOffsetY)
        local key = ch.key
        cb:SetScript("OnClick", function(self)
            if updating then return end
            if self:GetChecked() then
                ECB.workingCopy.hiddenChannels[key] = true
                ECB_DB.hiddenChannels[key] = true
            else
                ECB.workingCopy.hiddenChannels[key] = nil
                ECB_DB.hiddenChannels[key] = nil
            end
            ECB:ApplySettings(ECB.workingCopy)
        end)
        channelCheckboxes[key] = cb
        prevCbAnchor  = cb
        prevCbOffsetY = -4
    end

    local quickTagHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    quickTagHeader:SetPoint("TOPLEFT", prevCbAnchor, "BOTTOMLEFT", 0, -18)
    quickTagHeader:SetText("Quick Tags")

    local tagLabelName = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tagLabelName:SetPoint("TOPLEFT", quickTagHeader, "BOTTOMLEFT", 0, -10)
    tagLabelName:SetText("Label")
    local tagLabelBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    tagLabelBox:SetSize(130, 24)
    tagLabelBox:SetPoint("TOPLEFT", tagLabelName, "BOTTOMLEFT", 0, -4)
    tagLabelBox:SetAutoFocus(false)

    local tagValueName = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tagValueName:SetPoint("LEFT", tagLabelBox, "RIGHT", 16, 0)
    tagValueName:SetText("Value")
    local tagValueBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    tagValueBox:SetSize(220, 24)
    tagValueBox:SetPoint("TOPLEFT", tagValueName, "BOTTOMLEFT", 0, -4)
    tagValueBox:SetAutoFocus(false)

    local tagColorName = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tagColorName:SetPoint("TOPLEFT", tagLabelBox, "BOTTOMLEFT", 0, -18)
    tagColorName:SetText("Color")
    local tagColorBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    tagColorBox:SetSize(120, 24)
    tagColorBox:SetPoint("TOPLEFT", tagColorName, "BOTTOMLEFT", 0, -4)
    tagColorBox:SetAutoFocus(false)
    tagColorBox:SetText("#4aa3ff")

    local function Trim(value)
        return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
    end

    local function ParseHexColor(value)
        local hex = Trim(value):gsub("#", "")
        if #hex ~= 6 then return nil end
        local r = tonumber("0x" .. hex:sub(1, 2))
        local g = tonumber("0x" .. hex:sub(3, 4))
        local b = tonumber("0x" .. hex:sub(5, 6))
        if not r or not g or not b then return nil end
        return { r = r / 255, g = g / 255, b = b / 255 }
    end

    local tagRows = {}
    local editingTagIndex = nil
    local function RefreshTagRows()
        for _, row in ipairs(tagRows) do row:Hide() end

        local tags = ECB.workingCopy.quickTags or {}
        for i, tag in ipairs(tags) do
            local row = tagRows[i]
            if row == nil then
                row = CreateFrame("Frame", nil, panel)
                row:SetSize(420, 24)
                row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.label:SetPoint("LEFT", 0, 0)
                row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.value:SetPoint("LEFT", 120, 0)
                row.editBtn = CreateDarkButton(row, 44, 20, "Edit")
                row.editBtn:SetPoint("LEFT", 310, 0)
                row.deleteBtn = CreateDarkButton(row, 60, 20, "Delete")
                row.deleteBtn:SetPoint("LEFT", 360, 0)
                tagRows[i] = row
            end

            row.label:SetText(tag.label or "")
            row.value:SetText((tag.value or ""):sub(1, 28))
            row.editBtn:SetScript("OnClick", function()
                editingTagIndex = i
                tagLabelBox:SetText(tag.label or "")
                tagValueBox:SetText(tag.value or "")
                if tag.color then
                    local r, g, b = tag.color.r, tag.color.g, tag.color.b
                    tagColorBox:SetText(string.format("%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5)))
                else
                    tagColorBox:SetText("#4aa3ff")
                end
                addTagButton:SetText("Save")
            end)
            row.deleteBtn:SetScript("OnClick", function()
                table.remove(ECB.workingCopy.quickTags, i)
                ECB_DB.quickTags = ECB:CopyTable(ECB.workingCopy.quickTags)
                ECB:ApplySettings(ECB.workingCopy)
                RefreshTagRows()
            end)
            row:SetPoint("TOPLEFT", quickTagHeader, "BOTTOMLEFT", 0, -80 - ((i - 1) * 28))
            row:Show()
        end
    end

    local addTagButton = CreateDarkButton(panel, 80, 22, "Add")
    addTagButton:SetPoint("TOPLEFT", tagColorBox, "BOTTOMLEFT", 0, -12)
    addTagButton:SetScript("OnClick", function()
        local label = Trim(tagLabelBox:GetText())
        local value = Trim(tagValueBox:GetText())
        local color = ParseHexColor(tagColorBox:GetText())
        if label == "" or value == "" or not color then
            print("|cffff0000Quick tag requires label, value and a valid hex color.")
            return
        end

        local tag = { label = label, value = value, color = color, enabled = true }
        if editingTagIndex then
            ECB.workingCopy.quickTags[editingTagIndex] = tag
            editingTagIndex = nil
            addTagButton:SetText("Add")
        else
            ECB.workingCopy.quickTags = ECB.workingCopy.quickTags or {}
            table.insert(ECB.workingCopy.quickTags, tag)
        end

        ECB_DB.quickTags = ECB:CopyTable(ECB.workingCopy.quickTags)
        ECB:ApplySettings(ECB.workingCopy)
        tagLabelBox:SetText("")
        tagValueBox:SetText("")
        tagColorBox:SetText("#4aa3ff")
        RefreshTagRows()
    end)

    local tagImportHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tagImportHeader:SetPoint("TOPLEFT", addTagButton, "BOTTOMLEFT", 0, -18)
    tagImportHeader:SetText("Import / Export Tags")

    local tagImportText = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    tagImportText:SetSize(420, 90)
    tagImportText:SetPoint("TOPLEFT", tagImportHeader, "BOTTOMLEFT", 0, -8)
    tagImportText:SetMultiLine(true)
    tagImportText:SetAutoFocus(false)
    tagImportText:SetTextInsets(8, 8, 8, 8)
    tagImportText:SetText("label|value|#RRGGBB\nExample: @mythic+|<@&1393973414137696370>|#5aa3ff")
    tagImportText:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local function ExportTagsText()
        local lines = {}
        for _, tag in ipairs(ECB.workingCopy.quickTags or {}) do
            if tag and tag.label and tag.value then
                local r = tag.color and tag.color.r or 0.35
                local g = tag.color and tag.color.g or 0.75
                local b = tag.color and tag.color.b or 1.0
                local hex = string.format("%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
                table.insert(lines, string.format("%s|%s|#%s", tag.label, tag.value, hex))
            end
        end
        return table.concat(lines, "\n")
    end

    local function ImportTagsText()
        local text = tagImportText:GetText() or ""
        local tags = {}
        for line in string.gmatch(text, "[^\r\n]+") do
            local label, value, hex = line:match("^%s*(.-)%s*|%s*(.-)%s*|%s*(.-)%s*$")
            if label and value and label ~= "" and value ~= "" then
                local color = ParseHexColor(hex or "#4aa3ff")
                if not color then color = { r = 0.35, g = 0.75, b = 1.0 } end
                table.insert(tags, {
                    label = label,
                    value = value,
                    color = color,
                    enabled = true,
                })
            end
        end
        return tags
    end

    local exportTagsBtn = CreateDarkButton(panel, 90, 22, "Export")
    exportTagsBtn:SetPoint("TOPLEFT", tagImportText, "BOTTOMLEFT", 0, -10)
    exportTagsBtn:SetScript("OnClick", function()
        tagImportText:SetText(ExportTagsText())
    end)

    local importTagsBtn = CreateDarkButton(panel, 90, 22, "Import")
    importTagsBtn:SetPoint("LEFT", exportTagsBtn, "RIGHT", 8, 0)
    importTagsBtn:SetScript("OnClick", function()
        local imported = ImportTagsText()
        if #imported == 0 then
            print("|cffff0000No valid tags found in the import text.")
            return
        end
        ECB.workingCopy.quickTags = imported
        ECB_DB.quickTags = ECB:CopyTable(imported)
        ECB:ApplySettings(ECB.workingCopy)
        RefreshTagRows()
        tagImportText:SetText(ExportTagsText())
    end)

    local defaultsBtn = CreateDarkButton(panel, 90, 22, "Defaults")
    defaultsBtn:SetPoint("TOPLEFT", addTagButton, "BOTTOMLEFT", 0, -12)
    defaultsBtn:SetScript("OnClick", function()
        ApplyDefaults(sizeSlider, spacingSlider, tagSpacingSlider, verticalCheck, tagsBeforeCheck, channelCheckboxes)
    end)

    local lockBtn = CreateDarkButton(panel, 90, 22, "")
    lockBtn:SetPoint("LEFT", defaultsBtn, "RIGHT", 8, 0)

    local resetBtn = CreateDarkButton(panel, 110, 22, "Reset Position")
    resetBtn:SetPoint("LEFT", lockBtn, "RIGHT", 8, 0)
    resetBtn:SetScript("OnClick", function()
        -- Clear persisted custom position and re-anchor to default above ChatFrame1Tab
        ECB_DB.x = nil
        ECB_DB.y = nil
        if ECB.mainFrame then
            ECB.mainFrame:ClearAllPoints()
            if ChatFrame1Tab then
                ECB.mainFrame:SetPoint("BOTTOMLEFT", ChatFrame1Tab, "TOPLEFT", 25, ECB.db.bubbleSpacing)
            else
                -- fallback to screen center if ChatFrame1Tab missing
                ECB.mainFrame:SetPoint("CENTER", UIParent, "CENTER")
            end
        end
        print("|cff00ff00EasyChatChannelButtons:|r Position reset to default.")
    end)

    local function RefreshLockButton()
        local locked = (ECB_DB.locked ~= false)
        lockBtn._label:SetText(locked and "Unlock" or "Lock")
    end

    lockBtn:SetScript("OnClick", function()
        if ECB_DB.locked ~= false then
            ECB:UnlockFrame()
        else
            ECB:LockFrame()
        end
        RefreshLockButton()
    end)

    panel._sizeSlider        = sizeSlider
    panel._spacingSlider     = spacingSlider
    panel._tagSpacingSlider  = tagSpacingSlider
    panel._verticalCheck     = verticalCheck
    panel._tagsBeforeCheck   = tagsBeforeCheck
    panel._channelCheckboxes = channelCheckboxes

    -- OnShow: seed model and sync sliders under the updating guard.
    panel:SetScript("OnShow", function()
        ECB.savedBeforeEdit = ECB:CopyTable(ECB.db)
        ECB.workingCopy     = ECB:CopyTable(ECB.db)
        ECB.workingCopy.quickTags = ECB.workingCopy.quickTags or {}
        updating = true
        sizeSlider:SetValue(ECB.workingCopy.bubbleSize)
        spacingSlider:SetValue(ECB.workingCopy.bubbleSpacing)
        tagSpacingSlider:SetValue(ECB.workingCopy.tagSpacing or 6)
        verticalCheck:SetChecked(ECB.workingCopy.vertical)
        tagsBeforeCheck:SetChecked(ECB.workingCopy.tagsBeforeChannels ~= false)
        local hidden = ECB.workingCopy.hiddenChannels or {}
        for key, cb in pairs(channelCheckboxes) do
            cb:SetChecked(hidden[key] and true or false)
        end
        updating = false
        RefreshTagRows()
        tagImportText:SetText(ExportTagsText())
        RefreshLockButton()
    end)

    -- Blizzard panel lifecycle callbacks (called by the game, not by us).
    panel.okay    = CommitWorkingCopy
    panel.cancel  = CancelEditing
    panel.default = function() ApplyDefaults(sizeSlider, spacingSlider, tagSpacingSlider, verticalCheck, tagsBeforeCheck, channelCheckboxes) end

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
-- ECB:CreateConfigUI
-- Lazily creates the Blizzard config panel.
-- Safe to call multiple times; guarded by a cached reference.
-------------------------------------------------------------------------------
function ECB:CreateConfigUI()
    return self:CreateBlizzardConfig()
end

-------------------------------------------------------------------------------
-- ECB:InitializeConfig
-- Called once from Core.lua's OnLogin() after the database is ready.
-- Eagerly builds and registers the Blizzard options panel so it appears in
-- Interface > AddOns without the player needing to type /ecb first.
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
    if ui._sizeSlider       then ui._sizeSlider:SetValue(self.workingCopy.bubbleSize) end
    if ui._spacingSlider    then ui._spacingSlider:SetValue(self.workingCopy.bubbleSpacing) end
    if ui._tagSpacingSlider then ui._tagSpacingSlider:SetValue(self.workingCopy.tagSpacing or 6) end
    if ui._verticalCheck    then ui._verticalCheck:SetChecked(self.workingCopy.vertical) end
    if ui._tagsBeforeCheck  then ui._tagsBeforeCheck:SetChecked(self.workingCopy.tagsBeforeChannels ~= false) end
    if ui._channelCheckboxes then
        local hidden = self.workingCopy.hiddenChannels or {}
        for key, cb in pairs(ui._channelCheckboxes) do
            cb:SetChecked(hidden[key] and true or false)
        end
    end
    updating = false

    -- Open Blizzard Interface Options to this addon's panel.
    -- Settings.OpenToCategory expects the numeric ID, not the category object.
    if ui._category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(ui._category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(ui)
    end
end

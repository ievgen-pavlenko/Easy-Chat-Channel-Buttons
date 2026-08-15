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
-- Configuration UI: Blizzard settings canvas plus reusable dark manager and
-- transfer windows.  The same custom skin is used with or without ElvUI.
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

local function RegisterEscapeWindow(frame)
    if not frame or not frame.GetName or not frame:GetName() then return end
    UISpecialFrames = UISpecialFrames or {}
    for _, name in ipairs(UISpecialFrames) do
        if name == frame:GetName() then return end
    end
    UISpecialFrames[#UISpecialFrames + 1] = frame:GetName()
end

local function CreateTopCloseButton(parent)
    local button = CreateDarkButton(parent, 26, 22, "X")
    button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -10)
    button:SetScript("OnClick", function() parent:Hide() end)
    return button
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
    cb._label = lbl

    -- Blizzard's template only makes the square clickable.  Expand the hit
    -- region over the visible label so all settings checkboxes behave like a
    -- single control without changing their layout size.
    cb:SetHitRectInsets(0, -(lbl:GetStringWidth() + 4), 0, 0)

    return cb
end

-------------------------------------------------------------------------------
-- CreateDarkEditBox (module-private)
-- Compact single-line editor used by the prepared phrase list.
-------------------------------------------------------------------------------
local function CreateDarkEditBox(parent, width)
    local edit = CreateFrame("EditBox", nil, parent)
    edit:SetSize(width, 22)
    edit:SetAutoFocus(false)
    edit:SetFontObject(GameFontHighlightSmall)
    edit:SetJustifyH("LEFT")
    edit:SetTextInsets(6, 6, 0, 0)
    edit:SetMaxLetters(255)

    local border = edit:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.30, 0.30, 0.35, 0.9)
    local body = edit:CreateTexture(nil, "BACKGROUND", nil, 1)
    body:SetPoint("TOPLEFT", edit, "TOPLEFT", 1, -1)
    body:SetPoint("BOTTOMRIGHT", edit, "BOTTOMRIGHT", -1, 1)
    body:SetColorTexture(0.07, 0.07, 0.09, 0.98)

    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEnterPressed",  function(self) self:ClearFocus() end)
    return edit
end

local function PersistPhraseChanges()
    local phrases = type(ECB.workingCopy.phrases) == "table"
        and ECB.workingCopy.phrases or {}
    ECB.workingCopy.phrases = phrases
    ECB_DB.phrases = ECB:CopyTable(phrases)
    ECB:ApplySettings(ECB.workingCopy)
end

local function RefreshPhrasePositionLabel(button)
    local before = ECB.workingCopy.phrasePosition == "before"
    button._label:SetText(before and "Phrases: Before Chats" or "Phrases: After Chats")
end

-------------------------------------------------------------------------------
-- CreatePhraseEditor (module-private)
-- Scrollable editor for an arbitrary number of prepared phrases.  Rows are
-- reused while the panel is alive; each callback reads row._index so removal
-- and reordering never leave stale closures pointing at the wrong phrase.
-------------------------------------------------------------------------------
local function CreatePhraseEditor(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 285, -160)
    scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -32, 20)

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)

    -- Keep the scroll child inside the canvas at every Settings window size.
    -- UIPanelScrollFrameTemplate reserves roughly 28 px for its scrollbar.
    local function UpdateEditorWidth(width)
        child:SetWidth(math.max(1, (width or scroll:GetWidth()) - 28))
    end
    scroll:HookScript("OnSizeChanged", function(_, width)
        UpdateEditorWidth(width)
    end)
    UpdateEditorWidth()

    local rows = {}
    local Refresh

    local emptyText = child:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("TOPLEFT", child, "TOPLEFT", 6, -8)
    emptyText:SetPoint("RIGHT", child, "RIGHT", -10, 0)
    emptyText:SetJustifyH("LEFT")
    emptyText:SetText("No prepared phrases yet. Click Add Phrase to create one.")

    local function UpdateColor(row, r, g, b)
        local index = row._index
        local phrase = index and ECB.workingCopy.phrases[index]
        if not phrase then return end
        phrase.color = { r = r, g = g, b = b }
        row._colorTex:SetColorTexture(r, g, b, 1)
        PersistPhraseChanges()
    end

    local function OpenColorPicker(row)
        local index = row._index
        local phrase = index and ECB.workingCopy.phrases[index]
        if not phrase or not ColorPickerFrame then return end

        local color = type(phrase.color) == "table"
            and phrase.color or C.PHRASE_COLORS[1]
        local original = {
            r = tonumber(color.r) or 0.20,
            g = tonumber(color.g) or 0.65,
            b = tonumber(color.b) or 1.00,
        }
        local function ApplyColor()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            UpdateColor(row, r, g, b)
        end
        local function CancelColor(previous)
            previous = previous or original
            UpdateColor(row, previous.r or original.r,
                previous.g or original.g, previous.b or original.b)
        end

        local info = {
            r = original.r,
            g = original.g,
            b = original.b,
            swatchFunc = ApplyColor,
            cancelFunc = CancelColor,
        }
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow(info)
        else
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame.previousValues = original
            ColorPickerFrame.func = ApplyColor
            ColorPickerFrame.cancelFunc = CancelColor
            ColorPickerFrame:SetColorRGB(original.r, original.g, original.b)
            ColorPickerFrame:Show()
        end
    end

    local function CreateRow(index)
        local row = CreateFrame("Frame", nil, child)
        row:SetHeight(82)

        local rowBg = row:CreateTexture(nil, "BACKGROUND")
        rowBg:SetAllPoints()
        rowBg:SetColorTexture(0.10, 0.10, 0.12, index % 2 == 0 and 0.55 or 0.35)

        local numberLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        numberLabel:SetPoint("TOPLEFT", row, "TOPLEFT", 5, -5)
        row._numberLabel = numberLabel

        local colorButton = CreateDarkButton(row, 54, 18, "Color")
        colorButton:SetPoint("TOPRIGHT", row, "TOPRIGHT", -64, -3)
        local colorTex = colorButton:CreateTexture(nil, "OVERLAY")
        colorTex:SetPoint("LEFT", colorButton, "LEFT", 4, 0)
        colorTex:SetSize(10, 10)
        row._colorTex = colorTex
        colorButton._label:ClearAllPoints()
        colorButton._label:SetPoint("LEFT", colorTex, "RIGHT", 3, 0)
        colorButton._label:SetText("Color")
        colorButton:SetScript("OnClick", function() OpenColorPicker(row) end)

        local removeButton = CreateDarkButton(row, 56, 18, "Remove")
        removeButton:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -3)
        removeButton:SetScript("OnClick", function()
            if not row._index then return end
            table.remove(ECB.workingCopy.phrases, row._index)
            PersistPhraseChanges()
            Refresh()
        end)

        local textLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        textLabel:SetPoint("TOPLEFT", row, "TOPLEFT", 5, -29)
        textLabel:SetText("Text")
        local textEdit = CreateDarkEditBox(row, 10)
        textEdit:SetPoint("LEFT", textLabel, "LEFT", 50, 0)
        textEdit:SetPoint("RIGHT", row, "RIGHT", -5, 0)
        textEdit:SetScript("OnTextChanged", function(self, userInput)
            if updating or not userInput or not row._index then return end
            local phrase = ECB.workingCopy.phrases[row._index]
            if not phrase then return end
            phrase.text = self:GetText()
            PersistPhraseChanges()
        end)
        row._textEdit = textEdit

        local tooltipLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tooltipLabel:SetPoint("TOPLEFT", row, "TOPLEFT", 5, -56)
        tooltipLabel:SetText("Tooltip")
        local tooltipEdit = CreateDarkEditBox(row, 10)
        tooltipEdit:SetPoint("LEFT", tooltipLabel, "LEFT", 50, 0)
        tooltipEdit:SetPoint("RIGHT", row, "RIGHT", -5, 0)
        tooltipEdit:SetScript("OnTextChanged", function(self, userInput)
            if updating or not userInput or not row._index then return end
            local phrase = ECB.workingCopy.phrases[row._index]
            if not phrase then return end
            phrase.tooltip = self:GetText()
            PersistPhraseChanges()
        end)
        row._tooltipEdit = tooltipEdit

        rows[index] = row
        return row
    end

    Refresh = function()
        local phrases = type(ECB.workingCopy.phrases) == "table"
            and ECB.workingCopy.phrases or {}
        ECB.workingCopy.phrases = phrases
        updating = true
        for i, row in ipairs(rows) do row:Hide() end
        for i, phrase in ipairs(phrases) do
            if type(phrase) ~= "table" then
                phrase = {
                    text = tostring(phrase or ""),
                    tooltip = "",
                    color = ECB:CopyTable(C.PHRASE_COLORS[1]),
                }
                phrases[i] = phrase
            end
            local row = rows[i] or CreateRow(i)
            row._index = i
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -((i - 1) * 86))
            row:SetPoint("TOPRIGHT", child, "TOPRIGHT", -4, -((i - 1) * 86))
            row._numberLabel:SetText("Phrase " .. i)
            row._textEdit:SetText(type(phrase.text) == "string" and phrase.text or "")
            row._tooltipEdit:SetText(type(phrase.tooltip) == "string" and phrase.tooltip or "")
            local color = type(phrase.color) == "table"
                and phrase.color or C.PHRASE_COLORS[1]
            row._colorTex:SetColorTexture(
                tonumber(color.r) or 0.20,
                tonumber(color.g) or 0.65,
                tonumber(color.b) or 1.00, 1)
            row:Show()
        end
        child:SetHeight(math.max(30, #phrases * 86))
        if #phrases == 0 then emptyText:Show() else emptyText:Hide() end
        if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
        local maxScroll = scroll:GetVerticalScrollRange()
        if scroll:GetVerticalScroll() > maxScroll then
            scroll:SetVerticalScroll(maxScroll)
        end
        updating = false
    end

    return scroll, Refresh
end

-------------------------------------------------------------------------------
-- Prepared phrase transfer dialog
-- A single reusable modal serves both export and import.  Export text is
-- selected automatically; import validates before showing a destructive
-- replacement confirmation.
-------------------------------------------------------------------------------
local function CreatePhraseTransferDialog()
    if ECB._phraseTransferDialog then return ECB._phraseTransferDialog end

    local dialog = CreateFrame("Frame", "EasyChatChannelButtonsPhraseTransferDialog", UIParent)
    dialog:SetSize(520, 340)
    dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetFrameLevel(200)
    dialog:SetClampedToScreen(true)
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", function(self) self:StartMoving() end)
    dialog:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    dialog:Hide()
    RegisterEscapeWindow(dialog)

    local border = dialog:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.32, 0.32, 0.38, 1)
    local body = dialog:CreateTexture(nil, "BACKGROUND", nil, 1)
    body:SetPoint("TOPLEFT", dialog, "TOPLEFT", 1, -1)
    body:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -1, 1)
    body:SetColorTexture(0.055, 0.055, 0.07, 0.99)

    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, -17)
    dialog._title = title

    CreateTopCloseButton(dialog)

    local instruction = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    instruction:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    instruction:SetPoint("RIGHT", dialog, "RIGHT", -18, 0)
    instruction:SetJustifyH("LEFT")
    dialog._instruction = instruction

    local editScroll = CreateFrame(
        "ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
    editScroll:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, -70)
    editScroll:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -32, 66)

    local edit = CreateFrame("EditBox", nil, editScroll)
    edit:SetSize(1, 1)
    edit:SetAutoFocus(false)
    edit:SetMultiLine(true)
    edit:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    edit:SetJustifyH("LEFT")
    edit:SetJustifyV("TOP")
    edit:SetTextInsets(8, 8, 8, 8)
    editScroll:SetScrollChild(edit)

    local measure = dialog:CreateFontString(nil, "OVERLAY")
    measure:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    measure:SetAlpha(0)
    measure:SetWordWrap(true)
    if measure.SetNonSpaceWrap then measure:SetNonSpaceWrap(true) end

    local function UpdateTransferEditLayout()
        local width = math.max(1, editScroll:GetWidth() - 4)
        edit:SetWidth(width)
        measure:SetWidth(math.max(1, width - 16))
        measure:SetText(edit:GetText() or "")
        edit:SetHeight(math.max(editScroll:GetHeight(), measure:GetStringHeight() + 20))
        if editScroll.UpdateScrollChildRect then editScroll:UpdateScrollChildRect() end
    end

    editScroll:HookScript("OnSizeChanged", UpdateTransferEditLayout)
    edit:SetScript("OnTextChanged", UpdateTransferEditLayout)
    edit:SetScript("OnCursorChanged", function(_, _, y, _, height)
        local cursorTop = math.max(0, -(y or 0))
        local cursorBottom = cursorTop + (height or 0)
        local scrollTop = editScroll:GetVerticalScroll()
        local scrollBottom = scrollTop + editScroll:GetHeight()
        if cursorTop < scrollTop then
            editScroll:SetVerticalScroll(cursorTop)
        elseif cursorBottom > scrollBottom then
            editScroll:SetVerticalScroll(cursorBottom - editScroll:GetHeight())
        end
    end)
    edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        dialog:Hide()
    end)
    edit:SetScript("OnKeyDown", function(self, key)
        if key == "A" and IsControlKeyDown and IsControlKeyDown() then
            self:HighlightText()
        end
    end)
    dialog._edit = edit
    dialog._editScroll = editScroll

    local editBorder = dialog:CreateTexture(nil, "ARTWORK")
    editBorder:SetPoint("TOPLEFT", editScroll, "TOPLEFT", -1, 1)
    editBorder:SetPoint("BOTTOMRIGHT", editScroll, "BOTTOMRIGHT", 1, -1)
    editBorder:SetColorTexture(0.30, 0.30, 0.35, 0.95)
    local editBody = dialog:CreateTexture(nil, "ARTWORK", nil, 1)
    editBody:SetAllPoints(editScroll)
    editBody:SetColorTexture(0.025, 0.025, 0.035, 1)

    local status = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 18, 45)
    status:SetPoint("RIGHT", dialog, "RIGHT", -18, 0)
    status:SetJustifyH("LEFT")
    dialog._status = status

    local closeButton = CreateDarkButton(dialog, 80, 24, "Close")
    closeButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -16, 14)
    closeButton:SetScript("OnClick", function() dialog:Hide() end)

    local importButton = CreateDarkButton(dialog, 90, 24, "Import")
    importButton:SetPoint("RIGHT", closeButton, "LEFT", -8, 0)
    dialog._importButton = importButton

    dialog:SetScript("OnHide", function()
        edit:ClearFocus()
        status:SetText("")
    end)

    importButton:SetScript("OnClick", function()
        local phrases, err = ECB:DeserializePhrases(edit:GetText())
        if not phrases then
            status:SetText("|cffff5050" .. (err or "Invalid phrase export.") .. "|r")
            return
        end

        status:SetText("")
        local popup = StaticPopup_Show("ECB_CONFIRM_PHRASE_IMPORT", tostring(#phrases), nil, {
            phrases = phrases,
            dialog = dialog,
        })
        if popup then
            -- Keep the confirmation above this high-level modal on every UI
            -- scale.  Cancelling the popup restores the import window.
            dialog:Hide()
        else
            status:SetText("|cffff5050Unable to open the confirmation dialog.|r")
        end
    end)

    ECB._phraseTransferDialog = dialog
    return dialog
end

StaticPopupDialogs["ECB_CONFIRM_PHRASE_IMPORT"] = {
    text = "Are you sure you want to import %s prepared phrases?\n\nThis will replace the current phrase list.",
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, data)
        if not data or type(data.phrases) ~= "table" then return end
        ECB.workingCopy.phrases = ECB:CopyTable(data.phrases)
        -- Confirmation makes the import an explicit committed action.  Keep
        -- it even if the legacy Interface Options panel later fires Cancel;
        -- unrelated settings still restore from their original snapshot.
        ECB.savedBeforeEdit.phrases = ECB:CopyTable(data.phrases)
        PersistPhraseChanges()
        if ECB._blizzPanel and ECB._blizzPanel._refreshPhrases then
            ECB._blizzPanel._refreshPhrases()
        end
        if data.dialog then data.dialog:Hide() end
        print("|cff00ff00Easy Chat Channel Buttons:|r Imported " .. #data.phrases .. " prepared phrases.")
    end,
    OnCancel = function(_, data)
        if data and data.dialog then
            data.dialog:Show()
            data.dialog:Raise()
            data.dialog._edit:SetFocus()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function ECB:ShowPhraseExportDialog()
    local dialog = CreatePhraseTransferDialog()
    local phrases = type(self.workingCopy.phrases) == "table"
        and self.workingCopy.phrases or self.db.phrases
    dialog._title:SetText("Export Prepared Phrases")
    dialog._instruction:SetText("Press Ctrl+C to copy the selected export text.")
    dialog._status:SetText("")
    dialog._importButton:Hide()
    dialog._edit:SetText(self:SerializePhrases(phrases))
    dialog._editScroll:SetVerticalScroll(0)
    dialog:Show()
    dialog:Raise()
    dialog._edit:SetFocus()
    dialog._edit:HighlightText()
end

function ECB:ShowPhraseImportDialog()
    local dialog = CreatePhraseTransferDialog()
    dialog._title:SetText("Import Prepared Phrases")
    dialog._instruction:SetText("Paste an Easy Chat Channel Buttons phrase export, then click Import.")
    dialog._status:SetText("")
    dialog._importButton:Show()
    dialog._edit:SetText("")
    dialog._editScroll:SetVerticalScroll(0)
    dialog:Show()
    dialog:Raise()
    dialog._edit:SetFocus()
end

-------------------------------------------------------------------------------
-- Custom channel manager
-------------------------------------------------------------------------------
local function CreateCustomChannelManager()
    if ECB._customChannelManager then return ECB._customChannelManager end

    local manager = CreateFrame("Frame", "EasyChatChannelButtonsCustomChannelManager", UIParent)
    manager:SetSize(640, 520)
    manager:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    manager:SetFrameStrata("DIALOG")
    manager:SetFrameLevel(200)
    manager:SetClampedToScreen(true)
    manager:SetMovable(true)
    manager:EnableMouse(true)
    manager:RegisterForDrag("LeftButton")
    manager:SetScript("OnDragStart", function(self) self:StartMoving() end)
    manager:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    manager:Hide()
    RegisterEscapeWindow(manager)

    local border = manager:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.30, 0.30, 0.35, 0.98)
    local body = manager:CreateTexture(nil, "BACKGROUND", nil, 1)
    body:SetPoint("TOPLEFT", manager, "TOPLEFT", 1, -1)
    body:SetPoint("BOTTOMRIGHT", manager, "BOTTOMRIGHT", -1, 1)
    body:SetColorTexture(0.055, 0.055, 0.075, 0.99)

    local title = manager:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", manager, "TOPLEFT", 16, -16)
    title:SetText("Custom Channels")

    local subtitle = manager:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    subtitle:SetText("Favorite numbered text channels. The addon does not join or leave channels.")

    CreateTopCloseButton(manager)

    local inputLabel = manager:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    inputLabel:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -14)
    inputLabel:SetText("Channel name or active /N")

    local input = CreateDarkEditBox(manager, 430)
    input:SetPoint("TOPLEFT", inputLabel, "BOTTOMLEFT", 0, -6)
    input:SetMaxLetters(255)

    local addManualButton = CreateDarkButton(manager, 92, 22, "Add Channel")
    addManualButton:SetPoint("LEFT", input, "RIGHT", 8, 0)

    local status = manager:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", input, "BOTTOMLEFT", 0, -5)
    status:SetPoint("RIGHT", manager, "RIGHT", -16, 0)
    status:SetJustifyH("LEFT")
    status:SetText("")
    manager._status = status

    local favoritesHeader = manager:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    favoritesHeader:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -16)
    favoritesHeader:SetText("Favorites")

    local availableHeader = manager:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    availableHeader:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 310, -16)
    availableHeader:SetText("Available in This Location")

    local function CreateList(left, right, header)
        local scroll = CreateFrame("ScrollFrame", nil, manager, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
        scroll:SetPoint("BOTTOMRIGHT", manager, "BOTTOMLEFT", right, 48)
        local child = CreateFrame("Frame", nil, scroll)
        child:SetSize(math.max(1, right - left - 28), 1)
        scroll:SetScrollChild(child)
        return scroll, child
    end

    local favoritesScroll, favoritesChild = CreateList(16, 302, favoritesHeader)
    local availableScroll, availableChild = CreateList(326, 612, availableHeader)
    local favoriteRows, availableRows = {}, {}

    local favoritesEmpty = favoritesChild:CreateFontString(
        nil, "OVERLAY", "GameFontDisableSmall")
    favoritesEmpty:SetPoint("TOPLEFT", favoritesChild, "TOPLEFT", 6, -8)
    favoritesEmpty:SetPoint("RIGHT", favoritesChild, "RIGHT", -8, 0)
    favoritesEmpty:SetJustifyH("LEFT")
    favoritesEmpty:SetText("No favorite channels yet.")

    local availableEmpty = availableChild:CreateFontString(
        nil, "OVERLAY", "GameFontDisableSmall")
    availableEmpty:SetPoint("TOPLEFT", availableChild, "TOPLEFT", 6, -8)
    availableEmpty:SetPoint("RIGHT", availableChild, "RIGHT", -8, 0)
    availableEmpty:SetJustifyH("LEFT")

    local function CreateFavoriteRow(index)
        local row = CreateFrame("Frame", nil, favoritesChild)
        row:SetSize(258, 38)
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.10, 0.10, 0.12, index % 2 == 0 and 0.55 or 0.35)

        local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        name:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -5)
        name:SetPoint("RIGHT", row, "RIGHT", -70, 0)
        name:SetJustifyH("LEFT")
        name:SetWordWrap(false)
        row._name = name

        local rowStatus = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        rowStatus:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 6, 5)
        rowStatus:SetPoint("RIGHT", row, "RIGHT", -70, 0)
        rowStatus:SetJustifyH("LEFT")
        row._status = rowStatus

        local remove = CreateDarkButton(row, 60, 20, "Remove")
        remove:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        remove:SetScript("OnClick", function()
            if not row._index then return end
            local favorites = ECB:CopyTable(ECB.workingCopy.customChannels or {})
            table.remove(favorites, row._index)
            ECB:SetCustomChannelFavorites(favorites)
            status:SetText("|cff55dd77Channel removed.|r")
        end)
        favoriteRows[index] = row
        return row
    end

    local function CreateAvailableRow(index)
        local row = CreateFrame("Frame", nil, availableChild)
        row:SetSize(258, 34)
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.10, 0.10, 0.12, index % 2 == 0 and 0.55 or 0.35)

        local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        name:SetPoint("LEFT", row, "LEFT", 6, 0)
        name:SetPoint("RIGHT", row, "RIGHT", -58, 0)
        name:SetJustifyH("LEFT")
        name:SetWordWrap(false)
        row._name = name

        local add = CreateDarkButton(row, 48, 20, "Add")
        add:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        add:SetScript("OnClick", function()
            local channel = row._channel
            if not channel then return end
            local favorite = ECB:BuildCustomChannelFavorite(channel)
            local favorites = ECB:CopyTable(ECB.workingCopy.customChannels or {})
            favorites[#favorites + 1] = favorite
            ECB:SetCustomChannelFavorites(favorites)
            status:SetText("|cff55dd77Channel added.|r")
        end)
        availableRows[index] = row
        return row
    end

    local function HasFavorite(favorites, candidate)
        local candidateIdentity = ECB:GetCustomChannelIdentity(candidate)
        local candidateName = string.lower(strtrim(candidate.name or ""))
        for _, favorite in ipairs(favorites) do
            if ECB:GetCustomChannelIdentity(favorite) == candidateIdentity then return true end
            if string.lower(strtrim(favorite.name or "")) == candidateName then return true end
        end
        return false
    end

    local function Refresh()
        local favorites = ECB:NormalizeCustomChannelFavorites(ECB.workingCopy.customChannels)
        ECB.workingCopy.customChannels = favorites

        for _, row in ipairs(favoriteRows) do row:Hide() end
        for i, favorite in ipairs(favorites) do
            local row = favoriteRows[i] or CreateFavoriteRow(i)
            local channel = ECB:ResolveCustomChannel(favorite)
            row._index = i
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", favoritesChild, "TOPLEFT", 0, -((i - 1) * 40))
            row._name:SetText(channel and channel.name or favorite.name)
            if channel then
                row._status:SetText("|cff55dd77Active (/" .. channel.localID .. ")|r")
            else
                row._status:SetText("|cff888888Unavailable|r")
            end
            row:Show()
        end
        if #favorites == 0 then favoritesEmpty:Show() else favoritesEmpty:Hide() end
        favoritesChild:SetHeight(math.max(30, #favorites * 40))
        if favoritesScroll.UpdateScrollChildRect then favoritesScroll:UpdateScrollChildRect() end

        for _, row in ipairs(availableRows) do row:Hide() end
        local available = {}
        for _, channel in ipairs(ECB.activeCustomChannels or {}) do
            if not HasFavorite(favorites, channel) then
                available[#available + 1] = channel
            end
        end
        for i, channel in ipairs(available) do
            local row = availableRows[i] or CreateAvailableRow(i)
            row._channel = channel
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", availableChild, "TOPLEFT", 0, -((i - 1) * 36))
            row._name:SetText(channel.name .. "  |cff888888/" .. channel.localID .. "|r")
            row:Show()
        end
        if #available == 0 then
            if #(ECB.activeCustomChannels or {}) == 0 then
                availableEmpty:SetText("No available numbered channels in this location.")
            else
                availableEmpty:SetText("All available channels are already favorites.")
            end
            availableEmpty:Show()
        else
            availableEmpty:Hide()
        end
        availableChild:SetHeight(math.max(30, #available * 36))
        if availableScroll.UpdateScrollChildRect then availableScroll:UpdateScrollChildRect() end
    end

    addManualButton:SetScript("OnClick", function()
        local raw = strtrim(input:GetText() or "")
        if raw == "" then
            status:SetText("|cffff5050Enter a channel name or an active /N.|r")
            return
        end

        local channel = ECB:ResolveCustomChannel(raw)
        local numeric = string.match(raw, "^/?%d+$")
        if numeric and not channel then
            status:SetText("|cffff5050That numbered channel is not active.|r")
            return
        end

        local favorite = channel and ECB:BuildCustomChannelFavorite(channel) or { name = raw }
        local favorites = ECB:NormalizeCustomChannelFavorites(ECB.workingCopy.customChannels)
        if HasFavorite(favorites, favorite) then
            status:SetText("|cffffcc00That channel is already a favorite.|r")
            return
        end

        favorites[#favorites + 1] = favorite
        ECB:SetCustomChannelFavorites(favorites)
        input:SetText("")
        input:ClearFocus()
        status:SetText("|cff55dd77Channel added.|r")
    end)
    input:SetScript("OnEnterPressed", function()
        addManualButton:Click()
    end)
    input:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        manager:Hide()
    end)

    local bottomCloseButton = CreateDarkButton(manager, 80, 24, "Close")
    bottomCloseButton:SetPoint("BOTTOMRIGHT", manager, "BOTTOMRIGHT", -16, 14)
    bottomCloseButton:SetScript("OnClick", function() manager:Hide() end)

    ECB._refreshCustomChannelManager = Refresh
    manager:SetScript("OnShow", function()
        status:SetText("")
        ECB:RefreshCustomChannels(true)
        Refresh()
    end)
    manager:SetScript("OnHide", function()
        input:ClearFocus()
        status:SetText("")
    end)

    ECB._customChannelManager = manager
    return manager
end

function ECB:RefreshCustomChannelManager()
    local manager = self._customChannelManager
    if manager and manager:IsShown() and self._refreshCustomChannelManager then
        self._refreshCustomChannelManager()
    end
end

function ECB:ShowCustomChannelManager()
    local manager = CreateCustomChannelManager()
    manager:Show()
    manager:Raise()
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

local function OnGroupSpacingChanged(self, rawVal)
    local val = floor(rawVal + 0.5)
    self._valueLabel:SetText(tostring(val))
    if updating then return end
    ECB.workingCopy.phraseGroupSpacing = val
    ECB_DB.phraseGroupSpacing = val
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
local function ApplyDefaults(sizeSlider, spacingSlider, groupGapSlider, verticalCheck,
                             showLabelsCheck, comfortableTargetsCheck,
                             channelCheckboxes, phrasePositionButton, refreshPhrases)
    local d = ECB:GetDefaults()   -- fresh CopyTable of ECB.defaults
    ECB.workingCopy = d
    updating = true
    sizeSlider:SetValue(d.bubbleSize)       -- updates thumb + label; skips pipeline
    spacingSlider:SetValue(d.bubbleSpacing) -- updates thumb + label; skips pipeline
    groupGapSlider:SetValue(d.phraseGroupSpacing)
    verticalCheck:SetChecked(d.vertical)    -- syncs checkbox; skips pipeline
    showLabelsCheck:SetChecked(d.showButtonLabels)
    comfortableTargetsCheck:SetChecked(d.comfortableClickTargets)
    for _, cb in pairs(channelCheckboxes) do
        cb:SetChecked(true)                 -- default: every built-in button visible
    end
    RefreshPhrasePositionLabel(phrasePositionButton)
    updating = false
    refreshPhrases()
    ECB:ApplySettings(ECB.workingCopy)      -- single layout pass with all values
    ECB:RefreshCustomChannelManager()
end

-------------------------------------------------------------------------------
-- CommitWorkingCopy (module-private)
-- Persists ECB.workingCopy to ECB_DB and ECB.db, then applies the committed
-- settings visually.  Called on OK / panel.okay.
-------------------------------------------------------------------------------
local function CommitWorkingCopy()
    for k, v in pairs(ECB.workingCopy) do
        ECB_DB[k] = type(v) == "table" and ECB:CopyTable(v) or v
    end
    ECB.db = ECB:CopyTable(ECB.workingCopy)
    -- Re-apply from the now-committed ECB.db so the visual state is always in
    -- sync with persisted values, even if live preview was never triggered.
    ECB:ApplySettings(ECB.db)
    ECB:RefreshCustomChannelManager()
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
    ECB:RefreshCustomChannelManager()
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
    subtitle:SetText("Configure the button bar and shortcuts.")

    local appearanceHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    appearanceHeader:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -12)
    appearanceHeader:SetText("Appearance")

    local sizeSlider = CreateLabeledSlider(
        panel, C.SLIDER.bubbleSize, appearanceHeader, -10, 220)
    local spacingSlider = CreateLabeledSlider(
        panel, C.SLIDER.bubbleSpacing, sizeSlider, -20, 220)
    local groupGapSlider = CreateLabeledSlider(
        panel, C.SLIDER.phraseGroupSpacing, spacingSlider, -20, 220)

    sizeSlider:SetScript("OnValueChanged",    OnSizeChanged)
    spacingSlider:SetScript("OnValueChanged", OnSpacingChanged)
    groupGapSlider:SetScript("OnValueChanged", OnGroupSpacingChanged)

    local verticalCheck = CreateLabeledCheckbox(panel, "Vertical layout", groupGapSlider, -22)
    verticalCheck:SetScript("OnClick", function(self)
        if updating then return end
        local checked = self:GetChecked()
        ECB.workingCopy.vertical = checked
        ECB_DB.vertical = checked
        ECB:ApplySettings(ECB.workingCopy)
    end)

    local accessibilityHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    accessibilityHeader:SetPoint("TOPLEFT", verticalCheck, "BOTTOMLEFT", 0, -10)
    accessibilityHeader:SetText("Accessibility")

    local showLabelsCheck = CreateLabeledCheckbox(
        panel, "Show button labels", accessibilityHeader, -2)
    showLabelsCheck:SetScript("OnClick", function(self)
        if updating then return end
        local checked = self:GetChecked() and true or false
        ECB.workingCopy.showButtonLabels = checked
        ECB_DB.showButtonLabels = checked
        ECB:ApplySettings(ECB.workingCopy)
    end)

    local comfortableTargetsCheck = CreateLabeledCheckbox(
        panel, "Comfortable click targets", showLabelsCheck, -2)
    comfortableTargetsCheck:SetScript("OnClick", function(self)
        if updating then return end
        local checked = self:GetChecked() and true or false
        ECB.workingCopy.comfortableClickTargets = checked
        ECB_DB.comfortableClickTargets = checked
        ECB:ApplySettings(ECB.workingCopy)
    end)

    -- Prepared phrases are edited in a dedicated scrollable column so the
    -- existing channel controls remain compact and easy to scan.
    local phraseHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    phraseHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 285, -54)
    phraseHeader:SetText("Prepared Phrases")

    local phrasePositionButton = CreateDarkButton(panel, 150, 22, "")
    phrasePositionButton:SetPoint("TOPLEFT", phraseHeader, "BOTTOMLEFT", 0, -16)
    phrasePositionButton:SetScript("OnClick", function()
        if updating then return end
        ECB.workingCopy.phrasePosition =
            ECB.workingCopy.phrasePosition == "before" and "after" or "before"
        ECB_DB.phrasePosition = ECB.workingCopy.phrasePosition
        RefreshPhrasePositionLabel(phrasePositionButton)
        ECB:ApplySettings(ECB.workingCopy)
    end)

    local addPhraseButton = CreateDarkButton(panel, 90, 22, "Add Phrase")
    addPhraseButton:SetPoint("LEFT", phrasePositionButton, "RIGHT", 8, 0)

    local exportPhrasesButton = CreateDarkButton(panel, 110, 22, "Export Phrases")
    exportPhrasesButton:SetPoint("TOPLEFT", phrasePositionButton, "BOTTOMLEFT", 0, -7)
    exportPhrasesButton:SetScript("OnClick", function()
        ECB:ShowPhraseExportDialog()
    end)

    local importPhrasesButton = CreateDarkButton(panel, 110, 22, "Import Phrases")
    importPhrasesButton:SetPoint("LEFT", exportPhrasesButton, "RIGHT", 8, 0)
    importPhrasesButton:SetScript("OnClick", function()
        ECB:ShowPhraseImportDialog()
    end)

    local phraseScroll, refreshPhrases = CreatePhraseEditor(panel)
    addPhraseButton:SetScript("OnClick", function()
        if type(ECB.workingCopy.phrases) ~= "table" then
            ECB.workingCopy.phrases = {}
        end
        local nextIndex = #ECB.workingCopy.phrases + 1
        local preset = C.PHRASE_COLORS[((nextIndex - 1) % #C.PHRASE_COLORS) + 1]
        table.insert(ECB.workingCopy.phrases, {
            text = "",
            tooltip = "",
            color = { r = preset.r, g = preset.g, b = preset.b },
        })
        PersistPhraseChanges()
        refreshPhrases()
        if phraseScroll.UpdateScrollChildRect then phraseScroll:UpdateScrollChildRect() end
        phraseScroll:SetVerticalScroll(phraseScroll:GetVerticalScrollRange())
    end)

    -- Positive visibility controls remain backed by the existing
    -- hiddenChannels SavedVariables table.  Two semantic columns keep the
    -- panel compact: local/social chats on the left, group chats on the right.
    local builtInHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    builtInHeader:SetPoint("TOPLEFT", comfortableTargetsCheck, "BOTTOMLEFT", 0, -10)
    builtInHeader:SetText("Built-in Buttons")

    local channelCheckboxes = {}
    local columnAnchors = { builtInHeader, builtInHeader }
    for index, ch in ipairs(C.CHANNELS) do
        local column = index <= 5 and 1 or 2
        local firstInColumn = index == 1 or index == 6
        local cb = CreateLabeledCheckbox(
            panel, ch.tooltip, columnAnchors[column], -2)
        if firstInColumn and column == 2 then
            cb:ClearAllPoints()
            cb:SetPoint("TOPLEFT", builtInHeader, "BOTTOMLEFT", 126, -2)
        end

        local key = ch.key
        cb:SetScript("OnClick", function(self)
            if updating then return end
            if self:GetChecked() then
                ECB.workingCopy.hiddenChannels[key] = nil
                ECB_DB.hiddenChannels[key] = nil
            else
                ECB.workingCopy.hiddenChannels[key] = true
                ECB_DB.hiddenChannels[key] = true
            end
            ECB:ApplySettings(ECB.workingCopy)
        end)
        channelCheckboxes[key] = cb
        columnAnchors[column] = cb
    end

    local builtInBottomAnchor = columnAnchors[1]

    local defaultsBtn = CreateDarkButton(panel, 90, 22, "Defaults")
    defaultsBtn:SetPoint("TOPLEFT", builtInBottomAnchor, "BOTTOMLEFT", 0, -10)
    defaultsBtn:SetScript("OnClick", function()
        ApplyDefaults(sizeSlider, spacingSlider, groupGapSlider, verticalCheck,
            showLabelsCheck, comfortableTargetsCheck, channelCheckboxes,
            phrasePositionButton, refreshPhrases)
    end)

    local lockBtn = CreateDarkButton(panel, 90, 22, "")
    lockBtn:SetPoint("LEFT", defaultsBtn, "RIGHT", 8, 0)

    local resetBtn = CreateDarkButton(panel, 110, 22, "Reset Position")
    -- Keep this action on its own row.  The phrase list occupies the right
    -- column and can otherwise overlap this wider button on narrow canvases.
    resetBtn:SetPoint("TOPLEFT", defaultsBtn, "BOTTOMLEFT", 0, -6)
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
        print("|cff00ff00Easy Chat Channel Buttons:|r Position reset to default.")
    end)

    local customChannelsBtn = CreateDarkButton(panel, 150, 22, "Manage Custom Channels")
    customChannelsBtn:SetPoint("LEFT", resetBtn, "RIGHT", 8, 0)
    customChannelsBtn:SetScript("OnClick", function()
        ECB:ShowCustomChannelManager()
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
    panel._groupGapSlider    = groupGapSlider
    panel._verticalCheck     = verticalCheck
    panel._showLabelsCheck   = showLabelsCheck
    panel._comfortableTargetsCheck = comfortableTargetsCheck
    panel._channelCheckboxes = channelCheckboxes
    -- Compatibility alias for code that may still use the original local
    -- control name.  The persisted key also intentionally remains unchanged.
    panel._phraseGapSlider   = groupGapSlider
    panel._phrasePositionButton = phrasePositionButton
    panel._refreshPhrases    = refreshPhrases
    panel._phraseScroll      = phraseScroll
    panel._customChannelsButton = customChannelsBtn

    -- OnShow: seed model and sync sliders under the updating guard.
    panel:SetScript("OnShow", function()
        ECB.savedBeforeEdit = ECB:CopyTable(ECB.db)
        ECB.workingCopy     = ECB:CopyTable(ECB.db)
        updating = true
        sizeSlider:SetValue(ECB.workingCopy.bubbleSize)
        spacingSlider:SetValue(ECB.workingCopy.bubbleSpacing)
        groupGapSlider:SetValue(ECB.workingCopy.phraseGroupSpacing)
        verticalCheck:SetChecked(ECB.workingCopy.vertical)
        showLabelsCheck:SetChecked(ECB.workingCopy.showButtonLabels == true)
        comfortableTargetsCheck:SetChecked(
            ECB.workingCopy.comfortableClickTargets == true)
        local hidden = ECB.workingCopy.hiddenChannels or {}
        for key, cb in pairs(channelCheckboxes) do
            cb:SetChecked(not hidden[key])
        end
        RefreshPhrasePositionLabel(phrasePositionButton)
        updating = false
        refreshPhrases()
        ECB:RefreshCustomChannelManager()
        RefreshLockButton()
    end)

    panel:SetScript("OnHide", function()
        if ECB._customChannelManager then ECB._customChannelManager:Hide() end
    end)

    -- Blizzard panel lifecycle callbacks (called by the game, not by us).
    panel.okay    = CommitWorkingCopy
    panel.cancel  = CancelEditing
    panel.default = function()
        ApplyDefaults(sizeSlider, spacingSlider, groupGapSlider, verticalCheck,
            showLabelsCheck, comfortableTargetsCheck, channelCheckboxes,
            phrasePositionButton, refreshPhrases)
    end

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
    if ui._sizeSlider    then ui._sizeSlider:SetValue(self.workingCopy.bubbleSize)       end
    if ui._spacingSlider then ui._spacingSlider:SetValue(self.workingCopy.bubbleSpacing) end
    local groupGapSlider = ui._groupGapSlider or ui._phraseGapSlider
    if groupGapSlider then groupGapSlider:SetValue(self.workingCopy.phraseGroupSpacing) end
    if ui._verticalCheck then ui._verticalCheck:SetChecked(self.workingCopy.vertical)    end
    if ui._showLabelsCheck then
        ui._showLabelsCheck:SetChecked(self.workingCopy.showButtonLabels == true)
    end
    if ui._comfortableTargetsCheck then
        ui._comfortableTargetsCheck:SetChecked(
            self.workingCopy.comfortableClickTargets == true)
    end
    if ui._channelCheckboxes then
        local hidden = self.workingCopy.hiddenChannels or {}
        for key, cb in pairs(ui._channelCheckboxes) do
            cb:SetChecked(not hidden[key])
        end
    end
    if ui._phrasePositionButton then
        RefreshPhrasePositionLabel(ui._phrasePositionButton)
    end
    updating = false
    if ui._refreshPhrases then ui._refreshPhrases() end

    -- Open Blizzard Interface Options to this addon's panel.
    -- Settings.OpenToCategory expects the numeric ID, not the category object.
    if ui._category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(ui._category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(ui)
    end
end

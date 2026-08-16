local addonName, ns = ...
local ECB = ns.ECB
local C = ns.Constants

-------------------------------------------------------------------------------
-- EasyChatChannelButtons – Utils
-- Shared serialization helpers for prepared phrase export/import.
-------------------------------------------------------------------------------

-- The transfer header deliberately avoids the pipe character because WoW
-- EditBox can escape literal pipes while moving text through the clipboard.
local PHRASE_EXPORT_HEADER_V1 = "ECBPHRASESv1:"
local PHRASE_EXPORT_HEADER_V2 = "ECBPHRASESv2:"
local MAX_IMPORT_BYTES = 262144
local MAX_IMPORT_PHRASES = 200
local MAX_FIELD_BYTES = 4096

local function ColorByte(value, fallback)
    value = tonumber(value) or fallback
    value = math.max(0, math.min(1, value))
    return math.floor(value * 255 + 0.5)
end

local function AppendField(result, value)
    value = type(value) == "string" and value or ""
    result[#result + 1] = tostring(#value)
    result[#result + 1] = ":"
    result[#result + 1] = value
end

-------------------------------------------------------------------------------
-- ECB:SerializePhrases
-- Length-prefixed fields preserve spaces, punctuation, UTF-8 text, and any
-- delimiter characters without requiring an external JSON/Base64 library.
-------------------------------------------------------------------------------
function ECB:SerializePhrases(phrases, phraseDraftBehavior)
    phrases = type(phrases) == "table" and phrases or {}
    phraseDraftBehavior = self:NormalizePhraseDraftBehavior(phraseDraftBehavior)

    local result = { PHRASE_EXPORT_HEADER_V2, tostring(#phrases), ";" }
    AppendField(result, phraseDraftBehavior)
    for _, phrase in ipairs(phrases) do
        phrase = type(phrase) == "table" and phrase or {}
        local text = type(phrase.text) == "string" and phrase.text or ""
        local tooltip = type(phrase.tooltip) == "string" and phrase.tooltip or ""
        local preferredChannel = C.NormalizePhraseChannel(phrase.preferredChannel)
        local color = type(phrase.color) == "table" and phrase.color or {}
        local r = ColorByte(color.r, 0.20)
        local g = ColorByte(color.g, 0.65)
        local b = ColorByte(color.b, 1.00)

        AppendField(result, text)
        AppendField(result, tooltip)
        AppendField(result, preferredChannel)
        result[#result + 1] = r .. "," .. g .. "," .. b .. ";"
    end
    return table.concat(result)
end

local function ReadUnsigned(data, position, separator)
    if type(position) ~= "number" then return nil, position, "missing position" end
    local separatorPosition = string.find(data, separator, position, true)
    if not separatorPosition then return nil, position, "missing separator" end

    local raw = string.sub(data, position, separatorPosition - 1)
    if raw == "" or not string.match(raw, "^%d+$") then
        return nil, position, "invalid number"
    end
    return tonumber(raw), separatorPosition + 1
end

local function ReadField(data, position)
    local length, nextPosition, err = ReadUnsigned(data, position, ":")
    if not length then return nil, position, err end
    if length > MAX_FIELD_BYTES then return nil, position, "field is too long" end

    local lastByte = nextPosition + length - 1
    if lastByte > #data then return nil, position, "truncated field" end
    return string.sub(data, nextPosition, lastByte), lastByte + 1
end

-------------------------------------------------------------------------------
-- ECB:DeserializePhrases
-- Returns a transfer table or nil plus a user-facing validation error.  v1
-- imports receive CURRENT for every phrase and no draft-behavior override.
-------------------------------------------------------------------------------
function ECB:DeserializePhrases(exportText)
    if type(exportText) ~= "string" then return nil, "Export text is missing." end
    local data = strtrim(exportText)
    if string.sub(data, 1, 3) == "\239\187\191" then
        data = string.sub(data, 4)
    end
    if #data > MAX_IMPORT_BYTES then return nil, "Export text is too large." end

    local version, position
    if string.sub(data, 1, #PHRASE_EXPORT_HEADER_V2) == PHRASE_EXPORT_HEADER_V2 then
        version = 2
        position = #PHRASE_EXPORT_HEADER_V2 + 1
    elseif string.sub(data, 1, #PHRASE_EXPORT_HEADER_V1) == PHRASE_EXPORT_HEADER_V1 then
        version = 1
        position = #PHRASE_EXPORT_HEADER_V1 + 1
    else
        return nil, "This is not an Easy Chat Channel Buttons phrase export."
    end

    local count, nextPosition, err = ReadUnsigned(data, position, ";")
    if not count then return nil, "Invalid phrase count: " .. (err or "unknown error") .. "." end
    position = nextPosition
    if count > MAX_IMPORT_PHRASES then
        return nil, "An import can contain at most " .. MAX_IMPORT_PHRASES .. " phrases."
    end
    if type(position) ~= "number" then
        return nil, "Invalid phrase data position."
    end

    local phraseDraftBehavior
    if version == 2 then
        phraseDraftBehavior, position, err = ReadField(data, position)
        if not phraseDraftBehavior then
            return nil, "The draft behavior is invalid: " .. (err or "unknown error") .. "."
        end
        if not self.PHRASE_DRAFT_BEHAVIOR_BY_KEY[phraseDraftBehavior] then
            return nil, "The export contains an unknown draft behavior."
        end
    end

    local phrases = {}
    for i = 1, count do
        local text
        text, position, err = ReadField(data, position)
        if not text then return nil, "Phrase " .. i .. " has an invalid text field." end

        local tooltip
        tooltip, position, err = ReadField(data, position)
        if not tooltip then return nil, "Phrase " .. i .. " has an invalid tooltip field." end

        local preferredChannel = C.DEFAULT_PHRASE_CHANNEL
        if version == 2 then
            preferredChannel, position, err = ReadField(data, position)
            if not preferredChannel then
                return nil, "Phrase " .. i .. " has an invalid channel field."
            end
            if not C.PHRASE_CHANNEL_BY_KEY[preferredChannel] then
                return nil, "Phrase " .. i .. " has an unknown preferred channel."
            end
        end

        local colorEnd = string.find(data, ";", position, true)
        if not colorEnd then return nil, "Phrase " .. i .. " has no color terminator." end
        local colorText = string.sub(data, position, colorEnd - 1)
        local r, g, b = string.match(colorText, "^(%d+),(%d+),(%d+)$")
        r, g, b = tonumber(r), tonumber(g), tonumber(b)
        if not r or r > 255 or not g or g > 255 or not b or b > 255 then
            return nil, "Phrase " .. i .. " has an invalid color."
        end
        position = colorEnd + 1

        phrases[i] = {
            text = text,
            tooltip = tooltip,
            preferredChannel = preferredChannel,
            color = { r = r / 255, g = g / 255, b = b / 255 },
        }
    end

    if string.match(string.sub(data, position), "%S") then
        return nil, "Unexpected data was found after the last phrase."
    end
    return {
        phrases = phrases,
        phraseDraftBehavior = phraseDraftBehavior,
        version = version,
    }
end

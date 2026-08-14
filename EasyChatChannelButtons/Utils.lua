local addonName, ns = ...
local ECB = ns.ECB

-------------------------------------------------------------------------------
-- EasyChatChannelButtons – Utils
-- Shared serialization helpers for prepared phrase export/import.
-------------------------------------------------------------------------------

-- The transfer header deliberately avoids the pipe character because WoW
-- EditBox can escape literal pipes while moving text through the clipboard.
local PHRASE_EXPORT_HEADER = "ECBPHRASESv1:"
local MAX_IMPORT_BYTES = 262144
local MAX_IMPORT_PHRASES = 200
local MAX_FIELD_BYTES = 4096

local function ColorByte(value, fallback)
    value = tonumber(value) or fallback
    value = math.max(0, math.min(1, value))
    return math.floor(value * 255 + 0.5)
end

-------------------------------------------------------------------------------
-- ECB:SerializePhrases
-- Length-prefixed fields preserve spaces, punctuation, UTF-8 text, and any
-- delimiter characters without requiring an external JSON/Base64 library.
-------------------------------------------------------------------------------
function ECB:SerializePhrases(phrases)
    phrases = type(phrases) == "table" and phrases or {}

    local result = { PHRASE_EXPORT_HEADER, tostring(#phrases), ";" }
    for _, phrase in ipairs(phrases) do
        phrase = type(phrase) == "table" and phrase or {}
        local text = type(phrase.text) == "string" and phrase.text or ""
        local tooltip = type(phrase.tooltip) == "string" and phrase.tooltip or ""
        local color = type(phrase.color) == "table" and phrase.color or {}
        local r = ColorByte(color.r, 0.20)
        local g = ColorByte(color.g, 0.65)
        local b = ColorByte(color.b, 1.00)

        result[#result + 1] = tostring(#text)
        result[#result + 1] = ":"
        result[#result + 1] = text
        result[#result + 1] = tostring(#tooltip)
        result[#result + 1] = ":"
        result[#result + 1] = tooltip
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
-- Returns a phrase array or nil plus a user-facing validation error.
-------------------------------------------------------------------------------
function ECB:DeserializePhrases(exportText)
    if type(exportText) ~= "string" then return nil, "Export text is missing." end
    local data = strtrim(exportText)
    if string.sub(data, 1, 3) == "\239\187\191" then
        data = string.sub(data, 4)
    end
    if #data > MAX_IMPORT_BYTES then return nil, "Export text is too large." end
    if string.sub(data, 1, #PHRASE_EXPORT_HEADER) ~= PHRASE_EXPORT_HEADER then
        return nil, "This is not an Easy Chat Channel Buttons phrase export."
    end

    local position = #PHRASE_EXPORT_HEADER + 1
    local count, nextPosition, err = ReadUnsigned(data, position, ";")
    if not count then return nil, "Invalid phrase count: " .. (err or "unknown error") .. "." end
    position = nextPosition
    if count > MAX_IMPORT_PHRASES then
        return nil, "An import can contain at most " .. MAX_IMPORT_PHRASES .. " phrases."
    end
    if type(position) ~= "number" then
        return nil, "Invalid phrase data position."
    end

    local phrases = {}
    for i = 1, count do
        local text
        text, position, err = ReadField(data, position)
        if not text then return nil, "Phrase " .. i .. " has an invalid text field." end

        local tooltip
        tooltip, position, err = ReadField(data, position)
        if not tooltip then return nil, "Phrase " .. i .. " has an invalid tooltip field." end

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
            color = { r = r / 255, g = g / 255, b = b / 255 },
        }
    end

    if string.match(string.sub(data, position), "%S") then
        return nil, "Unexpected data was found after the last phrase."
    end
    return phrases
end

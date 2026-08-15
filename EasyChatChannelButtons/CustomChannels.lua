local addonName, ns = ...
local ECB = ns.ECB

-------------------------------------------------------------------------------
-- EasyChatChannelButtons – Custom Channels
-- Discovery and persistence helpers for numbered text channels (/1 … /20).
-- Local channel IDs are deliberately runtime-only because they may change
-- after a zone transition or when the player joins/leaves another channel.
-------------------------------------------------------------------------------

local function Trim(value)
    if type(value) ~= "string" then return "" end
    return strtrim(value)
end

local function NormalizeName(value)
    return string.lower(Trim(value))
end

local function IsSupportedChannelType(channelType)
    local permanentTypes = Enum and Enum.PermanentChatChannelType
    local zoneType = permanentTypes and permanentTypes.Zone or 1
    local customType = permanentTypes and permanentTypes.Custom or 3
    return channelType == zoneType or channelType == customType
end

local function IsZoneChannelType(channelType)
    local permanentTypes = Enum and Enum.PermanentChatChannelType
    local zoneType = permanentTypes and permanentTypes.Zone or 1
    return channelType == zoneType
end

local function NormalizeRuntimeInfo(info)
    if type(info) ~= "table" then return nil end

    local name = Trim(info.name)
    local localID = tonumber(info.localID)
    if name == "" or not localID or localID <= 0 then return nil end
    if not IsSupportedChannelType(info.channelType) then return nil end

    local zoneChannelID = tonumber(info.zoneChannelID)
    if not IsZoneChannelType(info.channelType)
        or not zoneChannelID or zoneChannelID <= 0 then
        zoneChannelID = nil
    end

    return {
        name          = name,
        shortcut      = Trim(info.shortcut),
        localID       = localID,
        instanceID    = tonumber(info.instanceID) or 0,
        zoneChannelID = zoneChannelID,
        channelType   = info.channelType,
    }
end

local function GetInfoFromIdentifier(identifier)
    if not C_ChatInfo or not C_ChatInfo.GetChannelInfoFromIdentifier then
        return nil
    end
    identifier = Trim(tostring(identifier or ""))
    if identifier == "" then return nil end

    local info = C_ChatInfo.GetChannelInfoFromIdentifier(identifier)
    if not info and string.sub(identifier, 1, 1) == "/" then
        info = C_ChatInfo.GetChannelInfoFromIdentifier(string.sub(identifier, 2))
    end
    return NormalizeRuntimeInfo(info)
end

-------------------------------------------------------------------------------
-- BuildChannelAvailability
-- C_ChatInfo can retain zone channels such as Trade while they are temporarily
-- unusable.  The legacy channel list exposes that state as its third value in
-- each id/name/disabled triplet, so use it as the availability authority.
-------------------------------------------------------------------------------
local function BuildChannelAvailability()
    local byLocalID, byName = {}, {}
    if type(GetChannelList) ~= "function" then
        return byLocalID, byName, false
    end

    local values = { pcall(GetChannelList) }
    local succeeded = table.remove(values, 1)
    if not succeeded then
        return byLocalID, byName, false
    end

    for index = 1, #values, 3 do
        local localID = tonumber(values[index])
        local name = Trim(values[index + 1])
        local available = values[index + 2] ~= true

        if localID and localID > 0 then byLocalID[localID] = available end
        if name ~= "" then byName[NormalizeName(name)] = available end
    end
    return byLocalID, byName, true
end

-------------------------------------------------------------------------------
-- ECB:GetCustomChannelIdentity
-- Zone channels use Blizzard's stable zoneChannelID.  Player-created channels
-- use their normalized name.  The transient localID is never part of identity.
-------------------------------------------------------------------------------
function ECB:GetCustomChannelIdentity(channel)
    if type(channel) ~= "table" then return nil end

    local zoneChannelID = tonumber(channel.zoneChannelID)
    if zoneChannelID and zoneChannelID > 0 then
        return "zone:" .. tostring(zoneChannelID)
    end

    local name = NormalizeName(channel.name)
    if name == "" then return nil end
    return "name:" .. name
end

-------------------------------------------------------------------------------
-- ECB:NormalizeCustomChannelFavorites
-- Sanitizes imported/legacy SavedVariables without mutating the source table.
-------------------------------------------------------------------------------
function ECB:NormalizeCustomChannelFavorites(favorites)
    local result = {}
    local seen = {}
    local seenNames = {}
    if type(favorites) ~= "table" then return result end

    for _, favorite in ipairs(favorites) do
        if type(favorite) == "table" then
            local name = Trim(favorite.name)
            local zoneChannelID = tonumber(favorite.zoneChannelID)
            if not zoneChannelID or zoneChannelID <= 0 then zoneChannelID = nil end

            local normalized = {
                name = name,
                zoneChannelID = zoneChannelID,
            }
            local identity = name ~= "" and self:GetCustomChannelIdentity(normalized) or nil
            local normalizedName = NormalizeName(name)
            if identity and not seen[identity] and not seenNames[normalizedName] then
                seen[identity] = true
                seenNames[normalizedName] = true
                result[#result + 1] = normalized
            end
        elseif type(favorite) == "string" then
            local name = Trim(favorite)
            local identity = name ~= "" and "name:" .. NormalizeName(name) or nil
            local normalizedName = NormalizeName(name)
            if identity and not seen[identity] and not seenNames[normalizedName] then
                seen[identity] = true
                seenNames[normalizedName] = true
                result[#result + 1] = { name = name }
            end
        end
    end
    return result
end

-------------------------------------------------------------------------------
-- ECB:DiscoverActiveCustomChannels
-- Uses the modern Retail C_ChatInfo API and returns supported channels sorted
-- by their current local number.  Communities are excluded by channelType.
-------------------------------------------------------------------------------
function ECB:DiscoverActiveCustomChannels()
    local result = {}
    local seen = {}
    if not C_ChatInfo
        or not C_ChatInfo.GetNumActiveChannels
        or not C_ChatInfo.GetChannelShortcut
        or not C_ChatInfo.GetChannelInfoFromIdentifier then
        return result
    end

    local availabilityByLocalID, availabilityByName, availabilityKnown =
        BuildChannelAvailability()

    local count = tonumber(C_ChatInfo.GetNumActiveChannels()) or 0
    for index = 1, count do
        local shortcut = C_ChatInfo.GetChannelShortcut(index)
        local info = shortcut and GetInfoFromIdentifier(shortcut) or nil

        -- Defensive fallback for clients where the shortcut is unavailable or
        -- is not accepted as an identifier.  Active list indexes usually map
        -- to a valid channel identifier, but the resolved localID remains the
        -- only value used for the live button.
        if not info then info = GetInfoFromIdentifier(tostring(index)) end
        if info then
            local available = availabilityByLocalID[info.localID]
            if available == nil then
                available = availabilityByName[NormalizeName(info.name)]
            end

            local identity = self:GetCustomChannelIdentity(info)
            if identity and not seen[identity]
                and (not availabilityKnown or available == true) then
                seen[identity] = true
                result[#result + 1] = info
            end
        end
    end

    table.sort(result, function(a, b)
        if a.localID == b.localID then return a.name < b.name end
        return a.localID < b.localID
    end)
    return result
end

local function BuildActiveMaps(channels)
    local byIdentity, byName, byLocalID = {}, {}, {}
    for _, channel in ipairs(channels) do
        local identity = ECB:GetCustomChannelIdentity(channel)
        if identity then byIdentity[identity] = channel end
        byName[NormalizeName(channel.name)] = channel
        byLocalID[channel.localID] = channel
    end
    return byIdentity, byName, byLocalID
end

-------------------------------------------------------------------------------
-- ECB:ResolveCustomChannel
-- Resolves a saved favorite, name, or current /N against the latest runtime
-- channel list.  It never returns a stale channel number.
-------------------------------------------------------------------------------
function ECB:ResolveCustomChannel(value)
    local byIdentity = self.activeCustomChannelsByIdentity or {}
    local byName = self.activeCustomChannelsByName or {}
    local byLocalID = self.activeCustomChannelsByLocalID or {}

    if type(value) == "table" then
        local identity = self:GetCustomChannelIdentity(value)
        if identity and byIdentity[identity] then return byIdentity[identity] end

        local name = NormalizeName(value.name)
        if name ~= "" and byName[name] then return byName[name] end
        value = value.name
    end

    local identifier = Trim(value)
    if identifier == "" then return nil end

    local numeric = string.match(identifier, "^/?(%d+)$")
    if numeric then return byLocalID[tonumber(numeric)] end

    local direct = GetInfoFromIdentifier(identifier)
    if direct then
        local identity = self:GetCustomChannelIdentity(direct)
        return (identity and byIdentity[identity]) or byName[NormalizeName(direct.name)]
    end
    return byName[NormalizeName(identifier)]
end

function ECB:BuildCustomChannelFavorite(channel)
    if type(channel) ~= "table" then return nil end
    local name = Trim(channel.name)
    if name == "" then return nil end
    local zoneChannelID = tonumber(channel.zoneChannelID)
    if not zoneChannelID or zoneChannelID <= 0 then zoneChannelID = nil end
    return {
        name = name,
        zoneChannelID = zoneChannelID,
    }
end

-------------------------------------------------------------------------------
-- ECB:RefreshCustomChannels
-- Rebuilds runtime maps, performs the one-time initial seed, and refreshes all
-- consumers.  ECB_DB.customChannelsInitialized is migration metadata rather
-- than a user setting, so Defaults cannot accidentally trigger another seed.
-------------------------------------------------------------------------------
function ECB:RefreshCustomChannels(allowInitialSeed)
    local channels = self:DiscoverActiveCustomChannels()
    self.activeCustomChannels = channels
    self.activeCustomChannelsByIdentity,
        self.activeCustomChannelsByName,
        self.activeCustomChannelsByLocalID = BuildActiveMaps(channels)

    if allowInitialSeed and ECB_DB and ECB_DB.customChannelsInitialized ~= true
        and #channels > 0 then
        local favorites = {}
        for _, channel in ipairs(channels) do
            local favorite = self:BuildCustomChannelFavorite(channel)
            if favorite then favorites[#favorites + 1] = favorite end
        end
        self.db.customChannels = self:CopyTable(favorites)
        ECB_DB.customChannels = self:CopyTable(favorites)
        ECB_DB.customChannelsInitialized = true
        if self._blizzPanel and self._blizzPanel:IsShown() then
            self.workingCopy.customChannels = self:CopyTable(favorites)
            self.savedBeforeEdit.customChannels = self:CopyTable(favorites)
        end
    end

    local editBox = self.GetActiveEditBox and self:GetActiveEditBox() or nil
    if editBox then
        self.activeChatType = editBox:GetAttribute("chatType")
        self.activeChannelTarget = self.activeChatType == "CHANNEL"
            and self:GetEditBoxChannelTarget(editBox) or nil
    end

    if self.SyncCustomChannelButtons then self:SyncCustomChannelButtons() end
    if self.RefreshButtons then self:RefreshButtons() end
    if self.UpdateActiveIndicator then self:UpdateActiveIndicator() end
    if self.RefreshCustomChannelManager then self:RefreshCustomChannelManager() end
    return channels
end

-------------------------------------------------------------------------------
-- ECB:SetCustomChannelFavorites
-- Settings changes are previewed live and persisted immediately, matching the
-- existing Settings handlers.  The parent panel's Cancel callback restores the
-- saved snapshot when necessary.
-------------------------------------------------------------------------------
function ECB:SetCustomChannelFavorites(favorites)
    favorites = self:NormalizeCustomChannelFavorites(favorites)
    self.workingCopy.customChannels = self:CopyTable(favorites)
    ECB_DB.customChannels = self:CopyTable(favorites)
    ECB_DB.customChannelsInitialized = true
    self:ApplySettings(self.workingCopy)
    if self.RefreshCustomChannelManager then self:RefreshCustomChannelManager() end
end

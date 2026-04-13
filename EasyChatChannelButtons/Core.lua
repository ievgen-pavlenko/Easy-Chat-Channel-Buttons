local addonName, ns = ...

-------------------------------------------------------------------------------
-- EasyChatChannelButtons – Core
-- Shared namespace bootstrap, addon table, database helpers, event handler,
-- and slash command registration. Must be loaded first.
-------------------------------------------------------------------------------

local ECB = {}
ns.ECB = ECB

-------------------------------------------------------------------------------
-- Defaults
-------------------------------------------------------------------------------
ECB.defaults = {
    bubbleSize    = 10,
    bubbleSpacing = 7,
    vertical      = false,
}

-------------------------------------------------------------------------------
-- Shared runtime state
-------------------------------------------------------------------------------
ECB.mainFrame       = nil
ECB.buttons         = {}
ECB.ElvUIE          = nil  -- resolved at PLAYER_LOGIN

-- Config working copies
ECB.db              = {}   -- runtime settings (mirrors ECB_DB)
ECB.workingCopy     = {}   -- values being edited in the config UI
ECB.savedBeforeEdit = {}   -- snapshot taken when config opens; restored on Cancel

-------------------------------------------------------------------------------
-- ECB:CopyTable
-------------------------------------------------------------------------------
function ECB:CopyTable(src)
    local t = {}
    for k, v in pairs(src) do t[k] = v end
    return t
end

-------------------------------------------------------------------------------
-- ECB:GetDefaults
-------------------------------------------------------------------------------
function ECB:GetDefaults()
    return self:CopyTable(self.defaults)
end

-------------------------------------------------------------------------------
-- ECB:InitializeDatabase
-- Ensures ECB_DB exists, fills every missing key from ECB.defaults (so
-- adding a new default requires no change here), then builds ECB.db as a
-- clean copy of the persisted settings.
--
-- ECB.defaults          – never mutated; the authoritative source of default values
-- ECB_DB                – WoW SavedVariables table; persisted across sessions
-- ECB.db                – runtime mirror; all addon code reads from here
-- EasyChatChannelButtonsDB – legacy SavedVariables name (pre-rename); migrated once
-------------------------------------------------------------------------------
function ECB:InitializeDatabase()
    -- One-time migration: if ECB_DB was never written but the old variable
    -- exists, reuse the player's existing settings rather than starting fresh.
    -- EasyChatChannelButtonsDB is declared in the TOC so WoW populates it at
    -- login.  After this assignment ECB_DB owns the table; the old global is
    -- left untouched and WoW will clear it naturally on the next reload once
    -- EasyChatChannelButtonsDB is removed from the TOC in a future version.
    if ECB_DB == nil and EasyChatChannelButtonsDB ~= nil then
        ECB_DB = EasyChatChannelButtonsDB
    end

    ECB_DB = ECB_DB or {}

    -- Backfill any key that is absent in the saved table (first run, or a new
    -- setting was added in a later version).
    for k, v in pairs(self.defaults) do
        if ECB_DB[k] == nil then
            ECB_DB[k] = v
        end
    end

    -- Build ECB.db as a clean copy of every persisted default-backed key.
    -- Using a loop means new settings are automatically included.
    for k in pairs(self.defaults) do
        self.db[k] = ECB_DB[k]
    end
end

-------------------------------------------------------------------------------
-- Startup flow
-- Called once from PLAYER_LOGIN after all other systems are ready.
-------------------------------------------------------------------------------
local function OnLogin()
    -- Resolve ElvUI core object if the addon is loaded.
    if ElvUI then ECB.ElvUIE = unpack(ElvUI) end

    -- Initialise saved variables before anything else reads ECB.db.
    ECB:InitializeDatabase()

    -- Build the button bar and register the Blizzard settings panel
    -- (or the ElvUI frame).  These methods live in Buttons.lua / Config.lua
    -- and are guaranteed to exist because the TOC loads them before Core.lua
    -- runs its events.
    ECB:CreateMainFrame()
    ECB:InitializeConfig()

    -- Apply the saved settings so buttons reflect the persisted size/spacing
    -- from the moment they first appear on screen.
    ECB:ApplySettings(ECB.db)

    -- Print startup messages.
    local version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"
    print("|cff00ff00Easy Chat Channel Buttons|r v" .. version .. " loaded.")

    local isLocked = ECB_DB.locked ~= false
    if isLocked then
        print("|cff00ff00Easy Chat Channel Buttons:|r Frame is |cffc0c0c0locked|r. Use |cffffcc00/ecb unlock|r to move it.")
    else
        print("|cff00ff00Easy Chat Channel Buttons:|r Frame is |cffffff00unlocked|r. Drag to reposition, then |cffffcc00/ecb lock|r.")
    end
end

-------------------------------------------------------------------------------
-- Event handler
-------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        OnLogin()
    else
        -- Any group/world event may change which channels are relevant.
        if ECB.mainFrame then ECB:UpdateButtonVisibility() end
    end
end)

-------------------------------------------------------------------------------
-- Slash commands
--   /ecb            opens the config UI
--   /ecb config     opens the config UI
--   /ecb lock       locks the frame position
--   /ecb unlock     unlocks the frame position
-------------------------------------------------------------------------------
SLASH_EASYCHATCHANNELBUTTONS1 = "/ecb"
SlashCmdList["EASYCHATCHANNELBUTTONS"] = function(msg)
    local cmd = strtrim(msg):lower()
    if cmd == "" or cmd == "config" then
        ECB:OpenConfig()
    elseif cmd == "lock" then
        ECB:LockFrame()
    elseif cmd == "unlock" then
        ECB:UnlockFrame()
    else
        print("|cff00ff00EasyChatChannelButtons:|r Usage:")
        print("  |cffffcc00/ecb|r or |cffffcc00/ecb config|r \226\128\147 open settings")
        print("  |cffffcc00/ecb lock|r                    \226\128\147 lock frame position")
        print("  |cffffcc00/ecb unlock|r                  \226\128\147 unlock frame position")
    end
end

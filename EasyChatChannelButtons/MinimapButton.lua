local addonName, ns = ...
local ECB = ns.ECB
local C = ns.Constants

-------------------------------------------------------------------------------
-- EasyChatChannelButtons – MinimapButton
-- Registers an entry in the standard minimap addon button list via
-- LibDataBroker-1.1 + LibDBIcon-1.0.
--
-- Left-click  → opens the config panel
-- Right-click → toggles the button bar visibility
-- The button position/visibility is managed entirely by LibDBIcon, so it
-- works correctly with both the round Blizzard minimap and square ElvUI /
-- other replacements, and respects the user's "hide minimap addon buttons"
-- setting.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- ECB:CreateMinimapButton
-- Called from OnLogin (Core.lua) after the database is initialised.
-- Silently skips if LibStub / LibDataBroker / LibDBIcon are not embedded
-- (e.g. during local dev before running the packager).
-------------------------------------------------------------------------------
function ECB:CreateMinimapButton()
    local LibStub     = LibStub
    if not LibStub then return end

    local LDB  = LibStub("LibDataBroker-1.1", true)
    local Icon = LibStub("LibDBIcon-1.0",       true)
    if not LDB or not Icon then return end

    -- Data broker launcher object.
    local dataobj = LDB:NewDataObject(C.ADDON_NAME, {
        type  = "launcher",
        label = C.ADDON_DISPLAY,
        icon  = "Interface\\AddOns\\EasyChatChannelButtons\\icon",

        OnClick = function(_, button)
            if button == "LeftButton" then
                ECB:OpenConfig()
            elseif button == "RightButton" then
                ECB:ToggleBarVisibility()
            end
        end,

        OnTooltipShow = function(tooltip)
            tooltip:AddLine(C.ADDON_DISPLAY)
            tooltip:AddLine(" ")
            tooltip:AddLine("|cffccccccLeft-click|r to open settings", 1, 1, 1)
            tooltip:AddLine("|cffccccccRight-click|r to show/hide the button bar", 1, 1, 1)
        end,
    })

    -- ECB_DB.minimapIcon  is the persistence table LibDBIcon reads/writes.
    -- It holds { hide, minimapPos, radius } and is initialised to {} so
    -- the library fills in its own defaults on first use.
    ECB_DB.minimapIcon = ECB_DB.minimapIcon or {}

    Icon:Register(C.ADDON_NAME, dataobj, ECB_DB.minimapIcon)

    self.minimapButton = Icon:GetMinimapButton(C.ADDON_NAME)
end

local addonName, ns = ...
local ECB = ns.ECB
local C = ns.Constants

-------------------------------------------------------------------------------
-- EasyChatChannelButtons – ElvUI
-- Safe ElvUI detection and optional ElvUI-specific styling helpers.
-- No ElvUI core files are modified.  All integration relies on the public
-- APIs that ElvUI injects into every Frame metatable at startup.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- ECB:IsElvUILoaded
-- Returns true when the ElvUI core object was successfully resolved at login.
-- ECB.ElvUIE is set in Core.lua's OnLogin() before any module code runs.
-------------------------------------------------------------------------------
function ECB:IsElvUILoaded()
    return ECB.ElvUIE ~= nil
end

-------------------------------------------------------------------------------
-- ECB:ApplyElvUIFrameStyle(frame)
-- Applies ElvUI backdrop styling to a config panel frame.
-- CreateBackdrop is injected by ElvUI into every Frame metatable via its
-- Toolkit AddAPI call.  Safe to call multiple times; ElvUI guards duplicates.
-------------------------------------------------------------------------------
function ECB:ApplyElvUIFrameStyle(frame)
    if not self:IsElvUILoaded() then return end
    if not frame then return end
    frame:CreateBackdrop()
end

-------------------------------------------------------------------------------
-- ECB:ApplyElvUIButtonStyle(btn)
-- Strips Blizzard button chrome and applies an ElvUI-style flat backdrop.
-- StripTextures is an injected helper; guarded before calling.
-- A subtle highlight texture is restored so hover feedback is not lost.
-- Used for config panel buttons (OK, Cancel, Defaults) only.
-- NOT used for circular channel bubble buttons.
-------------------------------------------------------------------------------
function ECB:ApplyElvUIButtonStyle(btn)
    if not self:IsElvUILoaded() then return end
    if not btn then return end
    if btn.StripTextures then btn:StripTextures() end
    btn:CreateBackdrop()
    btn:SetHighlightTexture([[Interface\Buttons\ButtonHilight-Square]], "ADD")
end

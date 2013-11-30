--------------------------------------
-- Raid Mana Tracker Initialization --
--------------------------------------

RMT = LibStub("AceAddon-3.0"):NewAddon("RaidManaTracker", "AceEvent-3.0", "AceConsole-3.0", "AceBucket-3.0")

if not RMT then return end

if not RMT.callbacks then
	RMT.callbacks = LibStub("CallbackHandler-1.0"):New(RMT)
end

local frame = RMT.frame
if (not frame) then
	frame = CreateFrame("Frame", "RaidManaTracker_Frame")
	RMT.frame = frame
end

RMT.frame:UnregisterAllEvents()
RMT.frame:RegisterEvent("GROUP_ROSTER_UPDATE")
RMT.frame:RegisterEvent("ADDON_LOADED")

RMT.frame:SetScript("OnEvent", function(this, event, ...)
	return RMT[event](RMT, ...)
end)

function RMT:ADDON_LOADED(name)
	if (name == "RaidManaTracker") then
		print("RaidManaTracker version 1.0, /rmt for command list")
	end
end

function RMT:GROUP_ROSTER_UPDATE()
	RMT:CheckVisibility()
end
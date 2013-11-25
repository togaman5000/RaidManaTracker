----------
-- TODO :
--
-- High Priority
-- 1. [Check mana specifically] DONE
-- 2. [Check phasing, e.g. Norushen] DONE
-- 3. [Reduce number of times addon iterates through healer table] DONE
-- 4. [Figure out this local globals thing, _G?] DONE
-- 5. Deal with Monks in some fashion, 5 stacks of mana tea is on-par with innervate
-- 6. [Speed everything up, then move update interval down to .5 seconds] DONE
--
-- Medium Priority
-- 1. Clean up/streamline
-- 2. Some sorta options menu (Ace3?)
-- 3. Better handling of frame positioning, sizing
--
-- Low Priority
-- 1. Split into modules
-- 2. Integrate libraries
-- 3. Fully-fleshed debug mode?
-- 4. Versions, Curse support, etc
----------


-------------
-- Globals --
-------------
RaidManaTracker_Version = 0.1

-------------------
-- Local Globals --
-------------------
local _G = _G
local GetRaidTargetIndex = GetRaidTargetIndex
local UnitName = UnitName
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitDebuff = UnitDebuff
local UnitBuff = UnitBuff
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local GetSpellInfo = GetSpellInfo
local GetRaidRosterInfo = GetRaidRosterInfo
local GetCurrentMapAreaID = GetCurrentMapAreaID
local GetMapNameByID = GetMapNameByID
local UnitGroupRolesAssigned = UnitGroupRolesAssigned

------------
-- Locals --
------------
local RaidManaTracker_UpdateInterval = 0.5

local RaidManaTracker_Defaults = {
	["Options"] = {
		["RaidLeaderEnable"] = true,
		["MainAssistEnable"] = false,
		["Enable"] = true,
		["InfoWindowAnchorPoint"] = "CENTER",
		["InfoWindowAnchorRelativeTo"] = "UIParent",
		["InfoWindowAnchor"] = "CENTER",
		["InfoWindowX"] = 150,
		["InfoWindowY"] = 0,
		["FontPath"] = "Fonts\\FRIZQT__.TTF",
		["FontSize"] = 12,
		["BarSpacing"] = 2,
		--["TrackHealerPersonals"] = false,
		--["TrackHealerPotions"] = false,
		["RecommendRaidWideCooldowns"] = false,
		["Version"] = RaidManaTracker_Version,
	}
};
local PersonalCooldownSpellIDs = {
	[54428] = 120,  						--Pally
	[34433] = 180,  						--Priest
	[123040] = 60, 							--Mindbender
	[132604] = 60, 							--Mindbender with glyph
	[29166] = 180,  						--Druid
	[16190] = 180,							--Shaman, since they have nothing other than Mana Tide
	--[18562] = 15, 							--Swiftmend DEBUGGING PURPOSES
	}
local RecommendSpellIDs = {
	["PRIEST"] = 64901,			 				--Hymn of Hope
	["SHAMAN"] = 16190,		 					--Mana Tide
	["DRUID"] = 29166,							--Innervate
	
	}
local PotionSpellIDs = {
	[105701] = "Potion of Focus", 			--Potion of Focus
	[105709] = "Master Mana Potion", 		--Master Mana Potion
	[105704] = "Alchemist's Rejuvenation", 	--Alchemist's Rejuvenation
	[130650] = "Water Spirit",				--Water Spirit
	}
-- local HealerSpecializationIDs = {
	-- 105, --Resto Druid
	-- 270, --Mistweaver Monk
	-- 65,  --Holy Paladin
	-- 256, --Discipline Priest
	-- 257, --Holy Priest
	-- 264, --Resto Shaman
	-- }
-- local HealerClasses = {
	-- "DRUID",
	-- "MONK",
	-- "PALADIN",
	-- "PRIEST",
	-- "SHAMAN",
	-- }

-- Basic enabled/disabled tracking variables
local RaidManaTrackerEnabled = true
local RaidManaTrackerRecommendationEnabled = true
local CurrentRecommendation = nil
local ManaThreshold = 65
	
-- Stuff for the frame
local BackgroundTexturePath = "|TInterface\\Tooltips\\ChatBubble-Background:0|t"
local potionFrameName = "RaidManaTracker_MainFrame_PotionIndicator"
local personalFrameName = "RaidManaTracker_MainFrame_PersonalIndicator"
local nameFrameName = "RaidManaTracker_MainFrame_HealerName"
local manaFrameName = "RaidManaTracker_MainFrame_ManaValue"
local RMT_LINE_WIDTH_EXTRA = 50
local RMT_WINDOW_MINIMUM_WIDTH = 150

-- Create tracking tables
local Healers = {}
local OnCD = {}
local RaidMembersForInspect = {}
local playerClass = nil

local _ = nil

local RaidManaTracker_debug = true

------------------------------
-- Enable/Disable Functions --
------------------------------

-- Check for settings, set to default if not found
-- TODO: Implement version checking
local function RaidManaTracker_Loaded()
	if (not RaidManaTracker_SavedVariables) then
		RaidManaTracker_SavedVariables = RaidManaTracker_Defaults["Options"];
	end
	
	if (RaidManaTracker_SavedVariables["Version"] < RaidManaTracker_Version) then
		RaidManaTracker_SavedVariables_Temp = RaidManaTracker_Defaults["Options"];
		for k,v in RaidManaTracker_SavedVariables do
			if (RaidManaTracker_Defaults["Options"][k]) then
				RaidManaTracker_SavedVariables_Temp[k] = v;
			end
		end
		RaidManaTracker_SavedVariables_Temp["Version"] = RaidManaTracker_Version;
		RaidManaTracker_SavedVariables = RaidManaTracker_SavedVariables_Temp;
	end
	
	RaidManaTracker_MainFrame:SetPoint(RaidManaTracker_SavedVariables.InfoWindowAnchorPoint, RaidManaTracker_SavedVariables.InfoWindowX, RaidManaTracker_SavedVariables.InfoWindowY);
	
	RaidManaTracker_MainFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
	RaidManaTracker_MainFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
	RaidManaTracker_MainFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	RaidManaTracker_MainFrame:RegisterEvent("INSPECT_READY")
	RaidManaTracker_MainFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
end

-- Runs when entering a raid or changing spec, sets addon operation mode given spec and settings
local function RaidManaTracker_SetMode()
	_, playerClass = UnitClass("player")
	
	if ((GetSpecializationRole(GetSpecialization()) == "HEALER") 
	or ((RaidManaTracker_SavedVariables.RaidLeaderEnable == true) and UnitIsGroupLeader("Player"))
	or ((RaidManaTracker_SavedVariables.MainAssistEnable == true) and UnitIsGroupAssistant("Player")))
	and (RaidManaTracker_SavedVariables.Enable == true) then
		RaidManaTrackerEnabled = true
	else
		RaidManaTrackerEnabled = false
	end
	
	if ((playerClass == "PRIEST") or ((playerClass == "DRUID") and (GetSpecialization() == 1)) or ((playerClass == "SHAMAN") and (GetSpecialization() == 3))) then
		RaidManaTrackerRecommendationEnabled = true
	end
end

--------------------------------
-- In-Combat Update Functions --
--------------------------------

-- Given a healer's name, return index
local function RaidManaTracker_GetIndexByName(name)
	for index, healer in pairs(Healers) do
		if healer.Name == name then
			return index
		end
	end
	return 0
end

-- Scale frame to fit the number of healers
local function RaidManaTracker_ChangeSize()
	local stringWidth, line = 0, 1
	RaidManaTracker_MainFrame:SetHeight((RaidManaTracker_MainFrame_HealerName1:GetHeight() * #(Healers)) + 2*(#(Healers) - 1) + 10)
	for index, healer in pairs(Healers) do
		if (_G[nameFrameName..index]:GetWidth() > stringWidth) then 
			stringWidth = _G[nameFrameName..index]:GetWidth()
			line = index
		end
	end
	local totalWidth = _G[nameFrameName..line]:GetWidth() + _G[potionFrameName..line]:GetWidth() + _G[personalFrameName..line]:GetWidth() + _G[manaFrameName..line]:GetWidth() + RMT_LINE_WIDTH_EXTRA
	if totalWidth < RMT_WINDOW_MINIMUM_WIDTH then totalWidth = RMT_WINDOW_MINIMUM_WIDTH end
	RaidManaTracker_MainFrame:SetWidth(totalWidth)
end

-- Process when important individuals use important spells
local function RaidManaTracker_UpdateCooldownUsage(name, spellID)	
	-- Track when spell is available by adding to a table OnCD, which is checked OnUpdate for when a spell is available
	if (PersonalCooldownSpellIDs[spellID]) then
		local index = RaidManaTracker_GetIndexByName(name)
		Healers[index].Personal = false
		_G[personalFrameName..index]:SetDesaturated(1)
		entry = {
			["Name"] = name,
			["Spell"] = spellID,
			["TimeReady"] = GetTime() + (PersonalCooldownSpellIDs[spellID]),
		}
		tinsert(OnCD, entry)
		table.sort(OnCD, function(a,b) return a.TimeReady < b.TimeReady end)		
	elseif (PotionSpellIDs[spellID]) then -- No need to make an entry in OnCD, potions don't come off cooldown until combat ends, which we can handle then
		local index = RaidManaTracker_GetIndexByName(name)
		Healers[index].Potion = false
		_G[potionFrameName..index]:SetDesaturated(1)
	end
end

-- Runs through the current queue of spells on CD, with the assumption that a lower index corresponds with an earlier available time
-- TODO: Modularize the entire Recommendation portion of the addon
local function RaidManaTracker_ProcessCooldownQueue()
	while (OnCD[1] and OnCD[1].TimeReady < GetTime()) do
		local index = RaidManaTracker_GetIndexByName(OnCD[1].Name)
		if (index ~= 0) then
			RaidCooldownSpellAvailable = true
			Healers[index].Personal = true
			_G[personalFrameName..index]:SetDesaturated(nil)
			tremove(OnCD, 1)
		end
	end
end

-- Clean up once combat is finished
-- TODO: Reset icon saturations
local function RaidManaTracker_EndCombatMode()
	RaidManaTracker_MainFrame:Hide()
	wipe(OnCD)
end

-- If addon is in Recommend mode, handles the animation of the relevant frames based on which, if any, healers meet criteria
local function RaidManaTracker_UpdateRecommendationStatus(avg)
	if ((UnitClass("player") == "Druid") and (CurrentRecommendation)) then -- Druid innervates target individuals, if you're a druid then name/mana matters, not avg
		if (CurrentRecommendation.ManaStatus >= ManaThreshold) then
			RaidManaTracker_MainFrame:StopAnimating()
		else
			local index = RaidManaTracker_GetIndexByName(CurrentRecommendation.Name)
			if (not _G[nameFrameName..index.."_Animation"]:IsPlaying()) then
				RaidManaTracker_MainFrame:StopAnimating()
				_G[nameFrameName..index.."_Animation"]:Play()
			end
		end
	else -- Shaman and Priests check averages. No need to check class, as this function should only be called if the player has a raidwide CD
		if (avg < ManaThreshold) then
			if (not RaidManaTracker_MainFrame_Animation:IsPlaying()) then RaidManaTracker_MainFrame_Animation:Play() end
		else
			RaidManaTracker_MainFrame_Animation:Stop()
		end
	end
end

-- General updater for all the healers
local function RaidManaTracker_UpdateHealerStatus()
	local mana, manaSum = 0, 0
	for index, healer in pairs(Healers) do
		if (UnitInPhase(healer.Name)) then -- Had problems with healers showing up late for, say, first trash pulls of the night. This should avoid that.
			healer.ManaStatus = math.ceil(UnitPower(healer.Name, 0)*100/UnitPowerMax(healer.Name, 0))
			manaSum = manaSum + healer.ManaStatus
			if (UnitClass(healer.Name) == "Monk") then
				local name, count = select(1, UnitBuff(healer.Name, "Mana Tea")), select(4, UnitBuff(healer.Name, "Mana Tea"))
				if (name == nil or count < 5) then
					healer.Personal = false
					_G[personalFrameName..index]:SetDesaturated(1)
				else
					_G[personalFrameName..index]:SetDesaturated(nil)
				end
			end
--			if (not healer.Personal) then
				if ((CurrentRecommendation == nil) or (CurrentRecommendation.ManaStatus > healer.ManaStatus)) then
					CurrentRecommendation = healer
				end
--			end
		end
	end
	
	
	if (RaidManaTrackerRecommendationEnabled) then
		local startTime, duration, enabled = GetSpellCooldown(RecommendSpellIDs[playerClass])
		print(startTime, " : ", duration, " : ", enabled)
		if ((startTime == 0) or (duration < 10)) then -- Checking if duration < 10 seconds to avoid any problems with spell being "on cooldown" when casting or GCD is active
			RaidManaTracker_UpdateRecommendationStatus(manaSum/#(Healers))
		else
			RaidManaTracker_MainFrame:StopAnimating()
		end
	end
end

-- Updates mana values for all healers
local function RaidManaTracker_UpdateWindow()
	for index, healer in pairs(Healers) do -- Iterating through all healers
		local manaPercent, frameName, manaColorCode = healer.ManaStatus, "RaidManaTracker_MainFrame_ManaValue"..index, RED_FONT_COLOR -- Starting with red saves typing, maybe not time
		if (manaPercent > 66) then 
			manaColorCode = GREEN_FONT_COLOR
		elseif (manaPercent > 33) then 
			manaColorCode = YELLOW_FONT_COLOR
		elseif (UnitIsDeadOrGhost(healer.Name)) then
			manaPercent = "DEAD"
		elseif (not UnitInPhase(healer.Name)) then
			manaPercent = "ZONE"
		end
		_G[frameName]:SetText(manaPercent)
		_G[frameName]:SetTextColor(manaColorCode.r, manaColorCode.g, manaColorCode.b)		
	end
end

-- Basic creation of new healer entries in the table
-- TODO: Find a better way of creating the entry, would like to be able to use the value's name as a workable variable later
local function RaidManaTracker_AddHealerToHealerTable(healer)
	if (RaidManaTracker_GetIndexByName(healer) == 0) then -- New healer, if left side is not 0 then healer is in table already
		local healerName = healer -- Need to temporarily store name (maybe?)
		healer = {
			["ManaStatus"] = math.floor(UnitPower(healerName, 0)*100/UnitPowerMax(healerName, 0)),
			["Potion"] = true,
			["Personal"] = true,
			["Name"] = healerName,
		}
		tinsert(Healers, healer)
		RaidManaTracker_EnableLine(#(Healers))
	end
end

--[[
local function RaidManaTracker_HandleInspectRequest(playerGUID)
	if (RaidMembersForInspect[playerGUID]) then
		local _, _, _, _, _, name, _ = GetPlayerInfoByGUID(playerGUID)
		local specID = GetInspectSpecialization(name)
		if (HealerSpecializationIDs[specID]) then
			RaidManaTracker_AddHealerToHealerTable(name)
		end
	end
end
--]]

-- Scan raid group, add healers or request info for healers that need Inspect
-- TODO: 	Make Inspect feature actually work, though logic here might be okay
--			Smarter roster handling, e.g. not having to wipe the roster every time?
local function RaidManaTracker_UpdateRoster()
	RaidManaTracker_ClearLines()
	wipe(Healers)

	if IsInRaid() then
		for i = 1,GetNumGroupMembers() do
			if (i > 25) then break end
			if (UnitGroupRolesAssigned("raid"..i) == "HEALER") then
				RaidManaTracker_AddHealerToHealerTable(UnitName("raid"..i))
--[[			elseif ((UnitGroupRolesAssigned("raid"..i) == "NONE") and HealerClasses[UnitClass("raid"..i)]) then
					if (CanInspect("raid"..i)) then
						if (HealerSpecializationIDs[GetInspectSpecialization("raid"..i)]) then
							RaidManaTracker_AddHealerToHealerTable(UnitName("raid"..i))
						end
					else
						NotifyInspect("raid"..i)
						tinsert(RaidMembersForInspect, UnitGuid("raid"..i))
					end --]]
			end
		end
	elseif (RaidManaTracker_debug == true) then -- DEBUGGING ONLY, enables testing while solo
		RaidManaTracker_AddHealerToHealerTable(UnitName("player"))
	end
end

-- Initial handling of displayed text, lines, size, etc
local function RaidManaTracker_InitializeWindow()
	for index, healer in pairs(Healers) do
			local _, HealerClass = UnitClass(healer.Name)
			
			_G[nameFrameName..index]:SetText(healer.Name)
			_G[nameFrameName..index]:SetTextColor(RAID_CLASS_COLORS[HealerClass].r, RAID_CLASS_COLORS[HealerClass].g, RAID_CLASS_COLORS[HealerClass].b)
			
			-- This part may be unnecessary, if FontString object automatically adjusts height. Would be best to get string height at addon load and set them all then
			local objectHeight = _G[nameFrameName..index]:GetStringHeight()
			_G[nameFrameName..index]:SetHeight(objectHeight)
			_G[manaFrameName..index]:SetHeight(objectHeight)
	end
	
	RaidManaTracker_UpdateHealerStatus()
	RaidManaTracker_UpdateWindow()
	RaidManaTracker_ChangeSize()
	
	-- No need to track combat log events until actually in combat, though would be nice to keep an eye on CDs even outside of combat
	
	-- Make sure not showing extra lines, though this may be unnecessary if roster update is handled properly. Fine for now, low impact
	for i = #(Healers) + 1, 8 do
		RaidManaTracker_DisableLine(i)
	end	
end

-- Four aspects to each line of information, one function enables them all
function RaidManaTracker_EnableLine(ind)
	_G[nameFrameName..ind]:Show()
	_G[manaFrameName..ind]:Show()
	_G[personalFrameName..ind]:Show()
	_G[potionFrameName..ind]:Show()
end

-- Four aspects to each line of information, one function disables them all
function RaidManaTracker_DisableLine(ind)
	_G[nameFrameName..ind]:Hide()
	_G[manaFrameName..ind]:Hide()
	_G[personalFrameName..ind]:Hide()
	_G[potionFrameName..ind]:Hide()
end

-- General frame line wipe function
function RaidManaTracker_ClearLines()
	for i = 1,#(Healers) do
		RaidManaTracker_DisableLine(i)
	end
end

-- Basic command functions for now, will change this up once options are implemented
function RaidManaTracker_SlashCommandHandler(msg)
	msg = strtrim(strlower(msg));
	
	if (msg == "enable") then
		RaidManaTracker_SavedVariables.Enable = true;
		if (not RaidManaTracker_MainFrame:IsShown()) and (UnitAffectingCombat("Player")) then RaidManaTracker_InitializeWindow() end
		print("RaidManaTracker enabled")
	elseif (msg == "disable") then
		RaidManaTracker_SavedVariables.Enable = false;
		if ((RaidManaTracker_MainFrame:IsShown()) and (UnitAffectingCombat("Player"))) then RaidManaTracker_MainFrame:Hide() end
		print("RaidManaTracker disabled")
	elseif (msg == "status") then
		if RaidManaTracker_SavedVariables.Enable == true then print("RaidManaTracker is currently enabled") else print("RaidManaTracker is currently disabled") end
	elseif (msg == "debug") then
		if (RaidManaTracker_debug) then RaidManaTracker_debug = false else RaidManaTracker_debug = true end
		print("RaidManaTracker debug mode set to ", RaidManaTracker_debug)
	else
		print("Valid commands:\n Enable\n Disable")
	end
end

function RaidManaTracker_OnMouseDown()
	RaidManaTracker_MainFrame:StartMoving()
end

function RaidManaTracker_OnMouseUp()
	RaidManaTracker_MainFrame:StopMovingOrSizing()
	local point, relativeTo, relativePoint, xOfs, yOfs = RaidManaTracker_MainFrame:GetPoint();
	RaidManaTracker_SavedVariables.InfoWindowX = xOfs;
	RaidManaTracker_SavedVariables.InfoWindowY = yOfs;
	
end

function RaidManaTracker_OnLoad()
	local _, playerClass = UnitClass("Player")
	local cColor = RAID_CLASS_COLORS[playerClass]
	RaidManaTracker_MainFrame:SetBackdropBorderColor(cColor.r, cColor.g, cColor.b, 0.4)

	RaidManaTracker_MainFrame:RegisterEvent("VARIABLES_LOADED")

	SlashCmdList["RAIDMANATRACKER"] = RaidManaTracker_SlashCommandHandler;
	SLASH_RAIDMANATRACKER1 = "/rmt";
end

function RaidManaTracker_OnUpdate(self, elapsed)
	self.TimeSinceLastUpdate = self.TimeSinceLastUpdate + elapsed;
	
	if (self.TimeSinceLastUpdate > RaidManaTracker_UpdateInterval) then
		RaidManaTracker_ProcessCooldownQueue()
		RaidManaTracker_UpdateHealerStatus()
		RaidManaTracker_UpdateWindow()
		self.TimeSinceLastUpdate = 0
	end
end

function RaidManaTracker_OnEvent(frame, event, ...)
	if ((IsInRaid()) or (RaidManaTracker_debug == true)) then
		if (event == "COMBAT_LOG_EVENT_UNFILTERED") then
			local spellType, sourceName = (select(2,...)), (select(5, ...))
			if ((RaidManaTracker_GetIndexByName ~= 0) and (spellType == "SPELL_CAST_SUCCESS" or spellType == "SPELL_SUMMON")) then
				local spellId, spellName, spellSchool = select(12, ...)
				RaidManaTracker_UpdateCooldownUsage(sourceName, spellId);
			end
		elseif ((event == "GROUP_ROSTER_UPDATE") or (event == "PLAYER_SPECIALIZATION_CHANGED")) then
			RaidManaTracker_MainFrame:Hide()
			RaidManaTracker_UpdateRoster()
			if (RaidManaTrackerEnabled) then
				RaidManaTracker_InitializeWindow()
				RaidManaTracker_MainFrame:Show()
			end
--[[		elseif (event == "INSPECT_READY") then
			local playerGUID = ...
			RaidManaTracker_HandleInspectRequest(playerGUID) --]]
		elseif (event == "PLAYER_REGEN_DISABLED")  then
			RaidManaTracker_SetMode()
			if (RaidManaTrackerEnabled) then 
				RaidManaTracker_InitializeWindow()
				RaidManaTracker_MainFrame:Show()
			end		
			RaidManaTracker_MainFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		elseif (event == "PLAYER_REGEN_ENABLED") then
			RaidManaTracker_MainFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			RaidManaTracker_MainFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
			RaidManaTracker_EndCombatMode();	
		end
	end
	
	if (event == "VARIABLES_LOADED") then
		RaidManaTracker_Loaded();
		RaidManaTracker_MainFrame:UnregisterEvent("VARIABLES_LOADED");
		RaidManaTracker_UpdateRoster()		
	end
end
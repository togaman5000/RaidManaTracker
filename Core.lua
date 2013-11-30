-- Where am I now: Explore using AceTimer instead of my own cooldown queue



--------------------------
-- RaidManaTracker v1.0 --
--------------------------
-- Author: Gray@Drenden --
--------------------------

if not RMT then return end
local RMT = RMT
local LGI = LibStub:GetLibrary("LibGroupInSpecT-1.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local AceTimer = LibStub("AceTimer-3.0")
local LSM = LibStub("LibSharedMedia-3.0")


local healerFrames = {}

------------
-- Roster --
------------

function RMT:OnUpdate(event, info)
	-- Both raid roster and healer roster concerned with GUID primarily
	local guid = info.guid
	local name = info.name
	local class = info.class
	local role = info.spec_role
	local role_detailed = info.spec_role_detailed
	
	-- Not all fields are available immediately, check for nils and if found wait it out
	if not guid or not name or not class or not (role or role_detailed) then return end

	RMT['raidRoster'][guid] = RMT['raidRoster'][guid] or {}
	RMT['raidRoster'][guid]['name'] = name
	RMT['raidRoster'][guid]['class'] = class
	RMT['raidRoster'][guid]['spec'] = spec
	RMT['raidRoster'][guid]['role'] = role or role_detailed
	RMT['raidRoster'][guid]['talents'] = talents
	
	if role == "healer" or role == "HEALER" then
		RMT['raidRoster'][guid].role = string.lower(RMT['raidRoster'][guid].role)
		if not tContains(RMT['healerRoster'], guid) then
			tinsert(RMT['healerRoster'], guid)
			if #(healerFrames) > #(RMT['healerRoster']) then -- Extra frames available, toss one to this healer
				RMT:AssignFrame(healerFrames[#(RMT['healerRoster'])], guid)
			else
				RMT:CreateHealerFrame(#healerFrames + 1, guid)
				RMT:AssignFrame(healerFrames[#healerFrames], guid)
			end
		end
		RMT:CheckVisibility()
	end
end

-- TODO: Understand what guids exactly are reported when the player leaves a group
function RMT:OnRemove(guid)
	if guid then -- Means someone in particular was removed
		if RMT['raidRoster'][guid].role == "healer" then
				local index = RMT:FindEntry(RMT['healerRoster'], guid)
				if index ~= 0 then -- It should never be zero, but just in case
					tremove(RMT['healerRoster'], index)
					for i = 1,#healerFrames do -- Reassigning all the frames
						if RMT['healerRoster'][i] then
							RMT:AssignFrame(healerFrames[i], RMT['healerRoster'][i])
						else
							RMT:AssignFrame(healerFrames[i], nil)
						end
					end
				end
			RMT:ResizeBase(RMTWatchFrameBase_Frame, #RMT['healerRoster'])
		end
		RMT['raidRoster'][guid] = nil
	else
		RMT['raidRoster'] = {}
		RMT['healerRoster'] = {}
		for i = 1, #healerFrames do
			RMT:AssignFrame(healerFrames[i], nil) -- Clear out and hide every frame TODO: make sure the player, if they're a healer, is shown
		end
	end
	RMT:CheckVisibility()
end

function RMT:SetExtras(set)
	if set then
	local inInstance, _ = IsInInstance()
	local maxPlayers = select(5, GetInstanceInfo())
	local maxSubgroup = 8
	
	if maxPlayers == 25 then
		maxSubgroup = 5
	elseif maxPlayers == 10 then
		maxSubgroup = 2
	end
	
	if IsInRaid() and inInstance then
		for i = 1, GetNumGroupMembers(), 1 do
			local subgroup = select(3, GetRaidRosterInfo(i))
			local guid = UnitGUID("raid"..tostring(i))
			if RMT['raidRoster'] and RMT['raidRoster'][guid] then
				if subgroup > maxSubgroup then
					RMT['raidRoster'][guid]["extra"] = true
				else
					RMT['raidRoster'][guid]["extra"] = nil
				end
			end
		end
	end
	
	--else
	
	end
end

function RMT:UpdateExtras()
	if not RMT.profileDB.autocheckextra
		or not IsInRaid()
		or InCombatLockdown() then return end
	
	RMT:SetExtras(true)
end

--------------
-- Displays --
--------------

function RMT:CreateWatchFrame()
	local RMTFrameAnchor = CreateFrame("Frame", 'RMTWatchFrameAnchor_Frame', UIParent)
	RMTFrameAnchor:SetClampedToScreen(true)
	RMTFrameAnchor:SetPoint(RMT.profileDB.framePoint, UIParent, RMT.profileDB.relativePoint, RMT.profileDB.xOffset, RMT.profileDB.yOffset)
	RMTFrameAnchor:SetSize(128*RMT.profileDB.scale, 128*RMT.profileDB.scale)
	RMTFrameAnchor:SetMovable(true)
	RMTFrameAnchor:SetFrameStrata("HIGH")
	RMTFrameAnchor:SetScript("OnDragStart", function(self) self:StartMoving() end)
	RMTFrameAnchor:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	RMTFrameAnchor:Hide()
	
	local RMTWatchFrameBase_Frame = CreateFrame("Frame", 'RMTWatchFrameBase_Frame', UIParent)
	RMTWatchFrameBase_Frame:SetSize(240 * RMT.profileDB.scale, 20 * RMT.profileDB.scale + 2 * (1 - RMT.profileDB.frameBackgroundInset + RMT.profileDB.frameEdgeSize) * RMT.profileDB.scale)
	RMTWatchFrameBase_Frame:SetPoint('TOPLEFT', RMTWatchFrameAnchor_Frame, 'TOPLEFT')
	RMTWatchFrameBase_Frame:SetClampedToScreen(true)
	
	RMT.locked = true
	RMT:CheckVisibility()
	
	RMT:RegisterBucketEvent("GROUP_ROSTER_UPDATE", 5, "UpdateExtras")
	
	local events = {}
	function events:PLAYER_ENTERING_WORLD(...)
		RMT:ChangeBackdrop(RMTWatchFrameBase_Frame)
	end
	RMTWatchFrameBase_Frame:SetScript("OnEvent", function(self, event, ...)
		events[event](self, ...)
	end)
	for k, v in pairs(events) do
		RMTWatchFrameBase_Frame:RegisterEvent(k)
	end
end

function RMT:CreateHealerFrame(index, guid)
	-- Using index as a reference to the healerRoster to keep things straight
	local frame = CreateFrame("Frame", 'RMTHealer'..index, RMTWatchFrameBase_Frame)
	frame:SetSize((RMTWatchFrameBase_Frame:GetWidth() - RMT.profileDB.frameEdgeSize * 2 + RMT.profileDB.frameBackgroundInset * 2), 20 * RMT.profileDB.scale)
	frame.index = index
	
	-- Name isolated on the left side
	frame.name = frame:CreateFontString(nil, "OVERLAY")
	frame.name:SetFont(LSM:Fetch('font', RMT.profileDB.font), 20 * RMT.profileDB.scale)
	RMT:SetTextColor(frame.name, guid, "class")
	frame.name:SetPoint("TOPLEFT")
	frame.name:SetPoint("BOTTOMLEFT")
	
	frame.potionTexture = frame:CreateTexture("RMTHealerPotionIndicator"..index)
	frame.potionTexture:SetTexture("Interface\\Icons\\Trade_alchemy_Potiona5")
	frame.potionTexture:SetPoint("TOPRIGHT")
	frame.potionTexture:SetHeight(20 * RMT.profileDB.scale)
	frame.potionTexture:SetWidth(frame.potionTexture:GetHeight())

	-- TODO: New option: Default texture (innervate), class-based texture, or texture of user's choosing
	-- TODO: Add in some way to track time remaining until CD available, e.g. tooltip or perhaps progressive coloring of one element or another
	frame.cooldownTexture = frame:CreateTexture("RMTHealerCooldownIndicator"..index)
	frame.cooldownTexture:SetTexture("Interface\\Icons\\spell_nature_lightning")
	frame.cooldownTexture:SetPoint("TOPRIGHT", frame.potionTexture, "TOPLEFT", -1, 0)
	frame.cooldownTexture:SetHeight(20 * RMT.profileDB.scale)
	frame.cooldownTexture:SetWidth(20 * RMT.profileDB.scale)
	
	frame.manaPercent = frame:CreateFontString("RMTHealerManaPercent"..index, "OVERLAY")
	frame.manaPercent:SetFont(LSM:Fetch('font', RMT.profileDB.font), 20 * RMT.profileDB.scale)
	frame.manaPercent:SetText("100") -- Not setting text with function as this leaves the text white, indicating the healer in question has yet to cast a spell
	frame.manaPercent:SetPoint("TOPRIGHT", frame.cooldownTexture, "TOPLEFT", -1, 0)
	frame.manaPercent:SetPoint("BOTTOM", frame, "BOTTOM")
	
	-- First gets tied to base frame, the rest get tied to the next one up
	-- TODO: Implement option for growth directions, I personally don't even like TOPLEFT
	if index == 1 then
		frame:SetPoint("TOPLEFT", (1 - RMT.profileDB.frameBackgroundInset + RMT.profileDB.frameEdgeSize) * RMT.profileDB.scale,
			-1 * (1 - RMT.profileDB.frameBackgroundInset + RMT.profileDB.frameEdgeSize) * RMT.profileDB.scale)
	else
		frame:SetPoint("TOPLEFT", "RMTHealer"..(frame.index - 1), "BOTTOMLEFT", 0, -1 * RMT.profileDB.barSpacing)
	end
	
	healerFrames[frame.index] = frame
	RMT:ResizeBase(RMTWatchFrameBase_Frame, #healerFrames)
	frame:Show()
end

function RMT:AssignFrame(frame, guid)
	frame:UnregisterAllEvents()
	
	if not guid then
		frame:Hide()
		return
	end
	
	local index = frame.index
	local events = {}
	function events:UNIT_POWER(...)
		local healer, powerType = ...
		if UnitGUID(healer) == RMT['healerRoster'][index] and powerType == "MANA" then
			local value = ceil(UnitPower(healer, 0)*100/UnitPowerMax(healer, 0))
			RMT:SetTextColor(frame.manaPercent, value, "mana")
		end
	end
	function events:UNIT_MAXPOWER(...)
		local healer, powerType = ...
		if powerType == "MANA"  and UnitGUID(healer) == RMT['healerRoster'][index] then
			local value = ceil(UnitPower(healer, 0)*100/UnitPowerMax(healer, 0))
			RMT:SetTextColor(frame.manaPercent, value, "mana")
		end
	end
	function events:COMBAT_LOG_EVENT_UNFILTERED(...)
		local timeStamp, event, sourceGUID, sourceName = select(1, ...), select(2, ...), select(4, ...), select(5, ...)
		if (event == "SPELL_CAST_SUCCESS" or event == "SPELL_SUMMON") and (sourceGUID == RMT['healerRoster'][index]) then
			local spellID, spellName, _ = select(12, ...)
			if RMT.personalCooldowns[spellID] then
				frame.cooldownTexture:SetDesaturated(1)
				AceTimer:ScheduleTimer(function()
					frame.cooldownTexture:SetDesaturated(nil)
				end, RMT.personalCooldowns[spellID].CD, frame, HealerCDUpdate)
			elseif RMT.potions[spellID] then
				frame.potionTexture:SetDesaturated(1)
			end
		elseif event == "UNIT_DIED" and UnitIsDeadOrGhost(RMT['raidRoster'][RMT['healerRoster'][index]].name) then
			frame.manaPercent:SetText("DEAD")
			frame.manaPercent:SetTextColor(1, 0, 0)
		end
	end
	-- if RMT['raidRoster'][RMT['healerRoster'][index]].class == "MONK" then
		-- function events:COM
	-- end
	
	frame:SetScript("OnEvent", function(self, event, ...)
		events[event](self, ...)
	end)
	
	for k, v in pairs(events) do
		frame:RegisterUnitEvent(k, RMT['raidRoster'][guid].name)
	end	
end

-- For manual resets only
function RMT:Reset()
	for index, frame in pairs(healerFrames) do
		frame.cooldownTexture:SetDesaturated(nil)
		frame.potionTexture:SetDesaturated(nil)
	end
end

-- No personal mana cooldowns are five minutes or longer, so none reset after a kill - keeping this for later use. Mana hymns are five minutes, but aren't personal and will be relegated to the recommendations module
function RMT:Wipe()
	--for index, healer in pairs(RMT['healerRoster']) do
end

--------------------
-- Initialization --
--------------------

function RMT:CreateRaidTables()
	RMT.cooldownQueue = {}
	RMT.raidRoster = {}
	RMT.healerRoster = {}
	RMT.recommendRoster = {}
end

function RMT:RMT_SlashHandler(input)
	local str1, str2 = input:match("^(%S*)%s*(.-)$")
	
	if str1 == "" then
		print("Raid Mana Tracker:")
		print("/rmt config - Open RMT Options")
		print("/rmt show - Toggle visibility on watch frame")
		print("/rmt lock - Toggle lock on watch frame")
		print("/rmt reset - Mark all cooldowns and potions as available")
	elseif str1 == "config" or str1 == "opt" or str1 == "options" then
		AceConfigDialog:Open("RMT")
	elseif str1 == "show" or str1 == "hide" then
		RMT:ToggleVisibility()
	elseif str1 == "lock" or str1 == "unlock" then
		RMT:ToggleMover()
	elseif str1 == "reset" or str1 == "wipe" then
		RMT:Reset()
	else
		print("Unrecognized command")
		print("/rmt for available commands")
	end
end

function RMT:OnInitialize()
	RMT:RegisterChatCommand("RMT", "RMT_SlashHandler")
	RMT:RegisterChatCommand("RAIDMANATRACKER", "RMT_SlashHandler")
	
	RMT.db = AceDB:New("RaidManaTrackerDB", RMT.defaults, true)
	RMT.profileDB = RMT.db.profile
	RMT:SetupOptions()
	
	LGI.RegisterCallback(RMT, "GroupInSpecT_Update", function(event, ...)
		RMT.OnUpdate(...)
	end)
	
	LGI.RegisterCallback(RMT, "GroupInSpecT_Remove", function(...)
		RMT.OnRemove(...)
	end)
	
	RMT.RegisterCallback(RMT, "HealerCDUpdate", function(event, ...)
		local frame = ...;
		frame:SetDesaturated(nil);
	end)
		
	RMT:CreateRaidTables()
	RMT:CreateWatchFrame()
	
	RMT:CheckVisibility()
end

function RMT:OnEnable()

end

function RMT:OnDisable()

end

function RMT:TimerFeedback()

end
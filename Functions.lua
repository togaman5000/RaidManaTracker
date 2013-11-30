-- Where am I now: bar rearrangement

---------------------------------
-- Raid Mana Tracker Functions --
---------------------------------

if not RMT then return end
local RMT = RMT
local LGI = LibStub:GetLibrary("LibGroupInSpecT-1.0")
local LSM = LibStub("LibSharedMedia-3.0")

-------------
-- Utility --
-------------

function RMT:GetGroupType()
	return ((select(2, IsInInstance()) == "pvp" and "battleground") or (select(2, IsInInstance()) == "arena" and "battleground") or (IsInRaid() and "raid") or (GetNumSubgroupMembers() > 0 and "party") or "none")
end

function RMT:ClassColorString(class)
	return string.format("|cFF%02x%02x%02x",
		RAID_CLASS_COLORS[class].r * 255,
		RAID_CLASS_COLORS[class].g * 255,
		RAID_CLASS_COLORS[class].b * 255)
end

function RMT:SetTextColor(frame, value, class)
	-- frame needs to be a fontstring
	if not frame:IsObjectType("FontString") then return end

	if class == "mana" then -- value is percentage amount, 0 <= value <= 100
		valueColor = RED_FONT_COLOR
		if value > self.profileDB.highMana then
			valueColor = GREEN_FONT_COLOR
		elseif value > self.profileDB.lowMana then
			valueColor = YELLOW_FONT_COLOR
		end
		frame:SetText(value)
		frame:SetTextColor(valueColor.r, valueColor.g, valueColor.b)
	elseif class == "class" then -- value is player GUID
		local classColor = RAID_CLASS_COLORS[RMT['raidRoster'][value].class]
		frame:SetText(RMT['raidRoster'][value].name)
		frame:SetTextColor(classColor.r, classColor.g, classColor.b)
	end
end

function RMT:SortCooldowns(a, b)
	return a.readyTime < b.readyTime and true or false
end

function RMT:FindEntry(t, e) -- t is the table, e is the entry
	for index, value in pairs(t) do
		if t[index] == e then
			return index
		end
	end
	return 0
end

function RMT:RearrangeHealerFrames(frame)
	local parent = frame:GetParent()
	local children = parent:GetChildren() -- Getting the frames "siblings"
	for index, child in pairs(children) do -- Find the sibling attached to frame, and attach it like frame
		local relativeTo = select(2, child:GetPoint())
		if relativeTo == frame then
			local point, relativeFrame, relativePoint, xOfs, yOfs = frame:GetPoint()
			child:SetPoint(point, relativeFrame, relativePoint, xOfs, yOfs)
		end
	end
	
	frame:Hide()
end

function RMT:CheckVisibility()
	local frame = RMTWatchFrameBase_Frame
	local groupType = RMT:GetGroupType()
	
	frame:Hide()
	RMT.show = nil
	
	if RMT.profileDB.groupShow == "always" then
		frame:Show()
		RMT.show = true
	elseif RMT.profileDB.groupShow == "raid" and groupType == "raid" then
		if RMT.profileDB.groupPositionShow == "always" then
			frame:Show()
			RMT.show = true
		elseif RMT.profileDB.groupPositionShow == "lead" and (UnitIsGroupAssistant("player") or UnitIsGroupLeader("player") or GetSpecializationRole(GetSpecialization()) == "HEALER") then
			frame:show()
			RMT.show = true
		elseif RMT.profileDB.groupPositionShow == "healer" and GetSpecializationRole(GetSpecialization()) == "HEALER" then
			frame:Show()
			RMT.show = true
		end
	elseif RMT.profileDB.groupShow == "party" and (groupType == "raid" or groupType == "party") then
		frame:Show()
		RMT.show = true
	end
	
	if #RMT['healerRoster'] == 0 then
		frame:Hide()
		RMT.show = false
	end
end

function RMT:ToggleVisibility()
	local frame = RMTWatchFrameBase_Frame
	if (RMT.show) then
		frame:Hide()
		RMT.show = nil
	else
		frame:Show()
		RMT.show = true
	end
end

function RMT:ToggleMover()
	local watchFrameMover = RMTWatchFrameAnchor_Frame
	if (RMT.locked) then
		watchFrameMover:EnableMouse(true)
		watchFrameMover:RegisterForDrag("LeftButton")
		watchFrameMover:Show()
		RMT.locked = nil
		print("RMT: unlocked")
	else
		watchFrameMover:EnableMouse(false)
		watchFrameMover:RegisterForDrag(nil)
		watchFrameMover:Hide()
		RMT.locked = true
		
		local point, _, relPoint, xOfs, yOfs = watchFrameMover:GetPoint(1)
		RMT.profileDB.framePoint = point
		RMT.profileDB.relativePoint = relPoint
		RMT.profileDB.xOffset = xOfs
		RMT.profileDB.yOffset = yOfs
		
		print("RMT: locked")
	end
end

function RMT:Reset()
	local watchFrameMover = RMTWatchFrameAnchor_Frame
	RMT.profileDB.framePoint = RMT.defaults.framePoint
	RMT.profileDB.relativePoint = RMT.defaults.relativePoint
	RMT.profileDB.xOffset = RMT.defaults.xOffset
	RMT.profileDB.yOffset = RMT.defaults.yOffset
	watchFrameMover:SetPoint(
		RMT.profileDB.framePoint,
		UIParent,
		RMT.profileDB.relativePoint,
		RMT.profileDB.xOffset,
		RMT.profileDB.yOffset)
end
----------------------
-- Frame Appearance --
----------------------
function RMT:ChangeBackdrop(frame)
	frame:SetBackdrop( {
		bgFile = LSM:Fetch('background', RMT.profileDB.frameBackground),
		edgeFile = LSM:Fetch('border', RMT.profileDB.frameBorder),
		tile = false, tileSize = 0, edgeSize = RMT.profileDB.frameEdgeSize,
		insets = { 	left = RMT.profileDB.frameBackgroundInset,
					right = RMT.profileDB.frameBackgroundInset,
					top = RMT.profileDB.frameBackgroundInset,
					bottom = RMT.profileDB.frameBackgroundInset,
			},
		})
	frame:SetBackdropColor(
		RMT.profileDB.backdropColor.r,
		RMT.profileDB.backdropColor.g,
		RMT.profileDB.backdropColor.b,
		RMT.profileDB.backdropColor.a)
	if RMT.profileDB.borderColorByClass then
		local classColor = RAID_CLASS_COLORS[select(2, UnitClass("player"))]
		frame:SetBackdropBorderColor(
			classColor.r,
			classColor.g,
			classColor.b,
			RMT.profileDB.borderColor.a)
	else
		frame:SetBackdropBorderColor(
			RMT.profileDB.borderColor.r,
			RMT.profileDB.borderColor.g,
			RMT.profileDB.borderColor.b,
			RMT.profileDB.borderColor.a)
	end
end

function RMT:ResizeBase(frame, entries)
	frame:SetHeight(2 * (RMT.profileDB.frameEdgeSize - RMT.profileDB.frameBackgroundInset) + (20 * RMT.profileDB.scale * entries) + (RMT.profileDB.barSpacing * (entries - 1)))
	print(#RMT['healerRoster'])
	if #RMT['healerRoster'] == 0 then
		frame:Hide()
	end
end
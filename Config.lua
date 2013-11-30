-----------------------------
-- RaidManaTracker Options --
-----------------------------

if not RMT then return end
local RMT = RMT
local LSM = LibStub("LibSharedMedia-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local AceGUILSM = LibStub("AceGUISharedMediaWidgets-1.0")

function RMT:SetupOptions()
	RMT.options.args.profile = AceDBOptions:GetOptionsTable(RMT.db)
	
	AceConfig:RegisterOptionsTable("RMT", RMT.options, nil)
	AceConfig:RegisterOptionsTable("RMTBlizz", RMT.blizzOptionsMenu, nil)
	
	AceConfigDialog:AddToBlizOptions("RMTBlizz", "Raid Mana Tracker", nil, "general")	
end

RMT.defaults = {
	profile = {
		enable = true,
		scale = 1,
		xOffset = 0,
		yOffset = 0,
		framePoint = 'CENTER',
		relativePoint = 'CENTER',
		show = "always",
		groupShow = "always",
		groupPositionShow = "always",
		recommend = false,
		accounce = false,
		-- growthHorizontal = "right",
		-- growthVertical = "down",
		outofcombat = true,
		highMana = 66,
		lowMana = 33,
		frameBackground = "Blizzard Tooltip",
		frameBorder = "Blizzard Tooltip",
		frameBackgroundInset = 2,
		frameEdgeSize = 1,
		font = "Friz Quadrata TT",
		backdropColorStyle = "default",
		backdropColor = {
			r = 1,
			g = 1,
			b = 1,
			a = 1.0,
		},
		borderColorByClass = false,
		borderColor = {
			r = 0.05,
			g = 0.05,
			b = 0.05,
			a = 0,
		},
		barSpacing = 1,
		hideExtras = true,
	},
}

RMT.options = {
	type = "group",
	name = "Raid Mana Tracker",
	args = {
		general = {
			order = 1,
			type = "group",
			name = "General Settings",
			args = {
				enable = {
					order = 2,
					type = "toggle",
					name = "Enable Watch",
					get = function()
						return RMT.profileDB.enable
					end,
					set = function()
						RMT.profileDB.enable = value
					end,
				},
				showGroupType = {
					order = 4,
					type = "select",
					name = "Enable In Group Type",
					get = function()
						return RMT.profileDB.groupShow
					end,
					set = function(info, value)
						RMT.profileDB.groupShow = value
					end,
					values = {
						["always"] = "Always",
						["raid"] = "Raid",
						["party"] = "Raid and Party",
					},
				},
				showGroupPosition = {
					order = 5,
					type = "select",
					name = "Enable If Group Position:",
					get = function()
						return RMT.profileDB.groupPositionShow
					end,
					set = function(info, value)
						RMT.profileDB.groupPositionShow = value
					end,
					values = {
						["always"] = "Always",
						["lead"] = "Lead or Assist",
						["healer"] = "Healer",
					},
				},
				configure = {
					type = "execute",
					name = "Apply Changes",
					desc = "Apply changes and reload the UI.",
					func = function()
						ReloadUI()
					end,
					order = 1,
					width = "full",
				},
				autohidecombat = {
					order = 3,
					type = "toggle",
					name = "Show Out of Combat",
					get = function()
						return RMT.profileDB.outofcombat
					end,
					set = function()
						RMT.profileDB.outofcombat = value
					end,
				},
				showextras = {
					order = 6,
					type = "toggle",
					name = "Hide Extras",
					desc = "Hide Benched Healers",
					get = function()
						return RMT.profileDB.hideExtras
					end,
					set = function()
						RMT.profileDB.hideExtras = value;
						RMT:SetExtras()
					end,
				},
			},
		},
		frame = {
			order = 2,
			type = "group",
			name = "Frame Settings",
			args = {
				configure = {
					type = "execute",
					name = "Apply Changes",
					desc = "Apply changes and reload the UI.",
					func = function()
						ReloadUI()
					end,
					order = 1,
					width = "full",
				},
				scale = {
					order = 2,
					type = "range",
					name = "Set Scale",
					desc = "Sets Scale of Watch Frame",
					min = 0.5, max = 1.5, step = 0.1,
					get = function()
						return RMT.profileDB.scale
					end,
					set = function(info, value)
						RMT.profileDB.scale = value
					end,
				},
				barheading = {
					order = 3,
					type = "header",
					name = "Bar Settings",
				},
				font = {
					order = 4,
					type = "select",
					dialogControl = "LSM30_Font",
					name = "Bar Font",
					desc = "Sets addon-wide font",
					values = LSM:HashTable("font"),
					get = function()
						return RMT.profileDB.font
					end,
					set = function(self, key)
						RMT.profileDB.font = key
						
					end,
				},
				barspacing = {
					order = 5,
					type = "range",
					name = "Set Bar Spacing",
					desc = "Sets Bar Spacing In Pixels",
					min = 0, max = 10, step = 1.0,
					get = function()
						return RMT.profileDB.barSpacing
					end,
					set = function(info, value)
						RMT.profileDB.barSpacing = value
					end,
				},
				backdropheading = {
					order = 6,
					type = "header",
					name = "Backdrop Settings",
				},
				backdrop = {
					order = 7,
					type = "select",
					dialogControl = "LSM30_Background",
					name = "Watch Frame Background",
					desc = "Sets Watch Frame Background",
					values = LSM:HashTable("background"),
					get = function()
						return RMT.profileDB.frameBackground
					end,
					set = function(self, key)
						RMT.profileDB.frameBackground = key;
						RMT:ChangeBackdrop(RMTWatchFrameBase_Frame);
					end,
				},
				backdropcolor = {
					order = 8,
					type = "color",
					name = "Background Color",
					desc = "Set Background Color",
					hasAlpha = true,
					get = function() return
						RMT.profileDB.backdropColor.r,
						RMT.profileDB.backdropColor.g,
						RMT.profileDB.backdropColor.b,
						RMT.profileDB.backdropColor.a
					end,
					set = function(_, r, g, b, a)
						RMT.profileDB.backdropColor.r = r;
						RMT.profileDB.backdropColor.b = b;
						RMT.profileDB.backdropColor.g = g;
						RMT.profileDB.backdropColor.a = a;
						RMT:ChangeBackdrop(RMTWatchFrameBase_Frame)
					end,
				},
				border = {
					order = 9,
					type = "select",
					dialogControl = "LSM30_Border",
					name = "Watch Frame Border",
					desc = "Sets Watch Frame Border",
					values = LSM:HashTable("border"),
					get = function()
						return RMT.profileDB.frameBorder
					end,
					set = function(self, key)
						RMT.profileDB.frameBorder = key;
						RMT:ChangeBackdrop(RMTWatchFrameBase_Frame);
					end,
				},
				bordercolor = {
					order = 10,
					type = "color",
					name = "Border Color",
					desc = "Set Border Color",
					hasAlpha = true,
					get = function() return
						RMT.profileDB.borderColor.r,
						RMT.profileDB.borderColor.g,
						RMT.profileDB.borderColor.b,
						RMT.profileDB.borderColor.a
					end,
					set = function(_, r, g, b, a)
						RMT.profileDB.borderColor.r = r;
						RMT.profileDB.borderColor.g = g;
						RMT.profileDB.borderColor.b = b;
						RMT.profileDB.borderColor.a = a;
						RMT:ChangeBackdrop(RMTWatchFrameBase_Frame)
					end,
				},
				bordercolorstyle = {
					order = 11,
					type = "toggle",
					name = "Color Border by Class",
					get = function()
						return RMT.profileDB.borderColorByClass
					end,
					set = function(key, value)
						RMT.profileDB.borderColorByClass = value
					end,
				},
				insets = {
					order = 12,
					type = "range",
					name = "Set Border Inset",
					desc = "Sets Border Inset",
					min = -5, max = 5, step = 1.0,
					get = function()
						return RMT.profileDB.frameBackgroundInset
					end,
					set = function(info, value)
						RMT.profileDB.frameBackgroundInset = value;
						RMT:ChangeBackdrop(RMTWatchFrameBase_Frame);
					end,
				},
				edgesize = {
					order = 13,
					type = "range",
					min = 0, max = 10, step = 1.0,
					name = "Edge Thickness",
					desc = "Set Edge Thickness",
					get = function() return
						RMT.profileDB.frameEdgeSize
					end,
					set = function(info, value)
						RMT.profileDB.frameEdgeSize = value;
						RMT:ChangeBackdrop(RMTWatchFrameBase_Frame)
					end,
				},
			},
		},
	},
}

RMT.blizzOptionsMenu = {
	type = "group",
	name = "Raid Mana Tracker",
	args = {
		general = {
			order = 1,
			type = "group",
			name = "Raid Mana Tracker",
			args = {
				openaceoptions = {
					type = "execute",
					name = "Open RMT Options",
					desc = "Open RMT Options",
					func = function()
						AceConfigDialog:CloseAll();
						AceConfigDialog:Open("RMT");
					end,
					order = 1,
				},
			},
		},
	},
}
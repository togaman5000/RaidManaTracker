-- TODO: Would like to get all data into a single table, but current implementation is fine
-- TODO: Better implementation for 4 different priest spells

---------------------------------------------------------
-- Contains relevant information for Raid Mana Tracker --
---------------------------------------------------------

if not RMT then return end
local RMT = RMT

RMT.personalCooldowns = {
	[29166] = { -- Innervate
		spellName = "Innervate",
		name = "DRUID_INNERVATE",
		CD = 180,
	},
	[115294] = { -- Mana Tea
		spellName = "Mana Tea",
		name = "MONK_MANA_TEA",
		CD = 1,
	},
	[54428] = { -- Divine Plea
		spellName = "Divine Plea",
		name = "PALADIN_DIVINE_PLEA",
		CD = 120,
	},
	[34433] = { -- Shadowfiend
		spellName = "Shadowfiend",
		name = "PRIEST_SHADOWFIEND",
		CD = 180,
	},
	[132603] = { -- Shadowfiend with Sha glyph
		spellName = "Shadowfiend",
		name = "PRIEST_SHADOWFIEND_SHA",
		CD = 180,
	},
	[123040] = { -- Mindbender
		spellName = "Mindbender",
		name = "PRIEST_MINDBENDER",
		CD = 60,
	},
	[132604] = { -- Mindbender with Sha glyph
		spellName = "Mindbender",
		name = "PRIEST_MINDBENDER_SHA",
		CD = 60,
	},
	[16190] = { -- Mana Tide Totem
		spellName = "Mana Tide Totem",
		name = "SHAMAN_MANA_TIDE",
		CD = 180,
	},
}

RMT.personalCooldownsByClass = { -- For potential use later
	["DRUID"] = {
		spellName = "Innervate",
		spellCD = 180,
	},
	["MONK"] = {
		spellName = "Mana Tea",
		spellCD = 1,
	},
	["PALADIN"] = {
		spellName = "Divine Plea",
		CD = 180,
	},
	["PRIEST"] = {
	
	},
}

RMT.potions = {
	[105701] = {
		name = "Potion of Focus",
	},
	[105709] = {
		name = "Master Mana Potion",
	},
	[105704] = {
		name = "Alchemist's Rejuvenation",
	},
	[130650] = {
		name = "Water Spirit",
	},
}

RMT.personalCooldownsOld = {
-- Druid
	{ -- Innervate
		spellID = 29166,
		name = "DRUID_INNERVATE",
		succ = "SPELL_CAST_SUCCESS",
		CD = 180,
		cast = 8,
		class = "DRUID"
	},
-- Monk, don't need but including for completion's sake
	{ -- Mana Tea
		spellID = 115294,
		name = "MONK_MANA_TEA",
		succ = "SPELL_CAST_SUCCESS",
		class = "MONK",
	},
-- Paladin
	{ -- Divine Plea
		spellID = 54428,
		name = "PALADIN_DIVINE_PLEA",
		succ = "SPELL_CAST_SUCCESS",
		CD = 120,
		cast = 9,
		class = "PALADIN",
		spec = 65,
	},
-- Priest
	{ -- Shadowfiend
		spellID = 34433,
		name = "PRIEST_SHADOWFIEND",
		succ = "SPELL_SUMMON",
		CD = 180,
		class = "PRIEST",
	},
	{ -- Shadowfiend with Sha Appearance
		spellID = 132603,
		name = "PRIEST_SHADOWFIEND_SHA",
		succ = "SPELL_SUMMON",
		CD = 180,
		class = "PRIEST",
	},
	{ -- Mindbender
		spellID = 123040,
		name = "PRIEST_MINDBENDER",
		succ = "SPELL_SUMMON",
		CD = 60,
		class = "PRIEST",
	},
	{ -- Mindbender with Sha Appearance
		spellID = 132604,
		name = "PRIEST_MINDBENDER_SHA",
		succ = "SPELL_SUMMON",
		CD = 60,
		class = "PRIEST",
	},
-- Shaman
	{ -- Mana Tide, counts as a personal as well as a raidwide
		spellID = 16190,
		name = "SHAMAN_MANA_TIDE",
		succ = "SPELL_CAST_SUCCESS",
		CD = 180,
		cast = 16,
		class = "SHAMAN",
		spec = 264,
	},
}

RMT.raidwideCooldowns = { -- Using term "raidwide" loosely here, refers to CDs that might be used on another player
-- Druid 
	{	-- Innervate
		spellID = 29166,
		name = "DRUID_INNERVATE",
		succ = "SPELL_CAST_SUCCESS",
		CD = 180,
		cast = 8,
		class = "DRUID"
	},
-- Priest
	{ -- Hymn of Hope
		spellID = 64901,
		name = "PRIEST_HYMN_OF_HOPE",
		succ = "SPELL_CAST_SUCCESS",
		CD = 360,
		cast = 8,
		class = "PRIEST",
	},
-- Shaman
	{ -- Mana Tide
		spellID = 16190,
		name = "SHAMAN_MANA_TIDE",
		succ = "SPELL_CAST_SUCCESS",
		CD = 180,
		cast = 16,
		class = "SHAMAN",
		spec = 264,
	},
}
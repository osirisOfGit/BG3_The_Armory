-- Can't assign any of these fields to local fields for convenience - breaks VSCode Lua type hints

--- @class AttunementRules
ConfigurationStructure.DynamicClassDefinitions.rules = {
	totalAttunementLimit = 13
}

---@enum RarityLimitCategories
RarityLimitCategories = {
	[1] = "Total",
	[2] = "Weapons",
	[3] = "Armor",
	[4] = "Accessories",
	Total = 13,
	Weapons = 4,
	Armor = 5,
	Accessories = 4,
}

--- @class LimitRarityBySlotGroup
ConfigurationStructure.DynamicClassDefinitions.rarityLimitPerSlot = {
	Total = 13,
	Weapons = 4,
	Armor = 5,
	Accessories = 4,
}

--- @type {[Rarity] : {[RarityLimitCategories] : number }}
ConfigurationStructure.DynamicClassDefinitions.rules.rarityLimits = {}

--- @alias AttuneGuiElement "resource"|"statusOnLimit"
--- @class RarityGuiRules
ConfigurationStructure.DynamicClassDefinitions.rules.rarityGuiDisplay = {
	["resource"] = false,
	["statusOnLimit"] = true,
}

---@enum Difficulties
Difficulties = {
	[1] = "EASY",
	[2] = "MEDIUM",
	[3] = "HARD",
	[4] = "HONOUR",
	EASY = 1,
	MEDIUM = 2,
	HARD = 3,
	HONOUR = 4
}

ConfigurationStructure.config.rules = {
	---@type { [Difficulties|'Base'] : AttunementRules }
	difficulties = {},
	---@type {[Rarity] : {[RarityLimitCategories] : RarityGuiRules}}
	rarityGuiRules = {},
	attunementGuiRules = TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.rules.rarityGuiDisplay)
}

ConfigurationStructure.config.rules.attunementGuiRules["resource"] = true

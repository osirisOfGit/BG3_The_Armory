-- Can't assign any of these fields to local fields for convenience - breaks VSCode Lua type hints

---@alias ItemStat Weapon|Armor|Object

ConfigurationStructure.config.items = {}

ConfigurationStructure.DynamicClassDefinitions.items = {}

---@class RarityOverride
ConfigurationStructure.DynamicClassDefinitions.items.rarityOverrides = {
	---@type Rarity
	Original = nil,
	---@type Rarity
	New = nil
}

---@alias StatName string

---@type { [StatName] : RarityOverride}
ConfigurationStructure.config.items.rarityOverrides = {}

---@type { [StatName] : boolean}
ConfigurationStructure.config.items.requiresAttunementOverrides = {}

---@type Rarity
ConfigurationStructure.config.items.attunementRarityThreshold = RarityEnum[2]

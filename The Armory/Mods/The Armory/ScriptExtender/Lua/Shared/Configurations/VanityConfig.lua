-- Can't use variables to shortcut as that breaks type hints by the lua extension

ConfigurationStructure.config.vanity = {}

--#region User Settings
ConfigurationStructure.config.vanity.settings = {
	general = {
		applyDyesWhenPreviewingEquipment = true
	},
	equipment = {
		---@type Guid[]
		favorites = {},
		imageSize = 90,
		rowSize = 4,
		showNames = true
	},
	dyes = {
		---@type Guid[]
		favorites = {},
		showDyeNames = true,
		imageSize = 90
	}
}
--#endregion

--#region Presets
ConfigurationStructure.DynamicClassDefinitions.vanity = {}

---@class ModDependency
ConfigurationStructure.DynamicClassDefinitions.modDependency = {
	Guid = nil,
	Version = nil
}

---@class VanityOutfitItemEntry
ConfigurationStructure.DynamicClassDefinitions.vanity.outfitItemEntry = {
	guid = nil,
	---@type ModDependency
	modDependency = nil,
}

---@class VanityOutfitSlot
ConfigurationStructure.DynamicClassDefinitions.vanity.outfitSlot = {
	---@type VanityOutfitItemEntry
	equipment = nil,
	---@type {[VanityWeaponType]: VanityOutfitSlot}
	weaponTypes = nil,
	---@type VanityOutfitItemEntry
	dye = nil,
}

---@alias VanityWeaponType string

ConfigurationStructure.DynamicClassDefinitions.vanity.outfit = {}

---@alias VanityOutfit {[ActualSlot]: VanityOutfitSlot}

---@class VanityPreset
ConfigurationStructure.DynamicClassDefinitions.vanity.preset = {
	Author = "",
	Name = "",
	Notes = "",
	Version = "",
	---@type ModDependency?
	ModSourced = nil,
	---@type ModDependency[]
	ModDependencies = {},
	---@type {[VanityCriteriaCompositeKey] : VanityOutfit}
	Outfits = {},
}

---@type {[Guid]: VanityPreset}
ConfigurationStructure.config.vanity.presets = {}

--#endregion

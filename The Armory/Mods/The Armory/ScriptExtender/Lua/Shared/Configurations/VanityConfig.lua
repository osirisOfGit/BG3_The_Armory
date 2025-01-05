-- Can't use variables to shortcut as that breaks type hints by the lua extension

ConfigurationStructure.config.vanity = {}

--#region User Settings
ConfigurationStructure.config.vanity.settings = {
	general = {
		applyDyesWhenPreviewingEquipment = true
	}
}
--#endregion

--#region Presets
ConfigurationStructure.DynamicClassDefinitions.vanity = {}

---@class ModDependency
ConfigurationStructure.DynamicClassDefinitions.modDependency = {
	Guid = "",
	Version = ""
}

---@class VanityOutfitItemEntry
ConfigurationStructure.DynamicClassDefinitions.vanity.outfitItemEntry = {
	guid = "",
	modDependency = ConfigurationStructure.DynamicClassDefinitions.modDependency
}

---@class VanityOutfitSlot
ConfigurationStructure.DynamicClassDefinitions.vanity.outfitSlot = {
	equipment = ConfigurationStructure.DynamicClassDefinitions.vanity.outfitItemEntry,
	dye = ConfigurationStructure.DynamicClassDefinitions.vanity.outfitItemEntry,
}

---@alias VanityWeaponType string

---@class VanityOutfit
---@type {[ActualSlot|VanityWeaponType]: VanityOutfitSlot}
ConfigurationStructure.DynamicClassDefinitions.vanity.outfit = {}

---@class VanityPreset
ConfigurationStructure.DynamicClassDefinitions.vanity.preset = {
	Author = "",
	Name = "",
	Description = "",
	Version = "",
	---@type Guid?
	ModSourced = nil,
	---@type ModDependency[]
	ModDependencies = {},
	---@type {[VanityCriteriaCompositeKey] : VanityOutfit}
	Outfits = {},
}

---@type VanityPreset[]
ConfigurationStructure.config.vanity.presets = {}

--#endregion

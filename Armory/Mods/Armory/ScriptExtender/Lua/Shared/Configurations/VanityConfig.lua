-- Can't use variables to shortcut as that breaks type hints by the lua extension

---@class Vanity
ConfigurationStructure.config.vanity = {}

--#region User Settings
ConfigurationStructure.config.vanity.settings = {
	general = {
		showSlotContextMenuOnRightClick = false,
		fillEmptySlots = true,
		---@alias outfitAndDependencyView "universal"|"perOutfit"
		---@type outfitAndDependencyView
		outfitAndDependencyView = "universal",
		itemValidator_ShowWorkaroundErrors = false,
		removeBladesongStatusOnReload = false
	},
	---@class EquipmentSettings
	equipment = {
		---@type Guid[]
		favorites = {},
		imageSize = 90,
		rowSize = 6,
		showNames = true,
		applyDyesWhenPreviewingEquipment = true,
		requireModifierForPreview = false
	},
	---@class DyeSettings
	dyes = {
		---@type Guid[]
		favorites = {},
		showNames = true,
		imageSize = 90
	}
}
--#endregion

--#region Presets

ConfigurationStructure.DynamicClassDefinitions.vanity = {}

---@class ModDependency
ConfigurationStructure.DynamicClassDefinitions.modDependency = {
	---@type string?
	Name = nil,
	---@type string
	Guid = nil,
	---@type string?
	Author = nil,
	---@type number[]
	Version = nil,
	---@type string?
	Resources = nil,
	---@type string?
	Notes = nil,
	---@type ModDependency?
	OriginalMod = nil,
}

---@class VanityOutfitItemEntry
ConfigurationStructure.DynamicClassDefinitions.vanity.outfitItemEntry = {
	name = nil,
	guid = nil,
	---@type ModDependency
	modDependency = nil,
	---@type string[]
	effects = nil
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
	Version = "",
	---@type boolean
	NSFW = true,
	---@type ModDependency?
	ModSourced = nil,
	isExternalPreset = false,
	---@type {[VanityCriteriaCompositeKey] : VanityOutfit}
	Outfits = {},
	---@type ModDependency[]
	CustomDependencies = {}
}

---@type {[Guid]: VanityPreset}
ConfigurationStructure.config.vanity.presets = {}

---@type {[Guid]: string}
ConfigurationStructure.config.vanity.miscNameCache = {}

---@type {[string]: VanityEffect}
ConfigurationStructure.config.vanity.effects = {
}
--#endregion

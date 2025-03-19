-- Can't use variables to shortcut as that breaks type hints by the lua extension

ConfigurationStructure.config.vanity = {}

--#region User Settings
ConfigurationStructure.config.vanity.settings = {
	general = {
		showSlotContextMenuModifier = nil,
		fillEmptySlots = true
	},
	---@class EquipmentSettings
	equipment = {
		---@type Guid[]
		favorites = {},
		imageSize = 90,
		rowSize = 6,
		showNames = true,
		applyDyesWhenPreviewingEquipment = true
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
	---@type number[]
	Version = nil,
	---@type ModDependency?
	OriginalMod = nil
}

---@class VanityOutfitItemEntry
ConfigurationStructure.DynamicClassDefinitions.vanity.outfitItemEntry = {
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
	---@type {[VanityCriteriaCompositeKey] : VanityOutfit}
	Outfits = {},
}

---@type {[Guid]: VanityPreset}
ConfigurationStructure.config.vanity.presets = {}

---@type {[string]: VanityEffect}
ConfigurationStructure.config.vanity.effects = {
	ARMORY_VANITY_EFFECT_Burning = {
		Name = "ARMORY_VANITY_EFFECT_Burning",
		effectProps = {
			StatusEffect = "2156dd48-f83b-4060-9a4e-cab994da8857"
		}
	},
	ARMORY_VANITY_EFFECT_Frozen = {
		Name = "ARMORY_VANITY_EFFECT_Frozen",
		effectProps = {
			StatusEffect = "62318bbf-d36a-497c-91a4-bda8f7fb7af7"
		}
	},
	ARMORY_VANITY_EFFECT_Golden_Shimmer = {
		Name = "ARMORY_VANITY_EFFECT_Golden_Shimmer",
		effectProps = {
			StatusEffect = "d798b3cf-15ab-4911-9884-82799e6fd3ef"
		}
	},
	ARMORY_VANITY_EFFECT_Invisible = {
		Name = "ARMORY_VANITY_EFFECT_Invisible",
		effectProps = {
			StatusEffect = "d26436d4-d019-4dfc-b2f1-da0ac195575f"
		}
	},
	ARMORY_VANITY_EFFECT_Running_Blood = {
		Name = "ARMORY_VANITY_EFFECT_Running_Blood",
		effectProps = {
			StatusEffect = "6a8e81d8-dda5-438d-8414-01db0dc1f2ff"
		}
	}
}
--#endregion

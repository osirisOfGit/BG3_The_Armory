Ext.Require("Shared/Vanity/MissingEnums.lua")


local effectCollection = {}

---@type ExtuiPopup
local formPopup

---@param extClass Ext_StaticData|Ext_Resource
---@param type string
local function buildEffectBankSupplier(extClass, type)
	return function()
		local displayOrderedMap = {}
		local displayToKeyMap = {}
		for _, key in ipairs(extClass.GetAll(type)) do
			---@type ResourceMultiEffectInfo|ResourceSoundResource
			local single = extClass.Get(key, type)
			displayToKeyMap[type == "Sound" and key or single.Name] = key
			table.insert(displayOrderedMap, type == "Sound" and key or single.Name)
		end
		table.sort(displayOrderedMap)
		return displayToKeyMap, displayOrderedMap
	end
end

local effectBanks = {
	AuraFX = buildEffectBankSupplier(Ext.StaticData, "MultiEffectInfo"),
	BeamEffect = buildEffectBankSupplier(Ext.StaticData, "MultiEffectInfo"),
	FormatColor = function() return FormatStringColor end,
	MaterialType = function() return MaterialType end,
	SoundLoop = buildEffectBankSupplier(Ext.Resource, "Sound"),
	SoundStart = buildEffectBankSupplier(Ext.Resource, "Sound"),
	SoundStop = buildEffectBankSupplier(Ext.Resource, "Sound"),
	SoundVocalLoop = function() return SoundVocalType end,
	SoundVocalStart = function() return SoundVocalType end,
	SoundVocalEnd = function() return SoundVocalType end,
	StatusEffect = buildEffectBankSupplier(Ext.StaticData, "MultiEffectInfo"),
}

---@class VanityEffect
VanityEffect = {
	---@type string
	Name = "",
	---@class VanityEffectProperties
	effectProps = {
		---@type string?
		AuraFX = "",
		---@type integer?
		AuraRadius = 0,
		---@type string?
		BeamEffect = "",
		---@type string?
		FormatColor = "",
		---@type string?
		MaterialType = "",
		---@type string?
		SoundLoop = "",
		---@type string?
		SoundStart = "",
		---@type string?
		SoundStop = "",
		---@type string?
		SoundVocalLoop = "",
		---@type string?
		SoundVocalStart = "",
		---@type string?
		SoundVocalEnd = "",
		---@type string?
		StatusEffect = "",
	}
}

---@param instance table
---@param name string
---@param effectProps VanityEffectProperties
---@return VanityEffect
function VanityEffect:new(instance, name, effectProps)
	instance = instance or {}
	setmetatable(instance, self)
	self.__index = self
	instance.Name = "ARMORY_VANITY_EFFECT_" .. name

	effectProps.Name = nil
	instance.effectProps = TableUtils:DeeplyCopyTable(effectProps)

	if not next(effectCollection) then
		for effectName, vanityEffect in pairs(ConfigurationStructure.config.vanity.effects) do
			effectCollection[effectName] = VanityEffect:new({}, vanityEffect.Name, vanityEffect.effectProps)
		end
	end

	return instance
end

if Ext.IsServer() then
	function VanityEffect:buildStat()
		if not Ext.Stats.Get(self.Name) then
			local newStat = Ext.Stats.Create(self.Name, "EFFECT", "_PASSIVES")
			for key, value in pairs(self.effectProps) do
				newStat[key] = value
			end
			newStat:Sync()
		end
	end
end

if Ext.IsClient() then
	Ext.Require("Client/_FormBuilder.lua")

	---@param parent ExtuiTreeParent
	function VanityEffect:buildCreateEffectForm(parent)
		formPopup = parent.ParentElement:AddPopup("Create Effect Form")

		---@type FormStructure[]
		local formInputs = { {
			label = "Name",
			type = "Text",
			errorMessageIfEmpty = "Must provide a name"
		} }
		for effectProp, value in TableUtils:OrderedPairs(self.effectProps) do
			table.insert(formInputs, {
				label = effectProp,
				propertyField = effectProp,
				type = type(value) == "number" and "NumericText" or "Text",
				dependsOn = (effectProp == "AuraRadius" and "AuraFX")
					or (effectProp == "FormatColor" and "MaterialType")
					or (effectProp == "MaterialType" and "FormatColor")
					or nil,
				errorMessageIfEmpty = (effectProp == "AuraRadius" and "AuraRadius is required if AuraFX is specified")
					or (effectProp == "FormatColor" and "FormatColor is required if MaterialType is specified")
					or (effectProp == "MaterialType" and "MaterialType is required if FormatColor is specified")
					or nil,
				enumTable = effectBanks[effectProp]

			} --[[@as FormStructure]])
		end

		FormBuilder:CreateForm(formPopup,
			function(inputs)
				local newEffect = VanityEffect:new({}, inputs.Name, inputs)
				effectCollection[newEffect.Name] = newEffect
				ConfigurationStructure.config.vanity.effects[newEffect.Name] = newEffect
			end,
			formInputs)

		formPopup:Open()
	end

	---@param parentPopup ExtuiPopup
	---@param vanityOutfitItemEntry VanityOutfitItemEntry
	function VanityEffect:buildSlotContextMenuEntries(parentPopup, vanityOutfitItemEntry)
		---@type ExtuiMenu
		local menu = parentPopup:AddMenu("Add Effects")
		for effectName, vanityEffect in TableUtils:OrderedPairs(effectCollection) do
			---@type ExtuiSelectable
			local effectSelectable = menu:AddSelectable(string.sub(effectName, #"ARMORY_VANITY_EFFECT_"), "DontClosePopups")
			effectSelectable.UserData = vanityEffect
			local contains = TableUtils:ListContains(vanityOutfitItemEntry.effects, effectName)
			effectSelectable.Selected = contains

			effectSelectable.OnClick = function()
				if effectSelectable.Selected then
					if not vanityOutfitItemEntry.effects then
						vanityOutfitItemEntry.effects = {}
					end
					local tableCopy = {}
					for _, effect in ipairs(vanityOutfitItemEntry.effects) do
						if effect ~= effectName then
							table.insert(tableCopy, effect)
						end
					end
					vanityOutfitItemEntry.effects.delete = true
					vanityOutfitItemEntry.effects = tableCopy
				end
			end
		end

		---@type ExtuiSelectable
		local addNewEffectSelectable = menu:AddSelectable("Create New Effect")
		addNewEffectSelectable.OnClick = function()
			self:buildCreateEffectForm(parentPopup)
		end
	end
end

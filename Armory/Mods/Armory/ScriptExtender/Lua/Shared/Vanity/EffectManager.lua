Ext.Require("Shared/Vanity/MissingEnums.lua")

---@type {[string]: VanityEffect}
local effectCollection = {}

---@type ExtuiWindow
local formPopup

---@param extClass Ext_StaticData|Ext_Resource
---@param type string
local function buildEffectBankSupplier(extClass, type)
	return function()
		local displayOrderedMap = {}
		local displayToKeyMap = {}
		for _, key in ipairs(extClass.GetAll(type)) do
			---@type ResourceMultiEffectInfo
			local single = extClass.Get(key, type)
			displayToKeyMap[type == "Sound" and key or single.Name] = key
			table.insert(displayOrderedMap, type == "Sound" and key or single.Name)
		end
		table.sort(displayOrderedMap)
		return displayToKeyMap, displayOrderedMap
	end
end

local effectBanks = {
	StatusEffect = buildEffectBankSupplier(Ext.StaticData, "MultiEffectInfo"),
}

---@class VanityEffect
VanityEffect = {
	---@type string
	Name = "",
	---@class VanityEffectProperties
	effectProps = {
		---@type string?
		StatusEffect = "",
		-- ---@type string?
		-- StatusEffectOnTurn = "",
		-- ---@type string?
		-- FormatColor = "",
		-- ---@type string?
		-- MaterialType = "",
	},
	cachedDisplayNames = {}
}

---@param instance table
---@param name string
---@param effectProps VanityEffectProperties
---@return VanityEffect
function VanityEffect:new(instance, name, effectProps)
	instance = instance or {}
	setmetatable(instance, self)
	self.__index = self
	instance.Name = name:gsub("%s", "_")
	if not string.match(instance.Name, "ARMORY_VANITY_EFFECT_") then
		instance.Name = "ARMORY_VANITY_EFFECT_" .. instance.Name
	end

	effectProps.Name = nil
	instance.effectProps = TableUtils:DeeplyCopyTable(effectProps)

	return instance
end

---@param targetVanity Vanity
---@param presetName string
---@param outfit VanityOutfit
---@param effectsFromSource {[string]: VanityEffect}
---@param overwriteSourceEffect boolean
function VanityEffect:CopyEffectsToPresetOutfit(targetVanity, presetName, outfit, effectsFromSource, overwriteSourceEffect)
	local vanityConfig = ConfigurationStructure:GetRealConfigCopy().vanity

	-- Remove any non-alpabetical and space characters so it can be used as a Status name if necessary
	local sanitizedPresetName = presetName:gsub("[^%a%s]", ""):gsub("%s", "_")

	local overwriteTracker = false

	local function processEffects(effects)
		for index, effect in pairs(effects) do
			local sanitizedEffect = effect .. "_" .. sanitizedPresetName
			if not overwriteTracker or (not targetVanity.effects[effect] and not targetVanity.effects[sanitizedEffect]) then
				overwriteTracker = true

				if vanityConfig.effects[effect] and overwriteSourceEffect and not TableUtils:TablesAreEqual(vanityConfig.effects[effect], effectsFromSource[effect]) then
					effects[index] = sanitizedEffect
					targetVanity.effects[sanitizedEffect] = TableUtils:DeeplyCopyTable(effectsFromSource[effect])
					targetVanity.effects[sanitizedEffect].Name = sanitizedEffect
				else
					targetVanity.effects[effect] = TableUtils:DeeplyCopyTable(effectsFromSource[effect])
				end
			elseif targetVanity.effects[sanitizedEffect] then
				effects[index] = sanitizedEffect
			end
		end
	end

	for _, outfitSlot in pairs(outfit) do
		if outfitSlot.equipment and outfitSlot.equipment.effects then
			processEffects(outfitSlot.equipment.effects)
		end

		if outfitSlot.weaponTypes then
			for _, weaponSlot in pairs(outfitSlot.weaponTypes) do
				if weaponSlot.equipment and weaponSlot.equipment.effects then
					processEffects(weaponSlot.equipment.effects)
				end
			end
		end
	end
end

if Ext.IsServer() then
	function VanityEffect:createStat()
		if not Ext.Stats.Get(self.Name) then
			Logger:BasicDebug("Creating Effect %s", self.Name)
			---@type StatusData
			local newStat = Ext.Stats.Create(self.Name, "StatusData", "_PASSIVES")
			for key, value in pairs(self.effectProps) do
				if value and value ~= "" then
					newStat[key] = value
				end
			end
			newStat.StackId = self.Name
			newStat:Sync()
			return true
		end
	end

	function VanityEffect:editStat()
		---@type StatusData?
		local newStat = Ext.Stats.Get(self.Name)
		if newStat then
			Logger:BasicDebug("Updating Effect %s to be %s", self.Name, Ext.Json.Stringify(self.effectProps))
			for key, value in pairs(self.effectProps) do
				if value and value ~= "" then
					newStat[key] = value
				else
					newStat[key] = nil
				end
			end
			newStat.StackId = self.Name
			newStat:Sync()

			if self.Name ~= "TheArmory_Vanity_PreviewEffect" then
				for _, entityId in pairs(Ext.Vars.GetEntitiesWithVariable("TheArmory_Vanity_EffectsMarker")) do
					if Osi.HasActiveStatus(entityId, self.Name) == 1 then
						Osi.RemoveStatus(entityId, self.Name)
						Ext.Timer.WaitFor(10, function()
							Osi.ApplyStatus(entityId, self.Name, -1, 1)
						end)
					end
				end
			end
			return true
		end
	end

	Ext.RegisterNetListener(ModuleUUID .. "_EditEffect", function(channel, payload, user)
		local effectRaw = Ext.Json.Parse(payload)
		VanityEffect:new({}, effectRaw.Name, effectRaw.effectProps):editStat()
	end)

	Ext.RegisterNetListener(ModuleUUID .. "_DeleteEffect", function(channel, effectName, user)
		VanityEffect:deleteStat(effectName)
	end)

	Ext.RegisterNetListener(ModuleUUID .. "_PreviewEffect", function(channel, payload, user)
		user = PeerToUserID(user)
		local character = Osi.GetCurrentCharacter(user)

		local effectRaw = Ext.Json.Parse(payload)
		local slot = effectRaw.slot

		local effect = VanityEffect:new({}, "TheArmory_Vanity_PreviewEffect", effectRaw.effectProps)
		if not effect:editStat() then
			effect:createStat()
		end

		local equippedItem = Osi.GetEquippedItem(character, slot)
		if equippedItem then
			Osi.ApplyStatus(Osi.GetEquippedItem(character, slot), effect.Name, 10)
		end
	end)
end

function VanityEffect:deleteStat(effectName)
	if Ext.IsClient() then
		effectName = self.Name
		ConfigurationStructure.config.vanity.effects[effectName].delete = true

		local function removeEffect(outfitSlot, presetName, outfitKey, slot, weaponType)
			if outfitSlot.equipment and outfitSlot.equipment.effects then
				if TableUtils:ListContains(outfitSlot.equipment.effects, effectName) then
					local tableCopy = {}
					for _, existingEffect in ipairs(outfitSlot.equipment.effects) do
						if existingEffect ~= effectName then
							table.insert(tableCopy, existingEffect)
						end
					end
					local proxyTable = ConfigurationStructure.config.vanity.presets[presetName].Outfits[outfitKey][slot]
					if weaponType then
						proxyTable = proxyTable.weaponTypes[weaponType]
					end
					proxyTable = proxyTable.equipment
					proxyTable.effects.delete = true
					proxyTable.effects = next(tableCopy) and tableCopy or nil

					Helpers:ClearEmptyTablesInProxyTree(proxyTable)
				end
			end
		end

		-- pairs returns the real table, not the proxy one
		for presetName, preset in pairs(ConfigurationStructure.config.vanity.presets) do
			for outfitKey, outfit in pairs(preset.Outfits) do
				for slot, outfitSlot in pairs(outfit) do
					removeEffect(outfitSlot, presetName, outfitKey, slot)
					if outfitSlot.weaponTypes then
						for weaponType, weaponTypeSlot in pairs(outfitSlot.weaponTypes) do
							removeEffect(weaponTypeSlot, presetName, outfitKey, slot, weaponType)
						end
					end
				end
			end
		end

		Ext.Net.PostMessageToServer(ModuleUUID .. "_DeleteEffect", effectName)
	else
		for _, entityId in pairs(Ext.Vars.GetEntitiesWithVariable("TheArmory_Vanity_EffectsMarker")) do
			if Osi.HasActiveStatus(entityId, effectName) == 1 then
				Osi.RemoveStatus(entityId, effectName)

				local removeMarker = true
				for otherEffectName in pairs(ConfigurationStructure.config.vanity.effects) do
					if otherEffectName ~= effectName then
						if Osi.HasActiveStatus(entityId, otherEffectName) == 1 then
							removeMarker = false
							break
						end
					end
				end
				if removeMarker then
					Ext.Entity.Get(entityId).Vars.TheArmory_Vanity_EffectsMarker = nil
				end
			end
		end
	end
end

if Ext.IsClient() then
	Ext.Require("Client/_FormBuilder.lua")

	---@param parent ExtuiTreeParent
	function VanityEffect:buildCreateEffectForm(parent)
		if formPopup then
			pcall(function(...)
				formPopup:Destroy()
			end)
		end

		formPopup = Ext.IMGUI.NewWindow(Translator:translate("Create Effect Form"))
		formPopup:SetFocus()
		formPopup.Closeable = true
		formPopup.NoCollapse = true
		formPopup.AlwaysAutoResize = true

		local warningText = formPopup:AddText(
			Translator:translate("Please be aware that there's currently no way for Armory to know which effects came from mods, so these won't show up in the mod dependencies"))
		warningText.UserData = "keep"
		warningText.TextWrapPos = 0
		warningText:SetStyle("Alpha", 0.65)

		---@type FormStructure[]
		local formInputs = { {
			label = "Name",
			type = "Text",
			errorMessageIfEmpty = "Must provide a name",
			defaultValue = self.Name and string.sub(self.Name, #"ARMORY_VANITY_EFFECT_" + 1),
			enabled = self.Name and self.Name ~= ""
		} }
		for effectProp, value in TableUtils:OrderedPairs(self.effectProps) do
			table.insert(formInputs, {
				label = effectProp,
				defaultValue = self.effectProps and self.effectProps[effectProp] or nil,
				propertyField = effectProp,
				type = type(value) == "number" and "NumericText" or "Text",
				enumTable = effectBanks[effectProp],
				errorMessageIfEmpty = "Must select a value"
			} --[[@as FormStructure]])
		end

		local inputSupplier = FormBuilder:CreateForm(formPopup,
			function(inputs)
				local initiateEdit = self.Name and self.Name ~= ""
				local effectToModify
				if initiateEdit then
					effectToModify = self
				else
					effectToModify = VanityEffect:new({}, inputs.Name, inputs)
				end

				if not effectToModify.cachedDisplayNames then
					effectToModify.cachedDisplayNames = {}
				end
				effectToModify.cachedDisplayNames[effectToModify.effectProps.StatusEffect] = nil

				inputs.Name = nil
				effectToModify.effectProps = inputs

				---@type ResourceMultiEffectInfo
				local mei = Ext.StaticData.Get(effectToModify.effectProps.StatusEffect, "MultiEffectInfo")
				effectToModify.cachedDisplayNames[effectToModify.effectProps.StatusEffect] = mei.Name

				effectCollection[effectToModify.Name] = effectToModify
				if ConfigurationStructure.config.vanity.effects[effectToModify.Name] then
					ConfigurationStructure.config.vanity.effects[effectToModify.Name].delete = true
				end
				ConfigurationStructure.config.vanity.effects[effectToModify.Name] = effectToModify

				formPopup:Destroy()
				if initiateEdit then
					Ext.Net.PostMessageToServer(ModuleUUID .. "_EditEffect", Ext.Json.Stringify(self))
				end
			end,
			formInputs)

		local previewButton = formPopup:AddButton(Translator:translate("Preview"))
		previewButton.SameLine = true
		previewButton.OnClick = function()
			local inputs = inputSupplier()
			if inputs then
				local effect = VanityEffect:new({}, inputs.Name, inputs)
				effect.slot = SlotContextMenu.itemSlot
				Ext.Net.PostMessageToServer(ModuleUUID .. "_PreviewEffect", Ext.Json.Stringify(effect))
			end
		end
		previewButton:Tooltip():AddText(string.format("\t  " .. Translator:translate("Will use a reserved status to apply the selected effect to the equipped item in the currently selected slot (%s) for 10 rounds"), SlotContextMenu.itemSlot)).TextWrapPos = 600
	end

	---@param parentPopup ExtuiPopup
	---@param vanityOutfitItemEntry VanityOutfitItemEntry?
	---@param onSubmitFunc function
	function VanityEffect:buildSlotContextMenuEntries(parentPopup, vanityOutfitItemEntry, onSubmitFunc)
		effectCollection = {}

		for effectName, vanityEffect in pairs(ConfigurationStructure.config.vanity.effects) do
			effectCollection[effectName] = VanityEffect:new({}, vanityEffect.Name, vanityEffect.effectProps)
		end

		---@type ExtuiMenu
		local menu = parentPopup:AddMenu(Translator:translate("Add Effects"))
		for effectName, vanityEffect in TableUtils:OrderedPairs(effectCollection) do
			---@type ExtuiMenu
			local effectMenu = menu:AddMenu(string.sub(effectName, #"ARMORY_VANITY_EFFECT_" + 1))

			---@type ExtuiSelectable
			local enableEffect = effectMenu:AddSelectable("", "DontClosePopups")
			enableEffect.UserData = vanityEffect
			enableEffect.Selected = (vanityOutfitItemEntry and vanityOutfitItemEntry.effects) and TableUtils:ListContains(vanityOutfitItemEntry.effects, effectName) or false
			enableEffect.Label = enableEffect.Selected and Translator:translate("Disable") or Translator:translate("Enable")
			if enableEffect.Selected then
				effectMenu:SetColor("Text", { 144 / 255, 238 / 255, 144 / 255, 1 })
			end

			enableEffect.OnClick = function()
				if enableEffect.Selected then
					effectMenu:SetColor("Text", { 144 / 255, 238 / 255, 144 / 255, 1 })
					vanityOutfitItemEntry = SlotContextMenu:GetOutfitSlot()
					if not vanityOutfitItemEntry.effects then
						vanityOutfitItemEntry.effects = {}
					end
					table.insert(vanityOutfitItemEntry.effects, effectName)
				elseif vanityOutfitItemEntry and vanityOutfitItemEntry.effects and vanityOutfitItemEntry.effects() then
					effectMenu:SetColor("Text", { 219 / 255, 201 / 255, 173 / 255, 0.78 })
					local tableCopy = {}
					for _, existingEffect in ipairs(vanityOutfitItemEntry.effects) do
						if existingEffect ~= effectName then
							table.insert(tableCopy, existingEffect)
						end
					end
					vanityOutfitItemEntry.effects.delete = true
					vanityOutfitItemEntry.effects = next(tableCopy) and tableCopy or nil

					Helpers:ClearEmptyTablesInProxyTree(vanityOutfitItemEntry)
				end
				onSubmitFunc()
				enableEffect.Label = enableEffect.Selected and Translator:translate("Disable") or Translator:translate("Enable")
			end

			---@type ExtuiSelectable
			local editEffect = effectMenu:AddSelectable(Translator:translate("Edit"))
			editEffect.IDContext = effectMenu.Label .. "Edit"
			editEffect.OnClick = function()
				vanityEffect:buildCreateEffectForm(parentPopup)
			end

			---@type ExtuiSelectable
			local deleteEffect = effectMenu:AddSelectable(Translator:translate("Delete"), "DontClosePopups")
			deleteEffect.IDContext = effectMenu.Label .. "Delete"
			deleteEffect.OnClick = function()
				vanityEffect:deleteStat()
				effectCollection[effectName] = nil
				effectMenu:Destroy()
				onSubmitFunc()
			end

			enableEffect:SetColor("Text", { 219 / 255, 201 / 255, 173 / 255, 0.78 })
			editEffect:SetColor("Text", { 219 / 255, 201 / 255, 173 / 255, 0.78 })
			deleteEffect:SetColor("Text", { 219 / 255, 201 / 255, 173 / 255, 0.78 })
		end

		---@type ExtuiSelectable
		local addNewEffectSelectable = menu:AddSelectable(Translator:translate("Create New Effect"))
		addNewEffectSelectable.OnClick = function()
			self:buildCreateEffectForm(parentPopup)
		end
	end
end

Translator:RegisterTranslation({
	["Create Effect Form"] = "h6be19d3e032543a58900a528e1399bfefa2g",
	["StatusEffect"] = "hf66bcec3350b4fa1b317a08b6d038e1d7eg6",
	["Please be aware that there's currently no way for Armory to know which effects came from mods, so these won't show up in the mod dependencies"] = "h5f8facf0545f4d9b9871fc4ef0756c720e53",
	["Must provide a name"] = "h3985d3d0bf8943f7b33cd0ac714e48020447",
	["Must select a value"] = "h3ab9121338134e3b850376b2c36f65d5ca1b",
	["Preview"] = "h38a45f57bdd7446bb5464ce2cfd4078bcegf",
	["Will use a reserved status to apply the selected effect to the equipped item in the currently selected slot (%s) for 10 rounds"] = "h10acf4ac4f2b4c6887e317d60bea1cf23e8g",
	["Add Effects"] = "h47d69cc7394e4b1eb882464b287b5719e3fb",
	["Disable"] = "h5fbccc4e25c241a887b57c60988bafe7e705",
	["Enable"] = "hb12adca21c4e45189573c291701a5fa6d293",
	["Edit"] = "hca540bf66df845bc9fde931f58c0aaa71b3b",
	["Delete"] = "h87dc5ed2db464ee9b73b29e2fcd22135100f",
	["Create New Effect"] = "h16fdaad3e9c04689afcf6469c0bc2f453751",
})

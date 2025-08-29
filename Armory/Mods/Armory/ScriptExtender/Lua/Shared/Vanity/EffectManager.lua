Ext.Require("Shared/Vanity/MissingEnums.lua")

---@type {[string]: VanityEffect}
local effectCollection = {}

---@class VanityEffect
VanityEffect = {
	---@type string
	Name = "",
	---@class VanityEffectProperties
	effectProps = {
		---@type string?
		StatusEffect = "",
	},
	cachedDisplayNames = {},
	sourceModId = nil,
	disableDuringDialogue = false
}

local defaultEffects = {
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
	},
	ARMORY_VANITY_EFFECT_Mug = {
		Name = "ARMORY_VANITY_EFFECT_Mug",
		effectProps =
		{
			StatusEffect = "3edc688a-c08c-47dc-a25f-91a91789666c"
		}
	},
	ARMORY_VANITY_EFFECT_True_Invisibility = {
		Name = "ARMORY_VANITY_EFFECT_True_Invisibility",
		effectProps =
		{
			StatusEffect = "b5aa3b03-feda-46fc-9c10-2aed4da05c05"
		}
	}
}

---@param instance table?
---@param name string
---@param effectProps VanityEffectProperties
---@return VanityEffect
function VanityEffect:new(instance, name, effectProps, disableDuringDialogue)
	instance = instance or {}
	setmetatable(instance, self)
	self.__index = self
	instance.Name = name:gsub("%s", "_")
	if not string.match(instance.Name, "ARMORY_VANITY_EFFECT_") then
		instance.Name = "ARMORY_VANITY_EFFECT_" .. instance.Name
	end

	effectProps.Name = nil
	instance.disableDuringDialogue = disableDuringDialogue
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

function VanityEffect:GetEffectOrMeiResource(effectString)
	local success, resource = pcall(function(...)
		---@type ResourceMultiEffectInfo
		local mei = Ext.StaticData.Get(effectString or self.effectProps.StatusEffect, "MultiEffectInfo")
		return mei
	end)

	if not success or not resource then
		success, resource = pcall(function()
			---@type ResourceEffectResource
			local effect = Ext.Resource.Get(effectString or self.effectProps.StatusEffect, "Effect")
			return effect
		end)
		return resource.EffectName, "Effect"
	else
		return resource.Name, "MEI"
	end
end

function VanityEffect:createStat()
	if not Ext.Stats.Get(self.Name) then
		Logger:BasicDebug("Creating Effect %s", self.Name)
		---@type StatusData
		local newStat = Ext.Stats.Create(self.Name, "StatusData", "_PASSIVES")
		for key, value in pairs(self.effectProps) do
			if value and value ~= "" then
				local name, meiOrEffect = self:GetEffectOrMeiResource()
				newStat[key] = meiOrEffect == "MEI" and value or name
			end
		end
		newStat.StackId = self.Name
		newStat:Sync()

		if Ext.IsServer() then
			if Ext.ServerNet.IsHost() then
				Ext.Timer.WaitFor(100, function()
					Channels.UpdateStatusEffect:Broadcast({
						Name = self.Name,
						effectProps = self.effectProps,
						disableDuringDialogue = self.disableDuringDialogue
					})
				end)
			end
		else
			Ext.System.ClientVisual.ReloadAllVisuals = true
		end
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
				local name, meiOrEffect = self:GetEffectOrMeiResource()
				newStat[key] = meiOrEffect == "MEI" and value or name
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

		if Ext.IsServer() then
			if Ext.ServerNet.IsHost() then
				Ext.Timer.WaitFor(100, function()
					Channels.UpdateStatusEffect:Broadcast({
						Name = self.Name,
						effectProps = self.effectProps,
						disableDuringDialogue = self.disableDuringDialogue
					})
				end)
			end
		else
			Ext.System.ClientVisual.ReloadAllVisuals = true
		end

		return true
	else
		return self:createStat()
	end
end

if Ext.IsServer() then
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

		if slot ~= "Character" then
			local equippedItem = Osi.GetEquippedItem(character, slot)
			if equippedItem then
				Osi.ApplyStatus(Osi.GetEquippedItem(character, slot), effect.Name, 10)
			end
		else
			Osi.ApplyStatus(character, effect.Name, 10)
		end
	end)

	---@type {[Guid]: {[Guid]: string[]}}
	local disabledEffects = {}

	Ext.Osiris.RegisterListener("DialogActorJoined", 4, "before", function(dialog, instanceID, actor, speakerIndex)
		if Osi.IsPlayer(actor) == 1 then
			Logger:BasicDebug("%s joined dialogue, checking if any effects need to be disabled", actor)
			---@type EntityHandle
			local entity = Ext.Entity.Get(actor)
			local _, charUserId = ServerPresetManager:GetCharacterPreset(entity.Uuid.EntityUuid)

			local vanity = ServerPresetManager.ActiveVanityPresets[charUserId]
			for _, slot in ipairs(SlotEnum) do
				local equippedItem = Osi.GetEquippedItem(actor, slot)
				if equippedItem then
					---@type EntityHandle
					local equippedItemEntity = Ext.Entity.Get(equippedItem)
					if equippedItemEntity.StatusContainer then
						for _, statusName in pairs(equippedItemEntity.StatusContainer.Statuses) do
							if statusName:find("ARMORY_VANITY_EFFECT") and vanity.effects[statusName].disableDuringDialogue then
								Logger:BasicDebug("Disabling effect %s", statusName)
								disabledEffects[actor] = disabledEffects[actor] or {}
								disabledEffects[actor][equippedItem] = disabledEffects[actor][equippedItem] or {}
								table.insert(disabledEffects[actor][equippedItem], statusName)
								Osi.RemoveStatus(equippedItem, statusName)
							end
						end
					end
				end
			end

			if entity.StatusContainer then
				for _, statusName in pairs(entity.StatusContainer.Statuses) do
					if statusName:find("ARMORY_VANITY_EFFECT") and vanity.effects[statusName].disableDuringDialogue then
						Logger:BasicDebug("Disabling effect %s", statusName)
						disabledEffects[actor] = disabledEffects[actor] or {}
						disabledEffects[actor][entity.Uuid.EntityUuid] = disabledEffects[actor][entity.Uuid.EntityUuid] or {}
						table.insert(disabledEffects[actor][entity.Uuid.EntityUuid], statusName)
						Osi.RemoveStatus(entity.Uuid.EntityUuid, statusName)
					end
				end
			end
		end
	end)

	Ext.Osiris.RegisterListener("DialogActorLeft", 4, "before", function(dialog, instanceID, actor, instanceEnded)
		if Osi.IsPlayer(actor) == 1 then
			if disabledEffects[actor] then
				Logger:BasicDebug("%s left dialogue, reenabling effects", actor)
				for itemUuid, effects in pairs(disabledEffects[actor]) do
					for _, effectName in pairs(effects) do
						Logger:BasicDebug("Reenabling %s", effectName)
						Osi.ApplyStatus(itemUuid, effectName, -1)
					end
				end
				disabledEffects[actor] = {}
			end
		end
	end)
end

function VanityEffect:deleteStat(effectName)
	if Ext.IsClient() then
		effectName = self.Name
		ConfigurationStructure.config.vanity.effects[effectName].delete = true

		local function removeEffect(outfitSlot, presetName, outfitKey, slot, weaponType)
			if outfitSlot.equipment and outfitSlot.equipment.effects then
				if TableUtils:IndexOf(outfitSlot.equipment.effects, effectName) then
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

			if preset.Character then
				for _, section in pairs(preset.Character) do
					if section["effects"] and TableUtils:IndexOf(section["effects"], effectName) then
						table.remove(section["effects"], TableUtils:IndexOf(section["effects"], effectName))
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

	Channels.UpdateStatusEffect:SetHandler(function(effectRaw, user)
		VanityEffect:new({}, effectRaw.Name, effectRaw.effectProps):editStat()
	end)

	---@type ExtuiWindow
	local formWindow

	local resourceEffectCache = {}

	---@type {[string]: string}
	local effects = {}

	local function buildStatusEffectBank()
		local function addEffect(effectString)
			local success, result = pcall(function(...)
				---@type ResourceMultiEffectInfo?
				local resource = Ext.StaticData.Get(effectString, "MultiEffectInfo")

				if resource then
					effects[resource.ResourceUUID] = resource.Name
				end
			end)
			if not success then
				if string.find(effectString, "[:;]") then
					for value in effectString:gmatch("([^;:]+)") do
						if not value:find(":") and resourceEffectCache[value] then
							effects[resourceEffectCache[value]] = value
						end
					end
				elseif resourceEffectCache[effectString] then
					effects[resourceEffectCache[effectString]] = effectString
				end
			end
		end

		if not next(effects) then
			for _, effect in pairs(Ext.Resource.GetAll("Effect")) do
				resourceEffectCache[Ext.Resource.Get(effect, "Effect").EffectName] = effect
			end

			for _, status in pairs(Ext.Stats.GetStats("StatusData")) do
				---@type StatusData
				status = Ext.Stats.Get(status)

				if status.StatusEffect and status.StatusEffect ~= "" then
					addEffect(status.StatusEffect)
				end

				if status.StatusEffectOverride and status.StatusEffectOverride ~= "" then
					addEffect(status.StatusEffectOverride)
				end

				if status.StatusEffectOverrideForItems and status.StatusEffectOverrideForItems ~= "" then
					addEffect(status.StatusEffectOverrideForItems)
				end

				if status.StatusEffectOnTurn and status.StatusEffectOnTurn ~= "" then
					addEffect(status.StatusEffectOnTurn)
				end
			end
		end

		return effects
	end

	---@param parent ExtuiTreeParent
	function VanityEffect:buildCreateEffectForm(parent)
		if formWindow then
			pcall(function(...)
				formWindow:Destroy()
			end)
		end

		local statusEffectBank = buildStatusEffectBank()

		formWindow = Ext.IMGUI.NewWindow(Translator:translate("Create Effect Form"))
		formWindow:SetFocus()
		formWindow.Closeable = true
		formWindow.NoCollapse = true
		formWindow:SetSize(Styler:ScaleFactor({ 300, 300 }), "FirstUseEver")

		local popup = formWindow:AddPopup("effects")

		formWindow:AddText(Translator:translate("Name") .. ":")
		local nameInput = formWindow:AddInputText("")
		nameInput.SameLine = true
		nameInput.Text = self.Name and string.sub(self.Name, #"ARMORY_VANITY_EFFECT_" + 1)
		nameInput.Disabled = self.Name and self.Name ~= ""

		formWindow:AddText("Chosen Effect: ")
		local selectedEffect = formWindow:AddText(self.effectProps.StatusEffect and statusEffectBank[self.effectProps.StatusEffect] or "")
		selectedEffect.SameLine = true

		---@type ExtuiButton
		local submitButton = formWindow:AddButton(Translator:translate("Submit"))
		local errorText = formWindow:AddText(Translator:translate("Please provide a name and select an effect"))
		errorText:SetColor("Text", { 1, 0.02, 0, 1 })
		errorText.Visible = false

		formWindow:AddSeparatorText(Translator:translate("Select and Preview")):SetStyle("SeparatorTextAlign", 0.5)

		formWindow:AddText("Search:")
		local searchBox = formWindow:AddInputText("")
		searchBox.SameLine = true
		searchBox.AutoSelectAll = true
		searchBox.Hint = "Case-insensitive"

		local options = {}
		local modNameToId = {}
		local sources = Ext.Types.Serialize(Ext.StaticData.GetSources("MultiEffectInfo"))
		for modId, modEffects in pairs(sources) do
			if #modEffects > 0 then
				for effectId in pairs(statusEffectBank) do
					if TableUtils:IndexOf(modEffects, effectId) then
						table.insert(options, Ext.Mod.GetMod(modId).Info.Name)
						modNameToId[Ext.Mod.GetMod(modId).Info.Name] = modId
						break
					end
				end
			end
		end
		table.sort(options)
		table.insert(options, 1, "All")

		formWindow:AddText("Filter by Mod:")
		local combo = formWindow:AddCombo("")
		combo.SameLine = true
		combo.Options = options
		combo.SelectedIndex = 0

		formWindow:AddText(Translator:translate("Click on an effect to preview it, Right-Click for options"))

		local childWin = formWindow:AddChildWindow("effects")

		local displayTable = childWin:AddTable("effects", 2)
		displayTable.RowBg = true
		displayTable.BordersInnerV = true
		displayTable.OptimizedDraw = true

		local displayRow = displayTable:AddRow()

		local counter = 0

		local effectSettings = ConfigurationStructure.config.vanity.settings.effects

		local sourcesCache = {}

		---@type ExtuiSelectable?
		local chosenEffect
		local function renderResults()
			chosenEffect = nil
			Helpers:KillChildren(displayTable)
			displayRow = displayTable:AddRow()

			counter = 0
			local searchUpper = searchBox.Text:upper()
			for effectId, effectName in TableUtils:OrderedPairs(statusEffectBank, function(key, value)
				return value
			end) do
				if (searchUpper == "" or effectName:upper():find(searchUpper))
					and (combo.SelectedIndex <= 0
						or TableUtils:IndexOf(sources[modNameToId[combo.Options[combo.SelectedIndex + 1]]], effectId) ~= nil)
				then
					counter = counter + 1
					---@type ExtuiSelectable
					local select = displayRow:AddCell():AddSelectable(effectName)
					select.UserData = {
						Name = effectName,
						StatusEffect = effectId
					} --[[@as VanityEffectProperties]]

					if TableUtils:IndexOf(effectSettings.undesirables, effectId) then
						select:SetStyle("Alpha", 0.5)
					end

					local modId = sourcesCache[effectId] or TableUtils:IndexOf(sources, function (value)
						return TableUtils:IndexOf(value, effectId) ~= nil
					end)
					if not sourcesCache[effectId] then
						sourcesCache[effectId] = modId
					end

					select:Tooltip():AddText(("\t From: %s"):format(modId and TableUtils:IndexOf(modNameToId, modId) or "Unknown"))

					select.OnClick = function()
						if chosenEffect then
							if chosenEffect.Handle == select.Handle then
								select.Selected = true
								return
							end
							chosenEffect.Selected = false
						end

						local effect = VanityEffect:new({}, nameInput.Text ~= "" and nameInput.Text or "RANDOM_PREVIEW", select.UserData)
						effect.slot = SlotContextMenu.itemSlot or "Character"
						Ext.Net.PostMessageToServer(ModuleUUID .. "_PreviewEffect", Ext.Json.Stringify(effect))
						chosenEffect = select
						selectedEffect.Label = effectName
					end

					select.OnRightClick = function()
						Helpers:KillChildren(popup)
						popup:Open()

						---@type ExtuiSelectable
						local unwanted = popup:AddSelectable(Translator:translate("Mark As Unwanted"))
						unwanted.Selected = TableUtils:IndexOf(effectSettings, effectId) ~= nil

						unwanted.OnClick = function()
							local index = TableUtils:IndexOf(effectSettings.undesirables, effectId)
							if index then
								effectSettings.undesirables[index] = nil
								select:SetStyle("Alpha", 1)
							else
								table.insert(effectSettings.undesirables, effectId)
								select:SetStyle("Alpha", 0.5)
							end
						end
					end

					if counter % displayTable.Columns == 0 then
						displayRow = displayTable:AddRow()
					end
				end
			end
		end
		renderResults()

		combo.OnChange = renderResults

		local timer
		searchBox.OnChange = function()
			if timer then
				Ext.Timer.Cancel(timer)
			end
			timer = Ext.Timer.WaitFor(400, function()
				timer = nil
				renderResults()
			end)
		end

		submitButton.OnClick = function()
			if selectedEffect.Label == "" or nameInput.Text == "" then
				errorText.Visible = true
			else
				local statusEffectId = TableUtils:IndexOf(statusEffectBank, selectedEffect.Label)
				errorText.Visible = false
				local initiateEdit = nameInput.Disabled
				local effectToModify
				if initiateEdit then
					effectToModify = self
					effectToModify.effectProps.StatusEffect = statusEffectId
				else
					effectToModify = VanityEffect:new({}, nameInput.Text, {
						StatusEffect = statusEffectId
					})
				end

				if not effectToModify.cachedDisplayNames then
					effectToModify.cachedDisplayNames = {}
				end
				effectToModify.cachedDisplayNames[effectToModify.effectProps.StatusEffect] = nil

				local success = pcall(function(...)
					---@type ResourceMultiEffectInfo
					local mei = Ext.StaticData.Get(effectToModify.effectProps.StatusEffect, "MultiEffectInfo")
					effectToModify.cachedDisplayNames[effectToModify.effectProps.StatusEffect] = mei.Name
				end)

				effectToModify.sourceModId = TableUtils:IndexOf(sources, function(value)
					return TableUtils:IndexOf(value, statusEffectId) ~= nil
				end)

				effectCollection[effectToModify.Name] = effectToModify
				if ConfigurationStructure.config.vanity.effects[effectToModify.Name] then
					ConfigurationStructure.config.vanity.effects[effectToModify.Name].delete = true
				end
				ConfigurationStructure.config.vanity.effects[effectToModify.Name] = effectToModify

				formWindow:Destroy()
				if initiateEdit then
					Ext.Net.PostMessageToServer(ModuleUUID .. "_EditEffect", Ext.Json.Stringify(self))
				end
			end
		end
	end

	---@param parentPopup ExtuiPopup
	---@param vanityOutfitItemEntry VanityOutfitItemEntry?
	---@param onSubmitFunc function
	function VanityEffect:buildSlotContextMenuEntries(parentPopup, vanityOutfitItemEntry, onSubmitFunc, forCharacter)
		effectCollection = {}

		for effectName, vanityEffect in pairs(ConfigurationStructure.config.vanity.effects) do
			effectCollection[effectName] = VanityEffect:new({}, vanityEffect.Name, vanityEffect.effectProps, vanityEffect.disableDuringDialogue)
		end

		---@type ExtuiMenu
		local menu = parentPopup:AddMenu(Translator:translate("Add Effects"))
		for effectName, vanityEffect in TableUtils:OrderedPairs(effectCollection) do
			---@type ExtuiMenu
			local effectMenu = menu:AddMenu(string.sub(effectName, #"ARMORY_VANITY_EFFECT_" + 1))

			---@type ExtuiSelectable
			local enableEffect = effectMenu:AddSelectable("", "DontClosePopups")
			enableEffect.UserData = vanityEffect
			enableEffect.Selected = (vanityOutfitItemEntry and vanityOutfitItemEntry.effects) and TableUtils:IndexOf(vanityOutfitItemEntry.effects, effectName) ~= nil or false
			enableEffect.Label = enableEffect.Selected and Translator:translate("Disable") or Translator:translate("Enable")
			if enableEffect.Selected then
				effectMenu:SetColor("Text", { 144 / 255, 238 / 255, 144 / 255, 1 })
			end

			---@type ExtuiSelectable
			local disableDuringDialogue

			enableEffect.OnClick = function()
				if enableEffect.Selected then
					effectMenu:SetColor("Text", { 144 / 255, 238 / 255, 144 / 255, 1 })
					if not forCharacter then
						vanityOutfitItemEntry = SlotContextMenu:GetOutfitSlot()
						if not vanityOutfitItemEntry.effects then
							vanityOutfitItemEntry.effects = {}
						end
					end
					table.insert(vanityOutfitItemEntry.effects, effectName)
					disableDuringDialogue.Visible = true
				elseif vanityOutfitItemEntry and vanityOutfitItemEntry.effects and vanityOutfitItemEntry.effects() then
					effectMenu:SetColor("Text", { 219 / 255, 201 / 255, 173 / 255, 0.78 })

					vanityOutfitItemEntry.effects[TableUtils:IndexOf(vanityOutfitItemEntry.effects, effectName)] = nil
					disableDuringDialogue.Visible = false
				end

				Helpers:ClearEmptyTablesInProxyTree(vanityOutfitItemEntry.effects)
				onSubmitFunc()
				enableEffect.Label = enableEffect.Selected and Translator:translate("Disable") or Translator:translate("Enable")
			end

			disableDuringDialogue = effectMenu:AddSelectable("", "DontClosePopups")
			disableDuringDialogue.Visible = enableEffect.Selected
			disableDuringDialogue.Label = vanityEffect.disableDuringDialogue
				and Translator:translate("Enable During Dialogue")
				or Translator:translate("Disable During Dialogue")

			disableDuringDialogue:Tooltip():AddText("\t " .. Translator:translate("Applies to the effect itself, not just to this item, so only needs to be set once"))

			disableDuringDialogue.Selected = vanityEffect.disableDuringDialogue or false
			disableDuringDialogue.OnClick = function()
				ConfigurationStructure.config.vanity.effects[effectName].disableDuringDialogue = disableDuringDialogue.Selected

				if disableDuringDialogue.Selected then
					disableDuringDialogue.Label = Translator:translate("Enable During Dialogue")
				else
					disableDuringDialogue.Label = Translator:translate("Disable During Dialogue")
				end
				onSubmitFunc()
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
			disableDuringDialogue:SetColor("Text", { 219 / 255, 201 / 255, 173 / 255, 0.78 })
			editEffect:SetColor("Text", { 219 / 255, 201 / 255, 173 / 255, 0.78 })
			deleteEffect:SetColor("Text", { 219 / 255, 201 / 255, 173 / 255, 0.78 })
		end

		---@type ExtuiSelectable
		local addNewEffectSelectable = menu:AddSelectable(Translator:translate("Create New Effect"))
		addNewEffectSelectable.OnClick = function()
			self:buildCreateEffectForm(parentPopup)
		end

		---@type ExtuiSelectable
		local restoreDefaults = menu:AddSelectable(Translator:translate("Restore Pre-Packaged Effects"), "DontClosePopups")
		restoreDefaults.OnClick = function()
			for effectName, effect in pairs(defaultEffects) do
				effect.cachedDisplayNames = effect.cachedDisplayNames or {}
				effect.cachedDisplayNames[effect.effectProps.StatusEffect] = self:GetEffectOrMeiResource(effect.effectProps.StatusEffect)
				ConfigurationStructure.config.vanity.effects[effectName] = effect
			end
			menu:Destroy()
			self:buildSlotContextMenuEntries(parentPopup, vanityOutfitItemEntry, onSubmitFunc, forCharacter)
		end
	end
end

Translator:RegisterTranslation({
	["Create Effect Form"] = "h6be19d3e032543a58900a528e1399bfefa2g",
	["StatusEffect"] = "hf66bcec3350b4fa1b317a08b6d038e1d7eg6",
	["Select and Preview"] = "ha73078fc910d45fabe4bd8e0e5c76ad608ba",
	["Click on an effect to preview it, Right-Click for options"] = "he3f38577711b4786a80551943e45e1ab39ge",
	["Please provide a name and select an effect"] = "h76efca8adf1744979ae856319043d7ee3601",
	["Mark As Unwanted"] = "h76efca8adf1744979ae856319043d7ee3601",
	["Add Effects"] = "h47d69cc7394e4b1eb882464b287b5719e3fb",
	["Disable"] = "h5fbccc4e25c241a887b57c60988bafe7e705",
	["Enable"] = "hb12adca21c4e45189573c291701a5fa6d293",
	["Disable During Dialogue"] = "h7bc9ab98a2a44106aa4f1ae5e85d7ae718bb",
	["Enable During Dialogue"] = "hcd094f8ace4841489f7ee4ab60d53bd23861",
	["Applies to the effect itself, not just to this item, so only needs to be set once"] = "hcbed2daa976b4176a3696eed82a3b02dbf7c",
	["Edit"] = "hca540bf66df845bc9fde931f58c0aaa71b3b",
	["Delete"] = "h87dc5ed2db464ee9b73b29e2fcd22135100f",
	["Create New Effect"] = "h16fdaad3e9c04689afcf6469c0bc2f453751",
	["Restore Pre-Packaged Effects"] = "hf7fbcebf0543427487ff3e48b2e16a22e7g0"
})

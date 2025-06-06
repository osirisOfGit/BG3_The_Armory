---@diagnostic disable: missing-fields

Ext.Require("Shared/Vanity/EffectManager.lua")

Ext.Vars.RegisterUserVariable("TheArmory_Vanity_OriginalItemInfo", {
	Server = true
})

Ext.Vars.RegisterUserVariable("TheArmory_Vanity_OriginalDyeInfo", {
	Server = true
})

Ext.Vars.RegisterUserVariable("TheArmory_Vanity_EffectsMarker", {
	Server = true
})

Ext.Vars.RegisterUserVariable("TheArmory_Vanity_Item_ReplicationComponents", {
	Server = true
})

Ext.Vars.RegisterUserVariable("TheArmory_Vanity_Item_CurrentlyMogging", {
	Server = true
})

Transmogger = {}

Transmogger.defaultPieces = {
	Helmet = "4d2e0931-3a01-4759-834b-8ae36749daab",
	VanityBody = "2f7aadd5-65ea-4ab6-8c55-88ee584c72df",
	Cloak = "a1978b4d-3d93-49ec-9a8b-d19171ed35d5",
	VanityBoots = "db2f2945-debc-4b18-b4f5-6456a11ecddb",
	Breast = "168b9099-19f5-44e4-b55c-e64ceb60b71f",
	Underwear = "d40b567d-6b66-447e-8923-2bbd0d7aea00",
	Gloves = "8e34fd76-8b6d-48a5-89e3-942289bec31e",
	Amulet = "51873c0d-f319-45e6-a6a2-79164cd8f3db",
	Boots = "97f37571-35e8-4cc8-8b0d-ff92d20ae0bb",
	Ring1 = "ecf4a8a4-7859-4a82-8c08-0c9526f29500",
	Ring2 = "ecf4a8a4-7859-4a82-8c08-0c9526f29500",
	LightSource = "50c43f27-a12e-412c-88f0-56e15eba692a",
	MusicalInstrument = "848ad8dc-59f3-464b-b8b2-95eab6022446",
	HideTransmog = "173aad0e-0db4-4f2f-8f24-49e6898b8f90"
}

-- Things that will cause me psychic damage: https://discord.com/channels/1174823496086470716/1193836567194771506/1327500800766771271

-- Everything commented out causes crashes
local componentsToCopy = {
	"Armor",
	"AttributeFlags",
	"BoostsContainer",
	"CanBeDisarmed",
	"Data",
	"DisplayName",
	"Equipable",
	["GameObjectVisual"] = {
		"Icon"
	},
	"Icon",
	"ItemBoosts",
	"ItemDye",
	-- "PassiveContainer",
	-- "ProficiencyGroup",
	"ServerBaseData",
	"ServerBaseWeapon",
	"ServerBoostTag",
	"ServerDisplayNameList",
	["ServerItem"] = {
		"ItemType",
		"Stats",
	},
	"ServerOwneeHistory",
	"ServerIconList",
	-- "ServerPassiveBase",
	-- "ServerPassivePersistentData",
	-- "ServerProficiencyGroupStats",
	"ServerTemplateTag",
	"StatusImmunities",
	"Tag",
	"Use",
	"Value",
	"Weapon"
}

local componentsToReplicateOnRefresh = {
	["DisplayName"] = true,
	["ServerDisplayNameList"] = true,
	["ServerIconList"] = true,
	["Icon"] = true,
	["Tag"] = true
}

---@param entity EntityHandle
---@return string
local function buildMetaInfoForLog(entity)
	---@type Weapon|Armor|Object
	local stat = Ext.Stats.Get(entity.Data.StatsId)
	local modInfo = stat.ModId and Ext.Mod.GetMod(stat.ModId).Info or nil
	return Ext.Json.Stringify({
		uuid = entity.ServerItem.Template.Name .. "_" .. entity.Uuid.EntityUuid,
		templateUuid = entity.ServerItem.Template.Name .. "_" .. entity.ServerItem.Template.Id,
		displayName = entity.DisplayName.Name:Get(),
		statName = stat.Name,
		modId = stat.ModId,
		modName = modInfo and modInfo.Name,
		modAuthor = modInfo and modInfo.Author,
		modVersion = modInfo and table.concat(modInfo.ModVersion, ".")
	})
end

-- Lock for transmogs that shouldn't run on save load, like polymorphed chars
Transmogger.saveLoadLock = false

---@param character EntityHandle
function Transmogger:MogCharacter(character)
	local characterPreset, charUserId = ServerPresetManager:GetCharacterPreset(character.Uuid.EntityUuid)

	if not characterPreset then
		Logger:BasicDebug("%s does not have an outfit, clearing their transmog", (character.DisplayName and character.DisplayName.Name:Get()) or character.Uuid.EntityUuid)
		Transmogger:ClearOutfit(character.Uuid.EntityUuid)
		return
	end

	local vanity = ServerPresetManager.ActiveVanityPresets[charUserId]

	-- characters that are wildshaped in a save when it's loaded will not start with their equipment, it gets added back by the game,
	-- but Vanity triggers before that happens, giving the player default items and blocking the requipment of the original ones
	-- Also, you can't change gear while whildshaped anyway
	if self.saveLoadLock then
		if vanity.settings.general.removeBladesongStatusOnReload
			and (Osi.HasActiveStatus(character.Uuid.EntityUuid, "BLADESONG_ARMOR_MESSAGE") == 1
				or Osi.HasActiveStatus(character.Uuid.EntityUuid, "BLADESONG_WEAPON_MESSAGE") == 1)
		then
			Logger:BasicInfo("Removed bladesong statuses from %s", character.Uuid.EntityUuid)
			Osi.RemoveStatus(character.Uuid.EntityUuid, "BLADESONG_WEAPON_MESSAGE")
			Osi.RemoveStatus(character.Uuid.EntityUuid, "BLADESONG_ARMOR_MESSAGE")
		end

		if character.ServerShapeshiftStates
			and character.ServerShapeshiftStates.States
			and character.ServerShapeshiftStates.States[1]
		then
			for _, status in pairs(character.StatusContainer.Statuses) do
				if Osi.IsStatusFromGroup(status, "SG_Polymorph") == 1 and Osi.IsStatusFromGroup(status, "SG_Disguise") == 0 then
					Logger:BasicWarning("Skipping transmog on %s as they're currently affected by a SG_Polymorph (but not SG_Disguise) status", character.Uuid.EntityUuid)
					return
				end
			end
		end
	end

	---@type VanityOutfit
	local outfit = characterPreset.Outfits[character.Vars.TheArmory_Vanity_ActiveOutfit]
	if not outfit then
		Logger:BasicDebug("No active outfit found for %s, skipping transmog", character.Uuid.EntityUuid)
		Transmogger:ClearOutfit(character.Uuid.EntityUuid)
		return
	end

	Logger:BasicDebug("Found active outfit for %s, beginning Mog process", character.Uuid.EntityUuid)

	for actualSlot, outfitSlot in pairs(outfit) do
		local equippedItem = Osi.GetEquippedItem(character.Uuid.EntityUuid, actualSlot)

		---@type string
		local vanityTemplate = outfitSlot.equipment and outfitSlot.equipment.guid or nil
		if vanityTemplate == "Hide Appearance" then
			vanityTemplate = self.defaultPieces["HideTransmog"]
		end

		if equippedItem and outfitSlot.weaponTypes then
			---@type Weapon
			local itemStat = Ext.Stats.Get(Ext.Entity.Get(equippedItem).Data.StatsId)
			for _, proficiencyGroup in pairs(itemStat["Proficiency Group"]) do
				if outfitSlot.weaponTypes[proficiencyGroup] and outfitSlot.weaponTypes[proficiencyGroup].equipment then
					outfitSlot = outfitSlot.weaponTypes[proficiencyGroup]
					vanityTemplate = outfitSlot.equipment.guid
					break
				end
			end
		end

		if not vanityTemplate then
			if equippedItem then
				local newItem = Transmogger:UnMogItem(equippedItem)
				if newItem then
					self:ApplyEffectStatus(outfitSlot, actualSlot, Ext.Entity.Get(newItem), character)
				end
			end
			goto continue
		end

		if not equippedItem then
			if self.defaultPieces[actualSlot] and (vanity.settings and vanity.settings.general.fillEmptySlots) then
				equippedItem = Osi.CreateAt(self.defaultPieces[actualSlot], 0, 0, 0, 0, 0, "")
			else
				goto continue
			end
		else
			if string.sub(Osi.GetTemplate(equippedItem), -36) == vanityTemplate then
				Logger:BasicDebug("Equipped item %s is already the vanity item %s", equippedItem, vanityTemplate)
				self:ApplyEffectStatus(outfitSlot, actualSlot, Ext.Entity.Get(equippedItem), character)
				goto continue
			end

			---@type EntityHandle
			local entity = Ext.Entity.Get(equippedItem)
			if not Ext.Template.GetRootTemplate(entity.ServerItem.Template.Id) then
				Logger:BasicWarning(
					"Item %s points to RootTemplate %s which does not exist - this indicates that this is likely a LocalItem, and therefore incompatible with Transmog due to being completely unique to the game world."
					.. " If this is not intended, please contact the modAuthor. Item info: \n%s",
					entity.ServerItem.Template.Name .. "_" .. equippedItem,
					entity.ServerItem.Template.Name .. "_" .. entity.ServerItem.Template.Id,
					buildMetaInfoForLog(entity)
				)
				goto continue
			end

			local unmoggedId = Transmogger:UnMogItem(equippedItem, true)
			equippedItem = unmoggedId or equippedItem
			if Osi.IsEquipped(equippedItem) == 1 then
				Ext.Entity.Get(equippedItem).Vars.TheArmory_Vanity_Item_CurrentlyMogging = true
				Osi.Unequip(character.Uuid.EntityUuid, equippedItem)
			end
		end

		self:TransmogItem(vanityTemplate, equippedItem, character, outfit, actualSlot)

		::continue::
	end

	for _, actualSlot in ipairs(SlotEnum) do
		if not outfit[actualSlot] then
			local equippedItem = Osi.GetEquippedItem(character.Uuid.EntityUuid, actualSlot)
			if equippedItem then
				Transmogger:UnMogItem(equippedItem)
				Transmogger:ApplyEffectStatus({}, actualSlot, Ext.Entity.Get(equippedItem), character)
			end
		end
	end

	Transmogger:ApplyDye(character)
end

---comment
---@param vanityTemplate string
---@param equippedItem string
---@param character EntityHandle
---@param outfitSlot VanityOutfitSlot?
---@param actualSlot ActualSlot?
function Transmogger:TransmogItem(vanityTemplate, equippedItem, character, outfitSlot, actualSlot)
	---@type ItemTemplate
	local vanityPiece = Ext.Template.GetTemplate(vanityTemplate)

	if not vanityPiece then
		Logger:BasicWarning("Item %s does not exist - mod is likely not loaded. See Validation Errors in the Preset Manager!", vanityTemplate)
		return
	end

	local vanityGuid = Osi.CreateAt(vanityPiece.Id, 0, 0, 0, 0, 0, "")

	-- Need to give the game enough time to set up the properties on the entity, otherwise things like ServerItem statuses don't show up
	-- Tried doing by tick and 10ms, but both were too fast
	Ext.Timer.WaitFor(50, function(e)
		---@type EntityHandle
		local createdVanityEntity = Ext.Entity.Get(vanityGuid)

		---@type EntityHandle
		local equippedItemEntity = Ext.Entity.Get(equippedItem)

		if equippedItemEntity.ServerItem.Template.Stats ~= equippedItemEntity.Data.StatsId then
			Logger:BasicWarning(
				"Item's stat string (%s) differs from its template's stat string (%s) - most likely this is a modded item, and the mod author did not ensure the item template points at the stat, and the stat points back to the same template."
				..
				" Work around will be executed, but you'll need to save and reload to finalize the process. Please reach out to the author and ask them to fix for best experience. Item info:\n%s",
				equippedItemEntity.Data.StatsId,
				equippedItemEntity.ServerItem.Template.Stats,
				buildMetaInfoForLog(equippedItemEntity))
		end

		createdVanityEntity.Vars.TheArmory_Vanity_OriginalItemInfo = {
			["template"] = equippedItemEntity.ServerItem.Template.Id,
			["stat"] = equippedItemEntity.Data.StatsId,
			["owner"] = character.Uuid.EntityUuid
		}

		local varComponentsToReplicateOnRefresh = {}

		Logger:BasicDebug("Mogging %s to look like %s for %s", equippedItemEntity.DisplayName.Name:Get(), vanityPiece.Name, character.DisplayName.Name:Get())

		Logger:BasicTrace("========== STARTING MOG FOR %s to %s ==========", equippedItemEntity.Uuid.EntityUuid, createdVanityEntity.Uuid.EntityUuid)
		local startTime = Ext.Utils.MonotonicTime()

		local createdErrorDumps
		for key, componentToCopy in pairs(componentsToCopy) do
			local success, error = pcall(function()
				if type(componentToCopy) == "string" then
					if equippedItemEntity[componentToCopy] then
						Logger:BasicTrace("Cloning component %s", componentToCopy)
						if componentToCopy == "BoostsContainer" then
							for _, statusToRemove in pairs(createdVanityEntity.ServerItem.StatusManager.Statuses) do
								Logger:BasicTrace("Removing status %s", statusToRemove.StatusId)
								Osi.RemoveStatus(createdVanityEntity.Uuid.EntityUuid, statusToRemove.StatusId)
							end
							for _, statusToAdd in pairs(equippedItemEntity.ServerItem.StatusManager.Statuses) do
								Logger:BasicTrace("Adding status %s", statusToAdd.StatusId)
								Osi.ApplyStatus(createdVanityEntity.Uuid.EntityUuid, statusToAdd.StatusId, Osi.GetStatusCurrentLifetime(equippedItem, statusToAdd.StatusId), 1)
							end
						else
							if equippedItemEntity[componentToCopy] then
								if not createdVanityEntity[componentToCopy] then
									Logger:BasicTrace("Creating %s on vanity item", componentToCopy)
									createdVanityEntity:CreateComponent(componentToCopy)
								end

								Ext.Types.Unserialize(createdVanityEntity[componentToCopy], Ext.Types.Serialize(equippedItemEntity[componentToCopy]))

								if componentToCopy == "Value" then
									-- TE had reports of crashing when multiple unique items exist in the world (not equipped or in the player inventory)
									createdVanityEntity.Value.Unique = false
								end

								if componentsToReplicateOnRefresh[componentToCopy] then
									varComponentsToReplicateOnRefresh[componentToCopy] = Ext.Types.Serialize(equippedItemEntity[componentToCopy])
								end

								if not string.find(componentToCopy, "Server") then
									Logger:BasicTrace("Replicating %s", componentToCopy)
									createdVanityEntity:Replicate(componentToCopy)
								end
							end
						end
					end
				else
					if not createdVanityEntity[key] then
						Logger:BasicTrace("Creating %s on vanity item", key)
						createdVanityEntity:CreateComponent(key)
					end

					for _, subComponentToCopy in pairs(componentToCopy) do
						Logger:BasicTrace("Cloning component %s under %s", subComponentToCopy, key)
						if type(equippedItemEntity[key][subComponentToCopy]) == "string" then
							createdVanityEntity[key][subComponentToCopy] = equippedItemEntity[key][subComponentToCopy]
						else
							Ext.Types.Unserialize(createdVanityEntity[key][subComponentToCopy], Ext.Types.Serialize(equippedItemEntity[key][subComponentToCopy]))
						end
					end
					if not string.find(key, "Server") then
						Logger:BasicTrace("Replicating %s", key)
						createdVanityEntity:Replicate(key)
					end
				end
			end)

			if not success then
				Logger:BasicError(
					"Encountered error while mogging %s to look like %s for %s. Entity Dumps created at dumps/. \n\tComponent Info: %s\n\tError: %s\n\tBase Item Info: %s\n\tVanity Item Info: %s",
					equippedItemEntity.DisplayName.Name:Get(),
					vanityPiece.Name,
					character.DisplayName.Name:Get(),
					Ext.Json.Stringify({
						name = type(componentToCopy) == "string" and componentToCopy or key,
						subComponents = (type(componentToCopy) == "table") and Ext.Json.Stringify(componentToCopy) or nil
					}),
					error,
					buildMetaInfoForLog(equippedItemEntity),
					buildMetaInfoForLog(createdVanityEntity))

				if not createdErrorDumps then
					createdErrorDumps = true

					FileUtils:SaveStringContentToFile(FileUtils:BuildRelativeJsonFileTargetPath(equippedItem, "dumps"),
						Ext.Json.Stringify(equippedItemEntity:GetAllComponents(), {
							IterateUserdata = true,
							StringifyInternalTypes = true,
							AvoidRecursion = true
						}))

					FileUtils:SaveStringContentToFile(FileUtils:BuildRelativeJsonFileTargetPath(createdVanityEntity.Uuid.EntityUuid, "dumps"),
						Ext.Json.Stringify(equippedItemEntity:GetAllComponents(), {
							IterateUserdata = true,
							StringifyInternalTypes = true,
							AvoidRecursion = true
						}))
				end
			end
		end

		createdVanityEntity.Vars.TheArmory_Vanity_Item_CurrentlyMogging = true
		if actualSlot then
			createdVanityEntity.Vars.TheArmory_Vanity_Item_ReplicationComponents = varComponentsToReplicateOnRefresh
		else
			createdVanityEntity.Vars.TheArmory_Vanity_PreviewItem = character.Uuid.EntityUuid
		end

		local function finishMog(waitCounter)
			waitCounter = waitCounter or 0
			if (Osi.IsWeapon(createdVanityEntity.Uuid.EntityUuid) == 1 and (actualSlot and Osi.GetEquippedItem(character.Uuid.EntityUuid, actualSlot))) and waitCounter <= 10 then
				Logger:BasicDebug("%s has a weapon equipped currently, giving game time to catch up", character.Uuid.EntityUuid)
				Ext.Timer.WaitFor(50, function()
					finishMog(waitCounter + 1)
				end)
			else
				Osi.Equip(character.Uuid.EntityUuid, createdVanityEntity.Uuid.EntityUuid, 1, 0, 1)
				if actualSlot then
					self:ApplyEffectStatus(outfitSlot[actualSlot], actualSlot, createdVanityEntity, character)
				end

				Logger:BasicTrace("========== FINISHED MOG FOR %s to %s in %dms ==========", equippedItemEntity.Uuid.EntityUuid, createdVanityEntity.Uuid.EntityUuid,
					Ext.Utils.MonotonicTime() - startTime)

				if outfitSlot then
					ModEventsManager:TransmogCompleted({
						character = character.Uuid.EntityUuid,
						cosmeticItemId = createdVanityEntity.Uuid.EntityUuid,
						cosmeticTemplateItemId = vanityTemplate,
						equippedItemTemplateId = equippedItemEntity.ServerItem.Template.Id,
						equippedItemId = equippedItem,
						slot = actualSlot
					})
				end

				Osi.RequestDelete(equippedItem)
			end
		end

		finishMog()
	end)
end

---@param outfitSlot VanityOutfitSlot
---@param actualSlot ActualSlot
---@param createdVanityEntity EntityHandle
---@param characterEntity EntityHandle
function Transmogger:ApplyEffectStatus(outfitSlot, actualSlot, createdVanityEntity, characterEntity)
	local _, charUserId = ServerPresetManager:GetCharacterPreset(characterEntity.Uuid.EntityUuid)

	local vanity = ServerPresetManager.ActiveVanityPresets[charUserId]

	if vanity then
		local effects = vanity.effects
		if outfitSlot.equipment and outfitSlot.equipment.effects then
			for _, effectName in ipairs(outfitSlot.equipment.effects) do
				local effectProps = effects[effectName]
				if effectProps then
					if Osi.HasActiveStatus(createdVanityEntity.Uuid.EntityUuid, effectName) == 0 then
						Logger:BasicDebug("Applying effect %s to %s - effect properties: %s",
							effectName,
							createdVanityEntity.DisplayName.Name:Get() or createdVanityEntity.ServerItem.Template.Name,
							Ext.Json.Stringify(effectProps))

						local effect = VanityEffect:new({}, effectName, effectProps.effectProps)
						effect:createStat()
						Ext.Timer.WaitFor(50, function()
							Osi.ApplyStatus(createdVanityEntity.Uuid.EntityUuid, effectName, -1, 1)
							createdVanityEntity.Vars.TheArmory_Vanity_EffectsMarker = true
						end)
					end
				else
					Logger:BasicWarning("Definition for effect %s assigned to slot %s in outfit assigned to %s was not found in the configs", effectName, actualSlot,
						characterEntity.DisplayName.Name:Get())
				end
			end
		end
		local removeEffectMarker = true

		if createdVanityEntity.StatusContainer then
			for _, statusName in pairs(createdVanityEntity.StatusContainer.Statuses) do
				if statusName:find("ARMORY_VANITY_EFFECT") then
					if effects[statusName] and TableUtils:ListContains((outfitSlot.equipment and outfitSlot.equipment.effects) or {}, statusName) then
						removeEffectMarker = false
					else
						Osi.RemoveStatus(createdVanityEntity.Uuid.EntityUuid, statusName)
					end
				end
			end
		end

		if removeEffectMarker then
			createdVanityEntity.Vars.TheArmory_Vanity_EffectsMarker = nil
		end
	else
		if createdVanityEntity.StatusContainer then
			for _, statusName in pairs(createdVanityEntity.StatusContainer.Statuses) do
				if statusName:find("ARMORY_VANITY_EFFECT") then
					Osi.RemoveStatus(createdVanityEntity.Uuid.EntityUuid, statusName)
				end
			end
		end
		createdVanityEntity.Vars.TheArmory_Vanity_EffectsMarker = nil
	end
end

---@param character EntityHandle
function Transmogger:ApplyDye(character)
	local characterPreset = ServerPresetManager:GetCharacterPreset(character.Uuid.EntityUuid)

	if not characterPreset then
		return
	end
	Logger:BasicDebug("Beginning Dye process for %s", character.Uuid.EntityUuid)

	---@type VanityOutfit
	local outfit = characterPreset.Outfits[character.Vars.TheArmory_Vanity_ActiveOutfit]

	for _, actualSlot in ipairs(SlotEnum) do
		local success, error = pcall(function()
			local equippedItem = Osi.GetEquippedItem(character.Uuid.EntityUuid, actualSlot)

			if not equippedItem then
				goto continue
			end
			--- @type EntityHandle
			local equippedItemEntity = Ext.Entity.Get(equippedItem)

			if outfit and outfit[actualSlot] then
				local outfitSlot = outfit[actualSlot]
				---@type string
				local dyeTemplate = outfitSlot.dye and outfitSlot.dye.guid

				if equippedItem and outfitSlot.weaponTypes then
					---@type Weapon
					local itemStat = Ext.Stats.Get(Ext.Entity.Get(equippedItem).Data.StatsId)
					for _, proficiencyGroup in pairs(itemStat["Proficiency Group"]) do
						if outfitSlot.weaponTypes[proficiencyGroup] then
							if outfitSlot.weaponTypes[proficiencyGroup].dye then
								dyeTemplate = outfitSlot.weaponTypes[proficiencyGroup].dye.guid
							end
							break
						end
					end
				end

				if not dyeTemplate then
					if equippedItemEntity.Vars.TheArmory_Vanity_OriginalDyeInfo then
						Logger:BasicDebug("%s in slot %s for %s doesn't have a corresponding outfit slot, so resetting the dye to %s", equippedItem, actualSlot,
							character.DisplayName.Name:Get(), equippedItemEntity.Vars.TheArmory_Vanity_OriginalDyeInfo)
						if equippedItemEntity.Vars.TheArmory_Vanity_OriginalDyeInfo == "00000000-0000-0000-0000-000000000000" then
							if equippedItemEntity.ItemDye then
								equippedItemEntity:RemoveComponent("ItemDye")
							end
						else
							if not equippedItemEntity.ItemDye then
								equippedItemEntity:CreateComponent("ItemDye")
							end
							equippedItemEntity.ItemDye.Color = equippedItemEntity.Vars.TheArmory_Vanity_OriginalDyeInfo
						end
						equippedItemEntity:Replicate("ItemDye")
						equippedItemEntity.Vars.TheArmory_Vanity_OriginalDyeInfo = nil
					end
					goto continue
				end

				Logger:BasicDebug("Applying dye %s to %s", dyeTemplate, equippedItem)

				if not equippedItemEntity.ItemDye then
					equippedItemEntity:CreateComponent("ItemDye")
					equippedItemEntity.Vars.TheArmory_Vanity_OriginalDyeInfo = "00000000-0000-0000-0000-000000000000"
				elseif not equippedItemEntity.Vars.TheArmory_Vanity_OriginalDyeInfo then
					equippedItemEntity.Vars.TheArmory_Vanity_OriginalDyeInfo = equippedItemEntity.ItemDye.Color
				end

				---@type ItemTemplate
				local itemDyeTemplate = Ext.Template.GetTemplate(dyeTemplate)

				if not itemDyeTemplate then
					Logger:BasicWarning("Dye %s does not exist - mod is likely not loaded. See Validation Errors in the Preset Manager!", dyeTemplate)
					goto continue
				end

				---@type ResourceMaterialPresetResource
				local materialPreset = Ext.Resource.Get(itemDyeTemplate.ColorPreset, "MaterialPreset")

				equippedItemEntity.ItemDye.Color = materialPreset.Guid
				equippedItemEntity:Replicate("ItemDye")
			elseif equippedItemEntity.Vars.TheArmory_Vanity_OriginalDyeInfo then
				Logger:BasicDebug("%s in slot %s for %s doesn't have a corresponding outfit slot, so resetting the dye to %s", equippedItem, actualSlot,
					character.DisplayName.Name:Get(), equippedItemEntity.Vars.TheArmory_Vanity_OriginalDyeInfo)

				if equippedItemEntity.Vars.TheArmory_Vanity_OriginalDyeInfo == "00000000-0000-0000-0000-000000000000" then
					if equippedItemEntity.ItemDye then
						equippedItemEntity:RemoveComponent("ItemDye")
					end
				else
					if not equippedItemEntity.ItemDye then
						equippedItemEntity:CreateComponent("ItemDye")
					end
					equippedItemEntity.ItemDye.Color = equippedItemEntity.Vars.TheArmory_Vanity_OriginalDyeInfo
				end
				equippedItemEntity:Replicate("ItemDye")
				equippedItemEntity.Vars.TheArmory_Vanity_OriginalDyeInfo = nil
			end
			::continue::
		end)

		if not success then
			Logger:BasicError("Error while applying dye to item in slot %s: \n%s", actualSlot, error)
		end
	end
end

Ext.Events.SessionLoaded:Subscribe(function(e)
	for _, entityId in pairs(Ext.Vars.GetEntitiesWithVariable("TheArmory_Vanity_Item_ReplicationComponents")) do
		---@type EntityHandle
		local entity = Ext.Entity.Get(entityId)

		if entity then
			Logger:BasicDebug("Updating components in need of refreshing on mogged item %s (%s)", entityId, entity.DisplayName.Name:Get())
			for component, serializedData in pairs(entity.Vars.TheArmory_Vanity_Item_ReplicationComponents) do
				Logger:BasicTrace("Refreshing component %s with %s",
					component,
					Ext.Json.Stringify(serializedData, {
						IterateUserdata = true,
						StringifyInternalTypes = true,
						AvoidRecursion = true
					}))

				Ext.Types.Unserialize(entity[component], serializedData)

				if not string.find(component, "Server") then
					Logger:BasicTrace("Replicating %s", component)
					entity:Replicate(component)
				end
			end
		end
	end
end, { Once = true })

function Transmogger:ClearOutfit(character)
	---@type EntityHandle
	local charEntity = Ext.Entity.Get(character)

	for _, actualSlot in ipairs(SlotEnum) do
		local equippedItem = Osi.GetEquippedItem(character, actualSlot)
		if equippedItem then
			local newItem = Transmogger:UnMogItem(equippedItem)
			if newItem then
				Transmogger:ApplyEffectStatus({}, actualSlot, Ext.Entity.Get(newItem), charEntity)
			end
		end
	end
	Transmogger:ApplyDye(charEntity)
end

---@param item any
---@return string?
function Transmogger:UnMogItem(item, currentlyMogging)
	if Osi.Exists(item) == 1 then
		---@type EntityHandle
		local itemEntity = Ext.Entity.Get(item)

		if not itemEntity.Vars.TheArmory_Vanity_Item_CurrentlyMogging then
			if itemEntity.Vars.TheArmory_Vanity_OriginalItemInfo then
				local inventoryOwner = Osi.GetInventoryOwner(item)
				if inventoryOwner then
					-- Backwards Compatibility with <= 0.4.0. TODO: Remove in 1.0.0
					local isTable = type(itemEntity.Vars.TheArmory_Vanity_OriginalItemInfo) == "table"
					local originalItemTemplate = isTable and itemEntity.Vars.TheArmory_Vanity_OriginalItemInfo.template or itemEntity.Vars.TheArmory_Vanity_OriginalItemInfo
					local originalItemStat = isTable and itemEntity.Vars.TheArmory_Vanity_OriginalItemInfo.stat or nil

					Logger:BasicDebug("%s was unequipped, so restoring to %s and giving to %s", item, originalItemTemplate, inventoryOwner)
					local vanityIsEquipped = Osi.IsEquipped(item)

					local newItem = Osi.CreateAt(originalItemTemplate, 0, 0, 0, 0, 0, "")
					if not newItem then
						local modInfo
						if originalItemStat then
							---@type Weapon|Armor|Object?
							local stat = Ext.Stats.Get(originalItemStat)
							modInfo = stat.OriginalModId and Ext.Mod.GetMod(stat.OriginalModId).Info or nil
						end

						---@type ItemTemplate
						local templateInfo = Ext.Template.GetRootTemplate(originalItemTemplate)
						local itemInfo = Ext.Json.Stringify({
							templateUuid = templateInfo.Name .. "_" .. originalItemTemplate,
							displayName = templateInfo.DisplayName:Get() or templateInfo.Name,
							statName = originalItemStat,
							modName = modInfo and modInfo.Name,
							modAuthor = modInfo and modInfo.Author,
							modVersion = modInfo and table.concat(modInfo.ModVersion, ".")
						})

						Logger:BasicError(
							"Unable to create a new instance of the template %s - can't correctly undo the transmog on this item, so doing a partial transmog on a different template. Item info: \n%s",
							originalItemTemplate,
							itemInfo)

						newItem = Osi.CreateAt(itemEntity.ServerItem.Template.Id, 0, 0, 0, 0, 0, "")
					end

					if vanityIsEquipped == 1 then
						itemEntity.Vars.TheArmory_Vanity_Item_CurrentlyMogging = true
						Osi.Unequip(inventoryOwner, item)
					end
					Ext.Timer.WaitFor(200, function()
						Osi.RequestDelete(item)
					end)

					---@type EntityHandle
					local newItemEntity = Ext.Entity.Get(newItem)
					if originalItemStat then
						if newItemEntity.Data.StatsId ~= originalItemStat then
							newItemEntity.Data.StatsId = originalItemStat
							newItemEntity:Replicate("Data")

							newItemEntity.ServerItem.Stats = originalItemStat
						end
					end
					if not currentlyMogging then
						Ext.Timer.WaitFor(20, function()
							if vanityIsEquipped == 1 then
								Osi.Equip(inventoryOwner, newItem)
							else
								Osi.ToInventory(newItem, inventoryOwner, 1, 0, 1)
							end

							ModEventsManager:TransmogRemoved({
								character = inventoryOwner,
								cosmeticItemId = item,
								cosmeticTemplateItemId = itemEntity.ServerItem.Template.Id,
								equippedItemId = newItem,
								equippedItemTemplateId = originalItemTemplate,
								slot = vanityIsEquipped == 1 and Ext.Stats.Get(newItemEntity.Data.StatsId).Slot or nil
							})
						end)
					end

					return newItem
				end
			else
				return item
			end
		end
	end
end

Ext.Osiris.RegisterListener("Unequipped", 2, "after", function(item, character)
	Logger:BasicDebug("%s unequipped %s", character, item)
	Ext.Timer.WaitFor(20, function()
		local newItem = Transmogger:UnMogItem(item)
		if newItem and not Ext.Entity.Get(newItem).Vars.TheArmory_Vanity_Item_CurrentlyMogging then
			Ext.Timer.WaitFor(20, function()
				Transmogger:MogCharacter(Ext.Entity.Get(character))
			end)
		end
	end)
end)

local transmoggingLock

Ext.Osiris.RegisterListener("Equipped", 2, "after", function(item, character)
	Logger:BasicDebug("%s equipped %s", character, item)
	---@type EntityHandle
	local itemEntity = Ext.Entity.Get(item)
	if itemEntity.Vars.TheArmory_Vanity_Item_CurrentlyMogging then
		itemEntity.Vars.TheArmory_Vanity_Item_CurrentlyMogging = nil
		Transmogger:ApplyDye(Ext.Entity.Get(character))
	else
		-- When swapping weapons between slots multiple equip/unequip events fire in rapid succession, and since we mog the whole character at once
		-- need to make sure we don't rapid fire a bunch of transmogs while timers are still processing
		if transmoggingLock then
			Ext.Timer.Cancel(transmoggingLock)
		end

		-- Otherwise damage dice starts duplicating for some reason. 50ms wasn't cutting it
		transmoggingLock = Ext.Timer.WaitFor(200, function()
			transmoggingLock = nil

			-- Weird bug when swapping dual wielded items between slots, Ext.Entity can't fully inspect somehow?
			-- Causes a CTD anyway, but in case this ever happens again in any other situation
			if not itemEntity.Uuid then
				Logger:BasicDebug("Item %s is missing it's UUID - this indicates something weird, believe it or not, so delaying transmog to give game some breathing room",
					item)

				transmoggingLock = Ext.Timer.WaitFor(300, function()
					Logger:BasicDebug("Item %s was equipped on %s, executing transmog",
						item,
						character)

					Transmogger:MogCharacter(Ext.Entity.Get(character))
				end)
			else
				Logger:BasicDebug("Item %s was equipped on %s, executing transmog",
					item,
					character)

				Transmogger:MogCharacter(Ext.Entity.Get(character))
			end
		end)
	end
end)

Ext.Vars.RegisterUserVariable("TheArmory_PlayerOutfit", {
	Server = true
})

Ext.Vars.RegisterUserVariable("TheArmory_OriginalItemInfo", {
	Server = true
})

local defaultPieces = {
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
	MusicalInstrument = "848ad8dc-59f3-464b-b8b2-95eab6022446"
}

-- Things that will cause me psychic damage: https://discord.com/channels/1174823496086470716/1193836567194771506/1327500800766771271

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

Transmogger = {}

---@param entity EntityHandle
---@return string
local function buildMetaInfoForLog(entity)
	---@type Weapon|Armor|Object
	local stat = Ext.Stats.Get(Osi.GetStatString(entity.Uuid.EntityUuid))

	return Ext.Json.Stringify({
		uuid = entity.Uuid.EntityUuid,
		templateUuid = entity.ServerItem.Template.Id,
		displayName = entity.DisplayName.Name:Get(),
		statName = stat.Name,
		modId = stat.ModId,
		modName = stat.ModId and Ext.Mod.GetMod(stat.ModId).Info.Name
	})
end

---@param character EntityHandle
---@param outfit VanityOutfit
function Transmogger:MogCharacter(character, outfit)
	character.Vars.TheArmory_PlayerOutfit = outfit

	for actualSlot, outfitSlot in pairs(outfit) do
		if outfitSlot.equipment and outfitSlot.equipment.guid then
			local equippedItem = Osi.GetEquippedItem(character.Uuid.EntityUuid, actualSlot)

			if not equippedItem then
				if defaultPieces[actualSlot] then
					equippedItem = Osi.CreateAt(defaultPieces[actualSlot], 0, 0, 0, 0, 0, "")
				else
					goto continue
				end
			else
				Osi.Unequip(character.Uuid.EntityUuid, equippedItem)
			end

			---@type ItemTemplate
			local vanityPiece = Ext.Template.GetTemplate(outfitSlot.equipment.guid)

			---@type EntityHandle
			local createdVanityEntity = Ext.Entity.Get(Osi.CreateAt(vanityPiece.Id, 0, 0, 0, 0, 0, ""))
			createdVanityEntity.Vars.TheArmory_OriginalItemInfo = equippedItem

			---@type EntityHandle
			local equippedItemEntity = Ext.Entity.Get(equippedItem)

			Logger:BasicDebug("Mogging %s to look like %s for %s", equippedItemEntity.DisplayName.Name:Get(), vanityPiece.Name, character.DisplayName.Name:Get())

			Logger:BasicTrace("========== STARTING MOG FOR %s to %s ==========", equippedItemEntity.Uuid.EntityUuid, createdVanityEntity.Uuid.EntityUuid)

			local createdErrorDumps
			for key, componentToCopy in pairs(componentsToCopy) do
				local componentBeingCopied
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
								end
							else
								if not createdVanityEntity[componentToCopy] then
									Logger:BasicTrace("Creating %s on vanity item", componentToCopy)
									createdVanityEntity:CreateComponent(componentToCopy)
								end

								if componentToCopy == "ProficiencyGroup" then
									createdVanityEntity.ProficiencyGroup.Flags = equippedItemEntity.ProficiencyGroup.Flags
								else
									componentBeingCopied = equippedItemEntity[componentToCopy]

									Ext.Types.Unserialize(createdVanityEntity[componentToCopy], Ext.Types.Serialize(equippedItemEntity[componentToCopy]))
								end

								if not string.find(componentToCopy, "Server") then
									Logger:BasicTrace("Replicating %s", componentToCopy)
									createdVanityEntity:Replicate(componentToCopy)
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
							componentBeingCopied = equippedItemEntity[key][subComponentToCopy]
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

					componentBeingCopied = nil
				end)

				if not success then
					local componentInfo = componentBeingCopied and Ext.Types.TypeOf(componentBeingCopied)
					Logger:BasicError(
						"Encountered error while mogging %s to look like %s for %s. Entity Dumps created at dumps/. \n\tComponent Info: %s\n\tError: %s\n\tBase Item Info: %s\n\tVanity Item Info: %s",
						equippedItemEntity.DisplayName.Name:Get(),
						vanityPiece.Name,
						character.DisplayName.Name:Get(),
						Ext.Json.Stringify({
							name = type(componentToCopy) == "string" and componentToCopy or key,
							subComponents = type(componentToCopy) == "table" and Ext.Json.Stringify(componentToCopy) or nil,
							typeOfComponent = componentInfo and Ext.Types.Serialize(componentInfo) or "Component was nil?"
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

			Ext.Timer.WaitFor(50, function()
				local charUUID = character.Uuid.EntityUuid
				local vanityUuid = createdVanityEntity.Uuid.EntityUuid
				Osi.SetOriginalOwner(vanityUuid, charUUID)
				Osi.SetOwner(vanityUuid, charUUID)
				Osi.Equip(charUUID, vanityUuid, 1, 0, 1)
			end)

			Logger:BasicTrace("========== FINISHED MOG FOR %s to %s ==========", equippedItemEntity.Uuid.EntityUuid, createdVanityEntity.Uuid.EntityUuid)
		end
		::continue::
	end
end

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

Transmogger = {}

---@param character EntityHandle
---@param outfit VanityOutfit
function Transmogger:MogCharacter(character, outfit)
	character.Vars.TheArmory_PlayerOutfit = outfit

	for actualSlot, outfitSlot in pairs(outfit) do
		if outfitSlot.equipment and outfitSlot.equipment.guid then
			---@type ItemTemplate
			local vanityPiece = Ext.Template.GetTemplate(outfitSlot.equipment.guid)

			
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
			
			local createdVanity = Osi.CreateAt(vanityPiece.Id, 0, 0, 0, 1, 0, "")
			Osi.RequestCanCombine(character.Uuid.EntityUuid, "e64e7287-d830-44a9-bbf9-0903a1cb48ec", equippedItem, createdVanity, "", "", 0)
			
			---@type EntityHandle
			local equippedItemEntity = Ext.Entity.Get(equippedItem)
			
			Logger:BasicDebug("Mogging %s to look like %s", equippedItemEntity.DisplayName.Name:Get(), vanityPiece.Name)
			
		end
		::continue::
	end
end

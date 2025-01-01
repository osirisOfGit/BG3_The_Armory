---@class DyePayload
---@field materialPreset Guid
---@field colors ResourcePresetDataVector3Parameter[]
---@field slot ActualSlot


Ext.RegisterNetListener(ModuleUUID .. "_PreviewDye", function(channel, payload, user)
	user = PeerToUserID(user)
	local character = Osi.GetCurrentCharacter(user)

	---@type DyePayload
	local dyePayload = Ext.Json.Parse(payload)

	local equippedItem = Osi.GetEquippedItem(character, dyePayload.slot)

	if equippedItem then
		---@type EntityHandle
		local itemEntity = Ext.Entity.Get(equippedItem)
		if not itemEntity.ItemDye then
			itemEntity:CreateComponent("ItemDye")
		end

		itemEntity.ItemDye.Color = dyePayload.materialPreset
		itemEntity:Replicate("ItemDye")
	end
end)

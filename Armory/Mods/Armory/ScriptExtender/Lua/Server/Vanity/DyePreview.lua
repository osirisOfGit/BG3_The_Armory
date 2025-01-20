---@class DyePayload
---@field materialPreset Guid
---@field slot ActualSlot

local userTracker = {}

-- TODO: Handle user swapping characters while previewing

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
			userTracker[user] = "00000000-0000-0000-0000-000000000000"
		elseif not userTracker[user] then
			userTracker[user] = itemEntity.ItemDye.Color
		end

		Logger:BasicDebug("DyePreview: Updating %s on %s to use materialPreset %s", equippedItem, character, dyePayload.materialPreset)

		itemEntity.ItemDye.Color = dyePayload.materialPreset
		itemEntity:Replicate("ItemDye")
	end
end)

Ext.RegisterNetListener(ModuleUUID .. "_StopPreviewingDye", function(channel, slot, user)
	user = PeerToUserID(user)
	local character = Osi.GetCurrentCharacter(user)

	local equippedItem = Osi.GetEquippedItem(character, slot)

	if equippedItem and userTracker[user] then
		---@type EntityHandle
		local itemEntity = Ext.Entity.Get(equippedItem)
		if not itemEntity.ItemDye or userTracker[user] then
			return
		end

		Logger:BasicDebug("DyePreview: Reverting %s on %s to %s", equippedItem, character, userTracker[user])

		itemEntity.ItemDye.Color = userTracker[user]
		itemEntity:Replicate("ItemDye")
		userTracker[user] = nil
	end
end)

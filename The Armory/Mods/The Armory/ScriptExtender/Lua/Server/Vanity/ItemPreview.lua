function PeerToUserID(peerID)
	-- usually just userid+1
	return (peerID & 0xffff0000) | 0x0001
end

---@class UserEntry
---@field previewItem Guid
---@field createdItem Guid
---@field equippedItem GUIDSTRING

---@type {[string] : UserEntry}
local previewingItemTable = {}

Ext.RegisterNetListener(ModuleUUID .. "_PreviewItem", function(channel, templateUUID, user)
	user = PeerToUserID(user)
	local character = Osi.GetCurrentCharacter(user)

	if not previewingItemTable[user] then
		previewingItemTable[user] = {}
	end

	local userPreview = previewingItemTable[user]

	Osi.TemplateAddTo(templateUUID, character, 1, 0)
	userPreview.previewItem = templateUUID
end)

Ext.Osiris.RegisterListener("TemplateAddedTo", 4, "after", function(objectTemplate, object2, inventoryHolder, addType)
	local userId = Osi.GetReservedUserID(inventoryHolder)
	if userId and previewingItemTable[userId] then
		local tracker = previewingItemTable[userId]
		if string.sub(objectTemplate, -36) == tracker.previewItem then
			Logger:BasicDebug("%s started previewing %s", inventoryHolder, object2)
			tracker.createdItem = object2

			tracker.equippedItem = Osi.GetEquippedItem(inventoryHolder, Ext.Stats.Get(Osi.GetStatString(object2)).Slot)

			Osi.Equip(inventoryHolder, object2, 1, 0)
		end
	end
end)

local function DeleteItem(character, userPreview)
	Logger:BasicDebug("%s stopped previewing %s", character, userPreview.createdItem)
	Osi.RequestDelete(userPreview.createdItem)
	if userPreview.equippedItem then
		Osi.Equip(character, userPreview.equippedItem)
		userPreview.equippedItem = nil
	end

	userPreview.createdItem = nil
	userPreview.previewItem = nil
end

Ext.RegisterNetListener(ModuleUUID .. "_StopPreviewingItem", function(channel, payload, user)
	user = PeerToUserID(user)
	local character = Osi.GetCurrentCharacter(user)

	local userPreview = previewingItemTable[user]
	if userPreview and userPreview.previewItem then
		if not userPreview.createdItem then
			Ext.Timer.WaitFor(200, function()
				DeleteItem(character, userPreview)
			end)
		else
			DeleteItem(character, userPreview)
		end
	end
end)

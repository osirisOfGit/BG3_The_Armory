function PeerToUserID(peerID)
	-- usually just userid+1
	return (peerID & 0xffff0000) | 0x0001
end

---@class UserEntry
---@field previewItem Guid
---@field createdItems {[number]: Guid}
---@field queuedItem Guid
---@field equippedItem GUIDSTRING

---@type {[string] : UserEntry}
local previewingItemTable = {}

Ext.RegisterNetListener(ModuleUUID .. "_PreviewItem", function(channel, templateUUID, user)
	user = PeerToUserID(user)
	local character = Osi.GetCurrentCharacter(user)

	if not previewingItemTable[user] then
		previewingItemTable[user] = { createdItems = {} }
	end

	local userPreview = previewingItemTable[user]

	if userPreview.previewItem then
		Logger:BasicDebug("%s added to queue for %s", templateUUID, character)
		userPreview.queuedItem = templateUUID
	else
		Osi.TemplateAddTo(templateUUID, character, 1, 0)
		userPreview.previewItem = templateUUID
	end
end)

Ext.Osiris.RegisterListener("TemplateAddedTo", 4, "after", function(objectTemplate, object2, inventoryHolder, addType)
	local userId = Osi.GetReservedUserID(inventoryHolder)
	if userId and previewingItemTable[userId] then
		local tracker = previewingItemTable[userId]
		if string.sub(objectTemplate, -36) == tracker.previewItem then
			table.insert(tracker.createdItems, object2)

			Logger:BasicDebug("%s started previewing %s", inventoryHolder, object2)

			tracker.equippedItem = Osi.GetEquippedItem(inventoryHolder, Ext.Stats.Get(Osi.GetStatString(object2)).Slot)

			Osi.Equip(inventoryHolder, object2, 1, 0)
			return
		else
			for index, item in pairs(tracker.createdItems) do
				if item == object2 then
					Osi.RequestDelete(item)
					tracker.createdItems[index] = nil
					return
				end
			end
		end
	end
end)

Ext.RegisterNetListener(ModuleUUID .. "_StopPreviewingItem", function(channel, payload, user)
	user = PeerToUserID(user)
	local character = Osi.GetCurrentCharacter(user)

	local userPreview = previewingItemTable[user]
	if userPreview then
		Logger:BasicDebug("%s stopped previewing %s", character, userPreview.previewItem)
		for _, item in pairs(userPreview.createdItems) do
			Osi.RequestDelete(item)
		end
		userPreview.createdItems = {}

		if userPreview.equippedItem then
			Osi.Equip(character, userPreview.equippedItem)
			userPreview.equippedItem = nil
		end

		if userPreview.queuedItem then
			Logger:BasicDebug("Previewing queued item %s for %s", userPreview.queuedItem, character)
			Osi.TemplateAddTo(userPreview.queuedItem, character, 1, 0)
			userPreview.previewItem = userPreview.queuedItem
			userPreview.queuedItem = nil
		else
			userPreview.previewItem = nil
		end
	end
end)

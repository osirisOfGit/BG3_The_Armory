---@class UserEntry
---@field previewItem Guid
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
	userPreview.previewItem = Osi.CreateAt(templateUUID, 0, 0, 0, 0, 0, "")

	Logger:BasicDebug("%s started previewing %s", character, userPreview.previewItem)

	userPreview.equippedItem = Osi.GetEquippedItem(character, Ext.Stats.Get(Osi.GetStatString(userPreview.previewItem)).Slot)

	-- Otherwise the avatar doesn't show it in the inventory view
	Ext.Timer.WaitFor(200, function()
		if userPreview.previewItem then
			Osi.Equip(character, userPreview.previewItem, 1, 0)
		end
	end)
end)

local function DeleteItem(character, userPreview)
	Logger:BasicDebug("%s stopped previewing %s", character, userPreview.previewItem)
	Osi.RequestDelete(userPreview.previewItem)
	if userPreview.equippedItem then
		Osi.Equip(character, userPreview.equippedItem)
		userPreview.equippedItem = nil
	end

	userPreview.previewItem = nil
end

Ext.RegisterNetListener(ModuleUUID .. "_StopPreviewingItem", function(channel, payload, user)
	user = PeerToUserID(user)
	local character = Osi.GetCurrentCharacter(user)

	local userPreview = previewingItemTable[user]
	if userPreview and userPreview.previewItem then
		DeleteItem(character, userPreview)
	end
end)

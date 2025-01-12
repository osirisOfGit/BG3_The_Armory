---@class UserEntry
---@field previewItem Guid
---@field equippedItem GUIDSTRING
---@field armorSet integer

---@type {[string] : UserEntry}
local previewingItemTable = {}

local resetSetTimer

Ext.RegisterNetListener(ModuleUUID .. "_PreviewItem", function(channel, templateUUID, user)
	user = PeerToUserID(user)
	local character = Osi.GetCurrentCharacter(user)

	if not previewingItemTable[user] then
		previewingItemTable[user] = {}
	end

	if resetSetTimer then
		Ext.Timer.Cancel(resetSetTimer)
		resetSetTimer = nil
	end

	local userPreview = previewingItemTable[user]
	if not userPreview.armorSet then
		userPreview.armorSet = Osi.GetArmourSet(character)
	end
	userPreview.previewItem = Osi.CreateAt(templateUUID, 0, 0, 0, 0, 0, "")

	Logger:BasicDebug("%s started previewing %s", character, userPreview.previewItem)

	local slot = Ext.Stats.Get(Osi.GetStatString(userPreview.previewItem)).Slot
	userPreview.equippedItem = Osi.GetEquippedItem(character, slot)

	local correctArmorSet = string.find(slot, "Vanity") and 1 or 0
	if correctArmorSet ~= userPreview.armorSet then
		Osi.SetArmourSet(character, correctArmorSet)
	end

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
		if resetSetTimer then
			Ext.Timer.Cancel(resetSetTimer)
			resetSetTimer = nil
		end

		resetSetTimer = Ext.Timer.WaitFor(1000, function()
			Osi.SetArmourSet(character, userPreview.armorSet)
			userPreview.armorSet = nil
		end)
		DeleteItem(character, userPreview)
	end
end)

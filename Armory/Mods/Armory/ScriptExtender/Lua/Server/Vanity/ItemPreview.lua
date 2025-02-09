---@class UserEntry
---@field previewItem Guid
---@field equippedItem GUIDSTRING
---@field armorSet integer

---@type {[string] : UserEntry}
local previewingItemTable = {}

local resetSetTimer

Ext.RegisterNetListener(ModuleUUID .. "_PreviewItem", function(channel, payload, user)
	payload = Ext.Json.Parse(payload)
	local templateUUID = payload.templateId

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

	if not userPreview.previewItem then
		Logger:BasicWarning("Attempted to create an instance of template %s for preview, but it wasn't made?", templateUUID)
		return
	end

	local stat = Osi.GetStatString(userPreview.previewItem)
	if not stat then
		return
	end

	Logger:BasicDebug("%s started previewing %s", character, templateUUID)

	local slot = Ext.Stats.Get(stat).Slot
	userPreview.equippedItem = Osi.GetEquippedItem(character, slot)
	if userPreview.equippedItem then
		Ext.Entity.Get(userPreview.equippedItem).Vars.TheArmory_Vanity_Item_CurrentlyMogging = true
	end

	local correctArmorSet = string.find(slot, "Vanity") and 1 or 0
	Osi.SetArmourSet(character, correctArmorSet)

	-- Otherwise the avatar doesn't show it in the inventory view
	Ext.Timer.WaitFor(200, function()
		if userPreview.previewItem then
			Ext.Entity.Get(userPreview.previewItem).Vars.TheArmory_Vanity_Item_CurrentlyMogging = true
			Osi.Equip(character, userPreview.previewItem, 1, 0)

			if payload.dye then
				---@type EntityHandle
				local itemEntity = Ext.Entity.Get(userPreview.previewItem)

				if not itemEntity.ItemDye then
					itemEntity:CreateComponent("ItemDye")
				end

				---@type ItemTemplate
				local dyeTemplate = Ext.Template.GetTemplate(payload.dye)

				---@type ResourceMaterialPresetResource
				local materialPreset = Ext.Resource.Get(dyeTemplate.ColorPreset, "MaterialPreset")

				itemEntity.ItemDye.Color = materialPreset.Guid

				itemEntity:Replicate("ItemDye")
			end
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

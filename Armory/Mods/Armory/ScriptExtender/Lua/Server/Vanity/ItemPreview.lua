Ext.Vars.RegisterUserVariable("TheArmory_Vanity_PreviewItem", {
	Server = true
})

---@class UserEntry
---@field previewItem Guid
---@field equippedItem GUIDSTRING
---@field armorSet integer

---@type {[string] : UserEntry}
local previewingItemTable = {}

local resetSetTimer

Channels.PreviewItem:SetHandler(function(payload, user)
	local templateUUID = payload.templateId
	local slot = payload.slot

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

	local stat = Ext.Entity.Get(userPreview.previewItem).Data.StatsId
	if not stat then
		return
	elseif not Ext.Stats.Get(stat) then
		---@type ItemTemplate
		local template = Ext.Template.GetTemplate(templateUUID)
		Logger:BasicError("%s could not be previewed as it does not have a stats string associated to it?", template.Name .. "_" .. template.Id)
		return
	end

	Logger:BasicDebug("%s started previewing %s", character, templateUUID)

	userPreview.equippedItem = Osi.GetEquippedItem(character, slot)
	if userPreview.equippedItem then
		Ext.Entity.Get(userPreview.equippedItem).Vars.TheArmory_Vanity_Item_CurrentlyMogging = true
	end

	local correctArmorSet = string.find(slot, "Vanity") and 1 or 0
	Osi.SetArmourSet(character, correctArmorSet)

	-- Non-weapons use cross-slot mogging with the default pieces, but weapons are just equipped as-is
	if not string.find(slot, "Weapon") then
		Transmogger:TransmogItem(templateUUID,
			Osi.CreateAt(Transmogger.defaultPieces[slot], 0, 0, 0, 0, 0, ""),
			Ext.Entity.Get(character)
		)

		-- Otherwise the avatar doesn't show it in the inventory view
		Ext.Timer.WaitFor(50, function()
			if payload.dye then
				Transmogger:ApplyDye(Ext.Entity.Get(character))
			end
		end)
	else
		if userPreview.previewItem then
			if userPreview.equippedItem then
				Osi.Unequip(character, userPreview.equippedItem)
			end

			Ext.Timer.WaitFor(50, function()
				---@type EntityHandle
				local previewEntity = Ext.Entity.Get(userPreview.previewItem)
				previewEntity.Vars.TheArmory_Vanity_PreviewItem = character
				previewEntity.Vars.TheArmory_Vanity_Item_CurrentlyMogging = true

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
			end)
		end
	end
end)

local function DeleteItem(character, userPreview)
	Logger:BasicDebug("%s stopped previewing %s", character, userPreview.previewItem or "Unknown")

	for _, item in pairs(Ext.Vars.GetEntitiesWithVariable("TheArmory_Vanity_PreviewItem") or {}) do
		local itemEntity = Ext.Entity.Get(item)
		if itemEntity and itemEntity.Vars.TheArmory_Vanity_PreviewItem == character then
			itemEntity.Vars.TheArmory_Vanity_Item_CurrentlyMogging = true
			Osi.Unequip(character, item)
			Ext.Timer.WaitFor(200, function()
				Osi.RequestDelete(item)
			end)
		end
	end

	if userPreview.equippedItem then
		Osi.Equip(character, userPreview.equippedItem)
		userPreview.equippedItem = nil
	end

	userPreview.previewItem = nil
end

Channels.StopPreviewingItem:SetHandler(function(payload, user)
	user = PeerToUserID(user)
	local character = Osi.GetCurrentCharacter(user)

	local userPreview = previewingItemTable[user]
	if userPreview then
		if userPreview.armorSet then
			if resetSetTimer then
				Ext.Timer.Cancel(resetSetTimer)
				resetSetTimer = nil
			end

			resetSetTimer = Ext.Timer.WaitFor(1000, function()
				Osi.SetArmourSet(character, userPreview.armorSet)
				userPreview.armorSet = nil
			end)
		end

		DeleteItem(character, userPreview)
	end
end)

---@alias ActualWeaponType string

---@class EquipmentPicker : PickerBaseClass
EquipmentPicker = PickerBaseClass:new("Equipment", {
	settings = ConfigurationStructure.config.vanity.settings.equipment,
	---@type ActualWeaponType
	weaponType = nil,
	---@type number
	equipmentPreviewTimer = nil,
	---@type VanityOutfitSlot
	vanityOutfitSlot = nil
})

---@param slot ActualSlot
---@param weaponType ActualWeaponType?
---@param outfitSlot VanityOutfitSlot
---@param onSelectFunc function
function EquipmentPicker:OpenWindow(slot, weaponType, outfitSlot, onSelectFunc)
	self.weaponType = weaponType
	self.onSelectFunc = onSelectFunc
	self.vanityOutfitSlot = outfitSlot

	PickerBaseClass.OpenWindow(self,
		slot,
		function()
			self.settingsMenu:AddText("Number of Items Per Row")
			local perRowSetting = self.settingsMenu:AddSliderInt("", self.settings.rowSize, 0, 10)
			perRowSetting.OnChange = function()
				self.settings.rowSize = perRowSetting.Value[1]
				self:RebuildDisplay()
			end

			self.settingsMenu:AddText("Apply Dye?")
			local applyDyeCheckbox = self.settingsMenu:AddCheckbox("", self.settings.applyDyesWhenPreviewingEquipment)
			applyDyeCheckbox.SameLine = true
			applyDyeCheckbox.OnChange = function()
				self.settings.applyDyesWhenPreviewingEquipment = applyDyeCheckbox.Checked
			end
		end,
		function()
			Ext.ClientNet.PostMessageToServer(ModuleUUID .. "_StopPreviewingItem", "")
		end)
end

local equivalentSlots = {
	["Breast"] = "VanityBody",
	["Boots"] = "VanityBoots"
}

---@param templateName string
---@param displayGroup ExtuiGroup|ExtuiCollapsingHeader
function EquipmentPicker:DisplayResult(templateName, displayGroup)
	local itemTemplateId = self.itemIndex.templateNameAndId[templateName]
	
	---@type ItemTemplate
	local itemTemplate = Ext.Template.GetRootTemplate(itemTemplateId)

	local isFavorited, favoriteIndex = TableUtils:ListContains(self.settings.favorites, itemTemplateId)
	if displayGroup.Handle == self.favoritesGroup.Handle and not isFavorited then
		return
	end

	---@type Armor|Weapon|Object
	local itemStat = Ext.Stats.Get(self.itemIndex.templateIdAndStat[itemTemplateId])

	-- I started out with a combined if statement. I can't stress enough that I severely regret that decision.
	local matchesSlot = itemStat.Slot == self.slot

	if self.weaponType and not string.find(Ext.Json.Stringify(itemStat["Proficiency Group"], { Beautify = false }), self.weaponType) then
		return
	elseif self.slot == "LightSource" and itemStat.ItemGroup ~= "Torch" then
		return
	elseif not matchesSlot and self.slot ~= "LightSource" then
		local canGoInOffhand = true
		if string.find(self.slot, "Offhand") and string.find(itemStat.Slot, "Main") and self.slot == string.gsub(itemStat.Slot, "Main", "Offhand") then
			for _, property in pairs(itemStat["Weapon Properties"]) do
				if property == "Heavy" or property == "Twohanded" then
					canGoInOffhand = false
					break
				end
			end
		else
			canGoInOffhand = false
		end

		local isEquivalentSlot = false
		for slot1, slot2 in pairs(equivalentSlots) do
			if (slot1 == self.slot and string.find(slot2, itemStat.Slot))
				or (slot2 == self.slot and string.find(slot1, itemStat.Slot))
			then
				isEquivalentSlot = true
				break
			end
		end

		if not canGoInOffhand and not isEquivalentSlot then
			return
		end
	end

	local numChildren = #displayGroup.Children
	local itemGroup = displayGroup:AddChildWindow(itemTemplate.Id .. displayGroup.Label)
	itemGroup.NoSavedSettings = true
	itemGroup.Size = { self.settings.imageSize + 40, self.settings.imageSize + (self.settings.showNames and 100 or 10) }
	itemGroup.SameLine = numChildren > 0 and (numChildren % self.settings.rowSize) > 0
	itemGroup.ResizeY = true

	local icon = itemGroup:AddImageButton(itemTemplate.Name, itemTemplate.Icon, { self.settings.imageSize, self.settings.imageSize })
	if icon.Image.Icon == "" then
		icon:Destroy()
		icon = itemGroup:AddImageButton(itemTemplate.Name, "Item_Unknown", { self.settings.imageSize, self.settings.imageSize })
	end
	icon.Background = { 0, 0, 0, 0.5 }

	local favoriteButtonAnchor = itemGroup:AddGroup("favoriteAnchor" .. itemTemplate.Id)
	favoriteButtonAnchor.SameLine = true
	local favoriteButton = favoriteButtonAnchor:AddImageButton("Favorite" .. itemTemplate.Id,
		-- Generating icon files requires dealing with the toolkit, so, the typo stays ᕦ(ò_óˇ)ᕤ
		isFavorited and "star_fileld" or "star_empty",
		{ 26, 26 })

	favoriteButton.UserData = itemTemplate.Id
	favoriteButton.Background = { 0, 0, 0, 0.5 }
	favoriteButton:SetColor("Button", { 0, 0, 0, 0.5 })

	favoriteButton.OnClick = function()
		if not isFavorited then
			table.insert(ConfigurationStructure.config.vanity.settings.equipment.favorites, favoriteButton.UserData)
			local func = favoriteButton.OnClick
			favoriteButton:Destroy()
			favoriteButton = favoriteButtonAnchor:AddImageButton("Favorite" .. itemTemplate.Id, "star_fileld", { 26, 26 })
			favoriteButton.UserData = itemTemplate.Id
			favoriteButton.OnClick = func
			favoriteButton.SameLine = true
			favoriteButton.Background = { 0, 0, 0, 0.5 }
			favoriteButton:SetColor("Button", { 0, 0, 0, 0.5 })
		else
			table.remove(ConfigurationStructure.config.vanity.settings.equipment.favorites, favoriteIndex)
		end
		self:RebuildDisplay()
	end

	icon.OnHoverEnter = function()
		self.equipmentPreviewTimer = Ext.Timer.WaitFor(300, function()
			Ext.ClientNet.PostMessageToServer(ModuleUUID .. "_PreviewItem", Ext.Json.Stringify({
				templateId = itemTemplate.Id,
				dye = (self.settings.applyDyesWhenPreviewingEquipment and self.vanityOutfitSlot and self.vanityOutfitSlot.dye) and self.vanityOutfitSlot.dye.guid or nil
			}))

			self.equipmentPreviewTimer = nil
		end)
	end

	icon.OnHoverLeave = function()
		if self.equipmentPreviewTimer then
			Ext.Timer.Cancel(self.equipmentPreviewTimer)
			self.equipmentPreviewTimer = nil
		end

		Ext.ClientNet.PostMessageToServer(ModuleUUID .. "_StopPreviewingItem", "")
	end

	icon.OnClick = function()
		Ext.ClientNet.PostMessageToServer(ModuleUUID .. "_StopPreviewingItem", "")
		self.onSelectFunc(itemTemplate)
		self.window.Open = false
	end

	if self.settings.showNames then
		itemGroup:AddText(itemTemplate.DisplayName:Get() or itemTemplate.Name).TextWrapPos = 0
	end

	Helpers:BuildTooltip(icon:Tooltip(), itemTemplate.DisplayName:Get() or itemTemplate.Name, itemStat)
end

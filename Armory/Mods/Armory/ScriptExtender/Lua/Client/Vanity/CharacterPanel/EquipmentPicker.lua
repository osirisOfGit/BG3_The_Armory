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

	Helpers:KillChildren(self.warningGroup)
	if string.match(self.slot, "Offhand") then
		local warningButton = Styler:ImageButton(self.warningGroup:AddImageButton("warningButton", "ico_exclamation_01", { 64, 64 }))

		local warningText = warningButton:Tooltip():AddText(
			"\t WARNING: While you have two transmogged weapons equipped, do _not_ drag and drop your main hand onto your offhand slot or vice-versa - this will cause a Crash To Desktop that I can't figure out. You can drag from your inventory into a weapon slot, just not between weapon slots")
		warningText.TextWrapPos = 600
		warningText:SetColor("Text", { 1, 0.02, 0, 1 })
	end
end

local equivalentSlots = {
	["Breast"] = "VanityBody",
	["Boots"] = "VanityBoots"
}

---@param itemTemplateId string
---@param displayGroup ExtuiGroup|ExtuiCollapsingHeader
function EquipmentPicker:DisplayResult(itemTemplateId, displayGroup)
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
	local itemGroup = displayGroup:AddChildWindow(itemTemplate.Id .. itemStat.Name .. displayGroup.Label)
	itemGroup.NoSavedSettings = true
	itemGroup.Size = { self.settings.imageSize + 40, self.settings.imageSize + (self.settings.showNames and 100 or 10) }
	itemGroup.SameLine = numChildren > 0 and (numChildren % self.settings.rowSize) > 0
	itemGroup.ResizeY = true

	local icon = itemGroup:AddImageButton(itemTemplate.Name, itemTemplate.Icon, { self.settings.imageSize, self.settings.imageSize })
	if icon.Image.Icon == "" then
		icon:Destroy()
		icon = itemGroup:AddImageButton(itemTemplate.Name .. itemStat.Name, "Item_Unknown", { self.settings.imageSize, self.settings.imageSize })
	end
	icon.Background = { 0, 0, 0, 0.5 }

	local favoriteButtonAnchor = itemGroup:AddGroup("favoriteAnchor" .. itemTemplate.Id .. itemStat.Name)
	favoriteButtonAnchor.SameLine = true
	local favoriteButton = Styler:ImageButton(favoriteButtonAnchor:AddImageButton("Favorite" .. itemTemplate.Id .. itemStat.Name,
		-- Generating icon files requires dealing with the toolkit, so, the typo stays ᕦ(ò_óˇ)ᕤ
		isFavorited and "star_fileld" or "star_empty",
		{ 26, 26 }))

	favoriteButton.UserData = itemTemplate.Id

	favoriteButton.OnClick = function()
		if not isFavorited then
			table.insert(ConfigurationStructure.config.vanity.settings.equipment.favorites, favoriteButton.UserData)
			local func = favoriteButton.OnClick
			favoriteButton:Destroy()
			favoriteButton = Styler:ImageButton(favoriteButtonAnchor:AddImageButton("Favorite" .. itemTemplate.Id .. itemStat.Name, "star_fileld", { 26, 26 }))
			favoriteButton.UserData = itemTemplate.Id
			favoriteButton.OnClick = func
			favoriteButton.SameLine = true
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
		-- Covers scenario where user hovers over one item, then super quickly moves to another and instantly clicks on it
		Ext.Timer.WaitFor(150, function()
			Ext.ClientNet.PostMessageToServer(ModuleUUID .. "_StopPreviewingItem", "")
		end)
		self.onSelectFunc(itemTemplate)
		self.window.Open = false
	end

	if self.settings.showNames then
		itemGroup:AddText(itemTemplate.DisplayName:Get() or itemTemplate.Name).TextWrapPos = 0
	end

	local tooltip = icon:Tooltip()
	Helpers:BuildTooltip(tooltip, itemTemplate.DisplayName:Get() or itemTemplate.Name, itemStat)

	if itemTemplate.StatusList then
		for _, templateStatus in ipairs(itemTemplate.StatusList) do
			---@type StatusData
			local status = Ext.Stats.Get(templateStatus)
			if status and status.StatusEffect and status.StatusEffect ~= "" then
				local success, error = pcall(function(...)
					---@type ResourceMultiEffectInfo
					local mei = Ext.StaticData.Get(status.StatusEffect, "MultiEffectInfo")
					if mei then
						tooltip:AddText("Status Effect: " .. mei.Name)
					end
				end)
				if not success then
					tooltip:AddText("Status Effect: " .. status.StatusEffect)

					-- Logger:BasicWarning("Couldn't load the Status Effect %s from Stat %s on Item %s (from Mod '%s') due to %s - please contact the mod author to fix this issue",
					-- status.StatusEffect,
					-- status.Name,
					-- itemTemplate.Name .. "_" .. itemTemplate.Id,
					-- status.ModId ~= "" and Ext.Mod.GetMod(status.ModId).Info.Name or "Unknown",
					-- error)
				end
			end
		end
	end
end

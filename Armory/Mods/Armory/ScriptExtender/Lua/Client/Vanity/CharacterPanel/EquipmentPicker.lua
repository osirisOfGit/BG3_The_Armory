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

function EquipmentPicker:CreateCustomFilters()
	--#region EquipmentRaceFilter
	local equipmentRaceFilter = PickerBaseFilterClass:new({ label = "EquipmentRace" })
	self.customFilters[equipmentRaceFilter.label] = equipmentRaceFilter
	equipmentRaceFilter.selectedFilters = {}

	equipmentRaceFilter.header, equipmentRaceFilter.updateLabelWithCount = Styler:DynamicLabelTree(self.filterGroup:AddTree("By Equipment Race"))
	local tooltip = equipmentRaceFilter.header:Tooltip()
	tooltip:AddText([[
These filters are determined by the 'Visuals' section of the itemTemplate using what's internally referred to as Equipment Race Ids
These do not represent the EquipmentRace guaranteed to show a given piece of equipment, but what EquipmentRace's the item has explicitly defined in their template
This means that, for example, an item that doesn't define Elf Male is still highly likely to work if it defines Human Male, as they share similar/the same models
Because of this, it's best to select multiple EquipmentRaces that look most similar to yours. For Strong types, Human Strongs and Orcs will generally work]])

	local raceGroup = equipmentRaceFilter.header:AddGroup("raceGroup")

	equipmentRaceFilter.apply = function(self, itemTemplate)
		if self.header.Visible
			and itemTemplate.Equipment
			and itemTemplate.Equipment.Visuals
			and TableUtils:ListContains(raceGroup.Children, function(value)
				return value.Checked
			end)
		then
			for bodyType in pairs(itemTemplate.Equipment.Visuals) do
				return TableUtils:ListContains(raceGroup.Children, function(value)
					---@cast value ExtuiCheckbox
					return value.UserData == bodyType and value.Checked
				end)
			end
			return false
		end
		return true
	end

	equipmentRaceFilter.initializeUIBuilder = function(self)
		if string.find(EquipmentPicker.slot, "Weapon") then
			self.header.Visible = false
			return
		else
			self.header.Visible = true
		end
		Helpers:KillChildren(raceGroup)

		self.filterTable = TableUtils:DeeplyCopyTable(EquipmentRace)
	end

	equipmentRaceFilter.buildFilterUI =
	---@param self PickerBaseFilterClass
	---@param itemTemplate ItemTemplate
		function(self, itemTemplate)
			local selectedCount = 0

			for bodyType, id in pairs(self.filterTable) do
				-- local buildRaceFilter = self:CheckFilterCache(self.filterListenerCache["EquipmentRace"][id], filterIndex)
				local buildRaceFilter

				if itemTemplate.Equipment and itemTemplate.Equipment.Visuals then
					for bodyTypeId in pairs(itemTemplate.Equipment.Visuals) do
						if bodyTypeId == id then
							buildRaceFilter = true
							break
						end
					end
				end

				if buildRaceFilter then
					self.filterTable[bodyType] = nil

					local checkbox = raceGroup:AddCheckbox(bodyType)
					checkbox.UserData = id
					checkbox.Checked = self.selectedFilters[id] or false
					selectedCount = selectedCount + (checkbox.Checked and 1 or 0)

					checkbox.OnChange = function()
						self.selectedFilters[checkbox.UserData] = checkbox.Checked or nil
						selectedCount = selectedCount + (checkbox.Checked and 1 or -1)
						self.updateLabelWithCount(selectedCount)
						EquipmentPicker:ProcessFilters(equipmentRaceFilter.label)
					end

					checkbox.OnHoverEnter = function()
						tooltip.Visible = false
					end

					checkbox.OnHoverLeave = function()
						tooltip.Visible = true
					end
					self.updateLabelWithCount(selectedCount)
				end
			end
		end
	--#endregion

	--#region ArmorType
	local armorTypeFilter = PickerBaseFilterClass:new({ label = "ArmoryType" })
	self.customFilters[armorTypeFilter.label] = armorTypeFilter
	armorTypeFilter.header, armorTypeFilter.updateLabelWithCount = Styler:DynamicLabelTree(self.filterGroup:AddTree("By Armor Type"))

	armorTypeFilter.header:Tooltip():AddText(
		"\t\t These filters are determined by what is set by the Stat of the item, not the material of the item itself (since there's no way to do that)")

	local armorTypeGroup = armorTypeFilter.header:AddGroup("")
	armorTypeFilter.apply = function(self, itemTemplate)
		if self.header.Visible
			and EquipmentPicker.itemIndex.templateIdAndStat[itemTemplate.Id]
			and TableUtils:ListContains(armorTypeGroup.Children, function(value)
				return value.Checked
			end)
		then
			---@type Armor|Weapon
			local stat = Ext.Stats.Get(EquipmentPicker.itemIndex.templateIdAndStat[itemTemplate.Id])

			if stat.ModifierList == "Armor" then
				return TableUtils:ListContains(armorTypeGroup.Children, function(value)
					---@cast value ExtuiCheckbox
					return value.UserData == stat.ArmorType and value.Checked
				end)
			else
				return false
			end
		end
		return true
	end

	armorTypeFilter.selectedFilters = {}


	armorTypeFilter.initializeUIBuilder = function(self)
		if string.find(EquipmentPicker.slot, "Weapon") then
			self.header.Visible = false
			return
		else
			self.header.Visible = true
		end
		Helpers:KillChildren(armorTypeGroup)

		self.filterTable = { "None" }

		for _, armorType in ipairs(Ext.Enums.ArmorType) do
			if tostring(armorType) ~= "Sentinel" then
				table.insert(self.filterTable, tostring(armorType))
			end
		end
	end

	armorTypeFilter.buildFilterUI =
	---@param self PickerBaseFilterClass
	---@param itemTemplate ItemTemplate
		function(self, itemTemplate)
			local selectedCount = 0

			for i, armorType in pairs(self.filterTable) do
				armorType = tostring(armorType)

				local buildArmorType

				---@type Armor|Weapon
				local stat = Ext.Stats.Get(EquipmentPicker.itemIndex.templateIdAndStat[itemTemplate.Id])
				if stat.ModifierList == "Armor" then
					if stat.ArmorType == armorType then
						buildArmorType = true
					end
				end

				if buildArmorType then
					self.filterTable[i] = nil
					local checkbox = armorTypeGroup:AddCheckbox(armorType)
					checkbox.UserData = armorType
					checkbox.Checked = self.selectedFilters[armorType] or false
					selectedCount = selectedCount + (checkbox.Checked and 1 or 0)
					checkbox.OnChange = function()
						self.selectedFilters[armorType] = checkbox.Checked or nil
						selectedCount = selectedCount + (checkbox.Checked and 1 or -1)

						self.updateLabelWithCount(selectedCount)
						EquipmentPicker:ProcessFilters(armorTypeFilter.label)
					end

					self.updateLabelWithCount(selectedCount)
				end
			end
		end
	--#endregion
end

---@param slot ActualSlot
---@param weaponType ActualWeaponType?
---@param outfitSlot VanityOutfitSlot
---@param onSelectFunc function
function EquipmentPicker:OpenWindow(slot, weaponType, outfitSlot, onSelectFunc)
	self.weaponType = weaponType
	self.onSelectFunc = onSelectFunc
	self.vanityOutfitSlot = outfitSlot

	local equivalentSlots = {
		["Breast"] = "VanityBody",
		["Boots"] = "VanityBoots"
	}

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

			local itemTypeFilter = PickerBaseFilterClass:new({ label = "SlotType", priority = 1 })
			self.customFilters[itemTypeFilter.label] = itemTypeFilter
			itemTypeFilter.apply = function(self, itemTemplate)
				local itemTemplateId = itemTemplate.Id

				---@type Armor|Weapon|Object
				local itemStat = Ext.Stats.Get(EquipmentPicker.itemIndex.templateIdAndStat[itemTemplateId])

				-- I started out with a combined if statement. I can't stress enough that I severely regret that decision.
				local matchesSlot = itemStat.Slot == EquipmentPicker.slot

				if EquipmentPicker.weaponType and not string.find(Ext.Json.Stringify(itemStat["Proficiency Group"], { Beautify = false }), EquipmentPicker.weaponType) then
					return false
				elseif EquipmentPicker.slot == "LightSource" and itemStat.ItemGroup ~= "Torch" then
					return false
				elseif not matchesSlot and EquipmentPicker.slot ~= "LightSource" then
					local canGoInOffhand = true
					if string.find(EquipmentPicker.slot, "Offhand") and string.find(itemStat.Slot, "Main") and EquipmentPicker.slot == string.gsub(itemStat.Slot, "Main", "Offhand") then
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
						if (slot1 == EquipmentPicker.slot and string.find(slot2, itemStat.Slot))
							or (slot2 == EquipmentPicker.slot and string.find(slot1, itemStat.Slot))
						then
							isEquivalentSlot = true
							break
						end
					end

					if not canGoInOffhand and not isEquivalentSlot then
						return false
					end
				end

				return true
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

---@param itemTemplate ItemTemplate
---@param displayGroup ExtuiGroup|ExtuiCollapsingHeader
function EquipmentPicker:DisplayResult(itemTemplate, displayGroup)
	local isFavorited, favoriteIndex = TableUtils:ListContains(self.settings.favorites, itemTemplate.Id)
	if displayGroup.Handle == self.favoritesGroup.Handle and not isFavorited then
		return
	end

	---@type Armor|Weapon|Object
	local itemStat = Ext.Stats.Get(self.itemIndex.templateIdAndStat[itemTemplate.Id])

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

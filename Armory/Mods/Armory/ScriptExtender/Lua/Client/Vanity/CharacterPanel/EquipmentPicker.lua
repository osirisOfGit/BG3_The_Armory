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

local clearStatSlotChildren

function EquipmentPicker:CreateCustomFilters()
	--#region EquipmentRaceFilter
	local equipmentRaceFilter = PickerBaseFilterClass:new({ label = "EquipmentRace" })
	self.customFilters[equipmentRaceFilter.label] = equipmentRaceFilter
	equipmentRaceFilter.selectedFilters = {}

	equipmentRaceFilter.header, equipmentRaceFilter.updateLabelWithCount = Styler:DynamicLabelTree(self.filterGroup:AddTree(Translator:translate("By Equipment Race")))
	local tooltip = equipmentRaceFilter.header:Tooltip()
	tooltip:AddText(Translator:translate([[
	 These filters are determined by the 'Visuals' section of the itemTemplate using what's internally referred to as Equipment Race Ids
These do not represent the EquipmentRace guaranteed to show a given piece of equipment, but what EquipmentRace's the item has explicitly defined in their template
This means that, for example, an item that doesn't define Elf Male is still highly likely to work if it defines Human Male, as they share similar/the same models
Because of this, it's best to select multiple EquipmentRaces that look most similar to yours. For Strong types, Human Strongs and Orcs will generally work]]))

	local raceGroup = equipmentRaceFilter.header:AddGroup("raceGroup")

	equipmentRaceFilter.apply = function(self, itemTemplate)
		if self.header.Visible
			and itemTemplate.Equipment
			and itemTemplate.Equipment.Visuals
			and TableUtils:IndexOf(raceGroup.Children, function(value)
				return value.Checked
			end)
		then
			for bodyType in pairs(itemTemplate.Equipment.Visuals) do
				if TableUtils:IndexOf(raceGroup.Children, function(value)
						---@cast value ExtuiCheckbox
						return value.UserData == bodyType and value.Checked
					end) then
					return true
				end
			end
			return false
		end
		return true
	end

	local selectedCount = 0
	equipmentRaceFilter.initializeUIBuilder = function(self)
		self.filterBuilders = {}

		if string.find(EquipmentPicker.slot, "Weapon") then
			self.header.Visible = false
			self.filterTable = {}
			return
		else
			self.header.Visible = true
		end

		selectedCount = 0

		self.filterTable = TableUtils:DeeplyCopyTable(EquipmentRace)
	end

	equipmentRaceFilter.buildUI = function(self)
		Helpers:KillChildren(raceGroup)
		for _, func in TableUtils:OrderedPairs(self.filterBuilders) do
			func()
		end
	end

	equipmentRaceFilter.prepareFilterUI =
	---@param self PickerBaseFilterClass
	---@param itemTemplate ItemTemplate
		function(self, itemTemplate)
			for bodyType, id in pairs(self.filterTable) do
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

					self.filterBuilders[bodyType] = function()
						local checkbox = raceGroup:AddCheckbox(Translator:translate(bodyType))
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
		end

	equipmentRaceFilter.header:AddNewLine()
	--#endregion

	--#region ArmorType
	local armorTypeFilter = PickerBaseFilterClass:new({ label = "ArmorType" })
	self.customFilters[armorTypeFilter.label] = armorTypeFilter
	armorTypeFilter.header, armorTypeFilter.updateLabelWithCount = Styler:DynamicLabelTree(self.filterGroup:AddTree(Translator:translate("By Armor Type")))

	local armorTypeTooltip = armorTypeFilter.header:Tooltip()
	armorTypeTooltip:AddText(
		"\t  " .. Translator:translate("These filters are determined by the Stat of the item, not the material of the item itself (since there's no way to do that)"))

	local armorTypeGroup = armorTypeFilter.header:AddGroup("")
	armorTypeFilter.apply = function(self, itemTemplate)
		if self.header.Visible
			and EquipmentPicker.itemIndex.templateIdAndStat[itemTemplate.Id]
			and TableUtils:IndexOf(armorTypeGroup.Children, function(value)
				return value.Checked
			end)
		then
			---@type Armor|Weapon
			local stat = Ext.Stats.Get(EquipmentPicker.itemIndex.templateIdAndStat[itemTemplate.Id])

			if stat.ModifierList == "Armor" then
				return TableUtils:IndexOf(armorTypeGroup.Children, function(value)
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

	local selectedCount = 0
	armorTypeFilter.initializeUIBuilder = function(self)
		self.filterBuilders = {}

		if string.find(EquipmentPicker.slot, "Weapon") then
			self.header.Visible = false
			return
		else
			self.header.Visible = true
		end

		selectedCount = 0

		self.filterTable = { "None" }

		for _, armorType in ipairs(Ext.Enums.ArmorType) do
			if tostring(armorType) ~= "Sentinel" then
				table.insert(self.filterTable, tostring(armorType))
			end
		end
	end

	armorTypeFilter.buildUI = function(self)
		Helpers:KillChildren(armorTypeGroup)
		for _, func in TableUtils:OrderedPairs(self.filterBuilders) do
			func()
		end
	end

	armorTypeFilter.prepareFilterUI =
	---@param self PickerBaseFilterClass
	---@param itemTemplate ItemTemplate
		function(self, itemTemplate)
			if self.header.Visible then
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
						self.filterBuilders[armorType] = function()
							local checkbox = armorTypeGroup:AddCheckbox(Translator:translate(armorType))
							checkbox.UserData = armorType
							checkbox.Checked = self.selectedFilters[armorType] or false
							selectedCount = selectedCount + (checkbox.Checked and 1 or 0)

							checkbox.OnHoverEnter = function()
								armorTypeTooltip.Visible = false
							end
							checkbox.OnHoverLeave = function()
								armorTypeTooltip.Visible = true
							end
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
			end
		end

	armorTypeFilter.header:AddNewLine()
	--#endregion

	--#region Item Stat Slot filter
	local statSlotFilter = PickerBaseFilterClass:new({ label = "StatSlot", priority = 0 })
	self.customFilters[statSlotFilter.label] = statSlotFilter
	statSlotFilter.header, statSlotFilter.updateLabelWithCount = Styler:DynamicLabelTree(self.filterGroup:AddTree(Translator:translate("By Stat Slot")))

	local statSlotTooltip = statSlotFilter.header:Tooltip()
	statSlotTooltip:AddText("\t  " .. Translator:translate("Determined by the Template's Stat's Slot"))

	statSlotFilter.selectedFilters = {}
	local statSlotCount = 0
	local statSlotGroup = statSlotFilter.header:AddGroup("statSlotFilter")

	statSlotFilter.header:AddNewLine()

	statSlotFilter.apply = function(self, itemTemplate)
		local itemTemplateId = itemTemplate.Id

		---@type Armor|Weapon|Object
		local itemStat = Ext.Stats.Get(EquipmentPicker.itemIndex.templateIdAndStat[itemTemplateId])

		---@param slot ActualSlot
		---@return boolean
		local function doesMatchSlot(slot)
			-- I started out with a combined if statement. I can't stress enough that I severely regret that decision.
			local matchesSlot = itemStat.Slot == slot

			if EquipmentPicker.weaponType and not string.find(Ext.Json.Stringify(itemStat["Proficiency Group"], { Beautify = false }), EquipmentPicker.weaponType) then
				return false
			elseif slot == "LightSource" and itemStat.ItemGroup ~= "Torch" then
				return false
			elseif not matchesSlot and slot ~= "LightSource" then
				local canGoInOffhand = true
				if string.find(slot, "Offhand") and string.find(itemStat.Slot, "Main") and slot == string.gsub(itemStat.Slot, "Main", "Offhand") then
					for _, property in pairs(itemStat["Weapon Properties"]) do
						if property == "Heavy" or property == "Twohanded" then
							canGoInOffhand = false
							break
						end
					end
				else
					canGoInOffhand = false
				end

				if not canGoInOffhand then
					return false
				end
			end

			return true
		end

		if string.find(EquipmentPicker.slot, "Weapon") or #statSlotGroup.Children == 0 then
			return doesMatchSlot(EquipmentPicker.slot)
		else
			if itemStat.ModifierList == "Weapon" then
				return false
			end

			if self.header.Visible
				and TableUtils:IndexOf(statSlotGroup.Children, function(value)
					return value.Checked
				end)
			then
				for _, slotBox in pairs(statSlotGroup.Children) do
					---@cast slotBox ExtuiCheckbox
					if slotBox.Checked and doesMatchSlot(slotBox.UserData) then
						return true
					end
				end
				return false
			end
		end

		return true
	end

	statSlotFilter.initializeUIBuilder = function(self)
		self.filterBuilders = {}

		if string.find(EquipmentPicker.slot, "Weapon") then
			self.header.Visible = false
			return
		else
			self.header.Visible = true
		end

		statSlotCount = 0

		self.filterTable = {}

		for _, slot in ipairs(SlotEnum) do
			if not string.find(slot, "Weapon") then
				table.insert(self.filterTable, slot)
			end
		end
	end

	statSlotFilter.buildUI = function(self)
		Helpers:KillChildren(statSlotGroup)
		for _, func in TableUtils:OrderedPairs(self.filterBuilders) do
			func()
		end
	end

	statSlotFilter.prepareFilterUI = function(self, itemTemplate)
		if self.header.Visible then
			for i, filterSlot in pairs(self.filterTable) do
				---@type Armor|Weapon|Object
				local itemStat = Ext.Stats.Get(EquipmentPicker.itemIndex.templateIdAndStat[itemTemplate.Id])

				if itemStat.Slot == filterSlot then
					self.filterTable[i] = nil
					self.filterBuilders[filterSlot] = function()
						local checkbox = statSlotGroup:AddCheckbox(Translator:translate(filterSlot))
						checkbox.UserData = filterSlot
						checkbox.Checked = self.selectedFilters[filterSlot] or false
						statSlotCount = statSlotCount + (checkbox.Checked and 1 or 0)

						checkbox.OnHoverEnter = function()
							statSlotTooltip.Visible = false
						end
						checkbox.OnHoverLeave = function()
							statSlotTooltip.Visible = true
						end
						checkbox.OnChange = function()
							self.selectedFilters[filterSlot] = checkbox.Checked or nil
							statSlotCount = statSlotCount + (checkbox.Checked and 1 or -1)

							self.updateLabelWithCount(statSlotCount)
							EquipmentPicker:ProcessFilters(self.label)
						end

						self.updateLabelWithCount(statSlotCount)
					end
				end
			end
		end
	end
	--#endregion

	--#region Template Slot Filter
	local templateSlotFilter = PickerBaseFilterClass:new({ label = "TemplateSlot", priority = 1 })
	self.customFilters[templateSlotFilter.label] = templateSlotFilter
	templateSlotFilter.header, templateSlotFilter.updateLabelWithCount = Styler:DynamicLabelTree(self.filterGroup:AddTree(Translator:translate("By Visual Slot")))

	local templateSlotTooltip = templateSlotFilter.header:Tooltip()
	templateSlotTooltip:AddText("\t  " .. "Determined by the Template's Equipment Slot")

	templateSlotFilter.selectedFilters = {}
	local templateSlotCount = 0
	local templateSlotGroup = templateSlotFilter.header:AddGroup("templateSlotFilter")

	templateSlotFilter.apply = function(self, itemTemplate)
		if self.header.Visible then
			if not itemTemplate.Equipment or not itemTemplate.Equipment.Slot then
				return false
			elseif TableUtils:IndexOf(templateSlotGroup.Children, function(value)
					return value.Checked
				end)
			then
				for _, slot in pairs(itemTemplate.Equipment.Slot) do
					if TableUtils:IndexOf(templateSlotGroup.Children, function(value)
							---@cast value ExtuiCheckbox
							return value.UserData == slot and value.Checked
						end)
					then
						return true
					end
				end
				return false
			end
		end
		return true
	end

	templateSlotFilter.initializeUIBuilder = function(self)
		self.filterBuilders = {}

		if string.find(EquipmentPicker.slot, "Weapon") then
			self.header.Visible = false
			return
		else
			self.header.Visible = true
		end

		templateSlotCount = 0

		self.filterTable = {}

		for _, slot in ipairs(TemplateEquipmentSlot) do
			table.insert(self.filterTable, slot)
		end
	end

	templateSlotFilter.buildUI = function(self)
		Helpers:KillChildren(templateSlotGroup)
		for _, func in TableUtils:OrderedPairs(self.filterBuilders) do
			func()
		end
	end

	templateSlotFilter.prepareFilterUI = function(self, itemTemplate)
		if self.header.Visible
			and itemTemplate.Equipment
			and itemTemplate.Equipment.Slot
		then
			for i, filterSlot in pairs(self.filterTable) do
				local buildCheckbox

				for _, templateSlot in pairs(itemTemplate.Equipment.Slot) do
					if templateSlot == filterSlot then
						buildCheckbox = true
						break
					end
				end

				if buildCheckbox then
					self.filterTable[i] = nil
					self.filterBuilders[filterSlot] = function()
						local checkbox = templateSlotGroup:AddCheckbox(Translator:translate(filterSlot))
						checkbox.UserData = filterSlot
						checkbox.Checked = self.selectedFilters[filterSlot] or false
						if filterSlot == "Cloak" then
							checkbox:Tooltip():AddText("\t  " .. Translator:translate("Vanilla cloaks don't use this value for some reason - use stat slots to find those"))
						end
						templateSlotCount = templateSlotCount + (checkbox.Checked and 1 or 0)

						checkbox.OnHoverEnter = function()
							templateSlotTooltip.Visible = false
						end
						checkbox.OnHoverLeave = function()
							templateSlotTooltip.Visible = true
						end
						checkbox.OnChange = function()
							self.selectedFilters[filterSlot] = checkbox.Checked or nil
							templateSlotCount = templateSlotCount + (checkbox.Checked and 1 or -1)

							self.updateLabelWithCount(templateSlotCount)
							EquipmentPicker:ProcessFilters(self.label)
						end

						self.updateLabelWithCount(templateSlotCount)
					end
				end
			end
		end
	end

	--#endregion

	clearStatSlotChildren = function()
		for _, statSlot in pairs(statSlotGroup.Children) do
			statSlot.Checked = statSlot.UserData == self.slot
		end
		statSlotFilter.selectedFilters = {}

		for _, templateSlot in pairs(templateSlotGroup.Children) do
			templateSlot.Checked = false
		end
		templateSlotFilter.selectedFilters = {}
	end
end

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
			self.settingsMenu:AddText(Translator:translate("Number of Items Per Row")):Tooltip():AddText("\t " .. Translator:translate("Only used for Favorites on Patch 8"))
			local perRowSetting = self.settingsMenu:AddSliderInt("", self.settings.rowSize, 0, 10)
			perRowSetting:Tooltip():AddText("\t " .. Translator:translate("Only used for Favorites on Patch 8"))
			perRowSetting.OnChange = function()
				self.settings.rowSize = perRowSetting.Value[1]
				self:ProcessFilters()
			end

			local applyDyeCheckbox = self.settingsMenu:AddCheckbox(Translator:translate("Apply Dye?"), self.settings.applyDyesWhenPreviewingEquipment)
			applyDyeCheckbox.OnChange = function()
				self.settings.applyDyesWhenPreviewingEquipment = applyDyeCheckbox.Checked
			end

			local requirePreviewModifierCheckbox = self.settingsMenu:AddCheckbox(Translator:translate("Require holding 'Shift' to trigger hover preview"),
				self.settings.requireModifierForPreview)
			requirePreviewModifierCheckbox:Tooltip():AddText("\t " .. Translator:translate("Must be held before hovering over the item"))
			requirePreviewModifierCheckbox.OnChange = function()
				self.settings.requireModifierForPreview = requirePreviewModifierCheckbox.Checked
			end
		end,
		function()
			Channels.StopPreviewingItem:SendToServer()
		end)

	clearStatSlotChildren()
	self.customFilters["StatSlot"].selectedFilters[slot] = true

	Helpers:KillChildren(self.warningGroup)
	self.warningGroup.Visible = false
	if string.match(self.slot, "Offhand") then
		self.warningGroup.Visible = true
		local warningButton = Styler:ImageButton(self.warningGroup:AddImageButton("warningButton", "ico_exclamation_01", { 64, 64 }))

		local warningText = warningButton:Tooltip():AddText(
			"\t  " ..
			Translator:translate(
				"WARNING: While you have two transmogged weapons equipped, do _not_ drag and drop your main hand onto your offhand slot or vice-versa - this will cause a Crash To Desktop that I can't figure out. You can drag from your inventory into a weapon slot, just not between weapon slots"))
		warningText.TextWrapPos = 600
		warningText:SetColor("Text", { 1, 0.02, 0, 1 })
	end
end

---@param itemTemplate ItemTemplate
---@param displayGroup ExtuiChildWindow|ExtuiCollapsingHeader
function EquipmentPicker:DisplayResult(itemTemplate, displayGroup)
	local favoriteIndex = TableUtils:IndexOf(self.settings.favorites, itemTemplate.Id)
	if displayGroup.Handle == self.favoritesGroup.Handle and not favoriteIndex then
		return
	end

	---@type Armor|Weapon|Object
	local itemStat = Ext.Stats.Get(self.itemIndex.templateIdAndStat[itemTemplate.Id])

	local numChildren = #displayGroup.Children
	local itemGroup = displayGroup:AddChildWindow(itemTemplate.Id .. itemStat.Name .. displayGroup.Label)
	itemGroup.NoSavedSettings = true
	itemGroup.Size = { self.settings.imageSize + 40, self.settings.imageSize + (self.settings.showNames and 100 or 10) }

	if displayGroup.Handle == self.resultsGroup.Handle and Ext.Utils.Version() >= 23 then
		local maxRowSize = math.floor(self.resultsGroup.LastSize[1] / itemGroup.Size[1])

		if maxRowSize > 0 then
			itemGroup.SameLine = #self.resultsGroup.Children > 0 and ((#self.resultsGroup.Children - 1) % maxRowSize) > 0
		else
			itemGroup.SameLine = numChildren > 0 and (numChildren % self.settings.rowSize) > 0
		end
	else
		itemGroup.SameLine = numChildren > 0 and (numChildren % self.settings.rowSize) > 0
	end
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
		favoriteIndex and "star_fileld" or "star_empty",
		{ 26, 26 }))

	favoriteButton.UserData = itemTemplate.Id

	favoriteButton.OnClick = function()
		if not favoriteIndex then
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
		self:ProcessFilters()
	end

	icon.OnHoverEnter = function()
		if (not self.settings.requireModifierForPreview and itemTemplate.Id ~= "6ea2650e-c12b-43d9-873e-f3d426d30d18") or Ext.ClientInput.GetInputManager().PressedModifiers == "Shift" then
			self.equipmentPreviewTimer = Ext.Timer.WaitFor(300, function()
				Channels.PreviewItem:SendToServer({
					templateId = itemTemplate.Id,
					dye = (self.settings.applyDyesWhenPreviewingEquipment and self.vanityOutfitSlot and self.vanityOutfitSlot.dye) and self.vanityOutfitSlot.dye.guid or nil,
					slot = self.slot
				})

				self.equipmentPreviewTimer = nil
			end)
		end
	end

	icon.OnHoverLeave = function()
		if self.equipmentPreviewTimer then
			Ext.Timer.Cancel(self.equipmentPreviewTimer)
			self.equipmentPreviewTimer = nil
		end

		Channels.StopPreviewingItem:SendToServer()
	end

	icon.OnClick = function()
		-- Covers scenario where user hovers over one item, then super quickly moves to another and instantly clicks on it
		Ext.Timer.WaitFor(150, function()
			Channels.StopPreviewingItem:SendToServer()
		end)
		self.onSelectFunc(itemTemplate)
		self.window.Open = false
	end

	if self.settings.showNames then
		itemGroup:AddText(itemTemplate.DisplayName:Get() or itemTemplate.Name).TextWrapPos = 0
	end

	local tooltip = icon:Tooltip()
	Helpers:BuildTooltip(tooltip, itemTemplate.DisplayName:Get() or itemTemplate.Name, itemStat)

	if itemTemplate.Id == "6ea2650e-c12b-43d9-873e-f3d426d30d18" then
		Styler:Color(
		tooltip:AddText(
		Translator:translate("This item has story flags associated to it - if you're in Act 3 and have not yet dealt with Gortash, or don't have an up-to-date save, don't select this item - hold `Shift` to trigger preview (which will trip the flag and run the cutscene if you meet the conditions).")),
			"ErrorText")
	end

	if itemTemplate.StatusList then
		for _, templateStatus in ipairs(itemTemplate.StatusList) do
			---@type StatusData
			local status = Ext.Stats.Get(templateStatus)
			if status and status.StatusEffect and status.StatusEffect ~= "" then
				local success, error = pcall(function(...)
					---@type ResourceMultiEffectInfo
					local mei = Ext.StaticData.Get(status.StatusEffect, "MultiEffectInfo")
					if mei then
						tooltip:AddText(Translator:translate("Status Effect") .. ": " .. mei.Name)
					end
				end)
				if not success then
					tooltip:AddText(Translator:translate("Status Effect") .. ": " .. status.StatusEffect)
				end
			end
		end
	end
end

Translator:RegisterTranslation({
	["By Equipment Race"] = "hb6ebd9f368894e11b9020f49ee3a8ec68dg5",
	[([[
	 These filters are determined by the 'Visuals' section of the itemTemplate using what's internally referred to as Equipment Race Ids
These do not represent the EquipmentRace guaranteed to show a given piece of equipment, but what EquipmentRace's the item has explicitly defined in their template
This means that, for example, an item that doesn't define Elf Male is still highly likely to work if it defines Human Male, as they share similar/the same models
Because of this, it's best to select multiple EquipmentRaces that look most similar to yours. For Strong types, Human Strongs and Orcs will generally work]])] =
	"h916fc5f1979342aeb9848b362bded8865ge3",
	["By Armor Type"] = "h4d1648200ebc4ccda856362ca12c087a03dc",
	["These filters are determined by the Stat of the item, not the material of the item itself (since there's no way to do that)"] = "hc7f094dd04e14c0fa607315cee3612f6ed80",
	["By Stat Slot"] = "heaec1ab79adf42eb89f43d5753f295df08be",
	["Determined by the Template's Stat's Slot"] = "hde39176c2440420b9a068a904d67e8717b52",
	["By Visual Slot"] = "hffec1d1dafee4460b9a6d63e5fabbb1cb233",
	["Determined by the Template's Equipment Slot"] = "he025d0ca53674df1953cb583bb93475aad95",
	["Vanilla cloaks don't use this value for some reason - use stat slots to find those"] = "h5eb8683de63b4131a1ebc9593a91e953b6a7",
	["Number of Items Per Row"] = "h670f5005fae647019d884dcb37db31dd9a7g",
	["Only used for Favorites on Patch 8"] = "h2b39a9f0f90840b19f8b602684ddbc7c4177",
	["Apply Dye?"] = "hd399ef020f5e4e319cf68affb8585f8d06b8",
	["WARNING: While you have two transmogged weapons equipped, do _not_ drag and drop your main hand onto your offhand slot or vice-versa - this will cause a Crash To Desktop that I can't figure out. You can drag from your inventory into a weapon slot, just not between weapon slots"] =
	"ha9c5c3919a744036925cf8010a1c7bb48a2f",
	["This item has story flags associated to it - if you're in Act 3 and have not yet dealt with Gortash, or don't have an up-to-date save, don't select this item - hold `Shift` to trigger preview (which will trip the flag and run the cutscene if you meet the conditions)."] = "he3a56800829144bba1b89ee28a5d6087d487",
	["Status Effect"] = "had9a379edf23424997655761c7dbbc6eb84g",
	["Require holding 'Shift' to trigger hover preview"] = "h4ad0af6a98204eb5aa05ce21fb216b68515c",
	["Must be held before hovering over the item"] = "h1def6ed3b47543629552444734f5757e83b7"
})

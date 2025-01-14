---@alias ActualWeaponType string

---@class EquipmentPicker : PickerBaseClass
EquipmentPicker = PickerBaseClass:new("Equipment", {
	settings = ConfigurationStructure.config.vanity.settings.equipment,
	rowCount = 0,
	---@type ActualWeaponType
	weaponType = nil
})

function EquipmentPicker:InitializeSearchBank()
	for templateName, template in pairs(Ext.ClientTemplate.GetAllRootTemplates()) do
		---@cast template ItemTemplate
		if template.TemplateType == "item" then
			---@type Weapon|Armor|Object
			local stat = Ext.Stats.Get(template.Stats)

			local success, error = pcall(function()
				local name = template.DisplayName:Get() or templateName
				if stat
					and (stat.ModifierList == "Weapon" or stat.ModifierList == "Armor")
					and not self.rootsByName[name]
				then
					table.insert(self.sortedTemplateNames, name)
					self.rootsByName[name] = template

					if stat.ModId ~= "" then
						if not self.templateNamesByModId[stat.ModId] then
							self.modIdByModName[Ext.Mod.GetMod(stat.ModId).Info.Name] = stat.ModId
							self.templateNamesByModId[stat.ModId] = {}
						end
						table.insert(self.templateNamesByModId[stat.ModId], name)
					end
				end
			end)
			if not success then
				Logger:BasicWarning("Couldn't load item %s with stat %s (from Mod '%s') into the table due to %s",
					template.Name,
					stat.Name,
					stat.ModId ~= "" and Ext.Mod.GetMod(stat.ModId).Info.Name or "Unknown",
					error)
			end
		end
	end

	table.sort(self.sortedTemplateNames)
end

---@param slot ActualSlot
---@param weaponType ActualWeaponType?
---@param onSelectFunc function
function EquipmentPicker:OpenWindow(slot, weaponType, onSelectFunc)
	PickerBaseClass.OpenWindow(self, slot, function()
		self.settingsMenu:AddText("Number of Items Per Row")
		local perRowSetting = self.settingsMenu:AddSliderInt("", self.settings.rowSize, 0, 10)
		perRowSetting.OnChange = function()
			self.settings.rowSize = perRowSetting.Value[1]
		end
	end)

	self.rowCount = 0
	self.weaponType = weaponType
	self.onSelectFunc = onSelectFunc
end

---@param templateName string
---@param displayGroup ExtuiGroup
function EquipmentPicker:DisplayResults(templateName, displayGroup)
	local itemTemplate = self.rootsByName[templateName]

	local rowCountCopy = self.rowCount
	if displayGroup.Handle == self.favoritesGroup.Handle then
		self.rowCount = #self.favoritesGroup.Children
	else
		local isInList, _ = TableUtils:ListContains(self.rootsByName, itemTemplate.Id)
		if not isInList then
			return
		end
	end


	---@type Armor|Weapon|Object
	local itemStat = Ext.Stats.Get(itemTemplate.Stats)

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

		if not canGoInOffhand then
			return
		end
	end

	if self.rowCount > self.settings.rowSize then
		self.rowCount = 0
	end
	self.rowCount = self.rowCount + 1

	local itemGroup = displayGroup:AddChildWindow(itemTemplate.Id .. displayGroup.Label)
	itemGroup.NoSavedSettings = true
	itemGroup.Size = { self.settings.imageSize + 40, self.settings.imageSize + (self.settings.showNames and 100 or 10) }
	itemGroup.SameLine = self.rowCount <= self.settings.rowSize
	itemGroup.ResizeY = true

	local icon = itemGroup:AddImageButton(itemTemplate.Name, itemTemplate.Icon, { self.settings.imageSize, self.settings.imageSize })
	if icon.Image.Icon == "" then
		icon:Destroy()
		icon = itemGroup:AddImageButton(itemTemplate.Name, "Item_Unknown", { self.settings.imageSize, self.settings.imageSize })
	end
	icon.Background = { 0, 0, 0, 0.5 }

	local isFavorited = TableUtils:ListContains(self.settings.favorites, itemTemplate.Id)
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
		local isInList, index = TableUtils:ListContains(self.settings.favorites, favoriteButton.UserData)
		if not isInList then
			table.insert(ConfigurationStructure.config.vanity.settings.equipment.favorites, favoriteButton.UserData)
			local func = favoriteButton.OnClick
			favoriteButton:Destroy()
			favoriteButton = favoriteButtonAnchor:AddImageButton("Favorite" .. itemTemplate.Id, "star_fileld", { 26, 26 })
			favoriteButton.UserData = itemTemplate.Id
			favoriteButton.OnClick = func
			favoriteButton.SameLine = true
			favoriteButton.Background = { 0, 0, 0, 0.5 }
			favoriteButton:SetColor("Button", { 0, 0, 0, 0.5 })

			self:DisplayResult(templateName, self.favoritesGroup)
		else
			table.remove(ConfigurationStructure.config.vanity.settings.equipment.favorites, index)

			EquipmentPicker:PickForSlot(slot, weaponType, onSelectFunc)
		end
	end

	icon.OnHoverEnter = function()
		previewTimer = Ext.Timer.WaitFor(200, function()
			Ext.ClientNet.PostMessageToServer(ModuleUUID .. "_PreviewItem", itemTemplate.Id)
			previewTimer = nil
		end)
	end

	icon.OnHoverLeave = function()
		if previewTimer then
			Ext.Timer.Cancel(previewTimer)
			previewTimer = nil
		end

		Ext.ClientNet.PostMessageToServer(ModuleUUID .. "_StopPreviewingItem", "")
	end

	icon.OnClick = function()
		Ext.ClientNet.PostMessageToServer(ModuleUUID .. "_StopPreviewingItem", "")
		onSelectFunc(itemTemplate)
		searchWindow.Open = false
	end

	if settings.showNames then
		itemGroup:AddText(itemTemplate.DisplayName:Get() or itemTemplate.Name).TextWrapPos = 0
	end

	Helpers:BuildTooltip(icon:Tooltip(), nil, Ext.Stats.Get(itemTemplate.Stats))

	self.rowCount = rowCountCopy
end

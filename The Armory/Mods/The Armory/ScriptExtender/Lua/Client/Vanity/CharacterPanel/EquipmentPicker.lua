---@type table<FixedString, ItemTemplate>
local rootsByName = {}
local sortedTemplateNames = {}

local templateNameByModId = {}
local modIdByModName = {}

local function populateTemplateTable()
	for templateName, template in pairs(Ext.ClientTemplate.GetAllRootTemplates()) do
		---@cast template ItemTemplate
		if template.TemplateType == "item" then
			---@type Weapon|Armor|Object
			local stat = Ext.Stats.Get(template.Stats)

			local success, error = pcall(function()
				local name = template.DisplayName:Get() or templateName
				if stat
					and (stat.ModifierList == "Weapon" or stat.ModifierList == "Armor")
					and not rootsByName[name]
				then
					table.insert(sortedTemplateNames, name)
					rootsByName[name] = template

					if stat.ModId ~= "" then
						if not templateNameByModId[stat.ModId] then
							modIdByModName[Ext.Mod.GetMod(stat.ModId).Info.Name] = stat.ModId
							templateNameByModId[stat.ModId] = {}
						end
						table.insert(templateNameByModId[stat.ModId], name)
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

	table.sort(sortedTemplateNames)
end

EquipmentPicker = {}

local settings = ConfigurationStructure.config.vanity.settings.equipment
local rowCount = 0

local previewTimer

---@type ExtuiWindow?
local searchWindow = nil

---@alias ActualWeaponType string

---@param slot ActualSlot
---@param weaponType ActualWeaponType?
---@param onSelectFunc function
function EquipmentPicker:PickForSlot(slot, weaponType, onSelectFunc)
	if not next(rootsByName) then
		populateTemplateTable()
	end

	rowCount = 0

	local itemSlot = string.find(slot, "Ring") and "Ring" or slot

	if not searchWindow then
		searchWindow = Ext.IMGUI.NewWindow("Equipment Picker")
		searchWindow.Closeable = true
		searchWindow.MenuBar = true
		local mainMenu = searchWindow:AddMainMenu()
		mainMenu.UserData = "keep"
		mainMenu:SetColor("PopupBg", { 0, 0, 0, 1 })

		---@type ExtuiMenu
		local settingsMenu = mainMenu:AddMenu("Settings")
		settingsMenu:AddText("Number of Items Per Row")
		local perRowSetting = settingsMenu:AddSliderInt("", settings.rowSize, 0, 10)
		perRowSetting.OnChange = function()
			settings.rowSize = perRowSetting.Value[1]
		end
		settingsMenu:AddSeparator()
		settingsMenu:AddText("Image Size")
		local imageSizeSetting = settingsMenu:AddSliderInt("", settings.imageSize, 10, 200)
		imageSizeSetting.OnChange = function()
			settings.imageSize = imageSizeSetting.Value[1]
		end
		settingsMenu:AddSeparator()
		settingsMenu:AddText("Show Item Names?")
		local showNameCheckbox = settingsMenu:AddCheckbox("", settings.showNames)
		showNameCheckbox.SameLine = true
		showNameCheckbox.OnChange = function()
			settings.showNames = showNameCheckbox.Checked
		end
	else
		if not searchWindow.Open then
			searchWindow.Open = true
		end

		for _, child in pairs(searchWindow.Children) do
			if child.UserData ~= "keep" then
				child:Destroy()
			end
		end
	end

	searchWindow:AddSeparatorText(string.format("Searching for %s%s items", slot, weaponType and " (" .. weaponType .. ")" or "")):SetStyle("SeparatorTextAlign", 0.5)

	--#region Input
	local searchInput = searchWindow:AddInputText("")
	searchInput.Hint = "Case-insensitive"
	searchInput.AutoSelectAll = true
	searchInput.EscapeClearsAll = true

	searchWindow:AddText("List all items by mod - will be cleared if above search is used")
	local getAllForModCombo = searchWindow:AddCombo("")
	getAllForModCombo.WidthFitPreview = true
	local modOpts = {}
	for modId, _ in pairs(templateNameByModId) do
		table.insert(modOpts, Ext.Mod.GetMod(modId).Info.Name)
	end
	table.sort(modOpts)
	getAllForModCombo.Options = modOpts
	--#endregion

	--#region Results
	searchWindow:AddSeparatorText("Results")

	local favoritesGroup = searchWindow:AddCollapsingHeader("Favorites")
	favoritesGroup:AddNewLine()
	favoritesGroup:AddNewLine()

	local resultGroup = searchWindow:AddCollapsingHeader("Search Results")
	resultGroup.DefaultOpen = true
	resultGroup:AddNewLine()
	resultGroup:AddNewLine()

	--- I'm beginning to see why Aahz and Volitio like OOP in Lua so much - managing scope like this is a PITA
	---@param displayGroup ExtuiCollapsingHeader
	---@param itemTemplate ItemTemplate
	---@return boolean
	local function createItemGroup(displayGroup, itemTemplate)
		local itemGroup = displayGroup:AddChildWindow(itemTemplate.Id .. displayGroup.Label)
		itemGroup.NoSavedSettings = true
		itemGroup.Size = {settings.imageSize + 40, settings.imageSize + (settings.showNames and 100 or 10)}
		itemGroup.SameLine = rowCount <= settings.rowSize
		itemGroup.ResizeY = true

		local icon = itemGroup:AddImageButton(itemTemplate.Name, itemTemplate.Icon, { settings.imageSize, settings.imageSize })
		if icon.Image.Icon == "" then
			icon:Destroy()
			icon = itemGroup:AddImageButton(itemTemplate.Name, "Item_Unknown", { settings.imageSize, settings.imageSize })
		end
		icon.Background = { 0, 0, 0, 0.5 }

		local isFavorited = TableUtils:ListContains(ConfigurationStructure.config.vanity.settings.equipment.favorites, itemTemplate.Id)
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
			local isInList, index = TableUtils:ListContains(ConfigurationStructure.config.vanity.settings.equipment.favorites, favoriteButton.UserData)
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

				createItemGroup(favoritesGroup, itemTemplate)
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

		return isFavorited
	end

	local function displayResult(templateName)
		local itemTemplate = rootsByName[templateName]

		---@type Armor|Weapon|Object
		local itemStat = Ext.Stats.Get(itemTemplate.Stats)

		-- I started out with a combined if statement. I can't stress enough that I severely regret that decision.
		local matchesSlot = itemStat.Slot == itemSlot

		if weaponType and not string.find(Ext.Json.Stringify(itemStat["Proficiency Group"], { Beautify = false }), weaponType) then
			return
		elseif itemSlot == "LightSource" and itemStat.ItemGroup ~= "Torch" then
			return
		elseif not matchesSlot and itemSlot ~= "LightSource" then
			local canGoInOffhand = true
			if string.find(itemSlot, "Offhand") and string.find(itemStat.Slot, "Main") and itemSlot == string.gsub(itemStat.Slot, "Main", "Offhand") then
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

		if createItemGroup(resultGroup, itemTemplate) then
			createItemGroup(favoritesGroup, itemTemplate)
		end

		if rowCount > settings.rowSize then
			rowCount = 0
		end
		rowCount = rowCount + 1
	end

	for _, templateName in pairs(sortedTemplateNames) do
		displayResult(templateName)
	end

	--#endregion

	getAllForModCombo.OnChange = function()
		rowCount = 0
		for _, child in pairs(resultGroup.Children) do
			child:Destroy()
		end
		-- \[[[^_^]]]/
		for _, templateName in pairs(templateNameByModId[modIdByModName[getAllForModCombo.Options[getAllForModCombo.SelectedIndex + 1]]]) do
			displayResult(templateName)
		end
	end

	local delayTimer
	searchInput.OnChange = function()
		if delayTimer then
			Ext.Timer.Cancel(delayTimer)
		end

		getAllForModCombo.SelectedIndex = -1

		delayTimer = Ext.Timer.WaitFor(150, function()
			for _, child in pairs(resultGroup.Children) do
				child:Destroy()
			end

			rowCount = 0
			if #searchInput.Text >= 3 then
				local upperSearch = string.upper(searchInput.Text)
				for _, templateName in pairs(sortedTemplateNames) do
					if string.find(string.upper(templateName), upperSearch) then
						displayResult(templateName)
					end
				end
			elseif #searchInput.Text == 0 then
				for _, templateName in pairs(sortedTemplateNames) do
					displayResult(templateName)
				end
			end
		end)
	end

	return searchWindow
end

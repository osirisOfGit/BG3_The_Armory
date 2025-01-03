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

local numPerRow = 4
local rowCount = 0
local imageSize = 90

local previewTimer

---@param tooltip ExtuiTooltip
---@param itemStat Weapon|Armor|Object
---@param itemTemplate ItemTemplate
local function BuildStatusTooltip(tooltip, itemStat, itemTemplate)
	tooltip:AddText("\n")

	if itemStat.ModId ~= "" then
		local mod = Ext.Mod.GetMod(itemStat.ModId).Info
		tooltip:AddText(string.format(Translator:translate("From mod '%s' by '%s'"), mod.Name, mod.Author))
	end

	if itemStat.OriginalModId ~= "" and itemStat.OriginalModId ~= itemStat.ModId then
		local mod = Ext.Mod.GetMod(itemStat.OriginalModId).Info
		tooltip:AddText(string.format(Translator:translate("Originally from mod '%s' by '%s'"), mod.Name, mod.Author))
	end
end

---@param itemGroup ExtuiChildWindow
---@param itemTemplate ItemTemplate
---@param imageButton ExtuiImageButton
---@param searchWindow ExtuiWindow
---@return ExtuiImageButton
local function createItemGroup(itemGroup, itemTemplate, imageButton, searchWindow)
	local icon = itemGroup:AddImageButton(itemTemplate.Name, itemTemplate.Icon, { imageSize, imageSize })
	if icon.Image.Icon == "" then
		icon:Destroy()
		icon = itemGroup:AddImageButton(itemTemplate.Name, "Item_Unknown", { imageSize, imageSize })
	end
	icon.Background = { 0, 0, 0, 0.5 }

	-- Generating icon files requires dealing with the toolkit, so, the typo stays ᕦ(ò_óˇ)ᕤ
	local favoriteButton = itemGroup:AddImageButton("Favorite", "star_empty", { 26, 26 })
	favoriteButton.SameLine = true
	favoriteButton.Background = { 0, 0, 0, 0.5 }
	favoriteButton:SetColor("Button", { 0, 0, 0, 0.5 })

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
		imageButton.UserData = itemTemplate
		searchWindow.OnClose()
		searchWindow.Open = false
	end

	itemGroup:AddText(itemTemplate.DisplayName:Get()).TextWrapPos = 0
	BuildStatusTooltip(icon:Tooltip(), Ext.Stats.Get(itemTemplate.Stats), itemTemplate)

	return favoriteButton
end

---@alias ActualWeaponType string

---@param slot ActualSlot
---@param slotButton ExtuiImageButton
---@param weaponType ActualWeaponType
function EquipmentPicker:PickForSlot(slot, slotButton, weaponType)
	if not next(rootsByName) then
		populateTemplateTable()
	end
	
	local itemSlot = string.find(slot, "Ring") and "Ring" or slot

	local searchWindow = Ext.IMGUI.NewWindow(string.format("Searching for %s%s items", slot, weaponType and " (" .. weaponType .. ")" or ""))
	searchWindow.Closeable = true
	searchWindow.AlwaysVerticalScrollbar = true

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
	resultGroup:AddNewLine()
	resultGroup:AddNewLine()

	local function displayResult(templateName)
		local itemTemplate = rootsByName[templateName]

		---@type Armor|Weapon|Object
		local itemStat = Ext.Stats.Get(itemTemplate.Stats)

		-- Try making a logic flow diagram out of this (╬▔皿▔)╯
		local isTorch = itemSlot == "LightSource" and itemStat.ItemGroup == "Torch"
		local matchesSlot = itemSlot ~= "LightSource" and itemStat.Slot == itemSlot
		local matchesWeaponType = not weaponType or string.find(Ext.Json.Stringify(itemStat["Proficiency Group"], { Beautify = false }), weaponType)
		local canGoInOffhandMelee = itemSlot ~= "Melee Offhand Weapon" or (itemStat.Slot == "Melee Offhand Weapon" or itemStat.Slot == "Melee Main Weapon")
		local canGoInOffhandRanged = itemSlot ~= "Ranged Offhand Weapon" or (itemStat.Slot == "Ranged Offhand Weapon" or itemStat.Slot == "Ranged Main Weapon")

		-- If the weapon type matches, that takes absolute precendence because the UI limits which slots a weapon type can be searched in
		-- However, we need to account for non-weapon items, so if the slot does not match, but we were given a weapon type, then we don't skip the item
		-- Then, there's torches >_>
		if not matchesWeaponType
			or (not isTorch
				and (
					not matchesSlot
					and (
						weaponType == nil
						or (not canGoInOffhandMelee
							and not canGoInOffhandRanged)
					)
				))
		then
			return
		end

		local itemGroup = resultGroup:AddChildWindow(itemTemplate.Name)
		itemGroup.Size = { imageSize * 1.5, imageSize * 2.5 }
		itemGroup.ChildAlwaysAutoResize = true
		itemGroup.SameLine = rowCount <= numPerRow

		local favoriteButton = createItemGroup(itemGroup, itemTemplate, slotButton, searchWindow)

		favoriteButton.OnClick = function()
			local favoriteItemGroup = favoritesGroup:AddChildWindow(itemTemplate.Name .. "_favorite")
			favoriteItemGroup.Size = { imageSize * 1.5, imageSize * 2.5 }
			favoriteItemGroup.ChildAlwaysAutoResize = true
			favoriteItemGroup.SameLine = rowCount <= numPerRow
			createItemGroup(favoriteItemGroup, itemTemplate, slotButton, searchWindow)
		end

		if rowCount > numPerRow then
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

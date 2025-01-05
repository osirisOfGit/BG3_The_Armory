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

---@type ExtuiWindow?
local openWindow = nil

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
---@param onSelectFunc function
---@return ExtuiImageButton
local function createItemGroup(itemGroup, itemTemplate, searchWindow, onSelectFunc)
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
		onSelectFunc(itemTemplate)
		searchWindow.Open = false
		openWindow:Destroy()
		openWindow = nil
	end

	itemGroup:AddText(itemTemplate.DisplayName:Get() or itemTemplate.Name).TextWrapPos = 0
	BuildStatusTooltip(icon:Tooltip(), Ext.Stats.Get(itemTemplate.Stats), itemTemplate)

	return favoriteButton
end


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

	local searchWindow = Ext.IMGUI.NewWindow(string.format("Searching for %s%s items", slot, weaponType and " (" .. weaponType .. ")" or ""))
	searchWindow.Closeable = true
	searchWindow.OnClose = function()
		openWindow:Destroy()
		openWindow = nil
	end

	if openWindow then
		openWindow.Open = false
		openWindow:Destroy()
	end
	openWindow = searchWindow

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

		local itemGroup = resultGroup:AddChildWindow(itemTemplate.Name)
		itemGroup.NoSavedSettings = true
		itemGroup.Size = { imageSize * 1.5, imageSize * 2.5 }
		itemGroup.ChildAlwaysAutoResize = true
		itemGroup.SameLine = rowCount <= numPerRow

		local favoriteButton = createItemGroup(itemGroup, itemTemplate, searchWindow, onSelectFunc)

		favoriteButton.OnClick = function()
			local favoriteItemGroup = favoritesGroup:AddChildWindow(itemTemplate.Name .. "_favorite")
			favoriteItemGroup.Size = { imageSize * 1.5, imageSize * 2.5 }
			favoriteItemGroup.ChildAlwaysAutoResize = true
			favoriteItemGroup.SameLine = rowCount <= numPerRow
			createItemGroup(favoriteItemGroup, itemTemplate, searchWindow, onSelectFunc)
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

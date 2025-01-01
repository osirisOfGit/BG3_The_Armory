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

populateTemplateTable()

EquipmentPicker = {}

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


---@param imageButton ExtuiImageButton
function EquipmentPicker:PickForSlot(imageButton)
	local itemSlot = string.find(imageButton.Label, "Ring") and "Ring" or imageButton.Label

	local searchWindow = Ext.IMGUI.NewWindow("Searching for " .. itemSlot .. " items")
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
	searchWindow:AddNewLine()

	local resultGroup = searchWindow:AddGroup("Search_" .. itemSlot)

	local numPerRow = 8
	local rowCount = 0
	local imageSize = 120
	local function displayResult(templateName)
		local itemTemplate = rootsByName[templateName]

		---@type Armor|Weapon|Object
		local itemStat = Ext.Stats.Get(itemTemplate.Stats)
		if (itemSlot == "LightSource" and itemStat.ItemGroup ~= "Torch")
			or ((itemSlot ~= "LightSource" and itemStat.Slot ~= itemSlot)
				and (itemSlot ~= "Melee Offhand Weapon" or (itemStat.Slot ~= "Melee Offhand Weapon" and itemStat.Slot ~= "Melee Main Weapon"))
				and (itemSlot ~= "Ranged Offhand Weapon" or (itemStat.Slot ~= "Ranged Offhand Weapon" and itemStat.Slot ~= "Ranged Main Weapon")))
		then
			return
		end

		local itemGroup = resultGroup:AddChildWindow(itemTemplate.Name)
		itemGroup.Size = { imageSize * 1.5, imageSize * 2 }
		itemGroup.ChildAlwaysAutoResize = true
		itemGroup.SameLine = rowCount <= numPerRow

		local icon = itemGroup:AddImageButton(itemTemplate.Name, itemTemplate.Icon, { imageSize, imageSize })
		if icon.Image.Icon == "" then
			icon:Destroy()
			icon = itemGroup:AddImageButton(itemTemplate.Name, "Item_Unknown", { imageSize, imageSize })
		end
		icon.SameLine = true
		icon.Background = { 0, 0, 0, 1 }

		itemGroup:AddText(templateName).TextWrapPos = 150

		BuildStatusTooltip(icon:Tooltip(), itemStat, itemTemplate)

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
end

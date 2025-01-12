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
					and (stat.ObjectCategory == "Dye")
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

DyePicker = {}

---@type ExtuiWindow?
local searchWindow

local searchResultsCache = {}
local useCache

--- TODO: Rewrite all this since it got super messy with favorites
---@param itemTemplate ItemTemplate
---@param slot ActualSlot
---@param onSelectFunc function
function DyePicker:PickDye(itemTemplate, slot, onSelectFunc)
	if not next(rootsByName) then
		populateTemplateTable()
	end

	if not searchWindow then
		searchWindow = Ext.IMGUI.NewWindow("Dye Picker")
		searchWindow.Closeable = true
	else
		if not searchWindow.Open then
			searchWindow.Open = true
		end
		for _, child in pairs(searchWindow.Children) do
			child:Destroy()
		end
	end
	searchWindow.OnClose = function()
		Ext.ClientNet.PostMessageToServer(ModuleUUID .. "_StopPreviewingDye", slot)
		useCache = false
		searchResultsCache = {}
	end

	searchWindow:AddSeparatorText(string.format("Searching for %s Dyes", slot)):SetStyle("SeparatorTextAlign", 0.5)

	---@type ExtuiGroup?
	local activeDyeGroup

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
	local favoritesHeader = searchWindow:AddCollapsingHeader("Favorites")
	favoritesHeader:AddNewLine()

	searchWindow:AddSeparator()
	local resultTable = searchWindow:AddTable("Dyes", 2)
	resultTable.NoSavedSettings = true
	resultTable:AddColumn("Dyes", "WidthFixed")
	resultTable:AddColumn("Information", "WidthStretch")

	local row = resultTable:AddRow()
	local dyeCell = row:AddCell()
	-- Child window isn't resizing according to its contents, aboslutely no idea why, i'm extremely tired of spending time on it
	-- I want the scroll just for this column, not the whole table, so i need it to be a child window.
	dyeCell:AddText("                                                                    ")
	local dyeWindow = dyeCell:AddChildWindow("DyeResults")
	dyeWindow.NoSavedSettings = true

	local infoCell = row:AddCell()

	local function displayResult(templateName, buildingFavorite)
		if not useCache and not buildingFavorite then
			table.insert(searchResultsCache, templateName)
		end

		local dyeTemplate = rootsByName[templateName]

		---@type ResourceMaterialPresetResource
		local materialPreset = Ext.Resource.Get(dyeTemplate.ColorPreset, "MaterialPreset")

		local isFavorited, favoriteIndex = TableUtils:ListContains(ConfigurationStructure.config.vanity.settings.dyes.favorites, dyeTemplate.Id)
		if not buildingFavorite or isFavorited then
			local targetSection = buildingFavorite and favoritesHeader or dyeWindow

			local favoriteButton = targetSection:AddImageButton("Favorite" .. templateName, isFavorited and "star_fileld" or "star_empty", { 26, 26 })
			favoriteButton.Background = { 0, 0, 0, 0.5 }
			favoriteButton:SetColor("Button", { 0, 0, 0, 0.5 })
			favoriteButton.SameLine = buildingFavorite or false

			local dyeImageButton = targetSection:AddImageButton(templateName, dyeTemplate.Icon, { 64, 64 })
			dyeImageButton.UserData = materialPreset.Guid
			dyeImageButton.SameLine = true
			dyeImageButton.Background = { 0, 0, 0, 0.5 }

			if not buildingFavorite then
				targetSection:AddText(templateName).SameLine = true
			else
				dyeImageButton:Tooltip():AddText("\t " .. templateName)
			end

			dyeImageButton.OnClick = function()
				if activeDyeGroup then
					activeDyeGroup:Destroy()
				end
				local dyeInfoGroup = infoCell:AddGroup(templateName .. slot .. "dye")

				---@type Object
				local dyeStat = Ext.Stats.Get(dyeTemplate.Stats)
				local modInfo = Ext.Mod.GetMod(dyeStat.ModId)

				dyeInfoGroup:AddSeparatorText(templateName)
				dyeInfoGroup:AddText(string.format("From '%s' by '%s'", modInfo.Info.Name, modInfo.Info.Author ~= '' and modInfo.Info.Author or "Larian"))
					:SetColor("Text", { 1, 1, 1, 0.5 })

				dyeInfoGroup:AddButton("Select").OnClick = function()
					activeDyeGroup = nil
					Ext.ClientNet.PostMessageToServer(ModuleUUID .. "_StopPreviewingDye", slot)
					onSelectFunc(dyeTemplate)
					searchWindow.Open = false
					searchWindow:Destroy()
					searchWindow = nil
				end
				dyeInfoGroup:AddSeparator()

				---@type ResourcePresetDataVector3Parameter[]
				local materialColorParams = {}
				for _, setting in pairs(Ext.Resource.Get(dyeImageButton.UserData, "MaterialPreset").Presets.Vector3Parameters) do
					table.insert(materialColorParams, setting)
				end
				table.sort(materialColorParams, function(a, b)
					return a.Parameter < b.Parameter
				end)

				local dyeTable = dyeInfoGroup:AddTable(templateName, 2)
				dyeTable.SizingStretchProp = true

				for _, colorSetting in pairs(materialColorParams) do
					if colorSetting.Color then
						local dyeRow = dyeTable:AddRow()
						dyeRow:AddCell():AddText(colorSetting.Parameter)
						if colorSetting.Enabled then
							dyeRow:AddCell():AddColorEdit("", colorSetting.Value).ItemReadOnly = true
						else
							dyeRow:AddCell():AddText("---")
						end
					end
				end

				activeDyeGroup = dyeInfoGroup
				Ext.ClientNet.PostMessageToServer(ModuleUUID .. "_PreviewDye", Ext.Json.Stringify({
					materialPreset = dyeImageButton.UserData,
					slot = slot
				}))
			end

			favoriteButton.OnClick = function()
				if not isFavorited then
					table.insert(ConfigurationStructure.config.vanity.settings.dyes.favorites, dyeTemplate.Id)
				else
					table.remove(ConfigurationStructure.config.vanity.settings.dyes.favorites, favoriteIndex)
				end
				useCache = true
				DyePicker:PickDye(itemTemplate, slot, onSelectFunc)
			end
		end
	end
	--#endregion
	for _, templateName in pairs(sortedTemplateNames) do
		if not string.find(templateName, "FOCUSDYES_MiraculousDye") and (not useCache or TableUtils:ListContains(searchResultsCache, templateName)) then
			displayResult(templateName)
		end
		displayResult(templateName, true)
	end

	getAllForModCombo.OnChange = function()
		activeDyeGroup = nil
		searchResultsCache = {}
		useCache = false

		for _, child in pairs(dyeWindow.Children) do
			child:Destroy()
		end

		for _, child in pairs(infoCell.Children) do
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
			activeDyeGroup = nil
			searchResultsCache = {}
			useCache = false

			for _, child in pairs(dyeWindow.Children) do
				child:Destroy()
			end

			for _, child in pairs(infoCell.Children) do
				child:Destroy()
			end

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

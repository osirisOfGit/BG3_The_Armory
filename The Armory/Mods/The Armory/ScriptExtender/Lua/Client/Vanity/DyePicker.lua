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

populateTemplateTable()

DyePicker = {}

---@type DyePayload
local dyePayload = {}

---@type ExtuiGroup?
local activeDyeGroup

---@param itemTemplate ItemTemplate
---@param slot ActualSlot
---@param dyeButton ExtuiImageButton
function DyePicker:PickDye(itemTemplate, slot, dyeButton)
	local searchWindow = Ext.IMGUI.NewWindow(string.format("Searching for %s Dyes", slot))
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
	searchWindow:AddSeparator()
	local resultTable = searchWindow:AddTable(dyeButton.Label, 2)
	resultTable:AddColumn("Dyes", "WidthFixed")
	resultTable:AddColumn("Information", "WidthStretch")
	local row = resultTable:AddRow()
	local dyeCell = row:AddCell()
	local infoCell = row:AddCell()

	local function displayResult(templateName)
		local dyeTemplate = rootsByName[templateName]

		---@type ResourceMaterialPresetResource
		local materialPreset = Ext.Resource.Get(dyeTemplate.ColorPreset, "MaterialPreset")

		local dyeImageButton = dyeCell:AddImageButton(templateName, dyeTemplate.Icon, { 32, 32 })
		dyeImageButton.UserData = materialPreset.Guid
		dyeCell:AddText(templateName).SameLine = true

		local dyeInfoGroup = infoCell:AddGroup(templateName)
		dyeInfoGroup.Visible = false

		---@type Object
		local dyeStat = Ext.Stats.Get(dyeTemplate.Stats)
		local modInfo = Ext.Mod.GetMod(dyeStat.ModId)

		dyeInfoGroup:AddSeparatorText(templateName)
		dyeInfoGroup:AddText(string.format("From '%s' by '%s'", modInfo.Info.Name, modInfo.Info.Author ~= '' and modInfo.Info.Author or "Larian")):SetColor("Text", { 1, 1, 1, 0.5 })
		dyeInfoGroup:AddButton("Select").OnClick = function()
			Ext.ClientNet.PostMessageToServer(ModuleUUID .. "_StopPreviewingDye", slot)
			dyeButton.UserData = dyeTemplate
			searchWindow.OnClose()
			searchWindow.Open = false
		end
		dyeInfoGroup:AddSeparator()

		---@type ResourcePresetDataVector3Parameter[]
		local materialColorParams = {}
		for _, setting in pairs(materialPreset.Presets.Vector3Parameters) do
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

		dyeImageButton.OnClick = function()
			if activeDyeGroup then
				activeDyeGroup.Visible = false
			end
			activeDyeGroup = dyeInfoGroup
			dyeInfoGroup.Visible = true
			dyePayload = {
				materialPreset = dyeImageButton.UserData,
				slot = slot
			}
			Ext.ClientNet.PostMessageToServer(ModuleUUID .. "_PreviewDye", Ext.Json.Stringify(dyePayload))
		end
	end
	--#endregion
	for _, templateName in pairs(sortedTemplateNames) do
		displayResult(templateName)
	end

	getAllForModCombo.OnChange = function()
		activeDyeGroup = nil

		for _, child in pairs(dyeCell.Children) do
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
			for _, child in pairs(dyeCell.Children) do
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
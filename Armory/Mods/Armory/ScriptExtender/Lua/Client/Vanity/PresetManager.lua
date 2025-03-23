Ext.Require("Client/_FormBuilder.lua")

VanityPresetManager = {}
VanityPresetManager.userName = ""

Ext.RegisterNetListener(ModuleUUID .. "UserName", function(channel, payload, userID)
	VanityPresetManager.username = payload
end)

---@type ExtuiWindow
local presetWindow

---@type ExtuiGroup
local userPresetSection

---@type ExtuiGroup
local modPresetSection

---@type ExtuiChildWindow
local presetInfoSection

---@type ExtuiGroup?
local presetActivelyViewing

---@param parent ExtuiTreeParent
---@param forPresetId string?
local function buildPresetForm(parent, forPresetId)
	---@type VanityPreset?
	local preset
	if forPresetId then
		preset = ConfigurationStructure.config.vanity.presets[forPresetId]
	end

	FormBuilder:CreateForm(parent, function(values)
			local presetID = forPresetId or FormBuilder:generateGUID()

			values.Outfits = preset and ConfigurationStructure:GetRealConfigCopy().vanity.presets[forPresetId].Outfits or {}

			if ConfigurationStructure.config.vanity.presets[presetID] then
				ConfigurationStructure.config.vanity.presets[presetID].delete = true
			end

			ConfigurationStructure.config.vanity.presets[presetID] = values

			parent.Visible = false
			VanityPresetManager:UpdatePresetView(presetID)
		end,
		{
			{
				label = "Author",
				defaultValue = preset and preset.Author or VanityPresetManager.username,
				type = "Text",
				errorMessageIfEmpty = "This is a required field",
			},
			{
				label = "Name",
				defaultValue = preset and preset.Name or nil,
				type = "Text",
				errorMessageIfEmpty = "This is a required field",
			},
			{
				label = "Version",
				defaultValue = preset and preset.Version or "1.0.0",
				type = "Text",
				errorMessageIfEmpty = "This is a required field",
			},
			{
				label = "NSFW",
				defaultValue = preset and preset.NSFW or true,
				type = "Checkbox",
			}
		}
	)
end

function VanityPresetManager:OpenManager()
	if presetWindow then
		presetWindow.Open = true
		presetWindow:SetFocus()
		VanityPresetManager:UpdatePresetView()
	elseif not presetWindow then
		Ext.Net.PostMessageToServer(ModuleUUID .. "UserName", "")
		presetWindow = Ext.IMGUI.NewWindow("Vanity Preset Manager")
		presetWindow.Closeable = true

		local createNewPresetButton = presetWindow:AddButton("Create a New Preset")
		local presetForm = presetWindow:AddGroup("NewPresetForm")
		presetForm.Visible = false

		createNewPresetButton.OnClick = function()
			buildPresetForm(presetForm)
			presetForm.Visible = not presetForm.Visible
		end

		local presetTable = presetWindow:AddTable("PresetTable", 2)
		presetTable.NoSavedSettings = true

		presetTable:AddColumn("PresetSelection", "WidthFixed")
		presetTable:AddColumn("PresetInfo", "WidthStretch")

		local row = presetTable:AddRow()

		local selectionCell = row:AddCell():AddChildWindow("UserPresets")
		selectionCell.NoSavedSettings = true
		selectionCell:SetSizeConstraints({ 200, 0 })
		presetTable.ColumnDefs[1].Width = 200

		userPresetSection = selectionCell:AddGroup("User_Presets")
		local userHeader = userPresetSection:AddSeparatorText("Your Presets")
		userHeader:SetStyle("SeparatorTextAlign", 0.5)
		userHeader.Font = "Large"
		userHeader.UserData = "keep"

		selectionCell:AddNewLine()
		modPresetSection = selectionCell:AddGroup("Mod-Provided_Presets")
		local modHeader = modPresetSection:AddSeparatorText("Mod Presets")
		modHeader:SetStyle("SeparatorTextAlign", 0.5)
		modHeader.Font = "Large"
		modHeader.UserData = "keep"

		presetInfoSection = row:AddCell():AddChildWindow("Preset Information")
		presetInfoSection.NoSavedSettings = true
		presetInfoSection.HorizontalScrollbar = true

		VanityPresetManager:UpdatePresetView()
	end
end

---@param preset VanityPreset
---@param parent ExtuiTreeParent
local function buildDependencyTable(preset, parent)
	local cachedDeps = {
		dye = {},
		equipment = {}
	}

	for _, outfitSlot in pairs(preset.Outfits) do
		for _, vanityOutfit in pairs(outfitSlot) do
			if vanityOutfit.dye and vanityOutfit.dye.modDependency then
				if not cachedDeps[vanityOutfit.dye.modDependency.Guid] then
					table.insert(cachedDeps.dye, vanityOutfit.dye.modDependency)
					cachedDeps[vanityOutfit.dye.modDependency.Guid] = true
				end
			end
			if vanityOutfit.equipment and vanityOutfit.equipment.modDependency then
				if not cachedDeps[vanityOutfit.equipment.modDependency.Guid] then
					table.insert(cachedDeps.equipment, vanityOutfit.equipment.modDependency)
					cachedDeps[vanityOutfit.equipment.modDependency.Guid] = true
				end
			end
			if vanityOutfit.weaponTypes then
				for _, weaponSlot in pairs(vanityOutfit.weaponTypes) do
					if weaponSlot.equipment.modDependency and not cachedDeps[weaponSlot.equipment.modDependency.Guid] then
						table.insert(cachedDeps.equipment, weaponSlot.equipment.modDependency)
						cachedDeps[weaponSlot.equipment.modDependency.Guid] = true
					end
				end
			end
		end
	end

	---@param a ModDependency
	---@param b ModDependency
	table.sort(cachedDeps.dye, function(a, b)
		return a.Guid < b.Guid
	end)

	---@param a ModDependency
	---@param b ModDependency
	table.sort(cachedDeps.equipment, function(a, b)
		return a.Guid < b.Guid
	end)

	---@param key string
	---@param modlist ModDependency[]
	local function buildDependencyTab(key, modlist)
		parent:AddSeparatorText(key .. " Dependencies"):SetStyle("SeparatorTextAlign", 0.1)

		local dependencyTable = parent:AddTable(key .. preset.Name .. preset.Author, 4)
		dependencyTable.PreciseWidths = true
		dependencyTable.SizingStretchProp = true

		local headerRow = dependencyTable:AddRow()
		headerRow.Headers = true
		headerRow:AddCell():AddText("Name")
		headerRow:AddCell():AddText("Author")
		headerRow:AddCell():AddText("Version")

		for _, modDependency in ipairs(modlist) do
			local mod = Ext.Mod.GetMod(modDependency.Guid)

			if mod and mod.Info.Author ~= '' then
				local modRow = dependencyTable:AddRow()

				local nameText = modRow:AddCell():AddText(mod and mod.Info.Name or "Unknown - Mod Not Loaded")
				nameText.TextWrapPos = 0
				local authorText = modRow:AddCell():AddText(mod and (mod.Info.Author ~= '' and mod.Info.Author or "Larian") or "Unknown")
				authorText.TextWrapPos = 0

				if not mod then
					nameText:SetColor("Text", { 1, 0.02, 0, 1 })
					authorText:SetColor("Text", { 1, 0.02, 0, 1 })
				end

				modRow:AddCell():AddText(table.concat(modDependency.Version, "."))
			end
		end
	end

	buildDependencyTab("Dye", cachedDeps.dye)
	parent:AddNewLine()
	buildDependencyTab("Equipment", cachedDeps.equipment)
end

function VanityPresetManager:UpdatePresetView(presetID)
	Helpers:KillChildren(userPresetSection)

	if presetActivelyViewing then
		presetActivelyViewing:Destroy()
		presetActivelyViewing = nil
	end

	local activePreset = Ext.Vars.GetModVariables(ModuleUUID).ActivePreset
	for guid, preset in TableUtils:OrderedPairs(ConfigurationStructure.config.vanity.presets, function(key)
		return ConfigurationStructure.config.vanity.presets[key].Name
	end) do
		if preset.SFW then
			preset.NSFW = preset.SFW
			preset.SFW = nil
		end

		-- userPresetSection:AddImageButton("Synced" .. guid, "ico_btn_load_d", {32, 32}).UserData = "keep"
		-- userPresetSection:AddImageButton("Synced" .. guid, "ico_cancel_h", {32, 32}).UserData = "keep"

		---@type ExtuiSelectable
		local presetSelectable = userPresetSection:AddSelectable(preset.Name)
		presetSelectable.UserData = "select"
		presetSelectable.SameLine = true
		presetSelectable.IDContext = guid

		presetSelectable.OnClick = function()
			if presetActivelyViewing then
				presetActivelyViewing:Destroy()
			end

			for _, selectable in pairs(userPresetSection.Children) do
				if selectable.Handle ~= presetSelectable.Handle and selectable.UserData == "select" then
					selectable.Selected = false
				end
			end

			local presetGroup = presetInfoSection:AddGroup(guid)
			presetActivelyViewing = presetGroup

			if activePreset ~= guid then
				presetGroup:AddButton("Activate (Save After)").OnClick = function()
					Vanity:ActivatePreset(guid)
					VanityPresetManager:UpdatePresetView(guid)
					presetWindow.Open = false
				end
			else
				presetGroup:AddButton("Deactivate (Save After)").OnClick = function()
					Vanity:ActivatePreset()
					VanityPresetManager:UpdatePresetView(guid)
				end
			end

			presetGroup:AddButton("Duplicate").OnClick = function()
				local newGuid = FormBuilder:generateGUID()
				ConfigurationStructure.config.vanity.presets[newGuid] = TableUtils:DeeplyCopyTable(ConfigurationStructure:GetRealConfigCopy().vanity.presets[guid])
				ConfigurationStructure.config.vanity.presets[newGuid].Name = ConfigurationStructure.config.vanity.presets[newGuid].Name .. " (Copy)"
				VanityPresetManager:UpdatePresetView(presetID)
			end

			presetGroup:AddButton("Delete").OnClick = function()
				ConfigurationStructure.config.vanity.presets[guid].delete = true
				VanityPresetManager:UpdatePresetView()
				if activePreset == guid then
					Vanity:ActivatePreset()
				end
			end

			local editButton = presetGroup:AddButton("Edit Info")

			local infoGroup = presetGroup:AddGroup("info")
			infoGroup:AddText("Name: " .. preset.Name)
			infoGroup:AddText("Author: " .. preset.Author)
			infoGroup:AddText("Version: " .. preset.Version)
			infoGroup:AddText("Contains Skimpy Outfits/Nudity? " .. (preset.NSFW and "Yes" or "No"))

			editButton.OnClick = function()
				if editButton.UserData then
					VanityPresetManager:UpdatePresetView(guid)
				else
					editButton.UserData = true
					buildPresetForm(infoGroup, guid)
				end
			end

			--#region Validation
			VanityModManager:DependencyValidator(preset, function()
				return presetGroup
			end)
			--#endregion

			--#region Custom Dependencies
			presetGroup:AddNewLine()
			local customDependencyHeader = presetGroup:AddCollapsingHeader("Custom Dependencies")
			local customDependencyButton = customDependencyHeader:AddButton("Add Custom Dependency")

			local customDepFormGroup = customDependencyHeader:AddGroup("CustomDependencyForm")
			customDepFormGroup.Visible = false

			---@param existingCustomDependency ModDependency?
			local function buildCustomDepForm(existingCustomDependency)
				FormBuilder:CreateForm(customDepFormGroup,
					function(results)
						customDepFormGroup.Visible = false

						local versionString = results["Version"]
						results["Version"] = {}
						for versionPart in string.gmatch(versionString, "[^%.]+") do
							table.insert(results["Version"], versionPart)
						end

						if not preset.CustomDependencies then
							preset.CustomDependencies = {}
						end

						if existingCustomDependency then
							existingCustomDependency["Version"].delete = true
							for key, value in pairs(results) do
								existingCustomDependency[key] = value
							end
						else
							table.insert(preset.CustomDependencies, results)
						end
						VanityPresetManager:UpdatePresetView(presetID)
					end,
					{
						{
							["label"] = "Name",
							["type"] = "Text",
							["errorMessageIfEmpty"] = "Required Field",
							["defaultValue"] = existingCustomDependency and existingCustomDependency.Name
						},
						{
							["label"] = "Minimum Version",
							["propertyField"] = "Version",
							["type"] = "NumericText",
							["errorMessageIfEmpty"] = "Required Field",
							["defaultValue"] = existingCustomDependency and table.concat(existingCustomDependency.Version, ".")
						},
						{
							["label"] = "UUID",
							["propertyField"] = "Guid",
							["type"] = "Text",
							["defaultValue"] = existingCustomDependency and existingCustomDependency.Guid
						},
						{
							["label"] = "UUIDs of Packaged Resources (i.e Classes, MultiEffect Info) - One UUID Per Line",
							["propertyField"] = "Resources",
							["type"] = "Multiline",
							["defaultValue"] = existingCustomDependency and existingCustomDependency.Resources,
						},
						{
							["label"] = "Notes",
							["type"] = "Multiline",
							["defaultValue"] = existingCustomDependency and existingCustomDependency.Notes
						},
					})
			end
			buildCustomDepForm()

			customDependencyButton.OnClick = function()
				customDepFormGroup.Visible = not customDepFormGroup.Visible
			end

			if preset.CustomDependencies and preset.CustomDependencies() then
				local customDependencyTable = customDependencyHeader:AddTable("CustomDependency", 6)
				customDependencyTable.Resizable = true

				local headerRow = customDependencyTable:AddRow()
				headerRow.Headers = true
				headerRow:AddCell():AddText("Name")
				headerRow:AddCell():AddText("Minimum Version")
				headerRow:AddCell():AddText("UUID")
				headerRow:AddCell():AddText("Packaged Resource UUIDs")
				headerRow:AddCell():AddText("Notes")

				for index, customDependency in TableUtils:OrderedPairs(preset.CustomDependencies, function(key)
					return preset.CustomDependencies[key].Name
				end) do
					local row = customDependencyTable:AddRow()

					local nameCell = row:AddCell()
					nameCell:AddText(customDependency.Name)

					row:AddCell():AddText(table.concat(customDependency.Version, "."))
					row:AddCell():AddText(customDependency.Guid or "---")
					row:AddCell():AddText(customDependency.Resources)
					row:AddCell():AddText(customDependency.Notes)

					if customDependency.Guid and customDependency.Guid ~= "" then
						local modInfo = Ext.Mod.GetMod(customDependency.Guid)
						if not modInfo then
							local warningImage = nameCell:AddImage("tutorial_warning_yellow", {32, 32})
							warningImage.SameLine = true
							warningImage:Tooltip():AddText("\t Provided GUID is not loaded in the current game - this may or may not be expected, depending on the nature of the mod")
						end
					end

					local actionCell = row:AddCell()
					actionCell:AddButton("Edit").OnClick = function()
						buildCustomDepForm(customDependency)
						customDepFormGroup.Visible = true
					end

					local deleteButton = actionCell:AddButton("X")
					deleteButton.SameLine = true
					deleteButton:SetColor("Button", { 0.6, 0.02, 0, 0.5 })
					deleteButton:SetColor("Text", { 1, 1, 1, 1 })
					deleteButton.OnClick = function()
						preset.CustomDependencies[index].delete = true
						VanityPresetManager:UpdatePresetView(presetID)
					end
				end
			end

			--#endregion
			presetGroup:AddNewLine()
			local swapViewButton = presetGroup:AddImageButton("swap_view", "ico_randomize_d", { 32, 32 })
			swapViewButton:Tooltip():AddText("\t Swap between Overall and Per-Outfit view")

			local generalSettings = ConfigurationStructure.config.vanity.settings.general

			local outfitsAndDependenciesGroup = presetGroup:AddGroup("OutfitsAndDeps")
			local function swapView()
				Helpers:KillChildren(outfitsAndDependenciesGroup)

				if generalSettings.outfitAndDependencyView == "universal" then
					outfitsAndDependenciesGroup:AddSeparatorText("Configured Outfits")
					VanityCharacterCriteria:BuildConfiguredCriteriaCombinationsTable(preset, outfitsAndDependenciesGroup)
					outfitsAndDependenciesGroup:AddNewLine()
					outfitsAndDependenciesGroup:AddSeparatorText("Mod Dependencies")
					buildDependencyTable(preset, outfitsAndDependenciesGroup)
				else
					outfitsAndDependenciesGroup:AddSeparatorText("Outfit Report")
					VanityModManager:BuildOutfitDependencyReport(preset, nil, outfitsAndDependenciesGroup)
				end
			end
			swapView()

			swapViewButton.OnClick = function()
				generalSettings.outfitAndDependencyView = generalSettings.outfitAndDependencyView == "universal" and "perOutfit" or "universal"
				swapView()
			end
		end

		if (not presetID and guid == activePreset) or presetID == guid then
			presetSelectable.OnClick()
			presetSelectable.Selected = true
		end
	end
end

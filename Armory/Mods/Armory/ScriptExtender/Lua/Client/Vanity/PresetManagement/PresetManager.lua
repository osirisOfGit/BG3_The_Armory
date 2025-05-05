Ext.Require("Client/_FormBuilder.lua")
Ext.Require("Shared/Vanity/ModPresetManager.lua")
Ext.Require("Client/Vanity/PresetManagement/ExportManager.lua")
Ext.Require("Client/Vanity/PresetManagement/BackupManager.lua")
Ext.Require("Client/Vanity/PresetManagement/ModDependencyManager.lua")

ServerPresetManager = {}
ServerPresetManager.userName = ""

---@type ExtuiWindow
local presetWindow

---@type ExtuiGroup
local userPresetSection

---@type ExtuiGroup
local otherUsersSection

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
			ServerPresetManager:UpdatePresetView(presetID)
		end,
		{
			{
				label = "Author",
				defaultValue = preset and preset.Author or ServerPresetManager.username,
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

function ServerPresetManager:OpenManager()
	if presetWindow then
		presetWindow.Open = true
		presetWindow:SetFocus()
		ServerPresetManager:UpdatePresetView()
	elseif not presetWindow then
		Channels.GetUserName:RequestToServer({}, function(data)
			self.userName = data.username
		end)

		presetWindow = Ext.IMGUI.NewWindow(Translator:translate("Vanity Preset Manager"))
		presetWindow.Closeable = true
		presetWindow:SetStyle("WindowMinSize", 250, 850)

		presetWindow.MenuBar = true
		local menu = presetWindow:AddMainMenu()
		---@type ExtuiMenu
		local presetMenu = menu:AddMenu(Translator:translate("Manage Presets"))

		---@type ExtuiSelectable
		local createNewPresetButton = presetMenu:AddSelectable(Translator:translate("Create"))
		---@type ExtuiSelectable
		local openExportManagerButton = presetMenu:AddSelectable(Translator:translate("Export"))
		---@type ExtuiSelectable
		local importPresetsFromFileButton = presetMenu:AddSelectable(Translator:translate("Import"))

		openExportManagerButton.OnClick = function()
			openExportManagerButton.Selected = false
			VanityExportManager:BuildExportManagerWindow()
		end

		importPresetsFromFileButton.OnClick = function()
			importPresetsFromFileButton.Selected = false
			VanityExportManager:BuildImportManagerWindow()
		end

		local presetForm = presetWindow:AddGroup("NewPresetForm")
		presetForm.Visible = false

		createNewPresetButton.OnClick = function()
			createNewPresetButton.Selected = false
			buildPresetForm(presetForm)
			presetForm.Visible = not presetForm.Visible
		end

		Channels.GetActiveUserPreset:RequestToServer({}, function(data)
			local presetId = data.presetId
			if not presetId and not ConfigurationStructure.config.vanity.presets() and not next(VanityModPresetManager.PresetModIndex) then
				createNewPresetButton.OnClick()
			end

			local presetTable = presetWindow:AddTable("PresetTable", 2)
			presetTable.Resizable = true

			presetTable:AddColumn("PresetSelection", "WidthFixed", 400 * Styler:ScaleFactor())
			presetTable:AddColumn("PresetInfo", "WidthStretch")

			local row = presetTable:AddRow()

			local selectionCell = row:AddCell():AddChildWindow("UserPresets")
			selectionCell.NoSavedSettings = true
			selectionCell:SetSizeConstraints({ 200, 0 })
			presetTable.ColumnDefs[1].Width = 0

			userPresetSection = selectionCell:AddGroup("User_Presets")
			local userHeader = userPresetSection:AddSeparatorText(Translator:translate("Your Presets"))
			userHeader:SetStyle("SeparatorTextAlign", 0.5)
			userHeader.Font = "Large"
			userHeader.UserData = "keep"

			otherUsersSection = selectionCell:AddGroup("Other_User_Presets")
			local otherUsersHeader = otherUsersSection:AddSeparatorText(Translator:translate("Other User's Presets"))
			otherUsersHeader:SetStyle("SeparatorTextAlign", 0.5)
			otherUsersHeader.Font = "Large"
			otherUsersHeader.UserData = "keep"

			selectionCell:AddNewLine()
			modPresetSection = selectionCell:AddGroup("Mod-Provided_Presets")
			local modHeader = modPresetSection:AddSeparatorText(Translator:translate("Mod Presets"))
			modHeader:SetStyle("SeparatorTextAlign", 0.5)
			modHeader.Font = "Large"
			modHeader.UserData = "keep"

			presetInfoSection = row:AddCell():AddChildWindow(Translator:translate("Preset Information"))
			presetInfoSection.NoSavedSettings = true
			presetInfoSection.HorizontalScrollbar = true

			VanityBackupManager:RestorePresetBackup()

			ServerPresetManager:UpdatePresetView()
		end)
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
		parent:AddSeparatorText(Translator:translate(key) .. " " .. Translator:translate("Dependencies")):SetStyle("SeparatorTextAlign", 0.1)

		local dependencyTable = parent:AddTable(key .. preset.Name .. preset.Author, 4)
		dependencyTable.PreciseWidths = true
		dependencyTable.SizingStretchProp = true

		local headerRow = dependencyTable:AddRow()
		headerRow.Headers = true
		headerRow:AddCell():AddText(Translator:translate("Name"))
		headerRow:AddCell():AddText(Translator:translate("Author"))
		headerRow:AddCell():AddText(Translator:translate("Version"))

		for _, modDependency in ipairs(modlist) do
			local mod = Ext.Mod.GetMod(modDependency.Guid)

			if mod and mod.Info.Author ~= '' then
				local modRow = dependencyTable:AddRow()

				local nameText = modRow:AddCell():AddText(mod and mod.Info.Name or Translator:translate("Unknown - Mod Not Loaded"))
				nameText.TextWrapPos = 0
				local authorText = modRow:AddCell():AddText(mod and (mod.Info.Author ~= '' and mod.Info.Author or "Larian") or Translator:translate("Unknown"))
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

function ServerPresetManager:UpdatePresetView(presetID)
	Helpers:KillChildren(userPresetSection)
	Helpers:KillChildren(modPresetSection)

	if presetActivelyViewing then
		presetActivelyViewing:Destroy()
		presetActivelyViewing = nil
	end

	local activePreset = Vanity.ActivePresetId

	---@param vanityContainer Vanity
	---@param presetCollection {[Guid]: VanityPreset}
	---@param externalOwner string?
	---@param parentSection ExtuiTreeParent
	local function buildSection(vanityContainer, presetCollection, externalOwner, parentSection)
		if externalOwner then
			parentSection:AddSeparator():SetColor("Separator", { 1, 1, 1, 0.6 })
			local sepText = parentSection:AddSeparatorText(externalOwner)
			sepText:SetStyle("SeparatorTextAlign", 0.5)
			sepText:SetColor("Text", { 1, 1, 1, 0.6 })
			parentSection:AddSeparator():SetColor("Separator", { 1, 1, 1, 0.6 })
		end

		for guid, preset in TableUtils:OrderedPairs(presetCollection, function(key)
			return presetCollection[key].Name
		end) do
			-- Only user presets can be backed up
			if not externalOwner then
				local isPresetInBackup = VanityBackupManager:IsPresetInBackup(guid)
				local syncButton = Styler:ImageButton(parentSection:AddImageButton("Synced" .. guid, isPresetInBackup and "ico_cloud" or "ico_cancel_h", { 26, 26 }))

				local tooltip = syncButton:Tooltip()
				tooltip:AddText(string.format(Translator:translate([[
	This preset %s backed up in all saves created for this campaign while this option is enabled (save after changing this option) - the backup for applicable presets will be updated when the Preset Manager window is opened (so launch this window to ensure all presets have the latest configs in the backup if you edited them in other saves) and for _active_ presets when a change is made in this campaign.

Backups will be restored when a save with the backup is loaded but the preset is not present in the local config.
Backup will be removed if this option is disabled or the preset is deleted via this UI
You can view the current backup state in a save by executing !Armory_Vanity_SeeBackedUpPresets and !Armory_Vanity_SeePresetBackupRegistry in the SE Console
]]),
					Translator:translate(isPresetInBackup and "is" or "is not"))).TextWrapPos = 1000


				syncButton.OnClick = function()
					VanityBackupManager:FlipPresetBackupRegistration(guid)
					ServerPresetManager:UpdatePresetView(guid)
				end
			end

			---@type ExtuiSelectable
			local presetSelectable = parentSection:AddSelectable(preset.Name)
			presetSelectable.UserData = "select"
			presetSelectable.SameLine = not externalOwner
			presetSelectable.IDContext = guid

			presetSelectable.OnClick = function()
				if presetActivelyViewing then
					presetActivelyViewing:Destroy()
				end

				for _, selectable in TableUtils:CombinedPairs(userPresetSection.Children, modPresetSection.Children) do
					if selectable.Handle ~= presetSelectable.Handle and selectable.UserData == "select" then
						selectable.Selected = false
					end
				end

				local presetGroup = presetInfoSection:AddGroup(guid)
				presetActivelyViewing = presetGroup

				-- Formatting the page into columns
				local metadataTable = presetGroup:AddTable("metadata", 3)
				metadataTable:AddColumn("", "WidthStretch")
				metadataTable:AddColumn("", "WidthFixed", 400 * Styler:ScaleFactor())
				metadataTable:AddColumn("", "WidthStretch")
				metadataTable.SizingStretchSame = true

				local titleRow = metadataTable:AddRow()
				titleRow:AddCell()
				local titleText = titleRow:AddCell():AddSelectable(preset.Name)
				-- There was no way of aligning pure text as of writing this
				titleText:SetStyle("SelectableTextAlign", 0.5)
				titleText.Disabled = true
				titleText.Font = "Large"
				titleRow:AddCell()

				local metadataRow = metadataTable:AddRow()
				metadataRow:AddCell()
				local metadataText = metadataRow:AddCell():AddSelectable(string.format("%s | v%s | %s", Translator:translate(preset.NSFW and "NSFW" or "SFW"), preset.Version,
					preset.Author))
				metadataText:SetStyle("SelectableTextAlign", 0.5)
				metadataText.Disabled = true
				metadataRow:AddCell()

				if not externalOwner and preset.ModSourced then
					local modRow = metadataTable:AddRow()
					modRow:AddCell()
					local mod = Ext.Mod.GetMod(preset.ModSourced.Guid)
					mod = mod and mod.Info or preset.ModSourced

					local text = modRow:AddCell():AddSelectable(string.format(Translator:translate("Copied from %s v%s by %s"), mod.Name,
						table.concat(mod.ModVersion or mod.Version, "."), mod.Author))
					text.Disabled = true
					text:SetStyle("SelectableTextAlign", 0.5)
					text:SetStyle("Alpha", 0.8)
				end

				local actionContainerRow = metadataTable:AddRow()
				actionContainerRow:AddCell()
				local actionContainer = actionContainerRow:AddCell()
				actionContainerRow:AddCell()

				local actionTable = actionContainer:AddTable("ActionTable", 3)
				actionTable:AddColumn("", "WidthStretch")
				actionTable:AddColumn("", "WidthFixed")
				actionTable:AddColumn("", "WidthStretch")
				local actionRow = actionTable:AddRow()
				actionRow:AddCell()
				local actionCell = actionRow:AddCell()
				actionRow:AddCell()

				local activateButton = Styler:ImageButton(
					actionCell:AddImageButton("Activate", activePreset ~= guid and "ico_active_button" or "ico_inactive_button", { 32, 32 })
				)

				if activePreset ~= guid then
					activateButton:Tooltip():AddText("\t  " .. Translator:translate("Activate this preset (deactivates the active preset if there is one)"))
					activateButton.OnClick = function()
						Vanity:ActivatePreset(guid)
						ServerPresetManager:UpdatePresetView(guid)
					end
				else
					activateButton:Tooltip():AddText("\t  " .. Translator:translate("Deactivate this preset"))
					activateButton.OnClick = function()
						Vanity:ActivatePreset()
						ServerPresetManager:UpdatePresetView(guid)
					end
				end

				if not externalOwner then
					local editButton = Styler:ImageButton(actionCell:AddImageButton("Edit", "ico_edit_d", { 32, 32 }))
					editButton:Tooltip():AddText("\t  " .. Translator:translate("Edit this preset's name/author/version/SFW flag"))
					editButton.SameLine = true

					local infoGroup = presetGroup:AddGroup("info")
					editButton.OnClick = function()
						if editButton.UserData then
							ServerPresetManager:UpdatePresetView(guid)
						else
							editButton.UserData = true
							buildPresetForm(infoGroup, guid)
						end
					end
				end

				local copyButton = Styler:ImageButton(actionCell:AddImageButton("Copy", "ico_copy_d", { 32, 32 }))
				copyButton:Tooltip():AddText(externalOwner and ("\t  " .. Translator:translate("Clone this preset into your local config, making a copy you can edit"))
					or ("\t  " .. Translator:translate("Duplicate this preset")))
				copyButton.SameLine = true
				copyButton.OnClick = function()
					local newGuid = FormBuilder:generateGUID()
					ConfigurationStructure.config.vanity.presets[newGuid] = TableUtils:DeeplyCopyTable(externalOwner and preset or
						ConfigurationStructure:GetRealConfigCopy().vanity.presets[guid])

					ConfigurationStructure.config.vanity.presets[newGuid].isExternalPreset = false

					if not externalOwner then
						ConfigurationStructure.config.vanity.presets[newGuid].Name = ConfigurationStructure.config.vanity.presets[newGuid].Name ..
							" " .. Translator:translate("(Copy)")
					end
					ServerPresetManager:UpdatePresetView(presetID)
				end

				if not externalOwner then
					local deleteButton = Styler:ImageButton(actionCell:AddImageButton("Delete", "ico_red_x", { 32, 32 }))
					deleteButton:Tooltip():AddText("\t  " .. Translator:translate("Delete this preset, deactivating first to remove active transmogs if it's active and removing it from the backup if enabled")).TextWrapPos = 600
					deleteButton.SameLine = true
					deleteButton.OnClick = function()
						if VanityBackupManager:IsPresetInBackup(guid) then
							VanityBackupManager:FlipPresetBackupRegistration(guid)
						end
						ConfigurationStructure.config.vanity.presets[guid].delete = true

						ServerPresetManager:UpdatePresetView()
						if activePreset == guid then
							Vanity:ActivatePreset()
						end
					end
				end

				VanityModDependencyManager:DependencyValidator(vanityContainer, preset, function()
					return presetGroup
				end)

				--#region Custom Dependencies
				presetGroup:AddNewLine()
				local customDependencyHeader = presetGroup:AddCollapsingHeader(Translator:translate("Custom Dependencies"))
				local customDependencyButton = customDependencyHeader:AddButton(Translator:translate("Add Custom Dependency"))
				customDependencyButton.Visible = not externalOwner

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
							ServerPresetManager:UpdatePresetView(presetID)
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

				if preset.CustomDependencies and (preset.__call and preset.CustomDependencies() or next(preset.CustomDependencies)) then
					local customDependencyTable = customDependencyHeader:AddTable("CustomDependency", 6)
					customDependencyTable.Resizable = true

					local headerRow = customDependencyTable:AddRow()
					headerRow.Headers = true
					headerRow:AddCell():AddText(Translator:translate("Name"))
					headerRow:AddCell():AddText(Translator:translate("Minimum Version"))
					headerRow:AddCell():AddText(Translator:translate("UUID"))
					headerRow:AddCell():AddText(Translator:translate("Packaged Resource UUIDs"))
					headerRow:AddCell():AddText(Translator:translate("Notes"))

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
								local warningImage = nameCell:AddImage("tutorial_warning_yellow", { 32, 32 })
								warningImage.SameLine = true
								warningImage:Tooltip():AddText(
									"\t  " ..
									Translator:translate("Provided GUID is not loaded in the current game - this may or may not be expected, depending on the nature of the mod"))
							end
						end

						if not externalOwner then
							local actionCell = row:AddCell()
							actionCell:AddButton("Edit").OnClick = function()
								buildCustomDepForm(customDependency)
								customDepFormGroup.Visible = true
							end

							local deleteButton = actionCell:AddButton(Translator:translate("X"))
							deleteButton.SameLine = true
							deleteButton:SetColor("Button", { 0.6, 0.02, 0, 0.5 })
							deleteButton:SetColor("Text", { 1, 1, 1, 1 })
							deleteButton.OnClick = function()
								preset.CustomDependencies[index].delete = true
								ServerPresetManager:UpdatePresetView(presetID)
							end
						end
					end
				end

				--#endregion
				presetGroup:AddNewLine()
				local swapViewButton = Styler:ImageButton(presetGroup:AddImageButton("swap_view", "ico_randomize_d", { 32, 32 }))
				swapViewButton:Tooltip():AddText("\t  " .. Translator:translate("Swap between Overall and Per-Outfit view"))

				local generalSettings = ConfigurationStructure.config.vanity.settings.general

				local outfitsAndDependenciesGroup = presetGroup:AddGroup("OutfitsAndDeps")
				local function swapView()
					Helpers:KillChildren(outfitsAndDependenciesGroup)

					if generalSettings.outfitAndDependencyView == "universal" then
						outfitsAndDependenciesGroup:AddSeparatorText(Translator:translate("Configured Outfits")):SetStyle("SeparatorTextAlign", 0.5)
						VanityCharacterCriteria:BuildConfiguredCriteriaCombinationsTable(preset, outfitsAndDependenciesGroup, nil,
							externalOwner and TableUtils:DeeplyCopyTable(VanityModPresetManager:GetPresetFromMod(guid).effects))
						outfitsAndDependenciesGroup:AddNewLine()
						outfitsAndDependenciesGroup:AddSeparatorText(Translator:translate("Mod Dependencies")):SetStyle("SeparatorTextAlign", 0.5)
						buildDependencyTable(preset, outfitsAndDependenciesGroup)
					else
						outfitsAndDependenciesGroup:AddSeparatorText(Translator:translate("Outfit Report")):SetStyle("SeparatorTextAlign", 0.5)
						VanityModDependencyManager:BuildOutfitDependencyReport(preset, nil, outfitsAndDependenciesGroup)
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

	buildSection(ConfigurationStructure.config.vanity, ConfigurationStructure.config.vanity.presets, nil, userPresetSection)

	Channels.GetUserPresetPool:RequestToServer({}, function(data)
		if next(data) then
			otherUsersSection.Visible = true

			for user, presetIds in pairs(data) do
				Channels.GetUserName:RequestToServer({ user = user }, function(data)
					Channels.GetAllPresets:RequestToClient({}, user, function(vanity)
						Logger:BasicInfo("Loading %s's presets", data.username)

						---@cast vanity Vanity
						buildSection(vanity, vanity.presets, data.username, otherUsersSection)
					end)
				end)
			end
		else
			otherUsersSection.Visible = false
		end
	end)

	VanityModPresetManager:ImportPresetsFromMods()
	if next(VanityModPresetManager.ModPresetIndex) then
		for modId, vanity in TableUtils:OrderedPairs(VanityModPresetManager.ModPresetIndex, function(key)
			return Ext.Mod.GetMod(key).Info.Name
		end) do
			buildSection(vanity, vanity.presets, Ext.Mod.GetMod(modId).Info.Name, modPresetSection)
		end
	else
		modPresetSection.Visible = false
	end
end

Channels.UpdateUserPreset:SetHandler(function (data, user)
	ServerPresetManager:UpdatePresetView(Vanity.ActivePresetId)

	if data.presetId == Vanity.ActivePresetId then
		Vanity:ActivatePreset(Vanity.ActivePresetId)
	end
end)

Channels.GetActiveUserPreset:SetRequestHandler(function(data, user)
	local vanity = VanityModPresetManager:GetPresetFromMod(data.presetId)
	if vanity then
		return vanity
	elseif ConfigurationStructure.config.vanity.presets[data.presetId] then
		return VanityExportManager:ExportPresets({ data.presetId })
	else
		return {}
	end
end)

Channels.GetAllPresets:SetRequestHandler(function(data, user)
	return ConfigurationStructure:GetRealConfigCopy().vanity
end)

Translator:RegisterTranslation({
	["This is a required field"] = "h2f93c88025444a8a8dc8692b89cd00749d82",
	["Author"] = "h0c775f4f9b1b4a8da184b42a54961e65gc0a",
	["Name"] = "h8cf4fc5072a14706bb86a7700e907395bb9d",
	["Version"] = "h0fbbbc8cc91342acb5f2618f7e516f02f784",
	["Vanity Preset Manager"] = "hfef14e1ed1e244da914d944ba1273dd77fga",
	["Manage Presets"] = "h36a65f42e9454d8e9d55db55acd77a17158e",
	["Create"] = "h02e16e4c68864e839f3e8051eaf2a2d9b04c",
	["Export"] = "he99b2e5a0ee74074a9958b5bfe5612f8558d",
	["Import"] = "h7bb0a4f461a54390804603cc81c72341633b",
	["Your Presets"] = "h9f20917d682d419cb126147a04f7cac54057",
	["Other User's Presets"] = "h7b69751666eb450598eceda1786653afecfc",
	["Mod Presets"] = "ha36a9cae681941d897becb20f0deb5873c5d",
	["Preset Information"] = "hec26e6f59bdb43eb85700c98e7a19143c347",
	["Dependencies"] = "hdf32fd262354456c9c1aec067af5220637bg",
	["Unknown - Mod Not Loaded"] = "hcc2a773852c04c058bbb400119a6d59b89d7",
	["Unknown"] = "ha9e7348b2fdf4b3c84d3e85d51bb7b828gge",
	["Equipment"] = "hd5230f18925447c48ae1aa25225548fe4gc2",
	[([[
	This preset %s backed up in all saves created for this campaign while this option is enabled (save after changing this option) - the backup for applicable presets will be updated when the Preset Manager window is opened (so launch this window to ensure all presets have the latest configs in the backup if you edited them in other saves) and for _active_ presets when a change is made in this campaign.

Backups will be restored when a save with the backup is loaded but the preset is not present in the local config.
Backup will be removed if this option is disabled or the preset is deleted via this UI
You can view the current backup state in a save by executing !Armory_Vanity_SeeBackedUpPresets and !Armory_Vanity_SeePresetBackupRegistry in the SE Console
]])] = "hdb1ccb583441428d9969cd8399a69f4fad93",
	["is"] = "hc866d5f99b614659a916d385a2a169ff4fba",
	["is not"] = "h655fa609aba94e4da173f288273bb164f327",
	["Copied from %s v%s by %s"] = "h56e8b2c4fe22439f872e50563cd22980475g",
	["Activate this preset (deactivates the active preset if there is one)"] = "h13cdd47ac7e042a899f01b53c16d7168500c",
	["Deactivate this preset"] = "h42ee9c3a84d24714948eba0228ed7332e1ab",
	["Edit this preset's name/author/version/SFW flag"] = "hd42726262de242a59fa8b101e7ae76a24cb6",
	["Clone this preset into your local config, making a copy you can edit"] = "hcfe9a7b1e464427ba15aaf9b84e1d1d945bf",
	["Duplicate this preset"] = "heebe64439a5148979d83ee0673ded21fc077",
	["(Copy)"] = "h42293f999b9949beaa6206ff558d630c8e12",
	["Delete this preset, deactivating first to remove active transmogs if it's active and removing it from the backup if enabled"] = "heb9024ee3f44462e8a590264854093def107",
	["Custom Dependencies"] = "hbd3ce5eb5269474da9bbcef2a47324a86772",
	["Add Custom Dependency"] = "h99ceff29985f4d5693aebbca0e79c0486959",
	["Required Field"] = "he4650ba63a7140ac8c8f0c4b571b8f68f343",
	["Minimum Version"] = "h5c0839d1f5ac4301868aa03ede57bd1cf191",
	["UUID"] = "h2fa625ee384f4a0e8316751b36c74a7ae781",
	["UUIDs of Packaged Resources (i.e Classes, MultiEffect Info) - One UUID Per Line"] = "h96f6254d6a5a4fc8b3c66fd1ae0fdf9bdg77",
	["Notes"] = "h24c4edbd963f4a9bbc2f4d687a55805ae561",
	["Packaged Resource UUIDs"] = "h5f891e61a23341f5a0006e2ff2fa4813f1a3",
	["Provided GUID is not loaded in the current game - this may or may not be expected, depending on the nature of the mod"] = "h1e0fd8dd3b4c4b74ac5f5612827665336cdb",
	["X"] = "h76c716ee29b14bed95b8ae32f030b812c5ac",
	["Swap between Overall and Per-Outfit view"] = "h2eb2e6ab9c57419b9b1a4e093a90f3d06d0g",
	["Configured Outfits"] = "h0a6eaeaa1fda45bfa725d97b81f4ea24b10f",
	["Mod Dependencies"] = "heaa77ab0ae33446b97b5ba4027a456e860c5",
	["Outfit Report"] = "hc92985c0bcec460f847ab891262ec4a15dec",
})

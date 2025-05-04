VanityExportManager = {}

VanityExportManager.ExportFilename = "Armory_Vanity_Mod_Presets.json"

---@param presetIds Guid[]
---@param existingExport Vanity?
---@param newIds boolean?
---@return Vanity?
function VanityExportManager:ExportPresets(presetIds, existingExport, newIds)
	if not next(presetIds) then
		return nil
	end

	local realConfig = ConfigurationStructure:GetRealConfigCopy()

	---@type Vanity
	local export = existingExport or {
		presets = {},
		effects = {},
		miscNameCache = {}
	}

	for _, presetId in pairs(presetIds) do
		local preset = realConfig.vanity.presets[presetId]

		for criteraKey, outfit in pairs(preset.Outfits) do
			local criteriaTable = ParseCriteriaCompositeKey(criteraKey)
			for _, resourceId in pairs(criteriaTable) do
				if realConfig.vanity.miscNameCache[resourceId] then
					export.miscNameCache[resourceId] = realConfig.vanity.miscNameCache[resourceId]
				end
			end

			for _, outfitSlot in pairs(outfit) do
				if outfitSlot.equipment and outfitSlot.equipment.effects then
					for _, effect in pairs(outfitSlot.equipment.effects) do
						export.effects[effect] = TableUtils:DeeplyCopyTable(realConfig.vanity.effects[effect])
					end
				end

				if outfitSlot.weaponTypes then
					for _, weaponSlot in pairs(outfitSlot.weaponTypes) do
						if weaponSlot.equipment and weaponSlot.equipment.effects then
							for _, effect in pairs(weaponSlot.equipment.effects) do
								export.effects[effect] = TableUtils:DeeplyCopyTable(realConfig.vanity.effects[effect])
							end
						end
					end
				end
			end
		end

		if newIds then
			presetId = FormBuilder:generateGUID()
		end

		export.presets[presetId] = preset
	end

	return export
end

---@param presetIds Guid[]
---@param exportToExtractFrom Vanity
---@param targetTable table?
function VanityExportManager:ImportPreset(presetIds, exportToExtractFrom, targetTable)
	---@type Vanity
	local vanityConfig = targetTable or ConfigurationStructure.config.vanity

	-- Since we modify the effect names on each piece of equipment if they already exist in the current config and are different resources
	exportToExtractFrom = TableUtils:DeeplyCopyTable(exportToExtractFrom)

	---@type Vanity
	---@diagnostic disable-next-line: missing-fields
	local tempVanity = {
		presets = {},
		effects = {},
		miscNameCache = {}
	}

	for _, presetId in ipairs(presetIds) do
		local preset = exportToExtractFrom.presets[presetId]

		for criteraKey, outfit in pairs(preset.Outfits) do
			local criteriaTable = ParseCriteriaCompositeKey(criteraKey)
			for _, resourceId in pairs(criteriaTable) do
				if exportToExtractFrom.miscNameCache[resourceId] then
					tempVanity.miscNameCache[resourceId] = exportToExtractFrom.miscNameCache[resourceId]
				end
			end

			VanityEffect:CopyEffectsToPresetOutfit(tempVanity, preset.Name, outfit, exportToExtractFrom.effects, targetTable == nil)

			tempVanity.presets[presetId] = preset
		end
	end

	for resourceId, cachedName in pairs(tempVanity.miscNameCache) do
		if not vanityConfig.miscNameCache[resourceId] then
			vanityConfig.miscNameCache[resourceId] = cachedName
		end
	end

	for effectName, effect in pairs(tempVanity.effects) do
		if not vanityConfig.effects[effectName] then
			vanityConfig.effects[effectName] = effect
		end
	end

	for presetId, preset in pairs(tempVanity.presets) do
		vanityConfig.presets[presetId] = preset
		Logger:BasicInfo("Restored preset '%s' from export", preset.Name)
	end
end

---@type ExtuiWindow
local exportWindow = nil

function VanityExportManager:BuildExportManagerWindow()
	if not exportWindow then
		exportWindow = Ext.IMGUI.NewWindow(Translator:translate("Preset Export Manager"))
		exportWindow.Closeable = true
		exportWindow.AlwaysAutoResize = true
	else
		exportWindow.Open = true
		exportWindow:SetFocus()
	end

	Helpers:KillChildren(exportWindow)

	local header = exportWindow:AddText(Translator:translate("Export Presets"))
	header.Font = "Large"

	exportWindow:AddText(
		"Selected presets will be exported to %localappdata%\\Larian Studios\\Baldur's Gate 3\\Script Extender\\Armory\\Armory_Vanity_Presets.json").TextWrapPos = 0

	exportWindow:AddText(Translator:translate([[
This file can then be packaged with any mod by placing it next to the meta.lsx or be manually sent to users for them to place in the same location
Active mods containing this file will automatically be read in by Armory and displayed under the 'Mod Presets' section of the Preset Manager. Users can manually import this file if present on their machine via the menu option within the Preset Manager
When exporting presets, an existing file will be completely overwritten with the chosen presets
]])).TextWrapPos = 800

	exportWindow:AddSeparator()

	local selectionGroup = exportWindow:AddGroup("SelectionGroup")

	local exportButton = exportWindow:AddButton(Translator:translate("Export"))

	local successText = exportWindow:AddText(Translator:translate("Preset(s) successfully exported!"))
	successText.Visible = false
	successText:SetColor("Text", { 144 / 255, 238 / 255, 144 / 255, 1 })

	local errorText = exportWindow:AddText(Translator:translate("File failed to save - check logs"))
	errorText.Visible = false
	errorText:SetColor("Text", { 1, 0.02, 0, 1 })

	for presetId, preset in TableUtils:OrderedPairs(ConfigurationStructure.config.vanity.presets, function(key)
		return ConfigurationStructure.config.vanity.presets[key].Name
	end) do
		local checkbox = selectionGroup:AddCheckbox(preset.Name)
		checkbox.UserData = presetId
		checkbox.OnChange = function()
			errorText.Visible = false
			successText.Visible = false
		end
	end

	exportButton.OnClick = function()
		local toExport = {}
		for _, presetBox in ipairs(selectionGroup.Children) do
			if presetBox.Checked then
				table.insert(toExport, presetBox.UserData)
			end
		end

		local success = FileUtils:SaveTableToFile(self.ExportFilename, VanityExportManager:ExportPresets(toExport, nil, true))
		errorText.Visible = not success
		successText.Visible = success
	end
end

---@type ExtuiWindow?
local importWindow

function VanityExportManager:BuildImportManagerWindow()
	if not importWindow then
		importWindow = Ext.IMGUI.NewWindow(Translator:translate("Import Presets"))
		importWindow.Closeable = true
		importWindow.AlwaysAutoResize = true
	else
		importWindow.Open = true
		importWindow:SetFocus()
	end

	Helpers:KillChildren(importWindow)

	local refreshButton = importWindow:AddButton(Translator:translate("Refresh"))

	local errorText = importWindow:AddText(string.format(
		Translator:translate(
		"Could not find or load %s - ensure it's present in %%localappdata%%\\Larian Studios\\Baldur's Gate 3\\Script Extender\\Armory\\ and not malformed! Check logs for more details"),
		self.ExportFilename))

	errorText.Visible = false
	errorText:SetColor("Text", { 1, 0.02, 0, 1 })

	local presetGroup = importWindow:AddGroup("PresetGroup")

	local successText = importWindow:AddText(Translator:translate("Preset(s) successfully imported!"))
	successText.Visible = false
	successText:SetColor("Text", { 144 / 255, 238 / 255, 144 / 255, 1 })
	local importButton = importWindow:AddButton(Translator:translate("Import Selected Presets"))

	---@type Vanity?
	local exportedPresets

	local function loadFile()
		Helpers:KillChildren(presetGroup)

		exportedPresets = FileUtils:LoadTableFile(self.ExportFilename)
		if not exportedPresets then
			errorText.Visible = true
			successText.Visible = false
		else
			successText.Visible = false
			errorText.Visible = false

			for presetId, preset in pairs(exportedPresets.presets) do
				local checkbox = presetGroup:AddCheckbox(string.format("%s v%s (%s)", preset.Name, preset.Version,
					preset.NSFW and Translator:translate("NSFW") or Translator:translate("SFW")))
				checkbox.Checked = true
				checkbox.UserData = presetId
			end
		end
	end
	loadFile()

	refreshButton.OnClick = loadFile

	importButton.OnClick = function()
		local presetsToImport = {}

		for _, checkbox in ipairs(presetGroup.Children) do
			if checkbox.Checked then
				table.insert(presetsToImport, checkbox.UserData)
			end
		end

		if #presetsToImport > 0 then
			VanityExportManager:ImportPreset(presetsToImport, exportedPresets)
			successText.Visible = true
			ServerPresetManager:UpdatePresetView()
		end
	end
end

Translator:RegisterTranslation({
	["Preset Export Manager"] = "h1e65934b5386473ead8b4c04e2599a40bc03",
	["Export Presets"] = "hf2d535d5082c4180b299a17bd1425d8d158c",
	[([[	
This file can then be packaged with any mod by placing it next to the meta.lsx or be manually sent to users for them to place in the same location
Active mods containing this file will automatically be read in by Armory and displayed under the 'Mod Presets' section of the Preset Manager. Users can manually import this file if present on their machine via the menu option within the Preset Manager
When exporting presets, an existing file will be completely overwritten with the chosen presets
]])] = "h74823c34b02c4ddaab857057d5f5940ffb38",
	["Preset(s) successfully exported!"] = "h2c61d10aaf184da9b05d657831ed2e3c4g51",
	["Export"] = "hbf30abefdee747b7acd0145be475ee3d43be",
	["File failed to save - check logs"] = "h7b62ce80af614dd997bb7655c0fee8f66016",
	["Import Presets"] = "h7cea480a601c448882c6724413a67d36g1d6",
	["Refresh"] = "hfe36d27abca34ce3be19669466742f648662",
	["Could not find or load %s - ensure it's present in %%localappdata%%\\Larian Studios\\Baldur's Gate 3\\Script Extender\\Armory\\ and not malformed! Check logs for more details"] =
	"h2220039b944a417db15fe7c6d52a3c112c47",
	["Preset(s) successfully imported!"] = "he5f85c5b317b48f28d5744da796c66245a20",
	["Import Selected Presets"] = "he795e262f136407c9b3c216e910d4d6fd495",
	["NSFW"] = "h6ed4ff24fd8647b1a7ef56df74b19c5de707",
	["SFW"] = "h528dee02d5a1465a9c7846a3cb74d3879800",
})

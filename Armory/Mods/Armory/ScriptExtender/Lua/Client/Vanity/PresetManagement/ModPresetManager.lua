VanityModPresetManager = {}

VanityModPresetManager.ExportFilename = "Armory_Vanity_Mod_Presets.json"

---@type ExtuiWindow
local exportWindow = nil

function VanityModPresetManager:BuildExportManagerWindow()
	if not exportWindow then
		exportWindow = Ext.IMGUI.NewWindow("Preset Export Manager")
		exportWindow.Closeable = true
		exportWindow.AlwaysAutoResize = true
	else
		exportWindow.Open = true
		exportWindow:SetFocus()
	end

	Helpers:KillChildren(exportWindow)

	local header = exportWindow:AddText("Export Presets")
	header.Font = "Large"

	exportWindow:AddText(
		"Selected presets will be exported to %localappdata%\\Larian Studios\\Baldur's Gate 3\\Script Extender\\Armory\\Armory_Vanity_Presets.json").TextWrapPos = 0

	exportWindow:AddText("This file can then be packaged with any mod by placing it next to the meta.lsx or be manually sent to users for them to place in the same location").TextWrapPos = 0
	exportWindow:AddText("Active mods containing this file will automatically be read in by Armory and displayed under the 'Mod Presets' section of the Preset Manager. Users can manually import this file if present on their machine via the menu option within the Preset Manager").TextWrapPos = 0

	exportWindow:AddText("When exporting presets, an existing file will be completely overwritten with the chosen presets")

	exportWindow:AddSeparator()

	local selectionGroup = exportWindow:AddGroup("SelectionGroup")

	local exportButton = exportWindow:AddButton("Export")

	local successText = exportWindow:AddText("Preset(s) successfully exported!")
	successText.Visible = false
	successText:SetColor("Text", { 144 / 255, 238 / 255, 144 / 255, 1 })

	local errorText = exportWindow:AddText("File failed to save - check logs")
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

		local success = FileUtils:SaveTableToFile(self.ExportFilename, VanityExportManager:ExportPresets(toExport))
		errorText.Visible = not success
		successText.Visible = success
	end
end

---@type ExtuiWindow?
local importWindow

function VanityModPresetManager:BuildImportManagerWindow()
	if not importWindow then
		importWindow = Ext.IMGUI.NewWindow("Import Presets")
		importWindow.Closeable = true
		importWindow.AlwaysAutoResize = true
	else
		importWindow.Open = true
		importWindow:SetFocus()
	end

	Helpers:KillChildren(importWindow)

	local refreshButton = importWindow:AddButton("Refresh")

	local errorText = importWindow:AddText(string.format(
		"Could not find or load %s - ensure it's present in %%localappdata%%\\Larian Studios\\Baldur's Gate 3\\Script Extender\\Armory\\ and not malformed! Check logs for more details",
		self.ExportFilename))

	errorText.Visible = false
	errorText:SetColor("Text", { 1, 0.02, 0, 1 })

	local presetGroup = importWindow:AddGroup("PresetGroup")

	local successText = importWindow:AddText("Preset(s) successfully imported!")
	successText.Visible = false
	successText:SetColor("Text", { 144 / 255, 238 / 255, 144 / 255, 1 })
	local importButton = importWindow:AddButton("Import Selected Presets")

	---@type VanityPresetExport?
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
				local checkbox = presetGroup:AddCheckbox(string.format("%s v%s (%s)", preset.Name, preset.Version, preset.NSFW and "NSFW" or "SFW"))
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
			VanityPresetManager:UpdatePresetView()
		end
	end
end

---Based off of Volitio's MCM approach - thx M8
function VanityModPresetManager:ImportPresetsFromMods()
    for _, uuid in ipairs(Ext.Mod.GetLoadOrder()) do
		local mod = Ext.Mod.GetMod(uuid)
		if mod then
			local presetFile = string.format("Mods/%s/%s", mod.Info.Directory, self.ExportFilename)
		end
    end
end

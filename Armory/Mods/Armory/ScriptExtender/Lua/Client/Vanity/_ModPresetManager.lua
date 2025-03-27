VanityModPresetManager = {}

VanityModPresetManager.ExportFilename = "Armory_Vanity_Mod_Presets.json"

---@type ExtuiWindow
local window = nil

function VanityModPresetManager:BuildExportManagerWindow()
	if not window then
		window = Ext.IMGUI.NewWindow("Preset Export Manager")
		window.Closeable = true
	else
		window.Open = true
		window:SetFocus()
	end

	Helpers:KillChildren(window)

	local header = window:AddText("Export Presets to Package In Mods")
	header.Font = "Large"

	window:AddText(
		"Selected presets will be exported to %localappdata%\\Larian Studios\\Baldur's Gate 3\\Script Extender\\Armory\\Armory_Vanity_Presets.json").TextWrapPos = 0

	window:AddText("This file can then be packaged with any mod by placing it next to the meta.lsx or be manually sent to users for them to place in the same location").TextWrapPos = 0
	window:AddText("Active mods containing this file will automatically be read in by Armory and displayed under the 'Mod Presets' section of the Preset Manager. Users can manually import this file if present on their machine via the menu option within the Preset Manager").TextWrapPos = 0

	window:AddText("When exporting presets, an existing file will be completely overwritten with the chosen presets")

	local selectionGroup = window:AddGroup("SelectionGroup")

	local exportButton = window:AddButton("Export")

	local successText = window:AddText("Preset(s) successfully exported!")
	successText.Visible = false
	successText:SetColor("Text", { 144 / 255, 238 / 255, 144 / 255, 1 })

	local errorText = window:AddText("File failed to save - check logs")
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

		local success = FileUtils:SaveTableToFile(self.ExportFilename, VanityExportAndBackupManager:ExportPresets(toExport))
		errorText.Visible = not success
		successText.Visible = success
	end
end

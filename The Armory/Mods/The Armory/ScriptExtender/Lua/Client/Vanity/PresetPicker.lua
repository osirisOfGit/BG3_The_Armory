VanityPresetPicker = {}

function VanityPresetPicker:OpenPicker()
	local presetWindow = Ext.IMGUI.NewWindow("Vanity Preset Manager")
	presetWindow.Closeable = true

	presetWindow:AddButton("Create a New Preset")

	local presetTable = presetWindow:AddTable("PresetTable", 2)
	presetTable.NoSavedSettings = true

	presetTable:AddColumn("PresetSelection", "WidthFixed")
	presetTable:AddColumn("PresetInfo", "WidthFixed")

	local row = presetTable:AddRow()

	local selectionCell = row:AddCell()

	local userPresets = selectionCell:AddChildWindow("UserPresets")
	userPresets.NoSavedSettings = true
	userPresets:AddSeparatorText("Your Presets")
	userPresets:AddButton("Test 1")

	local modPresets = selectionCell:AddChildWindow("ModPresets")
	modPresets.NoSavedSettings = true
	modPresets:AddSeparatorText("Mod-Added Presets")

	local infoCell = row:AddCell()
	local function buildInfoCell()
		
	end
end

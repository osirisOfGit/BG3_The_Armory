Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Vanity",
	--- @param tabHeader ExtuiTreeParent
	function(tabHeader)
		tabHeader.TextWrapPos = 0

		tabHeader:AddText("Select a Preset")
		local presetCombo = tabHeader:AddCombo("")
		presetCombo.SameLine = true
		presetCombo.Options = { "Preset", "Preset", "Preset" }

		local copyPresetButton = tabHeader:AddButton("Copy")

		local previewPresetButton = tabHeader:AddButton("Preview")
		previewPresetButton.SameLine = true
		previewPresetButton.A

		local applyPresetButton = tabHeader:AddButton("Apply")
		applyPresetButton.SameLine = true
	end)

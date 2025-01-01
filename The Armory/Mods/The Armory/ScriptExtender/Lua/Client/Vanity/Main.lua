Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Vanity",
	--- @param tabHeader ExtuiTreeParent
	function(tabHeader)
		tabHeader.TextWrapPos = 0

		--#region Presets
		tabHeader:AddText("Select a Preset").PositionOffset = { 400, 0 }
		local presetCombo = tabHeader:AddCombo("")
		presetCombo.SameLine = true
		presetCombo.WidthFitPreview = true
		presetCombo.Options = { "Preset", "Preset", "Preset" }

		local copyPresetButton = tabHeader:AddButton("Duplicate")
		copyPresetButton.PositionOffset = { 300, 0 }

		local previewPresetButton = tabHeader:AddButton("Preview")
		previewPresetButton.SameLine = true
		previewPresetButton.PositionOffset = { 100, 0 }

		local applyPresetButton = tabHeader:AddButton("Apply")
		applyPresetButton.SameLine = true
		applyPresetButton.PositionOffset = { 100, 0 }
		--#endregion

		--#region Character Panel
		local panelGroup = tabHeader:AddGroup("CharacterPanel")
		panelGroup:AddImageButton("Helmet", "c_slot_helmet")
		panelGroup:AddImageButton("Cloak", "c_slot_cloak")
		panelGroup:AddImageButton("Breast", "c_slot_breast")
		panelGroup:AddImageButton("Gloves", "c_slot_gloves")
		panelGroup:AddImageButton("Boots", "c_slot_boots")
		panelGroup:AddImageButton("LightSource", "c_slot_lightSource")
		panelGroup:AddImageButton("Instrument", "c_slot_instrument")
		panelGroup:AddImageButton("MeleeMainHand", "c_slot_meleeMainHand")
		panelGroup:AddImageButton("MeleeOffHand", "c_slot_meleeOffHand")
		panelGroup:AddImageButton("RangedMainHand", "c_slot_rangedMainHand")
		panelGroup:AddImageButton("RangedOffHand", "c_slot_rangedOffHand")
		panelGroup:AddImageButton("VanityClothes", "c_slot_vanityClothes")
		panelGroup:AddImageButton("VanityBoots", "c_slot_vanityBoots")

		--#endregion
	end)

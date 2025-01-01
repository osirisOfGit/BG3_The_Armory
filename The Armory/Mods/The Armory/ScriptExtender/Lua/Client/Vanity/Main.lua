Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Vanity",
	--- @param tabHeader ExtuiTreeParent
	function(tabHeader)
		tabHeader.TextWrapPos = 0

		--#region Presets
		tabHeader:AddText("Select a Preset").PositionOffset = { 200, 0 }
		local presetCombo = tabHeader:AddCombo("")
		presetCombo.SameLine = true
		presetCombo.WidthFitPreview = true
		presetCombo.Options = { "Preset", "Preset", "Preset" }

		local copyPresetButton = tabHeader:AddButton("Duplicate")
		copyPresetButton.PositionOffset = { 100, 0 }

		local previewPresetButton = tabHeader:AddButton("Preview")
		previewPresetButton.SameLine = true
		previewPresetButton.PositionOffset = { 100, 0 }

		local applyPresetButton = tabHeader:AddButton("Apply")
		applyPresetButton.SameLine = true
		applyPresetButton.PositionOffset = { 100, 0 }
		--#endregion

		--#region Character Panel
		tabHeader:AddSeparator()

		local panelGroup = tabHeader:AddGroup("CharacterPanel")
		local slotButtons = {
			{ "Helmet",         "c_slot_helmet" },
			{ "VanityClothes",  "c_slot_vanityClothes",  true },
			{ "Cloak",          "c_slot_cloak" },
			{ "VanityBoots",    "c_slot_vanityBoots",    true },
			{ "Breast",         "c_slot_breast" },
			{ "Underwear",      "c_slot_underwear",      true },
			{ "Gloves",         "c_slot_gloves" },
			{ "Amulet",         "c_slot_necklace",       true },
			{ "Boots",          "c_slot_boots" },
			{ "Ring1",          "c_slot_ring1",          true },
			{ "Dummy",          "ignore" },
			{ "Ring2",          "c_slot_ring2",          true },
			{ "LightSource",    "c_slot_lightSource" },
			{ "Instrument",     "c_slot_instrument",     true },
			{ "MeleeMainHand",  "c_slot_meleeMainHand" },
			{ "RangedMainHand", "c_slot_rangedMainHand", true },
			{ "MeleeOffHand",   "c_slot_meleeOffHand" },
			{ "RangedOffHand",  "c_slot_rangedOffHand",  true }
		}

		for _, button in ipairs(slotButtons) do
			local imageButton
			if button[1] == "Dummy" then
				imageButton = panelGroup:AddDummy(120, 60)
				imageButton.Label = button[2]
				imageButton.PositionOffset = { 100, 0 }
			else
				imageButton = panelGroup:AddImageButton(button[1], button[2])

				---@cast imageButton ExtuiImageButton

				-- if button[1] == "MeleeMainHand" or not button[1]:find("Hand") then
				imageButton.PositionOffset = { button[3] and 100 or 100, 0 }
				-- end

				panelGroup:AddImageButton(button[1] .. "_Dye", "Item_LOOT_Dye_Remover", { 32, 32 }).SameLine = true
			end
			if button[3] then
				imageButton.SameLine = true
			end
		end

		--#endregion
	end)

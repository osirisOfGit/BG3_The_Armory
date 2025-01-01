Ext.Require("Client/Vanity/EquipmentPicker.lua")
Ext.Require("Client/Vanity/DyePicker.lua")

Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Vanity",
	--- @param tabHeader ExtuiTreeParent
	function(tabHeader)
		---comment
		---@param element ExtuiStyledRenderable
		---@return ExtuiWindow
		local function GetWindow(element)
			if element.ParentElement then
				return GetWindow(element.ParentElement)
			end
			return element
		end
		local window = GetWindow(tabHeader)
		window.OnClose = function()

		end
		tabHeader.TextWrapPos = 0

		--#region Presets
		tabHeader:AddText("Select a Preset").PositionOffset = { 200, 0 }
		local presetCombo = tabHeader:AddCombo("")
		presetCombo.SameLine = true
		presetCombo.WidthFitPreview = true
		presetCombo.Options = { "Preset", "Preset", "Preset" }

		local copyPresetButton = tabHeader:AddButton("Clone")
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
			{ "Helmet",                "c_slot_helmet" },
			{ "VanityBody",            "c_slot_vanityClothes",  true },
			{ "Cloak",                 "c_slot_cloak" },
			{ "VanityBoots",           "c_slot_vanityBoots",    true },
			{ "Breast",                "c_slot_breast" },
			{ "Underwear",             "c_slot_underwear",      true },
			{ "Gloves",                "c_slot_gloves" },
			{ "Amulet",                "c_slot_necklace",       true },
			{ "Boots",                 "c_slot_boots" },
			{ "Ring1",                 "c_slot_ring1",          true },
			{ "Dummy",                 "ignore" },
			{ "Ring2",                 "c_slot_ring2",          true },
			{ "LightSource",           "c_slot_lightSource" },
			{ "MusicalInstrument",     "c_slot_instrument",     true },
			{ "Melee Main Weapon",     "c_slot_meleeMainHand" },
			{ "Ranged Main Weapon",    "c_slot_rangedMainHand", true },
			{ "Melee Offhand Weapon",  "c_slot_meleeOffHand" },
			{ "Ranged Offhand Weapon", "c_slot_rangedOffHand",  true }
		}

		-- https://bg3.norbyte.dev/search?q=type%3Atreasuretable+ST_SimpleMeleeWeapons
		-- https://bg3.norbyte.dev/search?q=using "_BaseWeapon"&ct=MzaoiTa00DM2NDE0MdFRCi5JLNELzkgsSk3RC09NLMjP0wsP8Iv3SMxJSi1KUYqtAQA%3D

		---@param slot string
		---@param template ItemTemplate
		local function BuildSlots(slot, template)
			local userDataCopy = {
				slot = template
			}
			for _, children in pairs(panelGroup.Children) do
				if children.UserData then
					userDataCopy[children.Label] = children.UserData
				end
				children:Destroy()
			end

			for _, button in ipairs(slotButtons) do
				local imageButton
				if button[1] == "Dummy" then
					imageButton = panelGroup:AddDummy(120, 60)
					imageButton.Label = button[2]
					imageButton.PositionOffset = { 100, 0 }
				else
					---@cast imageButton ExtuiImageButton

					if userDataCopy[button[1]] then
						local itemTemplate = userDataCopy[button[1]]
						imageButton = panelGroup:AddImageButton(button[1], itemTemplate.Icon)
						if imageButton.Image.Icon == "" then
							imageButton:Destroy()
							imageButton = panelGroup:AddImageButton(button[1], "Item_Unknown")
						end
						imageButton.UserData = itemTemplate
					else
						imageButton = panelGroup:AddImageButton(button[1], button[2])
					end
					imageButton.PositionOffset = { 100, 0 }
					imageButton.OnClick = function()
						EquipmentPicker:PickForSlot(imageButton).OnClose = function()
							if imageButton.UserData then
								BuildSlots(imageButton.Label, imageButton.UserData)
							end
						end
					end

					local dyeButton = panelGroup:AddImageButton(button[1] .. " Dye", "Item_LOOT_Dye_Remover", { 32, 32 })
					dyeButton.SameLine = true
					dyeButton.ItemReadOnly = imageButton.UserData ~= nil
					dyeButton.OnClick = function ()
						DyePicker:PickDye(imageButton.UserData, button[1], dyeButton)
					end
				end
				if button[3] then
					imageButton.SameLine = true
				end
			end
		end
		BuildSlots()

		--#endregion
	end)

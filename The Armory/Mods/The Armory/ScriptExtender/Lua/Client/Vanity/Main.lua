Ext.Require("Client/Vanity/EquipmentPicker.lua")
Ext.Require("Client/Vanity/DyePicker.lua")

---@type {[ActualSlot] : string[][]}
local weaponTypes = {
	["Melee Offhand Weapon"] = { { "Shields", "Item_WPN_HUM_Shield_A_0" } }
}

-- `WPN_Scimitar_FlameBlade` (╯‵□′)╯︵┻━┻
local foundTypes = {}

for _, statString in pairs(Ext.Stats.GetStats("Weapon")) do
	---@type Weapon
	local stat = Ext.Stats.Get(statString)
	if stat.Slot and (stat.Using == "_BaseWeapon") then
		if not weaponTypes[stat.Slot] then
			weaponTypes[stat.Slot] = {}
		end

		for _, proficiency in pairs(stat["Proficiency Group"]) do
			-- Proficiency tends to be the weapon type + 's', and weapon type is in the stat name
			-- e.g. `WPN_Pike` requires proficiency `Pikes`. Hope mods also follow this pattern
			if string.find(statString, string.sub(proficiency, 0, -2)) then
				if not foundTypes[proficiency] then
					local entry = { proficiency, Ext.Template.GetTemplate(stat.RootTemplate).Icon }
					table.insert(weaponTypes[stat.Slot], entry)

					if string.find(stat.Slot, "Main") then
						for _, property in pairs(stat["Weapon Properties"]) do
							if property == "Heavy" or property == "Twohanded" then
								goto breakOut
							end
						end
						local offHandSlot = string.gsub(stat.Slot, "Main", "Offhand")
						if not weaponTypes[offHandSlot] then
							weaponTypes[offHandSlot] = {}
						end
						table.insert(weaponTypes[offHandSlot], entry)
					end
				end
				foundTypes[proficiency] = true
				::breakOut::
				break
			end
		end
	end
end
foundTypes = nil

Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Vanity",
	--- @param tabHeader ExtuiTreeParent
	function(tabHeader)
		--EventChannels.MCM_WINDOW_CLOSED = "MCM_Window_Closed"

		tabHeader.TextWrapPos = 0

		--#region Presets
		tabHeader:AddText("Select a Preset").PositionOffset = { 300, 0 }
		local presetCombo = tabHeader:AddCombo("")
		presetCombo.SameLine = true
		presetCombo.WidthFitPreview = true
		presetCombo.Options = { "Preset", "Preset", "Preset" }

		local copyPresetButton = tabHeader:AddButton("Clone")
		copyPresetButton.PositionOffset = { 200, 0 }

		local previewPresetButton = tabHeader:AddButton("Preview")
		previewPresetButton.SameLine = true
		previewPresetButton.PositionOffset = { 100, 0 }

		local applyPresetButton = tabHeader:AddButton("Apply")
		applyPresetButton.SameLine = true
		applyPresetButton.PositionOffset = { 100, 0 }
		--#endregion

		--#region Character Panel
		tabHeader:AddSeparator()

		local displayTable = tabHeader:AddTable("SlotDisplayTable", 5)
		displayTable.ScrollY = true
		local equipmentColumn = displayTable:AddColumn("Equipment", "WidthFixed")
		local displayRow = displayTable:AddRow()
		local equipmentCell = displayRow:AddCell()

		local equipmentSlots = {
			{ "Helmet",            "c_slot_helmet" },
			{ "VanityBody",        "c_slot_vanityClothes" },
			{ "Cloak",             "c_slot_cloak" },
			{ "VanityBoots",       "c_slot_vanityBoots" },
			{ "Breast",            "c_slot_breast" },
			{ "Underwear",         "c_slot_underwear" },
			{ "Gloves",            "c_slot_gloves" },
			{ "Amulet",            "c_slot_necklace" },
			{ "Boots",             "c_slot_boots" },
			{ "Ring1",             "c_slot_ring1" },
			{ "Dummy",             "ignore" },
			{ "Ring2",             "c_slot_ring2" },
			{ "LightSource",       "c_slot_lightSource" },
			{ "MusicalInstrument", "c_slot_instrument" }
		}

		local weaponSlots = {
			{ "Melee Main Weapon",     "c_slot_meleeMainHand" },
			{ "Melee Offhand Weapon",  "c_slot_meleeOffHand" },
			{ "Ranged Main Weapon",    "c_slot_rangedMainHand" },
			{ "Ranged Offhand Weapon", "c_slot_rangedOffHand" }
		}

		---@type table<string, ExtuiTableCell>
		local weaponCols = {}
		for _, weaponSlot in pairs(weaponSlots) do
			displayTable:AddColumn(weaponSlot[1], "WidthFixed")

			local cell = displayRow:AddCell()
			cell.UserData = weaponSlot[1]
			cell:AddImage(weaponSlot[2]).UserData = "keep"
			
			weaponCols[weaponSlot[1]] = cell
		end

		-- https://bg3.norbyte.dev/search?q=type%3Atreasuretable+ST_SimpleMeleeWeapons
		-- https://bg3.norbyte.dev/search?q=using "_BaseWeapon"&ct=MzaoiTa00DM2NDE0MdFRCi5JLNELzkgsSk3RC09NLMjP0wsP8Iv3SMxJSi1KUYqtAQA%3D

		--- Creates the replica of the Character Equip Screen, grouping Equipment in one column and each weapon slot into their own columns
		--- so each weapon type can be configured separately as appropriate. Attaches the Equipment and Dye picker to each configurable slot
		---@param slotCell ExtuiTableCell
		---@param group string[][]
		---@param slot string
		---@param template ItemTemplate
		local function BuildSlots(slotCell, group, verticalSlots, slot, template)
			local userDataCopy = {
			}

			if slot then
				userDataCopy[slot] = template
			end

			for _, child in pairs(slotCell.Children) do
				if child.UserData ~= "keep" then
					-- Will be nil if the slot is empty, which is pointless here, but i'm lazy right now
					userDataCopy[child.Label] = child.UserData
					child:Destroy()
				end
			end

			for i, button in ipairs(group) do
				local imageButton
				if button[1] == "Dummy" then
					imageButton = slotCell:AddDummy(116, 60)
					imageButton.Label = button[2]
					-- imageButton.PositionOffset = { 100, 0 }
				else
					---@cast imageButton ExtuiImageButton

					if userDataCopy[button[1]] then
						local itemTemplate = userDataCopy[button[1]]
						imageButton = slotCell:AddImageButton(button[1], itemTemplate.Icon)
						if imageButton.Image.Icon == "" then
							imageButton:Destroy()
							imageButton = slotCell:AddImageButton(button[1], "Item_Unknown")
						end
						imageButton.UserData = itemTemplate
					else
						imageButton = slotCell:AddImageButton(button[1], button[2])
					end
					imageButton.Image.Size = {60, 60}
					imageButton.PositionOffset = { (not verticalSlots and i % 2 == 0) and 100 or 0, 0 }
					imageButton.OnClick = function()
						EquipmentPicker:PickForSlot(slotCell.UserData or button[1], imageButton).OnClose = function()
							if imageButton.UserData then
								BuildSlots(slotCell, group, verticalSlots, imageButton.Label, imageButton.UserData)
							end
						end
					end

					local dyeButton
					if userDataCopy[button[1] .. " Dye"] then
						local dyeTemplate = userDataCopy[button[1] .. " Dye"]
						dyeButton = slotCell:AddImageButton(button[1] .. " Dye", dyeTemplate.Icon, { 32, 32 })
						dyeButton.UserData = dyeTemplate
					else
						dyeButton = slotCell:AddImageButton(button[1] .. " Dye", "Item_LOOT_Dye_Remover", { 32, 32 })
					end
					dyeButton.SameLine = true
					dyeButton.OnClick = function()
						DyePicker:PickDye(imageButton.UserData, slotCell.UserData or button[1], dyeButton).OnClose = function()
							if dyeButton.UserData then
								BuildSlots(slotCell, group, verticalSlots, dyeButton.Label, dyeButton.UserData)
							end
						end
					end
				end

				imageButton.SameLine = not verticalSlots and i % 2 == 0
			end
		end
		BuildSlots(equipmentCell, equipmentSlots, false)

		for slot, group in pairs(weaponTypes) do
			BuildSlots(weaponCols[slot], group, true)
		end

		--#endregion
	end)

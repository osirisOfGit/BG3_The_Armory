Ext.Require("Client/Vanity/CharacterPanel/DyePicker.lua")
Ext.Require("Client/Vanity/CharacterPanel/EquipmentPicker.lua")

---@type {[ActualSlot] : string[][]}
local weaponTypes = {
	["Melee Offhand Weapon"] = { { "Shields", "Item_WPN_HUM_Shield_A_0" } }
}

local function PopulateWeaponTypes()
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
end

VanityCharacterPanel = {}

---@param tabHeader ExtuiTreeParent
function VanityCharacterPanel:BuildModule(tabHeader)
	if not weaponTypes["Cloak"] then
		PopulateWeaponTypes()
	end

	tabHeader:AddSeparator()

	local displayTable = tabHeader:AddTable("SlotDisplayTable", 5)
	displayTable.ScrollY = true
	displayTable:AddColumn("Equipment", "WidthFixed")
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

	---@type table<string, ExtuiCollapsingHeader>
	local weaponCols = {}
	for _, weaponSlot in pairs(weaponSlots) do
		displayTable:AddColumn(weaponSlot[1], "WidthFixed")

		local cell = displayRow:AddCell()
		cell.UserData = weaponSlot[1]
		cell:AddGroup(weaponSlot[1]).UserData = "keep"

		local collapse = cell:AddCollapsingHeader("")
		collapse.UserData = "keep"
		weaponCols[weaponSlot[1]] = collapse
	end

	-- https://bg3.norbyte.dev/search?q=type%3Atreasuretable+ST_SimpleMeleeWeapons
	-- https://bg3.norbyte.dev/search?q=using "_BaseWeapon"&ct=MzaoiTa00DM2NDE0MdFRCi5JLNELzkgsSk3RC09NLMjP0wsP8Iv3SMxJSi1KUYqtAQA%3D

	--- Creates the replica of the Character Equip Screen, grouping Equipment in one column and each weapon slot into their own columns
	--- so each weapon type can be configured separately as appropriate. Attaches the Equipment and Dye picker to each configurable slot
	--- TODO: Refactor this mess
	---@param parentContainer ExtuiTableCell|ExtuiGroup|ExtuiCollapsingHeader
	---@param group string[][]
	---@param verticalSlots boolean
	---@param slot string
	local function BuildSlots(parentContainer, group, verticalSlots, slot)
		local userDataCopy = {
		}

		for _, child in pairs(parentContainer.Children) do
			if child.UserData ~= "keep" then
				-- Will be nil if the slot is empty, which is pointless here, but i'm lazy right now
				userDataCopy[child.Label] = child.UserData
				child:Destroy()
			end
		end

		for i, button in ipairs(group) do
			local imageButton
			if button[1] == "Dummy" then
				imageButton = parentContainer:AddDummy(116, 60)
				imageButton.Label = button[2]
			else
				---@cast imageButton ExtuiImageButton

				local slotForImageButton = slot or button[1]

				--#region Equipment
				if userDataCopy[button[1]] then
					local itemTemplate = userDataCopy[button[1]]
					imageButton = parentContainer:AddImageButton(button[1], itemTemplate.Icon)
					if imageButton.Image.Icon == "" then
						imageButton:Destroy()
						imageButton = parentContainer:AddImageButton(button[1], "Item_Unknown")
					end
					imageButton.UserData = itemTemplate
				else
					imageButton = parentContainer:AddImageButton(button[1], button[2])
				end
				imageButton.Image.Size = { 60, 60 }
				imageButton.PositionOffset = { (not verticalSlots and i % 2 == 0) and 100 or 0, 0 }
				imageButton.OnClick = function()
					-- Third param allows us to send the weaponSlot and the associated slot at the same time when applicable, filtering results
					EquipmentPicker:PickForSlot(slotForImageButton, imageButton, slotForImageButton ~= button[1] and button[1] or nil).UserData = function()
						if imageButton.UserData then
							BuildSlots(parentContainer, group, verticalSlots, slot)
						end
					end
				end
				--#endregion

				--#region Dyes
				local dyeButton
				if userDataCopy[slotForImageButton .. " Dye"] then
					local dyeTemplate = userDataCopy[slotForImageButton .. " Dye"]
					dyeButton = parentContainer:AddImageButton(slotForImageButton .. " Dye", dyeTemplate.Icon, { 32, 32 })
					dyeButton.UserData = dyeTemplate
				else
					dyeButton = parentContainer:AddImageButton(slotForImageButton .. " Dye", "Item_LOOT_Dye_Remover", { 32, 32 })
				end
				dyeButton.SameLine = true
				dyeButton.OnClick = function()
					DyePicker:PickDye(imageButton.UserData, slotForImageButton, dyeButton).UserData = function()
						if dyeButton.UserData then
							BuildSlots(parentContainer, group, verticalSlots, slot)
						end
					end
				end
				--#endregion
			end

			imageButton.SameLine = not verticalSlots and i % 2 == 0
		end
	end
	BuildSlots(equipmentCell, equipmentSlots, false)

	-- I'll have you know, i'm not proud of this. But the functionality inside of BuildSlots is identical -
	-- it's just the friggen UI layout that changes
	for i, slotEntry in pairs(weaponSlots) do
		-- attaches the overall weapon slot to the group inside the respective column
		BuildSlots(displayRow.Children[i + 1].Children[1], { slotEntry }, true)
	end

	for slot, group in pairs(weaponTypes) do
		-- attaches the various weaponTypes to the Collapsing header inside the respective weapon slot column
		BuildSlots(weaponCols[slot], group, true, slot)
	end
end



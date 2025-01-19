Ext.Require("Client/Vanity/CharacterPanel/PickerBaseClass.lua")
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

local initialized = false

VanityCharacterPanel = {}

---@type ExtuiGroup
local panelGroup

local equipmentSlots = {
	{ "Helmet",            "c_slot_helmet" },
	{ "VanityBody",        "c_slot_vanityClothes" },
	{ "Cloak",             "c_slot_cloak" },
	{ "VanityBoots",       "c_slot_vanityBoots" },
	{ "Breast",            "c_slot_breast" },
	{ "Underwear",         "c_slot_underwear" },
	{ "Gloves",            "c_slot_gloves" },
	{ "Dummy",             "ignore" },
	-- { "Amulet",            "c_slot_necklace" },
	{ "Boots",             "c_slot_boots" },
	-- { "Ring1",             "c_slot_ring1" },
	-- { "Dummy2",            "ignore" },
	-- { "Ring2",             "c_slot_ring2" },
	-- { "LightSource",       "c_slot_lightSource" },
	{ "MusicalInstrument", "c_slot_instrument" }
}

local weaponSlots = {
	{ "Melee Main Weapon",     "c_slot_meleeMainHand" },
	{ "Melee Offhand Weapon",  "c_slot_meleeOffHand" },
	{ "Ranged Main Weapon",    "c_slot_rangedMainHand" },
	{ "Ranged Offhand Weapon", "c_slot_rangedOffHand" }
}

---@param tabHeader ExtuiTreeParent
---@param preset VanityPreset
---@param criteriaCompositeKey string
function VanityCharacterPanel:BuildModule(tabHeader, preset, criteriaCompositeKey)
	if not initialized then
		initialized = true
		PopulateWeaponTypes()
	end

	if not panelGroup then
		panelGroup = tabHeader:AddGroup("CharacterPanel")
	else
		for _, child in pairs(panelGroup.Children) do
			child:Destroy()
		end
	end
	panelGroup:AddSeparator()

	-- if it's just pipes, so no criteria in the outfit
	if string.match(criteriaCompositeKey, "^|+$") then
		return
	end

	local displayTable = panelGroup:AddTable("SlotDisplayTable", 5)
	displayTable.ScrollY = true
	displayTable:AddColumn("Equipment", "WidthFixed")
	local displayRow = displayTable:AddRow()
	local equipmentCell = displayRow:AddCell()

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

	local function InitializeOutfitSlot(itemSlot, weaponType)
		local outfitSlotEntryForItem
		if not preset.Outfits[criteriaCompositeKey] then
			preset.Outfits[criteriaCompositeKey] = {}
		end
		if not preset.Outfits[criteriaCompositeKey][itemSlot] then
			preset.Outfits[criteriaCompositeKey][itemSlot] =
				TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.vanity.outfitSlot)
		end

		outfitSlotEntryForItem = preset.Outfits[criteriaCompositeKey][itemSlot]

		if weaponType then
			if not outfitSlotEntryForItem.weaponTypes then
				outfitSlotEntryForItem.weaponTypes = {}
			end

			if not outfitSlotEntryForItem.weaponTypes[weaponType] then
				outfitSlotEntryForItem.weaponTypes[weaponType] =
					TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.vanity.outfitSlot)
			end
			outfitSlotEntryForItem = outfitSlotEntryForItem.weaponTypes[weaponType]
		end

		return outfitSlotEntryForItem
	end

	---@param itemTemplate ItemTemplate
	---@param outfitSlotEntryForItem VanityOutfitItemEntry
	local function RecordModDependency(itemTemplate, outfitSlotEntryForItem)
		outfitSlotEntryForItem.guid = itemTemplate.Id

		if itemTemplate.Stats then
			---@type Object
			local stat = Ext.Stats.Get(itemTemplate.Stats)
			local modInfo = Ext.Mod.GetMod(stat.ModId).Info
			if modInfo then
				outfitSlotEntryForItem.modDependency = {
					Guid = modInfo.ModuleUUID,
					Version = modInfo.ModVersion
				}
			end
		else
			Logger:BasicWarning("Can't record the mod dependency for item %s (%s) due to missing Stats entry",
				itemTemplate.DisplayName:Get() or itemTemplate.Name,
				itemTemplate.Id)
		end
	end

	--- Creates the replica of the Character Equip Screen, grouping Equipment in one column and each weapon slot into their own columns
	--- so each weapon type can be configured separately as desired. Attaches the Equipment and Dye picker to each configurable slot
	---@param parentContainer ExtuiTableCell|ExtuiGroup|ExtuiCollapsingHeader
	---@param group string[][]
	---@param verticalSlots boolean
	---@param slot string
	local function BuildSlots(parentContainer, group, verticalSlots, slot)
		for _, child in pairs(parentContainer.Children) do
			if child.UserData ~= "keep" then
				child:Destroy()
			end
		end

		local outfit = preset.Outfits[criteriaCompositeKey]

		for i, itemSlotOrWeaponTypeEntry in ipairs(group) do
			local imageButton
			if string.find(itemSlotOrWeaponTypeEntry[1], "Dummy") then
				-- Dummy size math makes 0 sense to me
				imageButton = parentContainer:AddDummy(164, 60)
				imageButton.Label = itemSlotOrWeaponTypeEntry[2]
			else
				---@cast imageButton ExtuiImageButton

				local itemSlot = slot or itemSlotOrWeaponTypeEntry[1]
				local weaponType = itemSlot ~= itemSlotOrWeaponTypeEntry[1] and itemSlotOrWeaponTypeEntry[1] or nil
				---@type VanityOutfitSlot?
				local outfitSlotEntry

				if outfit and outfit[itemSlot] then
					if weaponType then
						if outfit[itemSlot].weaponTypes and outfit[itemSlot].weaponTypes[weaponType] then
							outfitSlotEntry = outfit[itemSlot].weaponTypes[weaponType]
						end
					else
						outfitSlotEntry = outfit[itemSlot]
					end
				end

				local makeResetButton = false

				--#region Equipment
				if outfitSlotEntry and outfitSlotEntry.equipment then
					---@type ItemTemplate
					local itemTemplate = Ext.Template.GetTemplate(outfitSlotEntry.equipment.guid)

					imageButton = parentContainer:AddImageButton(itemSlotOrWeaponTypeEntry[1], itemTemplate.Icon)
					if imageButton.Image.Icon == "" then
						imageButton:Destroy()
						imageButton = parentContainer:AddImageButton(itemSlotOrWeaponTypeEntry[1], "Item_Unknown")
					end
					imageButton.UserData = itemTemplate

					Helpers:BuildTooltip(imageButton:Tooltip(), itemTemplate.DisplayName:Get(), Ext.Stats.Get(itemTemplate.Stats))
					makeResetButton = true
				else
					imageButton = parentContainer:AddImageButton(itemSlotOrWeaponTypeEntry[1], itemSlotOrWeaponTypeEntry[2])
					if weaponType then
						imageButton.Background = { 0, 0, 0, 1 }
						imageButton:Tooltip():AddText("\t " .. weaponType)
					end
				end
				imageButton.Image.Size = { 60, 60 }
				imageButton.PositionOffset = { (not verticalSlots and i % 2 == 0) and 100 or 0, 0 }
				imageButton.OnClick = function()
					-- Third param allows us to send the weaponType and the associated slot at the same time when applicable, filtering results
					EquipmentPicker:OpenWindow(itemSlot, weaponType, outfitSlotEntry,
						---@param itemTemplate ItemTemplate
						function(itemTemplate)
							local outfitSlotEntryForItem = InitializeOutfitSlot(itemSlot, weaponType)
							outfitSlotEntryForItem.equipment = outfitSlotEntryForItem.equipment or {}

							RecordModDependency(itemTemplate, outfitSlotEntryForItem.equipment)

							Ext.Timer.WaitFor(350, function()
								Ext.ClientNet.PostMessageToServer(ModuleUUID .. "_PresetUpdated", "")
							end)
							BuildSlots(parentContainer, group, verticalSlots, slot)
						end)
				end
				--#endregion

				--#region Dyes
				local dyeButton

				if outfitSlotEntry and outfitSlotEntry.dye then
					---@type ItemTemplate
					local dyeTemplate = Ext.Template.GetTemplate(outfitSlotEntry.dye.guid)
					dyeButton = parentContainer:AddImageButton(itemSlot .. " Dye", dyeTemplate.Icon, { 32, 32 })
					dyeButton.UserData = dyeTemplate
					Helpers:BuildTooltip(dyeButton:Tooltip(), dyeTemplate.DisplayName:Get(), Ext.Stats.Get(dyeTemplate.Stats))
					makeResetButton = true
				else
					dyeButton = parentContainer:AddImageButton(itemSlot .. " Dye", "Item_LOOT_Dye_Remover", { 32, 32 })
				end
				dyeButton.IDContext = itemSlotOrWeaponTypeEntry[1] .. " Dye"
				dyeButton.SameLine = true
				dyeButton.OnClick = function()
					DyePicker:OpenWindow(imageButton.UserData, itemSlot,
						---@param dyeTemplate ItemTemplate
						function(dyeTemplate)
							local outfitSlotEntryForItem = InitializeOutfitSlot(itemSlot, weaponType)

							outfitSlotEntryForItem.dye = outfitSlotEntryForItem.dye or {}

							RecordModDependency(dyeTemplate, outfitSlotEntryForItem.dye)

							Ext.Timer.WaitFor(350, function()
								Ext.ClientNet.PostMessageToServer(ModuleUUID .. "_PresetUpdated", "")
							end)
							BuildSlots(parentContainer, group, verticalSlots, slot)
						end)
				end
				--#endregion

				if makeResetButton then
					local resetButton = parentContainer:AddImageButton("reset" .. itemSlot, "ico_reset_d", { 32, 32 })
					resetButton.SameLine = true
					resetButton.OnClick = function()
						outfit[itemSlot].delete = true
						Ext.Timer.WaitFor(350, function()
							Ext.ClientNet.PostMessageToServer(ModuleUUID .. "_PresetUpdated", "")
						end)
						BuildSlots(parentContainer, group, verticalSlots, slot)
					end
				else
					parentContainer:AddDummy(40, 40).SameLine = true
				end
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

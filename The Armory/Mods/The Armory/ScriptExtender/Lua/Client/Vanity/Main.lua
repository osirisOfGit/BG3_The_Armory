Ext.Require("Client/Vanity/EquipmentPicker.lua")
Ext.Require("Client/Vanity/DyePicker.lua")

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

---@type {[Guid]: ResourceRace[]}
local playableRaces = {}

local function PopulatePlayableRaces()
	local foundSubraces = {}
	for _, presetGuid in pairs(Ext.StaticData.GetAll("CharacterCreationPreset")) do
		---@type ResourceCharacterCreationPreset
		local preset = Ext.StaticData.Get(presetGuid, "CharacterCreationPreset")

		if preset.RaceUUID then
			---@type ResourceRace
			local subRace = Ext.StaticData.Get(preset.SubRaceUUID, "Race")

			if not playableRaces[preset.RaceUUID] then
				playableRaces[preset.RaceUUID] = {}
			end

			if subRace and not foundSubraces[subRace.ResourceUUID] then
				table.insert(playableRaces[preset.RaceUUID], subRace)
				foundSubraces[subRace.ResourceUUID] = true
			end
		end
	end
end

---@type {[Guid] : ResourceClassDescription[] }
local classesAndSubclasses = {}
local function PopulateClassesAndSubclasses()
	for _, classGuid in pairs(Ext.StaticData.GetAll("ClassDescription")) do
		---@type ResourceClassDescription
		local class = Ext.StaticData.Get(classGuid, "ClassDescription")

		if class.ParentGuid == "00000000-0000-0000-0000-000000000000" and not classesAndSubclasses[class.ResourceUUID] then
			classesAndSubclasses[class.ResourceUUID] = {}
		else
			if not classesAndSubclasses[class.ParentGuid] then
				classesAndSubclasses[class.ParentGuid] = {}
			end

			table.insert(classesAndSubclasses[class.ParentGuid], class)
			table.sort(classesAndSubclasses[class.ParentGuid], function (a, b)
				return a.Name < b.Name
			end)
		end
	end


end

---@type Guid[]
local originCharacters = {}
---@type Guid[]
local hirelings = {}
local function PopulateOriginCharacters()
	for _, originGuid in pairs(Ext.StaticData.GetAll("Origin")) do
		---@type ResourceOrigin
		local origin = Ext.StaticData.Get(originGuid, "Origin")

		if origin.IsHenchman then
			table.insert(hirelings, originGuid)
		else
			table.insert(originCharacters, originGuid)
		end
	end

	--- O(fuck it)
	table.sort(originCharacters, function (a, b)
		return Ext.StaticData.Get(a, "Origin").Name < Ext.StaticData.Get(b, "Origin").Name
	end)
	table.sort(hirelings, function (a, b)
		-- Future Bug report probably
		return Ext.StaticData.Get(a, "Origin").DisplayName:Get() < Ext.StaticData.Get(b, "Origin").DisplayName:Get()
	end)
end

Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Vanity",
	--- @param tabHeader ExtuiTreeParent
	function(tabHeader)
		if not weaponTypes["Cloak"] then
			PopulateWeaponTypes()
		end

		--EventChannels.MCM_WINDOW_CLOSED = "MCM_Window_Closed"

		--#region Settings
		local settingsButton = tabHeader:AddButton("Settings")
		local settingsPopup = tabHeader:AddPopup("Settings")

		settingsButton.OnClick = function()
			settingsPopup:Open()
		end

		---@type ExtuiMenu
		local previewMenu = settingsPopup:AddMenu("Previewing")
		previewMenu:AddCheckbox("Apply Dyes When Previewing Equipment", true)
		--#endregion

		tabHeader.TextWrapPos = 0

		--#region Presets
		tabHeader:AddText("Select a Preset").PositionOffset = { 300, 0 }
		local presetCombo = tabHeader:AddCombo("")
		presetCombo.SameLine = true
		presetCombo.WidthFitPreview = true
		presetCombo.Options = { "Preset1", "Preset2", "Preset3" }

		local copyPresetButton = tabHeader:AddButton("Clone")
		copyPresetButton.PositionOffset = { 200, 0 }

		local previewPresetButton = tabHeader:AddButton("Preview")
		previewPresetButton.SameLine = true
		previewPresetButton.PositionOffset = { 100, 0 }

		local applyPresetButton = tabHeader:AddButton("Apply")
		applyPresetButton.SameLine = true
		applyPresetButton.PositionOffset = { 100, 0 }
		--#endregion

		--#region Race/Class Select
		if #playableRaces == 0 then
			PopulatePlayableRaces()
			PopulateClassesAndSubclasses()
			PopulateOriginCharacters()
		end

		local characterCriteriaSection = tabHeader:AddCollapsingHeader("Configure per Race/Class/BodyType")
		local characterCriteriaSelectionTable = tabHeader:AddTable("CharacterCriteraSelection", 7)

		local characterCriteriaTable = characterCriteriaSection:AddTable("Class-Race", 6)
		characterCriteriaTable:AddColumn("FirstRaceOrClassSelect", "WidthStretch")
		characterCriteriaTable:AddColumn("SecondClassOrRace", "WidthStretch")
		characterCriteriaTable:AddColumn("ThirdSubclassOrSubrace", "WidthStretch")
		characterCriteriaTable:AddColumn("FourthRace", "WidthStretch")
		characterCriteriaTable:AddColumn("FifthSubRace", "WidthStretch")
		characterCriteriaTable:AddColumn("SixthBodyTypeSubRace", "WidthStretch")

		local characterCriteriaRow = characterCriteriaTable:AddRow()
		characterCriteriaRow:AddCell()
		characterCriteriaRow:AddCell()
		characterCriteriaRow:AddCell()
		characterCriteriaRow:AddCell()
		characterCriteriaRow:AddCell()
		characterCriteriaRow:AddCell()

		local bodyTypeTree = {
			BodyType = {
				1, 2, 3, 4
			}
		}
		local raceTree = {
			Race = {
				["By Body Type"] = bodyTypeTree,
				SubRace = bodyTypeTree
			}
		}

		local tree = {
			["By Race"] = raceTree,
			["By Class"] = {
				ClassDescription = {
					SubClass = {
						Race = raceTree.Race,
						["By Body Type"] = bodyTypeTree,
						["By Origin"] = {
							Origin = {}
						},
						["By Hireling"] = {
							Hireling = {}
						}
					},
					["By Race"] = raceTree,
					["By Body Type"] = bodyTypeTree,
					["By Origin"] = {
						Origin = {}
					},
					["By Hireling"] = {
						Hireling = {}
					}
				}
			},
			["By Body Type"] = bodyTypeTree,
			["By Origin"] = {
				Origin = {}
			},
			["By Hireling"] = {
				Hireling = {}
			}
		}

		local function ClearOnSelect(columnIndex, selectable)
			---@type ExtuiTableCell
			local cell = characterCriteriaRow.Children[columnIndex]

			for _, childSelectable in pairs(cell.Children) do
				---@cast childSelectable ExtuiSelectable

				if selectable.UserData ~= childSelectable.UserData then
					childSelectable.Selected = false
				end
			end

			for index, columnCell in pairs(characterCriteriaRow.Children) do
				if index > columnIndex then
					for _, child in pairs(columnCell.Children) do
						child:Destroy()
					end
				end
			end
		end

		--- I know there's a bullet tree, but i like this aesthetic more
		--- TODO: Sort these alphabetically :sigh:
		--- @param trunk table
		--- @param columnIndex number
		--- @param valueCollection ResourceClassDescription[]|ResourceRace[]?
		local function BuildHorizontalSelectableTree(trunk, columnIndex, valueCollection)
			---@type ExtuiTableCell
			local cell = characterCriteriaRow.Children[columnIndex]

			for selectType, children in TableUtils:OrderedPairs(trunk) do
				if selectType == "By Race" or selectType == "By Class" or selectType == "By Body Type" or selectType == "By Origin" or selectType == "By Hireling" then
					local selectable = cell:AddSelectable(selectType)
					selectable.UserData = selectType
					selectable.OnActivate = function()
						ClearOnSelect(columnIndex, selectable)
						BuildHorizontalSelectableTree(children, columnIndex + 1)
					end
				elseif selectType == "Race" or selectType == "ClassDescription" then
					local table = selectType == "Race" and playableRaces or classesAndSubclasses
					for parentGuid, childResources in TableUtils:OrderedPairs(table, function (key)
						return Ext.StaticData.Get(key, selectType).Name
					end) do
						---@type ResourceRace|ResourceClassDescription
						local resource = Ext.StaticData.Get(parentGuid, selectType)

						local selectable = cell:AddSelectable(resource.DisplayName:Get() or resource.Name)
						selectable.UserData = parentGuid
						selectable.OnActivate = function()
							ClearOnSelect(columnIndex, selectable)
							BuildHorizontalSelectableTree(children, columnIndex + 1, childResources)
						end
					end
				elseif selectType == "SubRace" or selectType == "SubClass" then
					for _, childResource in pairs(valueCollection) do
						local selectable = cell:AddSelectable(childResource.DisplayName:Get() or childResource.Name)
						selectable.UserData = childResource.ResourceUUID
						selectable.OnActivate = function()
							ClearOnSelect(columnIndex, selectable)
							BuildHorizontalSelectableTree(children, columnIndex + 1)
						end
					end
				elseif selectType == "BodyType" then
					for _, bodyType in pairs(children) do
						local selectable = cell:AddSelectable(bodyType)
						selectable.UserData = bodyType
						selectable.OnActivate = function()
							ClearOnSelect(columnIndex, selectable)
							BuildHorizontalSelectableTree(children, columnIndex + 1)
						end
					end
				elseif selectType == "Origin" or selectType == "Hireling" then
					for _, originGuid in pairs(selectType == "Origin" and originCharacters or hirelings) do
						---@type ResourceOrigin
						local origin = Ext.StaticData.Get(originGuid, "Origin")

						local selectable = cell:AddSelectable(origin.DisplayName:Get() or origin.Name)
						selectable.UserData = originGuid
						selectable.OnActivate = function()
							ClearOnSelect(columnIndex, selectable)
							BuildHorizontalSelectableTree(children, columnIndex + 1)
						end
					end
				end
			end
		end

		BuildHorizontalSelectableTree(tree, 1)

		

		--#region Character Panel
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

		--#endregion
	end)

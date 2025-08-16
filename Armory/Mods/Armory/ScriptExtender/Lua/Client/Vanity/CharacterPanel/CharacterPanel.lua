Ext.Require("Client/Vanity/CharacterPanel/PickerBaseClass.lua")
Ext.Require("Client/Vanity/CharacterPanel/DyePicker.lua")
Ext.Require("Client/Vanity/CharacterPanel/EquipmentPicker.lua")
Ext.Require("Client/Vanity/CharacterPanel/SlotContextMenu.lua")

---@type {[ActualSlot] : string[][]}
local weaponTypes = {
	["Melee Offhand Weapon"] = { { "Shields", "Item_WPN_HUM_Shield_A_0" } }
}

local function PopulateWeaponTypes()
	local foundTypes = {}

	-- All these weapon types inherit from _BaseWeapon, but the `using` field gets wiped if any modder modifies them to use self-inheritance,
	-- so need to hardcode them :sadge:
	for _, statString in pairs({ "WPN_Mace", "WPN_LightHammer", "WPN_Scimitar", "WPN_Club", "WPN_Handaxe",
		"WPN_Javelin", "WPN_Sickle", "WPN_Dagger", "WPN_Flail", "WPN_Greatclub", "WPN_Maul", "WPN_Morningstar",
		"WPN_Quarterstaff", "WPN_Rapier", "WPN_Shortsword", "WPN_WarPick", "WPN_Greataxe", "WPN_Greatsword", "WPN_Spear",
		"WPN_Battleaxe", "WPN_Longsword", "WPN_Trident", "WPN_Warhammer", "WPN_Glaive", "WPN_Halberd", "WPN_Pike",
		"WPN_Scimitar_FlameBlade", "WPN_Dart", "WPN_LightCrossbow", "WPN_Shortbow", "WPN_Sling", "WPN_HandCrossbow",
		"WPN_HeavyCrossbow", "WPN_Longbow" })
	do
		---@type Weapon
		local stat = Ext.Stats.Get(statString)
		if stat.Slot then
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

VanityCharacterPanel = {
	---@type VanityPreset
	activePreset = nil,
	---@type VanityCriteriaCompositeKey
	criteriaCompositeKey = nil
}

---@param tabHeader ExtuiTreeParent
---@param preset VanityPreset?
---@param criteriaCompositeKey string?
function VanityCharacterPanel:BuildModule(tabHeader, preset, criteriaCompositeKey)
	if not initialized then
		initialized = true
		PopulateWeaponTypes()
	end

	if not panelGroup then
		panelGroup = tabHeader:AddGroup("CharacterPanel")

		panelGroup:AddSeparator()
	else
		Helpers:KillChildren(panelGroup)
	end

	if not preset then
		return
	end

	self.activePreset = preset
	self.criteriaCompositeKey = criteriaCompositeKey

	SlotContextMenu:initialize(panelGroup)

	---@cast criteriaCompositeKey string

	-- if it's just pipes, so no criteria in the outfit
	if string.match(criteriaCompositeKey, "^|+$") then
		return
	end

	if preset.isExternalPreset then
		local txt = panelGroup:AddText(
			Translator:translate(
				"Viewing a mod-provided preset, which can't be edited - if you wish to make changes, copy this preset to your local config via the Preset Manager first"))
		txt.Font = "Large"
		txt.TextWrapPos = 0
	else
		local copyOutfitFromButton = panelGroup:AddButton(Translator:translate("Copy From Another Outfit"))
		copyOutfitFromButton:Tooltip():AddText("\t  " .. Translator:translate("This will overwrite all slots in this outfit with the selected outfit (will clear slots that are empty in the chosen outfit)")).TextWrapPos = 600
		local copyPopup = panelGroup:AddPopup("CopyOutfit")
		copyOutfitFromButton.OnClick = function()
			Helpers:KillChildren(copyPopup)
			VanityCharacterCriteria:BuildConfiguredCriteriaCombinationsTable(preset, copyPopup, criteriaCompositeKey)
			copyPopup:Open()
		end

		local assignCharacterEffects = panelGroup:AddButton(Translator:translate("Add Effects To Character"))
		assignCharacterEffects.OnClick = function()
			Helpers:KillChildren(copyPopup)
			self.activePreset.Character = self.activePreset.Character or {}
			self.activePreset.Character[self.criteriaCompositeKey] = self.activePreset.Character[self.criteriaCompositeKey] or { effects = {} }
			
			copyPopup:Open()
			VanityEffect:buildSlotContextMenuEntries(copyPopup, self.activePreset.Character[self.criteriaCompositeKey], function()
				Vanity:UpdatePresetOnServer()
			end, true)
		end
	end

	local displayTable = panelGroup:AddTable("SlotDisplayTable", 5)
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

	self:BuildSlots(equipmentCell, equipmentSlots, false)

	-- I'll have you know, i'm not proud of this. But the functionality inside of BuildSlots is identical -
	-- it's just the friggen UI layout that changes
	for i, slotEntry in pairs(weaponSlots) do
		-- attaches the overall weapon slot to the group inside the respective column
		self:BuildSlots(displayRow.Children[i + 1].Children[1], { slotEntry }, true)
	end

	for slot, group in pairs(weaponTypes) do
		-- attaches the various weaponTypes to the Collapsing header inside the respective weapon slot column
		self:BuildSlots(weaponCols[slot], group, true, slot)
	end
end

--- Creates the replica of the Character Equip Screen, grouping Equipment in one column and each weapon slot into their own columns
--- so each weapon type can be configured separately as desired. Attaches the Equipment and Dye picker to each configurable slot
---@param parentContainer ExtuiTableCell|ExtuiGroup|ExtuiCollapsingHeader
---@param group string[][]
---@param verticalSlots boolean
---@param slot string
function VanityCharacterPanel:BuildSlots(parentContainer, group, verticalSlots, slot)
	Helpers:KillChildren(parentContainer)

	if not self.activePreset.Outfits then
		self.activePreset.Outfits = TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.vanity.outfit)
	end

	local outfit = self.activePreset.Outfits and self.activePreset.Outfits[self.criteriaCompositeKey]

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
				if (outfit[itemSlot].__call and not outfit[itemSlot]() or not next(outfit[itemSlot])) then
					outfit[itemSlot].delete = true
				elseif weaponType then
					if outfit[itemSlot].weaponTypes and outfit[itemSlot].weaponTypes[weaponType] then
						outfitSlotEntry = outfit[itemSlot].weaponTypes[weaponType]
					end
				else
					outfitSlotEntry = outfit[itemSlot]
				end
			end

			--#region Equipment
			if outfitSlotEntry and outfitSlotEntry.equipment and outfitSlotEntry.equipment.guid then
				if outfitSlotEntry.equipment.guid == "Hide Appearance" then
					imageButton = parentContainer:AddImageButton(itemSlotOrWeaponTypeEntry[1], "Item_Unknown")
					imageButton.Background = { 0, 0, 0, 1 }
					imageButton:SetColor("Button", { 0, 0, 0, 0.5 })
					imageButton:Tooltip():AddText(Translator:translate("Hiding Appearance"))
				else
					---@type ItemTemplate
					local itemTemplate = Ext.Template.GetTemplate(outfitSlotEntry.equipment.guid)
					if itemTemplate then
						imageButton = parentContainer:AddImageButton(itemSlotOrWeaponTypeEntry[1], itemTemplate.Icon)
						if imageButton.Image.Icon == "" then
							imageButton:Destroy()
							imageButton = parentContainer:AddImageButton(itemSlotOrWeaponTypeEntry[1], "Item_Unknown")
						end
						imageButton.UserData = itemTemplate

						Helpers:BuildTooltip(imageButton:Tooltip(), itemTemplate.DisplayName:Get(), Ext.Stats.Get(itemTemplate.Stats))
					else
						if not self.activePreset.isExternalPreset then
							outfitSlotEntry.equipment.guid = nil
							if outfitSlotEntry.equipment.modDependency then
								outfitSlotEntry.equipment.modDependency.delete = true
							end
						end
					end
				end
			end

			if not imageButton then
				imageButton = parentContainer:AddImageButton(itemSlotOrWeaponTypeEntry[1], itemSlotOrWeaponTypeEntry[2])
				if weaponType then
					imageButton.Background = { 0, 0, 0, 1 }
					imageButton:Tooltip():AddText("\t " .. weaponType)
				end
			end
			imageButton.Image.Size = { 60, 60 }
			imageButton.PositionOffset = { (not verticalSlots and i % 2 == 0) and 100 or 0, 0 }

			if not self.activePreset.isExternalPreset then
				SlotContextMenu:buildMenuForSlot(itemSlot,
					weaponType,
					outfitSlotEntry,
					imageButton,
					"equipment",
					function()
						-- Third param allows us to send the weaponType and the associated slot at the same time when applicable, filtering results
						EquipmentPicker:OpenWindow(itemSlot, weaponType, outfitSlotEntry,
							---@param itemTemplate ItemTemplate
							function(itemTemplate)
								local outfitSlotEntryForItem = self:InitializeOutfitSlot(itemSlot, weaponType)
								outfitSlotEntryForItem.equipment = outfitSlotEntryForItem.equipment or {}

								self:RecordModDependency(itemTemplate, outfitSlotEntryForItem.equipment)

								Vanity:UpdatePresetOnServer()
								self:BuildSlots(parentContainer, group, verticalSlots, slot)
							end)
					end,
					function()
						Vanity:UpdatePresetOnServer()
						self:BuildSlots(parentContainer, group, verticalSlots, slot)
					end)
			else
				imageButton.Disabled = true
			end
			--#endregion

			--#region Dyes
			local supplementaryGroup = parentContainer:AddGroup("Supplementary" .. itemSlotOrWeaponTypeEntry[1])
			supplementaryGroup.SameLine = true
			local dyeButton

			if outfitSlotEntry and outfitSlotEntry.dye and outfitSlotEntry.dye.guid then
				---@type ItemTemplate
				local dyeTemplate = Ext.Template.GetTemplate(outfitSlotEntry.dye.guid)
				if dyeTemplate then
					dyeButton = supplementaryGroup:AddImageButton(itemSlot .. " Dye", dyeTemplate.Icon, { 32, 32 })
					dyeButton.UserData = dyeTemplate
					Helpers:BuildTooltip(dyeButton:Tooltip(), dyeTemplate.DisplayName:Get(), Ext.Stats.Get(dyeTemplate.Stats))
				else
					if not self.activePreset.isExternalPreset then
						outfitSlotEntry.dye.delete = true
					end
					dyeButton = supplementaryGroup:AddImageButton(itemSlot .. " Dye", "Item_LOOT_Dye_Remover", { 32, 32 })
				end
			else
				dyeButton = supplementaryGroup:AddImageButton(itemSlot .. " Dye", "Item_LOOT_Dye_Remover", { 32, 32 })
			end

			dyeButton.IDContext = itemSlotOrWeaponTypeEntry[1] .. " Dye"

			if not self.activePreset.isExternalPreset then
				SlotContextMenu:buildMenuForSlot(itemSlot,
					weaponType,
					outfitSlotEntry,
					dyeButton,
					"dye",
					function()
						DyePicker:OpenWindow(imageButton.UserData, itemSlot,
							---@param dyeTemplate ItemTemplate
							function(dyeTemplate)
								local outfitSlotEntryForItem = self:InitializeOutfitSlot(itemSlot, weaponType)

								outfitSlotEntryForItem.dye = outfitSlotEntryForItem.dye or {}

								self:RecordModDependency(dyeTemplate, outfitSlotEntryForItem.dye)

								Vanity:UpdatePresetOnServer()
								self:BuildSlots(parentContainer, group, verticalSlots, slot)
							end)
					end,
					function()
						Vanity:UpdatePresetOnServer()
						self:BuildSlots(parentContainer, group, verticalSlots, slot)
					end)
			else
				dyeButton.Disabled = true
			end
			--#endregion

			--#region Effects
			if outfitSlotEntry and outfitSlotEntry.equipment and outfitSlotEntry.equipment.effects and (outfitSlotEntry.equipment.effects.__call and outfitSlotEntry.equipment.effects() or next(outfitSlotEntry.equipment.effects)) then
				local effectsText = supplementaryGroup:AddText(Translator:translate("EFF"))
				effectsText.Font = "Tiny"
				effectsText:SetColor("Text", { 144 / 255, 238 / 255, 144 / 255, 1 })
			end
			--#endregion
		end

		imageButton.SameLine = not verticalSlots and i % 2 == 0
	end
end

---@param itemTemplate ItemTemplate
---@param outfitSlotEntryForItem VanityOutfitItemEntry
function VanityCharacterPanel:RecordModDependency(itemTemplate, outfitSlotEntryForItem)
	outfitSlotEntryForItem.guid = itemTemplate.Id
	outfitSlotEntryForItem.name = itemTemplate.DisplayName:Get() or itemTemplate.Name

	local success, result = pcall(function(...)
		if itemTemplate.Stats then
			---@type Object
			local stat = Ext.Stats.Get(itemTemplate.Stats)
			if stat then
				if stat.ModId ~= "" then
					local modInfo = Ext.Mod.GetMod(stat.ModId).Info
					if modInfo then
						outfitSlotEntryForItem.modDependency = {
							Name = modInfo.Name,
							Guid = modInfo.ModuleUUID,
							Version = modInfo.ModVersion
						}
					end
				end
				if stat.OriginalModId ~= "" and stat.OriginalModId ~= stat.ModId then
					local originalModInfo = Ext.Mod.GetMod(stat.OriginalModId).Info
					if originalModInfo then
						outfitSlotEntryForItem.modDependency.OriginalMod = {
							Name = originalModInfo.Name,
							Guid = originalModInfo.ModuleUUID,
							Version = originalModInfo.ModVersion
						}
					end
				end
			else
				error(string.format("Stat %s does not exist", itemTemplate.Stats))
			end
		else
			error("No stats object")
		end
	end)
	if not success then
		Logger:BasicWarning("Can't record the mod dependency for item %s (%s) due to missing %s",
			itemTemplate.DisplayName:Get() or itemTemplate.Name,
			itemTemplate.Id,
			result)
	end
end

function VanityCharacterPanel:InitializeOutfitSlot(itemSlot, weaponType)
	local outfitSlotEntryForItem
	if not self.activePreset.Outfits[self.criteriaCompositeKey] then
		self.activePreset.Outfits[self.criteriaCompositeKey] = {}
	end
	if not self.activePreset.Outfits[self.criteriaCompositeKey][itemSlot] then
		self.activePreset.Outfits[self.criteriaCompositeKey][itemSlot] =
			TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.vanity.outfitSlot)
	end

	outfitSlotEntryForItem = self.activePreset.Outfits[self.criteriaCompositeKey][itemSlot]

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

Translator:RegisterTranslation({
	["Viewing a mod-provided preset, which can't be edited - if you wish to make changes, copy this preset to your local config via the Preset Manager first"] =
	"h87888372190f4a01bd3c236148d79209d284",
	["Copy From Another Outfit"] = "h39a529d80937485fa0cbd44a4a57c13dc09g",
	["This will overwrite all slots in this outfit with the selected outfit (will clear slots that are empty in the chosen outfit)"] = "h0450b90e8cd74c91b1fba6749387ecfd4ec0",
	["Hiding Appearance"] = "h88ee937b2cc54a608b75e7b6d1cd7682g54e",
	["EFF"] = "ha10b4c04046f48afb9f17c17727c442feeg0",
	["Add Effects To Character"] = "ha2588acc82bc4163a2ecb69f10d9d300b5a0"
})

VanityModManager = {}

---@param modDependency ModDependency
---@return string, string
function VanityModManager:GetModInfo(modDependency, excludeNotLoadedMessage)
	if modDependency.OriginalMod then
		modDependency = modDependency.OriginalMod
	end

	local mod = Ext.Mod.GetMod(modDependency.Guid)

	if mod then
		if not modDependency.Name then
			modDependency.Name = mod.Info.Name
		end

		if not modDependency.Version then
			modDependency.Version = mod.Info.ModVersion
		end

		return mod.Info.Name, ("v" .. table.concat(mod.Info.ModVersion, "."))
	else
		return string.format("%s%s", modDependency.Name or modDependency.Guid, not excludeNotLoadedMessage and "(Not Loaded)" or ""), ("v" .. table.concat(modDependency.Version, "."))
	end
end

---@class ValidationError
---@field resourceId string
---@field displayValue string
---@field category "Character Criteria"|"Equipment"|"Dye"|"Effect"
---@field modInfo ModDependency?

---@param preset VanityPreset
---@param parentSupplier fun():ExtuiTreeParent
function VanityModManager:DependencyValidator(preset, parentSupplier)
	if not ConfigurationStructure.config.vanity.miscNameCache then
		ConfigurationStructure.config.vanity.miscNameCache = {}
	end
	local miscNamCache = ConfigurationStructure.config.vanity.miscNameCache

	---@type {string : ValidationError[]}
	local validationErrors = {}

	---@param outfitItemEntry VanityOutfitItemEntry
	---@param category "Equipment"|"Dye"
	---@param criteriaKey VanityCriteriaCompositeKey
	local function validateSlot(outfitItemEntry, category, criteriaKey, cachedGuids)
		if outfitItemEntry.guid ~= "Hide Appearance" and (not outfitItemEntry.name or not cachedGuids[outfitItemEntry.guid]) then
			---@type ItemTemplate
			local template = Ext.Template.GetTemplate(outfitItemEntry.guid)
			if not template then
				if not cachedGuids[outfitItemEntry.guid] then
					if not validationErrors[criteriaKey] then
						validationErrors[criteriaKey] = {}
					end

					table.insert(validationErrors[criteriaKey],
						{
							resourceId = outfitItemEntry.guid,
							displayValue = outfitItemEntry.name,
							category = category,
							modInfo = outfitItemEntry.modDependency
						} --[[@as ValidationError]])
				end
			else
				outfitItemEntry.name = template.DisplayName:Get() or template.Name
			end
		end
		cachedGuids[outfitItemEntry.guid] = true

		if outfitItemEntry.effects then
			for _, effect in pairs(outfitItemEntry.effects) do
				local effectInstance = ConfigurationStructure.config.vanity.effects[effect]

				if not cachedGuids[effectInstance.effectProps.StatusEffect] then
					---@type ResourceMultiEffectInfo
					local mei = Ext.StaticData.Get(effectInstance.effectProps.StatusEffect, "MultiEffectInfo")
					if not mei then
						if not validationErrors[criteriaKey] then
							validationErrors[criteriaKey] = {}
						end

						table.insert(validationErrors[criteriaKey],
							{
								resourceId = effectInstance.effectProps.StatusEffect,
								displayValue = effectInstance.cachedDisplayNames and effectInstance.cachedDisplayNames[effectInstance.effectProps.StatusEffect],
								category = "Effect"
							} --[[@as ValidationError]])
					else
						if not effectInstance.cachedDisplayNames then
							effectInstance.cachedDisplayNames = {}
						end
						effectInstance.cachedDisplayNames[effectInstance.effectProps.StatusEffect] = mei.Name
					end
				end
				cachedGuids[effectInstance.effectProps.StatusEffect] = true
			end
		end
	end

	for criteriaKey, outfit in pairs(preset.Outfits) do
		local cachedGuids = {}

		local criteriaTable = ParseCriteriaCompositeKey(criteriaKey)
		local displayCriteriaTable = ConvertCriteriaTableToDisplay(criteriaTable)
		local displayCriteriaKey = CreateCriteriaCompositeKey(ConvertCriteriaTableToDisplay(criteriaTable, nil, true))

		for criteria, value in pairs(displayCriteriaTable) do
			if not cachedGuids[criteriaTable[criteria]] then
				if string.match(value, "Not Found") then
					if not validationErrors[displayCriteriaKey] then
						validationErrors[displayCriteriaKey] = {}
					end

					local modInfo
					for _, customDependency in pairs(preset.CustomDependencies) do
						if customDependency.Resources then
							for resource in string.gmatch(customDependency.Resources, "[^\n]+") do
								if string.gsub(resource, "%s+", "") == criteriaTable[criteria] then
									modInfo = TableUtils:DeeplyCopyTable(customDependency)
									modInfo.Name = modInfo.Name .. " (Custom Dependency)"
									goto exit_loop
								end
							end
						end
					end
					::exit_loop::

					table.insert(validationErrors[displayCriteriaKey],
						{
							resourceId = criteriaTable[criteria],
							displayValue = miscNamCache[criteriaTable[criteria]],
							category = "Character Criteria: " .. criteria,
							modInfo = modInfo
						} --[[@as ValidationError]])
				else
					miscNamCache[criteriaTable[criteria]] = value
				end
			end

			cachedGuids[criteriaTable[criteria]] = true
		end

		for _, vanityOutfitSlot in pairs(outfit) do
			if vanityOutfitSlot.dye and vanityOutfitSlot.dye.guid then
				validateSlot(vanityOutfitSlot.dye, "Dye", displayCriteriaKey, cachedGuids)
			end

			if vanityOutfitSlot.equipment then
				if vanityOutfitSlot.equipment.guid then
					validateSlot(vanityOutfitSlot.equipment, "Equipment", displayCriteriaKey, cachedGuids)
				end

				if vanityOutfitSlot.weaponTypes then
					for _, weaponOutfitSlot in pairs(vanityOutfitSlot.weaponTypes) do
						if weaponOutfitSlot.dye and weaponOutfitSlot.dye.guid then
							validateSlot(weaponOutfitSlot.dye, "Dye", displayCriteriaKey, cachedGuids)
						end

						if weaponOutfitSlot.equipment.guid then
							validateSlot(weaponOutfitSlot.equipment, "Equipment", displayCriteriaKey, cachedGuids)
						end
					end
				end
			end
		end
	end

	if next(validationErrors) then
		local parent = parentSupplier()
		parent:AddNewLine()

		local validationFailureHeader = parent:AddSeparatorText("Dependency Validation Failed!")

		parent:AddText(
		"Please clear/delete the relevant outfit/slots/effects or load the missing mods! (Missing equipment/dyes will be cleared when the relevant outfit is opened in the Vanity tab)")

		parent:AddText("Columns can be resized by clicking and dragging on the vertical lines between columns"):SetStyle("Alpha", 0.7)

		validationFailureHeader.Font = "Large"
		validationFailureHeader:SetColor("Text", { 1, 0.02, 0, 1 })

		for outfitCriteria, validationErrorList in TableUtils:OrderedPairs(validationErrors) do
			local header = parent:AddCollapsingHeader(outfitCriteria)
			header.DefaultOpen = true

			local validationErrorTable = header:AddTable("ValidationErrors", 4)
			validationErrorTable.Resizable = true
			validationErrorTable.SizingStretchProp = true

			local headerRow = validationErrorTable:AddRow()
			headerRow.Headers = true
			headerRow:AddCell():AddText("ResourceID")
			headerRow:AddCell():AddText("Display Name")
			headerRow:AddCell():AddText("Resource Category")
			headerRow:AddCell():AddText("Mod Info")

			for _, validationError in ipairs(validationErrorList) do
				local row = validationErrorTable:AddRow()
				row:AddCell():AddText(validationError.resourceId)
				row:AddCell():AddText(validationError.displayValue or "Unknown")
				row:AddCell():AddText(validationError.category)
				if validationError.modInfo then
					row:AddCell():AddText(string.format("%s (%s)", VanityModManager:GetModInfo(validationError.modInfo, true)))
				else
					row:AddCell():AddText("Unknown - check custom dependencies")
				end
			end
			parent:AddNewLine()
		end
	end
end

---@type ExtuiWindow
local dependencyWindow

---@param preset VanityPreset
---@param criteriaCompositeKey VanityCriteriaCompositeKey?
---@param parent ExtuiTreeParent?
function VanityModManager:BuildOutfitDependencyReport(preset, criteriaCompositeKey, parent)
	if not parent then
		if not dependencyWindow then
			dependencyWindow = Ext.IMGUI.NewWindow("Mod Dependencies")
			dependencyWindow.AlwaysAutoResize = true
			dependencyWindow.Closeable = true
		else
			dependencyWindow.Open = true
			dependencyWindow:SetFocus()
		end

		parent = dependencyWindow
		Helpers:KillChildren(parent)
	end

	parent:AddText("Columns can be resized by clicking and dragging on the vertical lines between columns"):SetStyle("Alpha", 0.7)
	local function generateOutfitSection(compositeKey)
		local criteraTable = ConvertCriteriaTableToDisplay(ParseCriteriaCompositeKey(compositeKey))
		local displayTable = {}
		for index, key in ipairs(VanityCharacterCriteriaType) do
			displayTable[index] = criteraTable[key]
		end

		local parent = parent
		local header
		if criteriaCompositeKey then
			header = parent:AddSeparatorText(table.concat(displayTable, "|"))
			header.Font = "Large"
		else
			header = parent:AddCollapsingHeader(table.concat(displayTable, "|"))
			header.DefaultOpen = true
			parent = header
		end

		local dependencyTable = parent:AddTable("DependencyTable", 6)
		dependencyTable.Resizable = true
		dependencyTable.RowBg = true

		if dependencyWindow and dependencyWindow.Open then
			dependencyTable.SizingFixedFit = true
		else
			dependencyTable.SizingStretchProp = true
		end

		local headerRow = dependencyTable:AddRow()
		headerRow.Headers = true
		headerRow:AddCell():AddText("Slot")
		headerRow:AddCell():AddText("Item")
		headerRow:AddCell():AddText("Mod")
		headerRow:AddCell():AddText("Dye")
		headerRow:AddCell():AddText("Mod")
		headerRow:AddCell():AddText("Effects")

		---@param row ExtuiTableRow
		---@param itemEntry VanityOutfitItemEntry
		local function buildCell(row, itemEntry)
			if itemEntry and itemEntry.guid then
				if itemEntry.guid == "Hide Appearance" then
					row:AddCell():AddText("Appearance Hidden")
					row:AddCell():AddText("---")
				else
					---@type ItemTemplate
					local template = Ext.Template.GetTemplate(itemEntry.guid)
					if template then
						row:AddCell():AddText((template.DisplayName:Get() or template.Name) or template.Id)
					else
						row:AddCell():AddText((itemEntry.name or itemEntry.guid) .. " (Not Loaded)")
					end

					row:AddCell():AddText(string.format("%s (%s)", VanityModManager:GetModInfo(itemEntry.modDependency)))
				end
			else
				row:AddCell():AddText("---")
				row:AddCell():AddText("---")
			end
		end

		for slot, slotEntry in TableUtils:OrderedPairs(preset.Outfits[compositeKey], function(key)
			return SlotEnum[key]
		end) do
			if (slotEntry.equipment and slotEntry.equipment.guid) or (slotEntry.dye and slotEntry.dye.guid) then
				local row = dependencyTable:AddRow()
				row:AddCell():AddText(slot)
				buildCell(row, slotEntry.equipment)
				buildCell(row, slotEntry.dye)

				if slotEntry.equipment and slotEntry.equipment.effects and next(slotEntry.equipment.effects) then
					local text = row:AddCell():AddText("")
					table.sort(slotEntry.equipment.effects)
					for _, effect in ipairs(slotEntry.equipment.effects) do
						text.Label = text.Label .. "|" .. string.sub(effect, #"ARMORY_VANITY_EFFECT_" + 1)
					end
					text.Label = text.Label .. "|"
				else
					row:AddCell():AddText("---")
				end
			end

			if slotEntry.weaponTypes and next(slotEntry.weaponTypes) then
				for weaponType, weaponSlotEntry in TableUtils:OrderedPairs(slotEntry.weaponTypes) do
					if weaponSlotEntry.equipment or weaponSlotEntry.dye then
						local newRow = dependencyTable:AddRow()
						newRow:AddCell():AddText(string.format("%s (%s)", slot, weaponType))
						buildCell(newRow, weaponSlotEntry.equipment)
						buildCell(newRow, weaponSlotEntry.dye)

						if weaponSlotEntry.equipment and weaponSlotEntry.equipment.effects and next(weaponSlotEntry.equipment.effects) then
							local text = newRow:AddCell():AddText("")
							table.sort(weaponSlotEntry.equipment.effects)
							for _, effect in ipairs(weaponSlotEntry.equipment.effects) do
								text.Label = text.Label .. "|" .. string.sub(effect, #"ARMORY_VANITY_EFFECT_" + 1)
							end
							text.Label = text.Label .. "|"
						else
							newRow:AddCell():AddText("---")
						end
					end
				end
			end
		end
	end

	if criteriaCompositeKey then
		generateOutfitSection(criteriaCompositeKey)
	else
		for compositeKey in TableUtils:OrderedPairs(preset.Outfits) do
			generateOutfitSection(compositeKey)
			parent:AddNewLine()
		end
	end
end

VanityModDependencyManager = {}

---@param mod Module
---@return ModDependency
function VanityModDependencyManager:RecordDependency(mod)
	return {
		Name = mod.Info.Name,
		Author = mod.Info.Author,
		Guid = mod.Info.ModuleUUID,
		Version = mod.Info.ModVersion
	} --[[@as ModDependency]]
end

---@param modDependency ModDependency
---@return string, string
function VanityModDependencyManager:GetModInfo(modDependency, excludeNotLoadedMessage)
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

		if not modDependency.Author then
			modDependency.Author = mod.Info.Author
		end

		return mod.Info.Name, ("v" .. table.concat(mod.Info.ModVersion, "."))
	else
		return string.format("%s%s", modDependency.Name or modDependency.Guid, not excludeNotLoadedMessage and Translator:translate("(Not Loaded)") or ""),
			("v" .. table.concat(modDependency.Version, "."))
	end
end

---@class ValidationError
---@field resourceId string
---@field displayValue string
---@field category "Character Criteria"|"Equipment"|"Dye"|"Effect"
---@field modInfo ModDependency?

---@param vanityContainer Vanity
---@param preset VanityPreset
---@param parentSupplier fun():ExtuiTreeParent
function VanityModDependencyManager:DependencyValidator(vanityContainer, preset, parentSupplier)
	if not preset then
		return
	end

	if not vanityContainer.miscNameCache then
		vanityContainer.miscNameCache = {}
	end
	local miscNamCache = vanityContainer.miscNameCache

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
			for effectName, effect in pairs(outfitItemEntry.effects) do
				local effectInstance = vanityContainer.effects[effect]

				if effectInstance then
					if not cachedGuids[effectInstance.effectProps.StatusEffect] then
						local resource = VanityEffect:GetEffectOrMeiResource(effectInstance.effectProps.StatusEffect)

						if not resource then
							if not validationErrors[criteriaKey] then
								validationErrors[criteriaKey] = {}
							end

							table.insert(validationErrors[criteriaKey],
								{
									resourceId = effectInstance.effectProps.StatusEffect,
									displayValue = effectInstance.cachedDisplayNames and effectInstance.cachedDisplayNames[effectInstance.effectProps.StatusEffect],
									category = "Effect",
									modInfo = effectInstance.modDependency
								} --[[@as ValidationError]])
						else
							if not effectInstance.cachedDisplayNames then
								effectInstance.cachedDisplayNames = {}
							end
							effectInstance.cachedDisplayNames[effectInstance.effectProps.StatusEffect] = resource
						end
						cachedGuids[effectInstance.effectProps.StatusEffect] = true
					end
				else
					outfitItemEntry.effects[effectName] = nil
				end
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
				if string.match(value, Translator:translate("Not Found")) then
					if not validationErrors[displayCriteriaKey] then
						validationErrors[displayCriteriaKey] = {}
					end

					local modInfo
					for _, customDependency in pairs(preset.CustomDependencies) do
						if customDependency.Resources then
							for resource in string.gmatch(customDependency.Resources, "[^\n]+") do
								if string.gsub(resource, "%s+", "") == criteriaTable[criteria] then
									modInfo = TableUtils:DeeplyCopyTable(customDependency)
									modInfo.Name = modInfo.Name .. " " .. Translator:translate("(Custom Dependency)")
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
							category = Translator:translate("Character Criteria:") .. " " .. criteria,
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

			if vanityOutfitSlot.equipment or vanityOutfitSlot.weaponTypes then
				if vanityOutfitSlot.equipment and vanityOutfitSlot.equipment.guid then
					validateSlot(vanityOutfitSlot.equipment, "Equipment", displayCriteriaKey, cachedGuids)
				end

				if vanityOutfitSlot.weaponTypes then
					for _, weaponOutfitSlot in pairs(vanityOutfitSlot.weaponTypes) do
						if weaponOutfitSlot.dye and weaponOutfitSlot.dye.guid then
							validateSlot(weaponOutfitSlot.dye, "Dye", displayCriteriaKey, cachedGuids)
						end

						if weaponOutfitSlot.equipment and weaponOutfitSlot.equipment.guid then
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

		local validationFailureHeader = parent:AddSeparatorText(Translator:translate("Dependency Validation Failed!"))
		validationFailureHeader:SetStyle("SeparatorTextAlign", 0.5)
		validationFailureHeader.Font = "Large"
		validationFailureHeader:SetColor("Text", { 1, 0.02, 0, 1 })

		parent:AddText(
			Translator:translate("Please clear/delete the relevant outfit/slots/effects or load the missing mods! (Missing equipment/dyes will be cleared when the relevant outfit is opened in the Vanity tab)")).TextWrapPos = 0

		parent:AddText(Translator:translate("Columns can be resized by clicking and dragging on the vertical lines between columns")):SetStyle("Alpha", 0.7)

		for outfitCriteria, validationErrorList in TableUtils:OrderedPairs(validationErrors) do
			local header = parent:AddCollapsingHeader(outfitCriteria)
			header.DefaultOpen = true

			local validationErrorTable = header:AddTable("ValidationErrors", 4)
			validationErrorTable.Resizable = true
			validationErrorTable.SizingStretchProp = true

			local headerRow = validationErrorTable:AddRow()
			headerRow.Headers = true
			headerRow:AddCell():AddText(Translator:translate("ResourceID"))
			headerRow:AddCell():AddText(Translator:translate("Display Name"))
			headerRow:AddCell():AddText(Translator:translate("Resource Category"))
			headerRow:AddCell():AddText(Translator:translate("Mod Info"))

			for _, validationError in ipairs(validationErrorList) do
				local row = validationErrorTable:AddRow()
				row:AddCell():AddText(validationError.resourceId)
				row:AddCell():AddText(validationError.displayValue or Translator:translate("Unknown"))
				row:AddCell():AddText(validationError.category)
				if validationError.modInfo then
					row:AddCell():AddText(string.format("%s (%s)", VanityModDependencyManager:GetModInfo(validationError.modInfo, true)))
				else
					row:AddCell():AddText(Translator:translate("Unknown - check custom dependencies"))
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
function VanityModDependencyManager:BuildOutfitDependencyReport(preset, criteriaCompositeKey, parent)
	if not parent then
		if not dependencyWindow then
			dependencyWindow = Ext.IMGUI.NewWindow(Translator:translate("Mod Dependencies"))
			dependencyWindow.AlwaysAutoResize = true
			dependencyWindow.Closeable = true
		else
			dependencyWindow.Open = true
			dependencyWindow:SetFocus()
		end

		parent = dependencyWindow
		Helpers:KillChildren(parent)
	end

	parent:AddText(Translator:translate("Columns can be resized by clicking and dragging on the vertical lines between columns")):SetStyle("Alpha", 0.7)
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
			header.IDContext = "OutfitView" .. header.Label
			header.DefaultOpen = true
			parent = header
		end

		local dependencyTable = parent:AddTable("DependencyTable", 7)
		dependencyTable.Resizable = true
		dependencyTable.RowBg = true

		if dependencyWindow and dependencyWindow.Open then
			dependencyTable.SizingFixedFit = true
		else
			dependencyTable.SizingStretchProp = true
		end

		local headerRow = dependencyTable:AddRow()
		headerRow.Headers = true
		headerRow:AddCell():AddText(Translator:translate("Slot"))
		headerRow:AddCell():AddText(Translator:translate("Item"))
		headerRow:AddCell():AddText(Translator:translate("Mod"))
		headerRow:AddCell():AddText(Translator:translate("Dye"))
		headerRow:AddCell():AddText(Translator:translate("Mod"))
		headerRow:AddCell():AddText(Translator:translate("Effects"))
		headerRow:AddCell():AddText(Translator:translate("Mod"))

		---@param row ExtuiTableRow
		---@param itemEntry VanityOutfitItemEntry
		local function buildCell(row, itemEntry)
			if itemEntry and itemEntry.guid then
				if itemEntry.guid == "Hide Appearance" then
					row:AddCell():AddText(Translator:translate("Appearance Hidden"))
					row:AddCell():AddText("---")
				else
					---@type ItemTemplate
					local template = Ext.Template.GetTemplate(itemEntry.guid)
					if template then
						row:AddCell():AddText((template.DisplayName:Get() or template.Name) or template.Id)
					else
						row:AddCell():AddText((itemEntry.name or itemEntry.guid) .. " " .. Translator:translate("(Not Loaded)"))
					end

					row:AddCell():AddText(string.format("%s (%s)", VanityModDependencyManager:GetModInfo(itemEntry.modDependency)))
				end
			else
				row:AddCell():AddText("---")
				row:AddCell():AddText("---")
			end
		end

		if preset.Character and preset.Character[compositeKey] then
			local charEffects = preset.Character[compositeKey]["effects"]
			if charEffects then
				local row = dependencyTable:AddRow()
				row:AddCell():AddText("Character")
				row:AddCell():AddText("---")
				row:AddCell():AddText("---")
				row:AddCell():AddText("---")
				row:AddCell():AddText("---")
				local text = row:AddCell():AddText("")
				local modText = row:AddCell():AddText("")
				for _, effect in ipairs(charEffects) do
					text.Label = text.Label .. "|" .. string.sub(effect, #"ARMORY_VANITY_EFFECT_" + 1)
					local vanityEffect = ConfigurationStructure.config.vanity.effects[effect]
					if vanityEffect and vanityEffect.modDependency then
						modText.Label = modText.Label .. ("|%s (%s)"):format(self:GetModInfo(vanityEffect.modDependency))
					else
						modText.Label = modText.Label .. "|Unknown"
					end
					text.Label = text.Label .. "|"
					modText.Label = modText.Label .. "|"
				end
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
					local modText = row:AddCell():AddText("")

					table.sort(slotEntry.equipment.effects)
					for _, effect in ipairs(slotEntry.equipment.effects) do
						text.Label = text.Label .. "|" .. string.sub(effect, #"ARMORY_VANITY_EFFECT_" + 1)
						local vanityEffect = ConfigurationStructure.config.vanity.effects[effect]
						if vanityEffect and vanityEffect.modDependency then
							modText.Label = modText.Label .. ("|%s (%s)"):format(self:GetModInfo(vanityEffect.modDependency))
						else
							modText.Label = modText.Label .. "|Unknown"
						end
					end
					text.Label = text.Label .. "|"
					modText.Label = modText.Label .. "|"
				else
					row:AddCell():AddText("---")
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

Translator:RegisterTranslation({
	["(Not Loaded)"] = "h30ebfb0890a94acfafd6fcb2c7055e95b3cc",
	["Not Found"] = "h86454123313f4929bd5323d270167fcec8cg",
	["(Custom Dependency)"] = "h793469ac5bc24c4987d5a1b09f7c7b89b714",
	["Character Criteria:"] = "h00f60c3fa76548999a7841c7df32782d0ded",
	["Dependency Validation Failed!"] = "he2c28fd2c0b44fa58a446bd615d758831a12",
	["Please clear/delete the relevant outfit/slots/effects or load the missing mods! (Missing equipment/dyes will be cleared when the relevant outfit is opened in the Vanity tab)"] =
	"h442cbe39c77f40a09e0509602f3a9fad604c",

	["Columns can be resized by clicking and dragging on the vertical lines between columns"] = "heb24a0aa862a4d0380d2f5038a48f8bcdf01",
	["ResourceID"] = "h8075c08128ba48c6a76e1315c1e02fd22dee",
	["Display Name"] = "habe8e5de7a1f4962b043cf6c7023635886af",
	["Resource Category"] = "h253b5aa5fb084ec1907b62ea91a50ef5af7e",
	["Mod Info"] = "h066957084e8f4457a6d8be67e244f9c7cd1g",
	["Unknown - check custom dependencies"] = "h24774f919e0148bcac988d09e6ec6b98231d",
	["Mod Dependencies"] = "hc0010df89a234f54b7fd4d48dc82acaaeb3g",
	["Slot"] = "h5e93f9fb5bac4a28904d1a16cf55f67c0f2e",
	["Item"] = "h75e82a26e6c6488798ece79f67c38f277g5c",
	["Dye"] = "h83253fe60dd1465192fbc54380e3b160bf7e",
	["Mod"] = "h17bbaf1f69dd4ab7842d6abea3272eea7ebf",
	["Effects"] = "h089952c189144c1bad82f5281bafef2397a8",
	["Appearance Hidden"] = "hcf4a7001f0b840068800475066d499a8ge2g",
})

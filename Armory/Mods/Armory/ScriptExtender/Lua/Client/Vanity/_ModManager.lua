ModManager = {}

---@param modDependency ModDependency
function ModManager:GetModInfo(modDependency)
	if modDependency.OriginalMod then
		modDependency = modDependency.OriginalMod
	end

	local mod = Ext.Mod.GetMod(modDependency.Guid)

	if mod then
		return mod.Info.Name, ("v" .. table.concat(mod.Info.ModVersion, "."))
	else
		return string.format("%s (Not Loaded)", modDependency.Name or modDependency.Guid), ("v" .. table.concat(modDependency.Version, "."))
	end
end

function ModManager:BuildCustomDependencyForm(preset, parent)
	
end

---@type ExtuiWindow
local dependencyWindow

---@param preset VanityPreset
---@param criteriaCompositeKey VanityCriteriaCompositeKey?
---@param parent ExtuiTreeParent?
function ModManager:BuildOutfitDependencyReport(preset, criteriaCompositeKey, parent)
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

		local dependencyTable = parent:AddTable("DependencyTable" .. parent.IDContext, 6)
		dependencyTable.Resizable = true

		if dependencyWindow and dependencyWindow.Open then
			dependencyTable.SizingFixedFit = true
		else
			dependencyTable.SizingStretchProp = true
		end

		dependencyTable.RowBg = true

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
						row:AddCell():AddText(itemEntry.guid .. " (Not Found)")
					end

					row:AddCell():AddText(string.format("%s (%s)", ModManager:GetModInfo(itemEntry.modDependency)))
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

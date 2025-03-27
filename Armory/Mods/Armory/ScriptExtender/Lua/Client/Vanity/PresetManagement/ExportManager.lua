---@class VanityPresetExport
---@field effects {[string]: VanityEffect}
---@field miscNameCache {[Guid]: string}
---@field presets {[Guid]: VanityPreset}

VanityExportManager = {}

---@param presetIds Guid[]
---@param existingExport VanityPresetExport?
---@return VanityPresetExport
function VanityExportManager:ExportPresets(presetIds, existingExport)
	local realConfig = ConfigurationStructure:GetRealConfigCopy()

	---@type VanityPresetExport
	local export = existingExport or {
		presets = {},
		effects = {},
		miscNameCache = {}
	}

	for _, presetId in pairs(presetIds) do
		local preset = realConfig.vanity.presets[presetId]

		for criteraKey, outfit in pairs(preset.Outfits) do
			local criteriaTable = ParseCriteriaCompositeKey(criteraKey)
			for _, resourceId in pairs(criteriaTable) do
				if realConfig.vanity.miscNameCache[resourceId] then
					export.miscNameCache[resourceId] = realConfig.vanity.miscNameCache[resourceId]
				end
			end

			for _, outfitSlot in pairs(outfit) do
				if outfitSlot.equipment and outfitSlot.equipment.effects then
					for _, effect in pairs(outfitSlot.equipment.effects) do
						export.effects[effect] = TableUtils:DeeplyCopyTable(realConfig.vanity.effects[effect])
					end
				end

				if outfitSlot.weaponTypes then
					for _, weaponSlot in pairs(outfitSlot.weaponTypes) do
						if weaponSlot.equipment and weaponSlot.equipment.effects then
							for _, effect in pairs(weaponSlot.equipment.effects) do
								export.effects[effect] = TableUtils:DeeplyCopyTable(realConfig.vanity.effects[effect])
							end
						end
					end
				end
			end
		end

		export.presets[presetId] = preset
	end

	return export
end

---@param presetIds Guid[]
function VanityExportManager:ImportPreset(presetIds, exportToExtractFrom)
	-- Since we modify the effect names on each piece of equipment if they already exist in the current config and are different resources
	exportToExtractFrom = TableUtils:DeeplyCopyTable(exportToExtractFrom)

	---@type VanityPresetExport
	local importedPreset = {
		presets = {},
		effects = {},
		miscNameCache = {}
	}

	for _, presetId in ipairs(presetIds) do
		local preset = exportToExtractFrom.presets[presetId]

		-- Remove any non-alpabetical and space characters so it can be used as a Status name if necessary
		local sanitizedPresetName = preset.Name:gsub("[^%a%s]", ""):gsub("%s", "_")

		for criteraKey, outfit in pairs(preset.Outfits) do
			local criteriaTable = ParseCriteriaCompositeKey(criteraKey)
			for _, resourceId in pairs(criteriaTable) do
				if exportToExtractFrom.miscNameCache[resourceId] then
					importedPreset.miscNameCache[resourceId] = exportToExtractFrom.miscNameCache[resourceId]
				end
			end

			for _, outfitSlot in pairs(outfit) do
				if outfitSlot.equipment and outfitSlot.equipment.effects then
					for index, effect in pairs(outfitSlot.equipment.effects) do
						if not importedPreset.effects[effect] then
							if not importedPreset.effects[effect .. sanitizedPresetName] then
								if ConfigurationStructure.config.vanity.effects[effect] then
									if not TableUtils:TablesAreEqual(ConfigurationStructure.config.vanity.effects[effect], exportToExtractFrom.effects[effect]) then
										outfitSlot.equipment.effects[index] = effect .. sanitizedPresetName

										importedPreset.effects[effect .. sanitizedPresetName] = TableUtils:DeeplyCopyTable(exportToExtractFrom.effects[effect])
										importedPreset.effects[effect .. sanitizedPresetName].Name = effect .. sanitizedPresetName
									end
								else
									importedPreset.effects[effect] = TableUtils:DeeplyCopyTable(exportToExtractFrom.effects[effect])
								end
							else
								outfitSlot.equipment.effects[index] = effect .. sanitizedPresetName
							end
						end
					end
				end

				if outfitSlot.weaponTypes then
					for _, weaponSlot in pairs(outfitSlot.weaponTypes) do
						if weaponSlot.equipment and weaponSlot.equipment.effects then
							for index, effect in pairs(weaponSlot.equipment.effects) do
								if not importedPreset.effects[effect] then
									if not importedPreset.effects[effect .. sanitizedPresetName] then
										if ConfigurationStructure.config.vanity.effects[effect] then
											if not TableUtils:TablesAreEqual(ConfigurationStructure.config.vanity.effects[effect], exportToExtractFrom.effects[effect]) then
												weaponSlot.equipment.effects[index] = effect .. sanitizedPresetName

												importedPreset.effects[effect .. sanitizedPresetName] = TableUtils:DeeplyCopyTable(exportToExtractFrom.effects[effect])
												importedPreset.effects[effect .. sanitizedPresetName].Name = effect .. sanitizedPresetName
											end
										else
											importedPreset.effects[effect] = TableUtils:DeeplyCopyTable(exportToExtractFrom.effects[effect])
										end
									else
										weaponSlot.equipment.effects[index] = effect .. sanitizedPresetName
									end
								end
							end
						end
					end
				end
			end

			importedPreset.presets[presetId] = preset
		end
	end

	for resourceId, cachedName in pairs(importedPreset.miscNameCache) do
		if not ConfigurationStructure.config.vanity.miscNameCache[resourceId] then
			ConfigurationStructure.config.vanity.miscNameCache[resourceId] = cachedName
		end
	end

	for effectName, effect in pairs(importedPreset.effects) do
		if not ConfigurationStructure.config.vanity.effects[effectName] then
			ConfigurationStructure.config.vanity.effects[effectName] = effect
		end
	end

	for presetId, preset in pairs(importedPreset.presets) do
		ConfigurationStructure.config.vanity.presets[presetId] = preset
		Logger:BasicInfo("Restored preset '%s' from export", preset.Name)
	end
end

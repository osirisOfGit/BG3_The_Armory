---@class VanityPresetExport
---@field effects {[string]: VanityEffect}
---@field miscNameCache {[Guid]: string}
---@field presets {[Guid]: VanityPreset}

Ext.Vars.RegisterModVariable(ModuleUUID, "SavedPresets", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true
})

---@alias VanityPresetBackupRegistry {[Guid]: boolean}

Ext.Vars.RegisterModVariable(ModuleUUID, "PresetBackupRegistry", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true,
	SyncOnWrite = true
})

VanityExportAndBackupManager = {}

---@type VanityPresetExport?
local cachedBackup

Ext.RegisterConsoleCommand("Armory_Vanity_SeePresetBackupRegistry", function(cmd, ...)
	---@type VanityPresetBackupRegistry
	local presetBackupRegistry = Ext.Vars.GetModVariables(ModuleUUID).PresetBackupRegistry

	if presetBackupRegistry then
		_D(presetBackupRegistry)
	else
		_D("Registry is nil!")
	end
end)

Ext.RegisterConsoleCommand("Armory_Vanity_SeeBackedUpPresets", function(cmd, ...)
	---@type VanityPresetExport?
	local savedPresets = Ext.Vars.GetModVariables(ModuleUUID).SavedPresets

	if savedPresets then
		_D(savedPresets)
	else
		_D("No backed up presets!")
	end
end)


---@param presetId Guid
---@return boolean
function VanityExportAndBackupManager:IsPresetInBackup(presetId)
	if not cachedBackup then
		cachedBackup = Ext.Vars.GetModVariables(ModuleUUID).SavedPresets
	end

	return (cachedBackup and cachedBackup.presets[presetId] ~= nil) or false
end

if Ext.IsClient() then
	---@param presetIds Guid[]
	---@param existingExport VanityPresetExport?
	---@return VanityPresetExport
	function VanityExportAndBackupManager:ExportPresets(presetIds, existingExport)
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

	--#region Backups

	---@type VanityPresetBackupRegistry
	local backupRegistry

	---@param presetId Guid
	---@return boolean
	function VanityExportAndBackupManager:ShouldBackupPreset(presetId)
		if not backupRegistry then
			backupRegistry = Ext.Vars.GetModVariables(ModuleUUID).PresetBackupRegistry or {}
		end

		return backupRegistry[presetId]
	end

	---@param presetId Guid
	function VanityExportAndBackupManager:FlipPresetBackupRegistration(presetId)
		if not VanityExportAndBackupManager:ShouldBackupPreset(presetId) then
			backupRegistry[presetId] = true
			VanityExportAndBackupManager:BackupPresets({ presetId })
		else
			backupRegistry[presetId] = false
			VanityExportAndBackupManager:RemovePresetsFromBackup({ presetId })
		end

		Ext.Vars.GetModVariables(ModuleUUID).PresetBackupRegistry = backupRegistry
	end

	---@param presetIds Guid[]
	function VanityExportAndBackupManager:BackupPresets(presetIds)
		for i, id in ipairs(presetIds) do
			if not VanityExportAndBackupManager:ShouldBackupPreset(id) then
				Logger:BasicDebug("Preset %s should not be backed up, and will be excluded", id)
				presetIds[i] = nil
			end
		end

		if #presetIds == 0 then
			Logger:BasicDebug("None of the provided presets are eligible for backup - skipping.")
			return
		end

		cachedBackup = VanityExportAndBackupManager:ExportPresets(presetIds, cachedBackup)

		Ext.Vars.GetModVariables(ModuleUUID).SavedPresets = cachedBackup
		Logger:BasicInfo("Selected presets backed up successfully")
	end

	---@param presetId Guid
	---@return VanityPresetExport
	function VanityExportAndBackupManager:GetPresetFromBackup(presetId)
		-- Since we modify the effect names on each piece of equipment if they already exist in the current config and are different resources
		local cloneOfBackup = TableUtils:DeeplyCopyTable(cachedBackup or Ext.Vars.GetModVariables(ModuleUUID).SavedPresets)

		---@type VanityPresetExport
		local export = {
			presets = {},
			effects = {},
			miscNameCache = {}
		}

		local preset = cloneOfBackup.presets[presetId]

		-- Remove any non-alpabetical and space characters so it can be used as a Status name if necessary
		local sanitizedPresetName = preset.Name:gsub("[^%a%s]", ""):gsub("%s", "_")

		for criteraKey, outfit in pairs(preset.Outfits) do
			local criteriaTable = ParseCriteriaCompositeKey(criteraKey)
			for _, resourceId in pairs(criteriaTable) do
				if cloneOfBackup.miscNameCache[resourceId] then
					export.miscNameCache[resourceId] = cloneOfBackup.miscNameCache[resourceId]
				end
			end

			for _, outfitSlot in pairs(outfit) do
				if outfitSlot.equipment and outfitSlot.equipment.effects then
					for index, effect in pairs(outfitSlot.equipment.effects) do
						if not export.effects[effect] then
							if not export.effects[effect .. sanitizedPresetName] then
								if ConfigurationStructure.config.vanity.effects[effect] then
									if not TableUtils:TablesAreEqual(ConfigurationStructure.config.vanity.effects[effect], cloneOfBackup.effects[effect]) then
										outfitSlot.equipment.effects[index] = effect .. sanitizedPresetName

										export.effects[effect .. sanitizedPresetName] = TableUtils:DeeplyCopyTable(cloneOfBackup.effects[effect])
										export.effects[effect .. sanitizedPresetName].Name = effect .. sanitizedPresetName
									end
								else
									export.effects[effect] = TableUtils:DeeplyCopyTable(cloneOfBackup.effects[effect])
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
								if not export.effects[effect] then
									if not export.effects[effect .. sanitizedPresetName] then
										if ConfigurationStructure.config.vanity.effects[effect] then
											if not TableUtils:TablesAreEqual(ConfigurationStructure.config.vanity.effects[effect], cloneOfBackup.effects[effect]) then
												weaponSlot.equipment.effects[index] = effect .. sanitizedPresetName

												export.effects[effect .. sanitizedPresetName] = TableUtils:DeeplyCopyTable(cloneOfBackup.effects[effect])
												export.effects[effect .. sanitizedPresetName].Name = effect .. sanitizedPresetName
											end
										else
											export.effects[effect] = TableUtils:DeeplyCopyTable(cloneOfBackup.effects[effect])
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

			export.presets[presetId] = preset
		end

		return export
	end

	---@param presetId Guid?
	---@param presetBackup VanityPresetExport?
	function VanityExportAndBackupManager:RestorePresetBackup(presetId, presetBackup)
		if presetId then
			if not presetBackup then
				presetBackup = self:GetPresetFromBackup(presetId)
			end

			for resourceId, cachedName in pairs(presetBackup.miscNameCache) do
				if not ConfigurationStructure.config.vanity.miscNameCache[resourceId] then
					ConfigurationStructure.config.vanity.miscNameCache[resourceId] = cachedName
				end
			end

			for effectName, effect in pairs(presetBackup.effects) do
				if not ConfigurationStructure.config.vanity.effects[effectName] then
					ConfigurationStructure.config.vanity.effects[effectName] = effect
				end
			end

			ConfigurationStructure.config.vanity.presets[presetId] = presetBackup.presets[presetId]
			Logger:BasicInfo("Restored preset '%s' from backup", presetBackup.presets[presetId].Name)
		else
			cachedBackup = cachedBackup or Ext.Vars.GetModVariables(ModuleUUID).SavedPresets
			for savedPresetId in pairs(cachedBackup.presets) do
				if not ConfigurationStructure.config.vanity.presets[savedPresetId] then
					self:RestorePresetBackup(savedPresetId)
				end
			end

			for presetIdToUpdate in pairs(ConfigurationStructure.config.vanity.presets) do
				self:BackupPresets({ presetIdToUpdate })
			end
		end
	end

	---@param presetIds Guid[]
	function VanityExportAndBackupManager:RemovePresetsFromBackup(presetIds)
		local presetsToKeep = {}
		if cachedBackup then
			for savedPresetId in pairs(cachedBackup.presets) do
				local keepPreset = true
				for _, presetId in pairs(presetIds) do
					if presetId == savedPresetId then
						keepPreset = false
					end
				end
				if keepPreset then
					table.insert(presetsToKeep, savedPresetId)
				end
			end
		end

		cachedBackup = VanityExportAndBackupManager:ExportPresets(presetsToKeep)
		Ext.Vars.GetModVariables(ModuleUUID).SavedPresets = cachedBackup
	end

	--#endregion
end

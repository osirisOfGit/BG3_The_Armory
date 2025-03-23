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

Ext.RegisterConsoleCommand("Armory_Vanity_SeePresetBackupRegistry", function (cmd, ...)
	---@type VanityPresetBackupRegistry
	local presetBackupRegistry = Ext.Vars.GetModVariables(ModuleUUID).PresetBackupRegistry

	if presetBackupRegistry then
		_D(presetBackupRegistry)
	else
		_D("Registry is nil!")
	end
end)

Ext.RegisterConsoleCommand("Armory_Vanity_SeeBackedUpPresets", function (cmd, ...)
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
	---@type VanityPresetExport?
	local savedPresets = Ext.Vars.GetModVariables(ModuleUUID).SavedPresets

	return savedPresets and savedPresets.presets[presetId] ~= nil or false
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

	---@param presetId Guid
	---@return boolean
	function VanityExportAndBackupManager:ShouldBackupPreset(presetId)
		---@type VanityPresetBackupRegistry
		local presetBackupRegistry = Ext.Vars.GetModVariables(ModuleUUID).PresetBackupRegistry

		return presetBackupRegistry and presetBackupRegistry[presetId]
	end

	---@param presetId Guid
	function VanityExportAndBackupManager:FlipPresetBackupRegistration(presetId)
		---@type VanityPresetBackupRegistry
		local presetBackupRegistry = Ext.Vars.GetModVariables(ModuleUUID).PresetBackupRegistry

		if not presetBackupRegistry then
			presetBackupRegistry = {}
		end

		if not presetBackupRegistry[presetId] then
			presetBackupRegistry[presetId] = true
			VanityExportAndBackupManager:BackupPresets({ presetId })
		else
			presetBackupRegistry[presetId] = false
			VanityExportAndBackupManager:RemovePresetsFromBackup({ presetId })
		end

		Ext.Vars.GetModVariables(ModuleUUID).PresetBackupRegistry = presetBackupRegistry
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

		Ext.Vars.GetModVariables(ModuleUUID).SavedPresets = VanityExportAndBackupManager:ExportPresets(presetIds, Ext.Vars.GetModVariables(ModuleUUID).SavedPresets)
		Logger:BasicInfo("Selected presets backed up successfully")
	end

	---@param presetIds Guid[]
	function VanityExportAndBackupManager:RemovePresetsFromBackup(presetIds)
		---@type VanityPresetExport
		local savedPresets = Ext.Vars.GetModVariables(ModuleUUID).SavedPresets

		local presetsToKeep = {}
		if savedPresets then
			for _, presetId in pairs(presetIds) do
				if not savedPresets.presets[presetId] then
					table.insert(presetsToKeep, presetId)
				end
			end
		end

		Ext.Vars.GetModVariables(ModuleUUID).SavedPresets = VanityExportAndBackupManager:ExportPresets(presetsToKeep)
	end

	--#endregion
end

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
	SyncToServer = true
})

VanityExportAndBackupManager = {}

---@param presetId Guid
---@return boolean
function VanityExportAndBackupManager:IsPresetInBackup(presetId)
	---@type VanityPresetExport
	local savedPresets = Ext.Vars.GetModVariables(ModuleUUID).SavedPresets

	return savedPresets.presets[presetId] ~= nil
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
	function VanityExportAndBackupManager:FlipPresetBackupRegistration(presetId)
		---@type VanityPresetBackupRegistry
		local presetBackupRegistry = Ext.Vars.GetModVariables(ModuleUUID).PresetBackupRegistry

		if not presetBackupRegistry then
			presetBackupRegistry = {}
		end

		if not presetBackupRegistry[presetId] then
			presetBackupRegistry[presetId] = true
		else
			presetBackupRegistry[presetId] = false
		end

		Ext.Vars.GetModVariables(ModuleUUID).PresetBackupRegistry = presetBackupRegistry
	end

	---@param presetIds Guid[]
	function VanityExportAndBackupManager:BackupPresets(presetIds)
		Ext.Vars.GetModVariables(ModuleUUID).SavedPresets = VanityExportAndBackupManager:ExportPresets(presetIds, Ext.Vars.GetModVariables(ModuleUUID).SavedPresets)
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

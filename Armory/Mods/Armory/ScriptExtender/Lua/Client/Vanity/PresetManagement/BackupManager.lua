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

VanityBackupManager = {}

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
function VanityBackupManager:IsPresetInBackup(presetId)
	if not cachedBackup then
		cachedBackup = Ext.Vars.GetModVariables(ModuleUUID).SavedPresets
	end

	return (cachedBackup and cachedBackup.presets[presetId] ~= nil) or false
end

---@type VanityPresetBackupRegistry
local backupRegistry

---@param presetId Guid
---@return boolean
function VanityBackupManager:ShouldBackupPreset(presetId)
	if not backupRegistry then
		backupRegistry = Ext.Vars.GetModVariables(ModuleUUID).PresetBackupRegistry or {}
	end

	return backupRegistry[presetId]
end

---@param presetId Guid
function VanityBackupManager:FlipPresetBackupRegistration(presetId)
	if not VanityBackupManager:ShouldBackupPreset(presetId) then
		backupRegistry[presetId] = true
		VanityBackupManager:BackupPresets({ presetId })
	else
		backupRegistry[presetId] = false
		VanityBackupManager:RemovePresetsFromBackup({ presetId })
	end

	Ext.Vars.GetModVariables(ModuleUUID).PresetBackupRegistry = backupRegistry
end

---@param presetIds Guid[]
function VanityBackupManager:BackupPresets(presetIds)
	for i, id in ipairs(presetIds) do
		if not VanityBackupManager:ShouldBackupPreset(id) then
			Logger:BasicDebug("Preset %s should not be backed up, and will be excluded", id)
			presetIds[i] = nil
		end
	end

	if #presetIds == 0 then
		Logger:BasicDebug("None of the provided presets are eligible for backup - skipping.")
		return
	end

	cachedBackup = VanityExportManager:ExportPresets(presetIds, cachedBackup)

	Ext.Vars.GetModVariables(ModuleUUID).SavedPresets = cachedBackup
	Logger:BasicInfo("Selected presets backed up successfully")
end

---@param presetId Guid?
---@param presetBackup VanityPresetExport?
function VanityBackupManager:RestorePresetBackup(presetId, presetBackup)
	if presetId then
		if not presetBackup then
			presetBackup = cachedBackup or Ext.Vars.GetModVariables(ModuleUUID).SavedPresets
		end
		presetBackup = VanityExportManager:ImportPreset({ presetId }, presetBackup)
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
function VanityBackupManager:RemovePresetsFromBackup(presetIds)
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

	cachedBackup = VanityExportManager:ExportPresets(presetsToKeep)
	Ext.Vars.GetModVariables(ModuleUUID).SavedPresets = cachedBackup
end

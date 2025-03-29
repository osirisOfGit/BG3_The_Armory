VanityModPresetManager = {}

---@type {[Guid] : Guid}
VanityModPresetManager.PresetModIndex = {}

---@type {[Guid] : Vanity}
VanityModPresetManager.ModPresetIndex = setmetatable({}, {
	__mode = "v",
	__index = function(t, k)
		local modId = VanityModPresetManager.PresetModIndex[k]

		if modId then
			local export = VanityModPresetManager:GetExportFromMod(k)
			rawset(t, k, export)
			return export
		end
	end
})

---@param modId Guid
---@return Vanity?
function VanityModPresetManager:GetExportFromMod(modId)
	local mod = Ext.Mod.GetMod(modId)
	if mod then
		---@type Vanity?
		local presetFile = FileUtils:LoadTableFile(string.format("Mods/%s/%s", mod.Info.Directory, VanityExportManager.ExportFilename))
		if presetFile then
			return presetFile
		end
	end
end

function VanityModPresetManager:ImportPresetsFromMods()
	if not next(VanityModPresetManager.PresetModIndex) then
		for _, uuid in ipairs(Ext.Mod.GetLoadOrder()) do
			local presetExport = self:GetExportFromMod(uuid)
			if presetExport and presetExport.presets then
				for presetId in pairs(presetExport.presets) do
					self.PresetModIndex[presetId] = uuid
				end
			end
		end
	end
end

---@param presetId Guid
---@return Vanity?
function VanityModPresetManager:GetPresetFromMod(presetId)
	if self.PresetModIndex[presetId] then
		return self.ModPresetIndex[self.PresetModIndex[presetId]]
	end
end


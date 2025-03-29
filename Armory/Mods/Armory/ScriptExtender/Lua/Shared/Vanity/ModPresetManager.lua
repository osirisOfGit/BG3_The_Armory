VanityModPresetManager = {}

---@type {[Guid] : Guid}
VanityModPresetManager.PresetModIndex = {}

local modList = {}

---@type {[Guid] : Vanity}
VanityModPresetManager.ModPresetIndex = setmetatable({}, {
	__mode = "v",
	__index = function(t, k)
		Logger:BasicDebug("Loading mod %s into index", k)

		local modId = VanityModPresetManager.PresetModIndex[k] or (Ext.Mod.GetMod(k) and k)

		if modId then
			local export = VanityModPresetManager:GetExportFromMod(k)
			rawset(t, k, export)
			return export
		end
	end,
	-- I'm 99% sure i'm overengineering this, but i'm tired and kinda obssesed with memory management right now
	__pairs = function(t)
		local keys = {}
		for k in next, t do
			table.insert(keys, k)
		end
		for _, id in ipairs(modList) do
			if not rawget(t, id) then
				t[id] = t[id] -- Trigger __index
				table.insert(keys, id)
			end
		end
		local function iter(tbl, key)
			local nextKey = table.remove(keys, 1)
			if nextKey then
				return nextKey, tbl[nextKey]
			end
		end
		return iter, t, nil
	end
})

---@param modId Guid
---@return Vanity?, Module?
function VanityModPresetManager:GetExportFromMod(modId)
	local mod = Ext.Mod.GetMod(modId)
	if mod then
		---@type Vanity?
		local presetFile = FileUtils:LoadTableFile(string.format("Mods/%s/%s", mod.Info.Directory, VanityExportManager.ExportFilename), "data")
		if presetFile then
			return presetFile, mod
		end
	end
end

function VanityModPresetManager:ImportPresetsFromMods()
	if not next(VanityModPresetManager.PresetModIndex) then
		for _, uuid in ipairs(Ext.Mod.GetLoadOrder()) do
			local presetExport, mod = self:GetExportFromMod(uuid)
			if presetExport and presetExport.presets then
				table.insert(modList, uuid)
				Logger:BasicDebug("Found preset file in %s", uuid)
				self.ModPresetIndex[uuid] = presetExport
				for presetId, preset in pairs(presetExport.presets) do
					preset.ModSourced = VanityModDependencyManager:RecordDependency(mod)
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

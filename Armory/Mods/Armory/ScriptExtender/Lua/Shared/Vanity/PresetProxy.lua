---@diagnostic disable: missing-fields
---@type Vanity
PresetProxy = {
	effects = {},
	miscNameCache = {},
	--- Everything except the PresetManager only access the active preset,
	--- so if the active preset swaps and isn't in this table, we change the Vanity view to the container of the active preset
	--- This also allows us to use weak values so the GC can clear any presets that aren't being used
	presets = setmetatable({}, {
		__mode = "v",
		__index = function(t, k)
			local presetExport = VanityModPresetManager:GetPresetFromMod(k)

			if not presetExport and ConfigurationStructure.config.vanity.presets[k] then
				presetExport = ConfigurationStructure.config.vanity
			end

			if presetExport then
				PresetProxy.effects = presetExport.effects
				PresetProxy.miscNameCache = presetExport.miscNameCache

				for i in pairs(t) do
					t[i] = nil
				end

				-- Lazy hack of preserving the ConfigurationStructure proxy if that's the container, since the tableUtil doesn't use pairs()
				for presetId, preset in TableUtils:OrderedPairs(presetExport.presets) do
					rawset(t, presetId, preset)
				end

				return rawget(t, k)
			end
		end
	})
}

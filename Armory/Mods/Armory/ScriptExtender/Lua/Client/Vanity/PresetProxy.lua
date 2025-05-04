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
			local function setValue(presetExport)
				if presetExport then
					Logger:BasicDebug("Found preset %s, loading into proxy", k)
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
				else
					Logger:BasicDebug("Preset %s was requested but could not be found", k)
				end
			end

			local presetExport = VanityModPresetManager:GetPresetFromMod(k)

			if not presetExport and ConfigurationStructure.config.vanity.presets[k] then
				-- don't need to make changes on the server, so get the real table for easier iterating
				if Ext.IsServer() then
					presetExport = ConfigurationStructure:GetRealConfigCopy().vanity
				else
					presetExport = ConfigurationStructure.config.vanity
				end
			end

			if not presetExport then
				local lock = true
				Channels.GetUserSpecificPreset:RequestToServer({ presetId = k }, function(data)
					if next(data) then
						Channels.GetUserSpecificPreset:RequestToClient({ presetId = k }, data.user, function(data)
							if next(data) then
								presetExport = data
							end

							lock = false
						end)
					end
				end)

				local function waitFor(callback)
					if lock then
						Ext.Timer.WaitFor(20, function()
							waitFor(callback)
						end)
					else
						callback(setValue(presetExport))
					end
				end

				return waitFor
			else
				return setValue(presetExport)
			end
		end
	})
}

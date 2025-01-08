Ext.Require("Shared/Configurations/VanityCharacterCriteria.lua")

Ext.Vars.RegisterModVariable(ModuleUUID, "ActivePreset", {
	Server = true, Client = true, SyncToClient = true, WriteableOnClient = true, WriteableOnServer = false
})

local config = ConfigurationStructure:UpdateConfigForServer()

local function ApplyTransmogsPerPreset()
	local activePresetId = Ext.Vars.GetModVariables(ModuleUUID).ActivePreset

	if activePresetId then
		local activePreset = config.vanity.presets[activePresetId]
		Logger:BasicInfo("Preset '%s' by '%s' (version %s) is now active", activePreset.Name, activePreset.Author, activePreset.Version)
		local activeOutfits = activePreset.Outfits

		if next(activeOutfits) then
			local playerCriteriaTable = {}
			for _, player in Osi.DB_Players:Get(nil) do
				---@type {[VanityCharacterCriteriaType] : string}
				local criteriaTable = {}

				---@type EntityHandle
				local playerEntity = Ext.Entity.Get(player[1])

				---@type ResourceRace
				local raceResource = Ext.StaticData.Get(playerEntity.Race.Race, "Race")
				if raceResource.ParentGuid == "00000000-0000-0000-0000-000000000000" then
					criteriaTable["Race"] = raceResource.ResourceUUID
				else
					criteriaTable["Race"] = raceResource.ParentGuid
					criteriaTable["Subrace"] = raceResource.ResourceUUID
				end

				local highestClassLevel = 0
				for _, classInfo in pairs(playerEntity.Classes.Classes) do
					if classInfo.Level > highestClassLevel then -- TODO - handle equal case
						highestClassLevel = classInfo.Level
						criteriaTable["Class"] = classInfo.ClassUUID
						if classInfo.SubClassUUID ~= "00000000-0000-0000-0000-000000000000" then
							criteriaTable["Subclass"] = classInfo.SubClassUUID
						else
							criteriaTable["Subclass"] = nil
						end
					end
				end

				criteriaTable["BodyType"] = playerEntity.CharacterCreationStats.BodyShape + playerEntity.CharacterCreationStats.BodyType

				---@type ResourceOrigin
				local originResource = Ext.StaticData.Get(playerEntity.Origin.Origin, "Origin")

				criteriaTable[originResource.IsHenchman and "Hireling" or "Origin"] = playerEntity.Origin.Origin

				Logger:BasicDebug("Player %s Criteria Table is: \n%s", player[1], Ext.Json.Stringify(playerCriteriaTable))

				---@type {[ActualSlot]: VanityOutfitSlot}
				local playerOutfit

				local compositeKey = CreateCriteriaCompositeKey(playerCriteriaTable)
				if activeOutfits[compositeKey] then
					playerOutfit = activeOutfits[compositeKey]
					Logger:BasicDebug("Player %s was matched to an outfit with criteria table: %s", player[1], Ext.Json.Stringify(playerCriteriaTable))
				else
					--[[
					Given
						[1] = "Origin",
						[2] = "Hireling",
						[3] = "Race",
						[4] = "Subrace",
						[5] = "BodyType",
						[6] = "Class",
						[7] = "Subclass",
	
					identify an outfit by the matching composite key, which uses the structure:
					Origin|Hireling|Race|Subrace|BodyType|Class|Subclass

					Example: (Actual key will use resource guids, this is just for clarity)
					Karlach||Tiefling|Zariel|2|Barbarian|

					Constraints:
					1. Origin + Hireling are mutually exclusive
					2. You can't have a Subrace/Subclass without a Race/Class
					3. A composite key can be made up of 1 - 6 values, adhering to the above constraints
					4. Enum is defined in descending order of weight - an outfit that has just Origin specified takes precedence over one that has just Race specified

					Sample of scenarios to solve for, in order of preferred matches
					1. Origin/Race/Subrace/BodyType/Class/Subclass
					2. Origin/Race/Subrace/BodyType
					3. Origin/Race/BodyType
					4. Origin/Race/Class/Subclass
					5. Origin/BodyType/Class
					6. Origin/Class

					Repeat shifting to the right (or down, if looking at the above enum) if all the permutations with Origin don't match any composite keys
					i.e. start looking for matches of Race/Subrace/BodyType
					]]

					-- t = populated criteria table from a player character. Assume all fields are populated (Origin instead of Hireling)

					-- only run the below if the composite key computed from t doesn't match an entry

					for i = 1, 7, 1 do

						-- This solves Origin/Race/Subrace/BodyType/Class or Origin/Race/Subrace
						for x = 7, i + 1, -1 do
							t[x] = nil
							-- if composite key computed from t matches an entry, return out
						end

						-- restore t back to original
						
						-- This solves Origin/Race/Class/Subclass and Origin/BodyType/Class/Subclass
						for y = i + 1, 7, 1 do
							-- if i == Origin then first iteration of y == Race
							tc = copy(t)
							for z = y + 1, 7, 1 do
								-- if y == Race then first iteration of z == Subrace
								t[z] = nil
								-- if composite key computed from t matches an entry, return out
							end
							t = tc
							t[y] = nil
						end

						-- restore t back to original

						-- How to solve Origin/Race/Class
						-- Regular exhaustive permutation algorithm at this point? Not that i know how to write one

						t[i] = nil
					end



					for keyToCheck = 1, 7, 1 do
						if playerCriteriaTable[VanityCharacterCriteriaType[keyToCheck]] then
							local newCompositeTable = TableUtils:DeeplyCopyTable(criteriaTable)

							for keyToRemove = 7, keyToCheck + 1, -1 do
								if keyToRemove ~= keyToCheck then
									local value = newCompositeTable[VanityCharacterCriteriaType[keyToRemove]]
									if value then
										newCompositeTable[VanityCharacterCriteriaType[keyToRemove]] = nil
										compositeKey = CreateCriteriaCompositeKey(newCompositeTable)
										if activeOutfits[compositeKey] then
											playerOutfit = activeOutfits[compositeKey]
											Logger:BasicDebug("Player %s was matched to an outfit with criteria table: %s", player[1], Ext.Json.Stringify(newCompositeTable))
											goto breakOut
										end
										newCompositeTable[VanityCharacterCriteriaType[keyToRemove]] = value
									end
								end
							end
						end
					end
					::breakOut::
				end
			end
		end
	end
end

Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", ApplyTransmogsPerPreset)

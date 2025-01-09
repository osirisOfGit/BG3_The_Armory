Ext.Require("Shared/Configurations/VanityCharacterCriteria.lua")
Ext.Require("Server/Vanity/OutfitMatcher.lua")

Ext.Vars.RegisterModVariable(ModuleUUID, "ActivePreset", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true
})

local function ApplyTransmogsPerPreset()
	local config = ConfigurationStructure:UpdateConfigForServer()
	local activePresetId = Ext.Vars.GetModVariables(ModuleUUID).ActivePreset

	if activePresetId then
		local activePreset = config.vanity.presets[activePresetId]
		Logger:BasicInfo("Preset '%s' by '%s' (version %s) is now active", activePreset.Name, activePreset.Author, activePreset.Version)
		local activeOutfits = activePreset.Outfits

		if next(activeOutfits) then
			for _, player in pairs(Osi.DB_Players:Get(nil)) do
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

				-- criteriaTable["BodyType"] = playerEntity.CharacterCreationStats.BodyShape + playerEntity.CharacterCreationStats.BodyType

				---@type ResourceOrigin
				local originResource = Ext.StaticData.Get(playerEntity.Origin.field_18, "Origin")

				criteriaTable[originResource.IsHenchman and "Hireling" or "Origin"] = originResource.ResourceUUID

				Logger:BasicDebug("Player %s Criteria Table is: \n%s", player[1], Ext.Json.Stringify(criteriaTable))

				---@type {[ActualSlot]: VanityOutfitSlot}
				local playerOutfit

				local compositeKey = CreateCriteriaCompositeKey(criteriaTable)
				if activeOutfits[compositeKey] then
					playerOutfit = activeOutfits[compositeKey]
					Logger:BasicDebug("Player %s was matched to an outfit with criteria table: %s", player[1], Ext.Json.Stringify(criteriaTable))
				else
					playerOutfit, compositeKey = Matcher.findBestMatch(criteriaTable, activeOutfits)
				end
				
				if playerOutfit then
					Logger:BasicDebug("Player %s was matched to an outfit with criteria table: %s", player[1], Ext.Json.Stringify(ParseCriteriaCompositeKey(compositeKey)))
					Transmogger:MogCharacter(playerEntity, playerOutfit)
				else
					Logger:BasicInfo("Could not find an outfit for player %s", player[1])
				end
			end
		end
	end
end

Ext.RegisterNetListener(ModuleUUID .. "_PresetUpdated", function(channel, payload, user)
	ApplyTransmogsPerPreset()
end)

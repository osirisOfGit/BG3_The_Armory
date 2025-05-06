Ext.Require("Shared/Configurations/VanityCharacterCriteria.lua")
Ext.Require("Server/Vanity/OutfitMatcher.lua")
Ext.Require("Server/Vanity/ServerPresetManager.lua")

Ext.Vars.RegisterUserVariable("TheArmory_Vanity_ActiveOutfit", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true,
	SyncOnWrite = true
})

PartyOutfitManager = {}

function PartyOutfitManager:ApplyTransmogsPerPreset()
	for _, player in pairs(Osi.DB_Players:Get(nil)) do
		player = player[1]
		local activePreset = ServerPresetManager:GetCharacterPreset(player)

		local activeOutfits
		if activePreset then
			activeOutfits = activePreset.Outfits
		end

		if activeOutfits and next(activeOutfits) then
			PartyOutfitManager:FindAndApplyOutfit(player, activeOutfits)
		else
			Logger:BasicDebug("%s does not have an outfit, clearing their transmog", player)
			Transmogger:ClearOutfit(player)
		end
	end
end

---@param player string
---@param activeOutfits {[VanityCriteriaCompositeKey] : VanityOutfit}
function PartyOutfitManager:FindAndApplyOutfit(player, activeOutfits)
	local startTime = Ext.Utils.MonotonicTime()

	---@type {[VanityCharacterCriteriaType] : string}
	local criteriaTable = {}

	---@type EntityHandle
	local playerEntity = Ext.Entity.Get(player)

	if playerEntity.Classes and playerEntity.Classes.Classes then
		local highestClassLevel = 0
		for _, classInfo in pairs(playerEntity.Classes.Classes) do
			if classInfo.Level > highestClassLevel then -- TODO - handle equal case
				highestClassLevel = classInfo.Level
				criteriaTable["Class"] = classInfo.ClassUUID
				if classInfo.SubClassUUID ~= "00000000-0000-0000-0000-000000000000" then
					criteriaTable["Subclass"] = classInfo.SubClassUUID
				end
			end
		end
	end

	if playerEntity.CharacterCreationStats then
		if playerEntity.CharacterCreationStats.Race then
			criteriaTable["Race"] = playerEntity.CharacterCreationStats.Race
			if playerEntity.CharacterCreationStats.SubRace ~= "00000000-0000-0000-0000-000000000000" then
				criteriaTable["Subrace"] = playerEntity.CharacterCreationStats.SubRace
			end
		end

		if playerEntity.CharacterCreationStats.BodyType then
			--[[
				BodyType    BodyShape
			1       1            0
			2       0            0
			3       1            1
			4       0            1
			]]
			local bodyType = playerEntity.CharacterCreationStats.BodyType
			local bodyShape = playerEntity.CharacterCreationStats.BodyShape
			if bodyType == 0 then
				bodyType = 2
			end
			if bodyShape == 1 then
				bodyShape = 2
			end

			criteriaTable["BodyType"] = bodyShape + bodyType
		end
	end

	if playerEntity.Origin and playerEntity.Origin.field_18 then
		---@type ResourceOrigin
		local originResource = Ext.StaticData.Get(playerEntity.Origin.field_18, "Origin")
		if originResource then
			criteriaTable[originResource.IsHenchman and "Hireling" or "Origin"] = originResource.ResourceUUID
		end
	end
	Logger:BasicDebug("Player %s Criteria Table is: \n%s", player, Ext.Json.Stringify(ConvertCriteriaTableToDisplay(criteriaTable, true)))

	---@type {[ActualSlot]: VanityOutfitSlot}?
	local playerOutfit

	local compositeKey = CreateCriteriaCompositeKey(criteriaTable)
	if activeOutfits[compositeKey] then
		playerOutfit = activeOutfits[compositeKey]
	else
		playerOutfit, compositeKey = OutfitMatcher.findBestMatch(criteriaTable, activeOutfits)
	end

	if playerOutfit then
		Logger:BasicInfo("%s was matched to an outfit (in %dms) with Criteria Table: %s", player, Ext.Utils.MonotonicTime() - startTime,
			Ext.Json.Stringify(ConvertCriteriaTableToDisplay(ParseCriteriaCompositeKey(compositeKey), true)))
		playerEntity.Vars.TheArmory_Vanity_ActiveOutfit = compositeKey
		Transmogger:MogCharacter(playerEntity)
	else
		Logger:BasicInfo("Could not find an outfit for player %s with criteriaTable %s", player, Ext.Json.Stringify(ConvertCriteriaTableToDisplay(criteriaTable, true)))
		playerEntity.Vars.TheArmory_Vanity_ActiveOutfit = nil
		Transmogger:ClearOutfit(player)
	end
end


Ext.Osiris.RegisterListener("CharacterJoinedParty", 1, "after", function(character)
	PartyOutfitManager:ApplyTransmogsPerPreset()
end)

--#region Camp Outfit Autoswapper

Ext.Osiris.RegisterListener("EnteredCombat", 2, "after", function(character, combatGuid)
	if Osi.HasActiveStatus(character, "ARMOR_VANITY_CAMP_CLOTHES_COMBAT_STATUS") == 1 then
		if Osi.GetArmourSet(character) == 1 then
			Osi.SetArmourSet(character, 0)
		end
	end
end)

Ext.Osiris.RegisterListener("LeftCombat", 2, "after", function(character, combatGuid)
	if Osi.HasActiveStatus(character, "ARMOR_VANITY_CAMP_CLOTHES_COMBAT_STATUS") == 1 then
		if Osi.GetArmourSet(character) == 0 then
			Osi.SetArmourSet(character, 1)
		end
	end
end)

Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function(level, _)
	if level == "SYS_CC_I" then return end

	for _, player_char in pairs(Osi.DB_Players:Get(nil)) do
		local character = player_char[1]
		if Osi.HasPassive(character, "ARMOR_VANITY_CAMP_CLOTHES_COMBAT_PASSIVE") == 0 then
			Osi.AddPassive(character, "ARMOR_VANITY_CAMP_CLOTHES_COMBAT_PASSIVE")
		end
	end
end)

---@param character CHARACTER
Ext.Osiris.RegisterListener("CharacterJoinedParty", 1, "after", function(character)
	if Osi.IsSummon(character) == 1 or Osi.IsPartyFollower(character) == 1 then return end

	if Osi.HasPassive(character, "ARMOR_VANITY_CAMP_CLOTHES_COMBAT_PASSIVE") == 0 then
		Osi.AddPassive(character, "ARMOR_VANITY_CAMP_CLOTHES_COMBAT_PASSIVE")
	end
end)

---@param character CHARACTER
Ext.Osiris.RegisterListener("CharacterLeftParty", 1, "after", function(character)
	if Osi.HasPassive(character, "ARMOR_VANITY_CAMP_CLOTHES_COMBAT_PASSIVE") == 1 then
		Osi.RemovePassive(character, "ARMOR_VANITY_CAMP_CLOTHES_COMBAT_PASSIVE")
		Osi.RemoveStatus(character, "ARMOR_VANITY_CAMP_CLOTHES_COMBAT_STATUS")
	end
end)
--#endregion

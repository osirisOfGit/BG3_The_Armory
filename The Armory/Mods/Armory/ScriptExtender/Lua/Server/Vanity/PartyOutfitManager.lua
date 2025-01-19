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

Ext.Vars.RegisterUserVariable("TheArmory_Vanity_ActiveOutfit", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true,
	SyncOnWrite = true
})

---@type VanityPreset
ActiveVanityPreset = nil

Ext.Events.SessionLoaded:Subscribe(function(e)
	ActiveVanityPreset = ConfigurationStructure:UpdateConfigForServer().vanity.presets[Ext.Vars.GetModVariables(ModuleUUID).ActivePreset]
end)

---@param player string
---@param activeOutfits {[VanityCriteriaCompositeKey] : VanityOutfit}
local function FindAndApplyOutfit(player, activeOutfits)
	local startTime = Ext.Utils.MonotonicTime()
	---@type {[VanityCharacterCriteriaType] : string}
	local criteriaTable = {}

	---@type EntityHandle
	local playerEntity = Ext.Entity.Get(player)

	criteriaTable["Race"] = playerEntity.CharacterCreationStats.Race
	if playerEntity.CharacterCreationStats.SubRace ~= "00000000-0000-0000-0000-000000000000" then
		criteriaTable["Subrace"] = playerEntity.CharacterCreationStats.SubRace
	end

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

	--[[
		 BodyType    BodyShape
	1       1            0
	2       1            1
	3       0            0
	4       0            1
	]]
	local bodyType = playerEntity.CharacterCreationStats.BodyType
	local bodyShape = playerEntity.CharacterCreationStats.BodyShape
	bodyShape = bodyType == 0 and bodyShape + 1 or bodyShape
	bodyType = bodyType == 0 and 2 or bodyType
	criteriaTable["BodyType"] = bodyShape + bodyType

	---@type ResourceOrigin
	local originResource = Ext.StaticData.Get(playerEntity.Origin.field_18, "Origin")

	criteriaTable[originResource.IsHenchman and "Hireling" or "Origin"] = originResource.ResourceUUID

	Logger:BasicDebug("Player %s Criteria Table is: \n%s", player, Ext.Json.Stringify(criteriaTable))

	---@type {[ActualSlot]: VanityOutfitSlot}
	local playerOutfit

	local compositeKey = CreateCriteriaCompositeKey(criteriaTable)
	if activeOutfits[compositeKey] then
		playerOutfit = activeOutfits[compositeKey]
		Logger:BasicDebug("Player %s was matched to an outfit with criteria table: %s", player, Ext.Json.Stringify(criteriaTable))
	else
		playerOutfit, compositeKey = OutfitMatcher.findBestMatch(criteriaTable, activeOutfits)
	end

	if playerOutfit then
		Logger:BasicDebug("Player %s was matched to an outfit (in %dms) with criteria table: %s", player, Ext.Utils.MonotonicTime() - startTime,
			Ext.Json.Stringify(ParseCriteriaCompositeKey(compositeKey)))
		playerEntity.Vars.TheArmory_Vanity_ActiveOutfit = compositeKey
		Transmogger:MogCharacter(playerEntity)
	else
		Logger:BasicInfo("Could not find an outfit for player %s with criteriaTable %s", player, Ext.Json.Stringify(criteriaTable))
	end
end

local function ApplyTransmogsPerPreset()
	local config = ConfigurationStructure:UpdateConfigForServer()
	local activePresetId = Ext.Vars.GetModVariables(ModuleUUID).ActivePreset

	if activePresetId then
		ActiveVanityPreset = config.vanity.presets[activePresetId]

		Logger:BasicInfo("Preset '%s' by '%s' (version %s) is now active", ActiveVanityPreset.Name, ActiveVanityPreset.Author, ActiveVanityPreset.Version)
		local activeOutfits = ActiveVanityPreset.Outfits

		if next(activeOutfits) then
			for _, player in pairs(Osi.DB_Players:Get(nil)) do
				FindAndApplyOutfit(player[1], activeOutfits)
			end
		end
	end
end

Ext.RegisterNetListener(ModuleUUID .. "_PresetUpdated", function(channel, payload, user)
	ApplyTransmogsPerPreset()
end)

Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function(levelName, isEditorMode)
	ApplyTransmogsPerPreset()
end)

Ext.Osiris.RegisterListener("CharacterJoinedParty", 1, "after", function(character)
	if ActiveVanityPreset and next(ActiveVanityPreset.Outfits) then
		FindAndApplyOutfit(character, ActiveVanityPreset.Outfits)
	end
end)

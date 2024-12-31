Ext.Vars.RegisterModVariable(ModuleUUID, "Config_State_Tracker", {
	Server = true,
	Client = false
})

local function buildStatString(stringToModify, stringToAdd)
	local result
	if not stringToModify or stringToModify == "" then
		result = stringToAdd
	else
		if stringToModify:sub(-1) ~= ";" then
			result = stringToModify .. ";" .. stringToAdd
		else
			result = stringToModify .. stringToAdd
		end
	end

	return result
end

local slotToCategory = {
	["Helmet"] = "Armor",
	["Breast"] = "Armor",
	["Cloak"] = "Armor",
	["Boots"] = "Armor",
	["Gloves"] = "Armor",
	["Amulet"] = "Accessories",
	["Ring"] = "Accessories",
	["MusicalInstrument"] = "Accessories"
}

local statFunctions = {
	---@param stat ItemStat
	["attunements"] = function(stat, _)
		-- Friggen lua falsy logic
		local shouldAttune = ConfigManager.ConfigCopy.items.requiresAttunementOverrides[stat.Name]
		if shouldAttune == nil then
			shouldAttune = (RarityEnum[stat.Rarity] >= RarityEnum[ConfigManager.ConfigCopy.items.attunementRarityThreshold] and (stat.Boosts ~= "" or stat.PassivesOnEquip ~= "" or stat.StatusOnEquip ~= ""))
		end

		if shouldAttune and (not stat.UseCosts or not (string.find(stat.UseCosts, ";Attunement:1") or string.find(stat.UseCosts, "^Attunement:1"))) then
			stat.UseCosts = buildStatString(stat.UseCosts, "Attunement:1")
			-- Khonsu scripts weren't working no matter what i tried, so this is the next best thing
			for _, requirement in pairs(stat.Requirements) do
				if requirement.Requirement == Ext.Enums.RequirementType.Combat then
					return
				end
			end
			local reqs = stat.Requirements
			table.insert(reqs, { Requirement = Ext.Enums.RequirementType.Combat, Param = -1, Not = true })
			stat.Requirements = reqs
		end
	end,
	---@param rarity Rarity
	---@param category RarityLimitCategories
	["rarityLimits"] = function(rarity, category)
		---@param stat ItemStat
		return function(stat)
			if stat.Rarity == rarity
				and (category == "Total"
					or (((string.find(stat.Slot, "Melee") or string.find(stat.Slot, "Ranged")) and category == "Weapons")
						or (slotToCategory[stat.Slot] or "") == category))
			then
				local resourceString = string.format("%s%sLimitAttunement:1", rarity, category)
				if (not stat.UseCosts or not string.find(stat.UseCosts, resourceString)) then
					stat.UseCosts = buildStatString(stat.UseCosts, resourceString)
				end
			end
		end
	end,
}

---@return AttunementRules
local function GetDifficulty()
	-- Thanks Focus
	local difficulty = Osi.GetRulesetModifierString("cac2d8bd-c197-4a84-9df1-f86f54ad4521")
	if difficulty == "HARD" and Osi.GetRulesetModifierBool("338450d9-d77d-4950-9e1e-0e7f12210bb3") == 1 then
		difficulty = "HONOUR"
	end
	Logger:BasicInfo("Processing rules with Difficulty rules %s", ConfigManager.ConfigCopy.rules.difficulties[difficulty] and difficulty or "Base")

	return ConfigManager.ConfigCopy.rules.difficulties[difficulty] or ConfigManager.ConfigCopy.rules.difficulties["Base"]
end

function BuildRelevantStatFunctions()
	local difficultyRules = GetDifficulty()

	if not difficultyRules then
		Logger:BasicWarning("Difficulty rules haven't been configured yet, meaning this is your first time loading. Reload to pick up the functionality!")
		return {}
	end

	local actionResources = ""

	local enabled = MCM.Get("enabled")

	if not enabled then
		Logger:BasicInfo("Functionality is disabled - disabling all resources")
	end

	local maxAmounts = {}
	local functionsToReturn = {}
	if difficultyRules.totalAttunementLimit < 13 then
		if enabled then
			Logger:BasicInfo("Attunement limit is set to %s, which is less than 12 (max number of equipable slots), so enabling Attunement resources",
				difficultyRules.totalAttunementLimit)
		end

		actionResources = buildStatString(actionResources, string.format("ActionResource(Attunement,%s,0)", enabled and difficultyRules.totalAttunementLimit or 0))
		maxAmounts["Attunement"] = enabled and difficultyRules.totalAttunementLimit or 0
		if enabled then
			table.insert(functionsToReturn, statFunctions["attunements"])
		end
	end

	for _, rarity in ipairs(RarityEnum) do
		for _, category in ipairs(RarityLimitCategories) do
			local categoryMaxSlots = RarityLimitCategories[category]
			if difficultyRules.rarityLimits[rarity][category] < categoryMaxSlots then
				if enabled then
					Logger:BasicInfo("Rarity %s's %s limit is set to %s, which is less than the max of %s, so enabling the associated resource",
						rarity,
						category,
						difficultyRules.rarityLimits[rarity][category],
						categoryMaxSlots
					)
				end

				actionResources = buildStatString(actionResources,
					string.format("ActionResource(%s%sLimitAttunement,%s,0)", rarity, category, enabled and difficultyRules.rarityLimits[rarity][category] or 0))

				-- Ext.StaticData.Get(cachedResources[rarity .. category .. "LimitAttunement"], "ActionResource").ShowOnActionResourcePanel = guiRules["resource"]


				maxAmounts[string.format("%s%sLimitAttunement", rarity, category)] = enabled and difficultyRules.rarityLimits[rarity][category] or 0

				if enabled then
					table.insert(functionsToReturn, statFunctions["rarityLimits"](rarity, category))
				end
			end
		end
	end

	local configState = Ext.Vars.GetModVariables(ModuleUUID).Config_State_Tracker or {
		maxAmounts = {},
		overrides = {}
	}

	if not configState.maxAmounts then
		configState.maxAmounts = {}
	end
	if not configState.overrides then
		configState.overrides = {}
	end

	if TableUtils:CompareLists(configState.maxAmounts, maxAmounts) and TableUtils:CompareLists(configState.overrides, ConfigManager.ConfigCopy.items) then
		Logger:BasicInfo("Configuration hasn't changed for this save - skipping rest of initialization")
		return {}
	else
		Logger:BasicInfo("Configuration has been changed for this save - proceeeding with the rest of initialization")
		Ext.Vars.GetModVariables(ModuleUUID).Config_State_Tracker = {
			maxAmounts = maxAmounts,
			overrides = ConfigManager.ConfigCopy.items
		}
	end

	for _, charEntity in pairs(Ext.Entity.GetAllEntitiesWithComponent("ActionResources")) do
		if charEntity.Uuid then
			local character = charEntity.Uuid.EntityUuid

			-- You would not believe the amount of shit i tried before i landed on this
			-- TLDR: Stats modified after StatsLoaded don't update the GUI for things using those stats that are already in the gameworld.
			-- e.g. adding a passive to CharacterStats gives them the initial passive, but changing the passive boosts on LevelGameplayReady doesn't show the resources until a reload
			-- So, shortcutting the process by just applying/removing boosts directly, which does update the GUI
			local playerAmountTracker = TableUtils:DeeplyCopyTable(maxAmounts)
			for _, boostEntry in pairs(charEntity.BoostsContainer.Boosts) do
				if boostEntry.Type == "ActionResource" then
					for _, boost in pairs(boostEntry.Boosts) do
						local resourceBoost = boost.ActionResourceValueBoost
						local resourceName = Ext.StaticData.Get(resourceBoost.ResourceUUID, "ActionResource").Name
						if playerAmountTracker[resourceName] then
							resourceBoost.Amount = playerAmountTracker[resourceName]
							playerAmountTracker[resourceName] = nil
						elseif string.match(resourceName, "^.*Attunement$") then
							Osi.RemoveBoosts(character, string.format("ActionResource(%s,%s,0)", resourceName, resourceBoost.Amount), 0, "", character)
						end
					end
					break
				end
			end

			for maxAmountResource, maxAmount in pairs(playerAmountTracker) do
				Osi.AddBoosts(character, string.format("ActionResource(%s,%s,0)", maxAmountResource, maxAmount), "", character)
			end

			local resources = charEntity.ActionResources.Resources
			for _, resource in pairs(resources) do
				local resource = resource[1]
				local resourceName = Ext.StaticData.Get(resource.ResourceUUID, "ActionResource").Name
				if string.match(resourceName, "^.*Attunement$") then
					if not maxAmounts[resourceName] then
						Osi.AddBoosts(character, string.format("ActionResource(%s,0,0)", resourceName), "", character)
					end
				end
			end
		end
	end

	return functionsToReturn
end

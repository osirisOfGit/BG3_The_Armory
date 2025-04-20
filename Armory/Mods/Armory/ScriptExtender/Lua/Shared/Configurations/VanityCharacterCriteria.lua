---@alias VanityCriteriaCompositeKey string

---@enum VanityCharacterCriteriaType
VanityCharacterCriteriaType = {
	[1] = "Origin",
	[2] = "Hireling",
	[3] = "Race",
	[4] = "Subrace",
	[5] = "BodyType",
	[6] = "Class",
	[7] = "Subclass",
	Origin = 1,
	Hireling = 2,
	Race = 3,
	Subrace = 4,
	BodyType = 5,
	Class = 6,
	Subclass = 7,
}

Translator:RegisterTranslation({
	["Origin"] = "ha057630ea08143a4b03a096c096b2ae078de",
	["Hireling"] = "heaa603343c5a41d28038e0aa9538b6fb3aa2",
	["Race"] = "hbee924c4dc99454c825b5245ee862e161e59",
	["Subrace"] = "h85d392bd42a14d92a6533654cfb969bd4agc",
	["BodyType"] = "h220792c3549346a0acf165fffd99503b975g",
	["Class"] = "h42428030fd9c47ccb714a2d75fb9889ea6f8",
	["Subclass"] = "haf2c5cb12b364e998df5d5d8e08246a091a8",
})

---@param criteriaTable {[VanityCharacterCriteriaType] : string} of VanityCharacterCriteria values to concat into an ordered key
---@return string compositeKey
function CreateCriteriaCompositeKey(criteriaTable)
	local criteria = {}
	for i = 1, 7 do
		criteria[i] = criteriaTable[VanityCharacterCriteriaType[i]] or ""
	end
	return table.concat(criteria, "|")
end

local function split(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	local pattern = "([^" .. sep .. "]*)"
	for str in string.gmatch(inputstr, pattern) do
		table.insert(t, str)
	end
	return t
end

---@param compositeKey string the composite key to parse
---@return {[VanityCharacterCriteriaType] : string} criteriaTable
function ParseCriteriaCompositeKey(compositeKey)
	local criteriaTable = {}

	local criteria = split(compositeKey, "|")
	for i = 1, 7 do
		criteriaTable[VanityCharacterCriteriaType[i]] = criteria[i] or ""
	end
	return criteriaTable
end

---@param criteriaTable table
---@param includeUUIDS boolean?
---@param usingCacheForMissing boolean?
---@return {[VanityCharacterCriteriaType]: string}
function ConvertCriteriaTableToDisplay(criteriaTable, includeUUIDS, usingCacheForMissing)
	local displayTable = {}
	for _, criteriaType in ipairs(VanityCharacterCriteriaType) do
		local criteriaId = criteriaTable[criteriaType]
		local criteriaValue
		if not criteriaId or criteriaId == "" then
			criteriaValue = "---"
		elseif criteriaType == "BodyType" then
			criteriaValue = criteriaId
		else
			local resourceType = (criteriaType == "Class" or criteriaType == "Subclass") and "ClassDescription" or criteriaType
			resourceType = criteriaType == "Subrace" and "Race" or resourceType
			resourceType = criteriaType == "Hireling" and "Origin" or resourceType

			---@type ResourceClassDescription|ResourceRace|ResourceOrigin
			local resource = Ext.StaticData.Get(criteriaId, resourceType)
			if resource then
				criteriaValue = resource.DisplayName:Get() or resource.Name
				if includeUUIDS then
					criteriaValue = string.format("%s (%s)", criteriaValue, criteriaId)
				end
				ConfigurationStructure.config.vanity.miscNameCache[criteriaId] = criteriaValue
			else
				if not usingCacheForMissing then
					criteriaValue = string.format("%s Not Found - Missing Mod? UUID: %s",
						ConfigurationStructure.config.vanity.miscNameCache[criteriaId] or "Unknown Name",
						criteriaId)
				else
					criteriaValue = ConfigurationStructure.config.vanity.miscNameCache[criteriaId] or ("Unknown Name: " .. criteriaId)
				end
			end
		end
		displayTable[criteriaType] = criteriaValue
	end

	return displayTable
end

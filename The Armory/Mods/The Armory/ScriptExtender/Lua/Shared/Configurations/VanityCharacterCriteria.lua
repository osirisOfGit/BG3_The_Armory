---@alias VanityCriteriaCompositeKey string

---@enum VanityCharacterCriteriaType
VanityCharacterCriteriaType = {
	Origin = 1,
	Hireling = 2,
	Race = 3,
	Subrace = 4,
	BodyType = 5,
	Class = 6,
	Subclass = 7,
	[1] = "Origin",
	[2] = "Hireling",
	[3] = "Race",
	[4] = "Subrace",
	[5] = "BodyType",
	[6] = "Class",
	[7] = "Subclass",
}

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
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
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

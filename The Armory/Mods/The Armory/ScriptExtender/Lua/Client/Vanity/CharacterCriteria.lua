---@type {[Guid]: ResourceRace[]}
local playableRaces = {}

local function PopulatePlayableRaces()
	local foundSubraces = {}
	for _, presetGuid in pairs(Ext.StaticData.GetAll("CharacterCreationPreset")) do
		---@type ResourceCharacterCreationPreset
		local preset = Ext.StaticData.Get(presetGuid, "CharacterCreationPreset")

		if preset.RaceUUID then
			---@type ResourceRace
			local subRace = Ext.StaticData.Get(preset.SubRaceUUID, "Race")

			if not playableRaces[preset.RaceUUID] then
				playableRaces[preset.RaceUUID] = {}
			end

			if subRace and not foundSubraces[subRace.ResourceUUID] then
				table.insert(playableRaces[preset.RaceUUID], subRace)
				foundSubraces[subRace.ResourceUUID] = true
			end
		end
	end
end

---@type {[Guid] : ResourceClassDescription[] }
local classesAndSubclasses = {}
local function PopulateClassesAndSubclasses()
	for _, classGuid in pairs(Ext.StaticData.GetAll("ClassDescription")) do
		---@type ResourceClassDescription
		local class = Ext.StaticData.Get(classGuid, "ClassDescription")

		if class.ParentGuid == "00000000-0000-0000-0000-000000000000" and not classesAndSubclasses[class.ResourceUUID] then
			classesAndSubclasses[class.ResourceUUID] = {}
		else
			if not classesAndSubclasses[class.ParentGuid] then
				classesAndSubclasses[class.ParentGuid] = {}
			end

			table.insert(classesAndSubclasses[class.ParentGuid], class)
			table.sort(classesAndSubclasses[class.ParentGuid], function(a, b)
				return a.Name < b.Name
			end)
		end
	end
end

---@type Guid[]
local originCharacters = {}
---@type Guid[]
local hirelings = {}
local function PopulateOriginCharacters()
	for _, originGuid in pairs(Ext.StaticData.GetAll("Origin")) do
		---@type ResourceOrigin
		local origin = Ext.StaticData.Get(originGuid, "Origin")

		if origin.IsHenchman then
			table.insert(hirelings, originGuid)
		else
			table.insert(originCharacters, originGuid)
		end
	end

	--- O(fuck it)
	table.sort(originCharacters, function(a, b)
		return Ext.StaticData.Get(a, "Origin").Name < Ext.StaticData.Get(b, "Origin").Name
	end)
	table.sort(hirelings, function(a, b)
		-- Future Bug report probably
		return Ext.StaticData.Get(a, "Origin").DisplayName:Get() < Ext.StaticData.Get(b, "Origin").DisplayName:Get()
	end)
end

VanityCharacterCriteria = {}

---@alias VanityCriteriaCompositeKey string

---@enum VanityCharacterCriteriaType
VanityCharacterCriteria.CriteriaType = {
	Class = 1,
	Subclass = 2,
	Race = 3,
	Subrace = 4,
	BodyType = 5,
	Origin = 6,
	Hireling = 7,
	[1] = "Class",
	[2] = "Subclass",
	[3] = "Race",
	[4] = "Subrace",
	[5] = "BodyType",
	[6] = "Origin",
	[7] = "Hireling"
}

---@param criteriaTable {[VanityCharacterCriteriaType] : string} of VanityCharacterCriteria values to concat into an ordered key
---@return string compositeKey
function VanityCharacterCriteria:CreateCriteriaCompositeKey(criteriaTable)
	local criteria = {}
	for i = 1, 7 do
		criteria[i] = criteriaTable[VanityCharacterCriteria.CriteriaType[i]] or ""
	end
	return table.concat(criteria, "|")
end

local function split(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
		table.insert(t, str)
	end
	return t
end

---@param compositeKey string the composite key to parse
---@return {[VanityCharacterCriteriaType] : string} criteriaTable
function VanityCharacterCriteria:ParseCriteriaCompositeKey(compositeKey)
	local criteriaTable = {}

	local criteria = split(compositeKey, "|")
	for i = 1, 7 do
		criteriaTable[VanityCharacterCriteria.CriteriaType[i]] = criteria[i] or ""
	end
	return criteriaTable
end

---@param tabHeader ExtuiTreeParent
function VanityCharacterCriteria:BuildModule(tabHeader)
	if #playableRaces == 0 then
		PopulatePlayableRaces()
		PopulateClassesAndSubclasses()
		PopulateOriginCharacters()
	end

	local characterCriteriaSection = tabHeader:AddCollapsingHeader("Configure by Character Criteria")
	local characterCriteriaSelectionTable = tabHeader:AddTable("CharacterCriteraSelection", 7)
	local charCriteriaHeaders = characterCriteriaSelectionTable:AddRow()
	charCriteriaHeaders.Headers = true

	for _, criteriaType in ipairs(VanityCharacterCriteria.CriteriaType) do
		charCriteriaHeaders:AddCell():AddText(criteriaType)
	end

	local selectionRow = characterCriteriaSelectionTable:AddRow()
	for _, col in pairs(charCriteriaHeaders.Children) do
		local cell = selectionRow:AddCell()
		cell.UserData = col.Children[1].Label
		cell:AddText("---")
	end

	local function findTextToUpdate(selectType, selectable)
		for _, cell in pairs(selectionRow.Children) do
			if cell.UserData == selectType then
				cell.Children[1].Label = selectable.Label
			end
		end
	end

	local characterCriteriaTable = characterCriteriaSection:AddTable("Class-Race", 6)
	characterCriteriaTable:AddColumn("FirstRaceOrClassSelect", "WidthStretch")
	characterCriteriaTable:AddColumn("SecondClassOrRace", "WidthStretch")
	characterCriteriaTable:AddColumn("ThirdSubclassOrSubrace", "WidthStretch")
	characterCriteriaTable:AddColumn("FourthRace", "WidthStretch")
	characterCriteriaTable:AddColumn("FifthSubRace", "WidthStretch")
	characterCriteriaTable:AddColumn("SixthBodyTypeSubRace", "WidthStretch")

	local characterCriteriaRow = characterCriteriaTable:AddRow()
	characterCriteriaRow:AddCell()
	characterCriteriaRow:AddCell()
	characterCriteriaRow:AddCell()
	characterCriteriaRow:AddCell()
	characterCriteriaRow:AddCell()
	characterCriteriaRow:AddCell()

	local bodyTypeTree = {
		BodyType = {
			1, 2, 3, 4
		}
	}
	local raceTree = {
		Race = {
			["By Body Type"] = bodyTypeTree,
			Subrace = bodyTypeTree
		}
	}

	local tree = {
		["By Race"] = raceTree,
		["By Class"] = {
			Class = {
				Subclass = {
					Race = raceTree.Race,
					["By Body Type"] = bodyTypeTree,
					["By Origin"] = {
						Origin = {}
					},
					["By Hireling"] = {
						Hireling = {}
					}
				},
				["By Race"] = raceTree,
				["By Body Type"] = bodyTypeTree,
				["By Origin"] = {
					Origin = {}
				},
				["By Hireling"] = {
					Hireling = {}
				}
			}
		},
		["By Body Type"] = bodyTypeTree,
		["By Origin"] = {
			Origin = {}
		},
		["By Hireling"] = {
			Hireling = {}
		}
	}

	local function ClearOnSelect(columnIndex, selectable)
		---@type ExtuiTableCell
		local cell = characterCriteriaRow.Children[columnIndex]

		for _, childSelectable in pairs(cell.Children) do
			---@cast childSelectable ExtuiSelectable

			if selectable.UserData ~= childSelectable.UserData then
				if childSelectable.Selected then
					for _, selectedTextCell in pairs(selectionRow.Children) do
						if selectedTextCell.Children[1].Label == childSelectable.Label then
							selectedTextCell.Children[1].Label = "---"
						end
					end
				end
				childSelectable.Selected = false
			end
		end

		for index, columnCell in pairs(characterCriteriaRow.Children) do
			if index > columnIndex then
				for _, child in pairs(columnCell.Children) do
					for _, selectedTextCell in pairs(selectionRow.Children) do
						if selectedTextCell.Children[1].Label == child.Label then
							selectedTextCell.Children[1].Label = "---"
						end
					end
					child:Destroy()
				end
			end
		end
	end

	--- I know there's a bullet tree, but i like this aesthetic more
	--- @param trunk table
	--- @param columnIndex number
	--- @param valueCollection ResourceClassDescription[]|ResourceRace[]?
	local function BuildHorizontalSelectableTree(trunk, columnIndex, valueCollection)
		---@type ExtuiTableCell
		local cell = characterCriteriaRow.Children[columnIndex]

		for selectType, children in TableUtils:OrderedPairs(trunk) do
			if selectType == "By Race" or selectType == "By Class" or selectType == "By Body Type" or selectType == "By Origin" or selectType == "By Hireling" then
				local selectable = cell:AddSelectable(selectType)
				selectable.UserData = selectType
				selectable.OnActivate = function()
					ClearOnSelect(columnIndex, selectable)
					findTextToUpdate(selectType, selectable)
					BuildHorizontalSelectableTree(children, columnIndex + 1)
				end
			elseif selectType == "Race" or selectType == "Class" then
				-- TODO: Really clean up this mess
				local table = selectType == "Race" and playableRaces or classesAndSubclasses
				for parentGuid, childResources in TableUtils:OrderedPairs(table, function(key)
					return Ext.StaticData.Get(key, selectType == "Race" and selectType or "ClassDescription").Name
				end) do
					---@type ResourceRace|ResourceClassDescription
					local resource = Ext.StaticData.Get(parentGuid, selectType == "Race" and selectType or "ClassDescription")

					local selectable = cell:AddSelectable(resource.DisplayName:Get() or resource.Name)
					selectable.UserData = parentGuid
					selectable.OnActivate = function()
						ClearOnSelect(columnIndex, selectable)
						findTextToUpdate(selectType, selectable)
						BuildHorizontalSelectableTree(children, columnIndex + 1, childResources)
					end
				end
			elseif selectType == "Subrace" or selectType == "Subclass" then
				for _, childResource in pairs(valueCollection) do
					local selectable = cell:AddSelectable(childResource.DisplayName:Get() or childResource.Name)
					selectable.UserData = childResource.ResourceUUID
					selectable.OnActivate = function()
						ClearOnSelect(columnIndex, selectable)
						findTextToUpdate(selectType, selectable)
						BuildHorizontalSelectableTree(children, columnIndex + 1)
					end
				end
			elseif selectType == "BodyType" then
				for _, bodyType in pairs(children) do
					local selectable = cell:AddSelectable(bodyType)
					selectable.UserData = bodyType
					selectable.OnActivate = function()
						ClearOnSelect(columnIndex, selectable)
						findTextToUpdate(selectType, selectable)
						BuildHorizontalSelectableTree(children, columnIndex + 1)
					end
				end
			elseif selectType == "Origin" or selectType == "Hireling" then
				for _, originGuid in pairs(selectType == "Origin" and originCharacters or hirelings) do
					---@type ResourceOrigin
					local origin = Ext.StaticData.Get(originGuid, "Origin")

					local selectable = cell:AddSelectable(origin.DisplayName:Get() or origin.Name)
					selectable.UserData = originGuid
					selectable.OnActivate = function()
						ClearOnSelect(columnIndex, selectable)
						findTextToUpdate(selectType, selectable)
						BuildHorizontalSelectableTree(children, columnIndex + 1)
					end
				end
			end
		end
	end

	BuildHorizontalSelectableTree(tree, 1)
end

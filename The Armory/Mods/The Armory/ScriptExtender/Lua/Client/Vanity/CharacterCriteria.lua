Ext.Require("Client/Vanity/CharacterPanel/CharacterPanel.lua")
Ext.Require("Shared/Configurations/VanityCharacterCriteria.lua")

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

local activeCriteria = {}

---@type ExtuiGroup
local criteriaGroup

---@param tabHeader ExtuiTreeParent
---@param preset VanityPreset
function VanityCharacterCriteria:BuildModule(tabHeader, preset)
	if #playableRaces == 0 then
		PopulatePlayableRaces()
		PopulateClassesAndSubclasses()
		PopulateOriginCharacters()
	end

	if not criteriaGroup then
		criteriaGroup = tabHeader:AddGroup("CharacterCriteria")
	else
		for _, child in pairs(criteriaGroup.Children) do
			child:Destroy()
		end
	end

	local characterCriteriaSection = criteriaGroup:AddCollapsingHeader("Configure by Character Criteria")
	characterCriteriaSection.DefaultOpen = true
	local criteriaSelectionDisplayTable = criteriaGroup:AddTable("CharacterCriteraSelection", 7)
	local charCriteriaHeaders = criteriaSelectionDisplayTable:AddRow()
	charCriteriaHeaders.Headers = true

	local selectedCriteriaDisplayRow = criteriaSelectionDisplayTable:AddRow()
	for _, criteriaType in ipairs(VanityCharacterCriteriaType) do
		charCriteriaHeaders:AddCell():AddText(criteriaType)
		local cell = selectedCriteriaDisplayRow:AddCell()
		cell.UserData = criteriaType
		cell:AddText("---")
	end

	local function findTextToUpdate(selectType, selectable)
		for _, cell in pairs(selectedCriteriaDisplayRow.Children) do
			if cell.UserData == selectType then
				cell.Children[1].Label = selectable.Label
			end
		end
	end

	local characterCriteriaTable = characterCriteriaSection:AddTable("Class-Race", 7)
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
	characterCriteriaRow:AddCell()

	local bodyTypeTree = {
		BodyType = {
			1, 2, 3, 4
		}
	}
	local raceTree = {
		Race = {
			["By Body Type"] = bodyTypeTree,
			["By Origin"] = {
				Origin = bodyTypeTree
			},
			["By Hireling"] = {
				Hireling = bodyTypeTree
			},
			Subrace = {
				BodyType = bodyTypeTree.BodyType,
				["By Origin"] = {
					Origin = {}
				},
				["By Hireling"] = {
					Hireling = {}
				},
			}
		}
	}

	local tree = {
		["By Race"] = raceTree,
		["By Class"] = {
			Class = {
				Subclass = {
					Race = raceTree.Race,
					["By Body Type"] = {
						BodyType = bodyTypeTree.BodyType,
						["By Origin"] = {
							Origin = {}
						},
						["By Hireling"] = {
							Hireling = {}
						},
					},
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

			if selectable.Label ~= childSelectable.Label then
				if childSelectable.Selected then
					for colIndex, selectedTextCell in pairs(selectedCriteriaDisplayRow.Children) do
						if selectedTextCell.Children[1].Label == childSelectable.Label then
							activeCriteria[VanityCharacterCriteriaType[colIndex]] = nil
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
					for colIndex, selectedTextCell in pairs(selectedCriteriaDisplayRow.Children) do
						if selectedTextCell.Children[1].Label == child.Label then
							activeCriteria[VanityCharacterCriteriaType[colIndex]] = nil
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
	local function BuildHorizontalSelectableTree(trunk, columnIndex, valueCollection, compositeKeyForHighlighting)
		---@type ExtuiTableCell
		local cell = characterCriteriaRow.Children[columnIndex]

		local function buildSelectable(selectType, resourceId, selectValue, children, childResources)
			---@type ExtuiSelectable
			local selectable = cell:AddSelectable(selectValue)
			selectable.UserData = selectType

			if not string.find(selectType, "By") then
				compositeKeyForHighlighting[selectType] = resourceId
				if preset.Outfits[CreateCriteriaCompositeKey(compositeKeyForHighlighting)] then
					selectable:SetColor("Text", { 144 / 255, 238 / 255, 144 / 255, 1 })
				end
			end

			selectable.OnActivate = function()
				ClearOnSelect(columnIndex, selectable)
				findTextToUpdate(selectType, selectable)
				compositeKeyForHighlighting = TableUtils:DeeplyCopyTable(activeCriteria)
				if not string.find(selectType, "By") then
					activeCriteria[selectType] = resourceId
					compositeKeyForHighlighting[selectType] = resourceId
				end
				BuildHorizontalSelectableTree(children, columnIndex + 1, childResources, compositeKeyForHighlighting or {})

				VanityCharacterPanel:BuildModule(tabHeader, preset, CreateCriteriaCompositeKey(activeCriteria))
			end
		end

		for selectType, children in TableUtils:OrderedPairs(trunk) do
			if selectType == "By Race" or selectType == "By Class" or selectType == "By Body Type" or selectType == "By Origin" or selectType == "By Hireling" then
				buildSelectable(selectType, nil, selectType, children, nil)
			elseif selectType == "Race" or selectType == "Class" then
				-- TODO: Really clean up this mess
				local table = selectType == "Race" and playableRaces or classesAndSubclasses
				for parentGuid, childResources in TableUtils:OrderedPairs(table, function(key)
					return Ext.StaticData.Get(key, selectType == "Race" and selectType or "ClassDescription").Name
				end) do
					---@type ResourceRace|ResourceClassDescription
					local resource = Ext.StaticData.Get(parentGuid, selectType == "Race" and selectType or "ClassDescription")

					buildSelectable(selectType, resource.ResourceUUID, resource.DisplayName:Get() or resource.Name, children, childResources)
				end
			elseif selectType == "Subrace" or selectType == "Subclass" then
				for _, childResource in pairs(valueCollection) do
					buildSelectable(selectType, childResource.ResourceUUID, childResource.DisplayName:Get() or childResource.Name, children, nil)
				end
			elseif selectType == "BodyType" then
				for _, bodyType in pairs(children) do
					buildSelectable(selectType, bodyType, bodyType, children, nil)
				end
			elseif selectType == "Origin" or selectType == "Hireling" then
				for _, originGuid in pairs(selectType == "Origin" and originCharacters or hirelings) do
					---@type ResourceOrigin
					local origin = Ext.StaticData.Get(originGuid, "Origin")

					buildSelectable(selectType, origin.ResourceUUID, origin.DisplayName:Get() or origin.Name, children, nil)
				end
			end
		end
	end

	BuildHorizontalSelectableTree(tree, 1)
end

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

---@type {[Guid] : ResourceClassDescription[]}
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

---@type ExtuiGroup
local criteriaGroup

---@param preset VanityPreset
---@param parent ExtuiTreeParent
function VanityCharacterCriteria:BuildConfiguredCriteriaCombinationsTable(preset, parent)
	local refreshButton = parent:AddButton("Refresh")

	local criteriaSelectionDisplayTable = parent:AddTable("ConfiguredCriteriaCombinations" .. parent.IDContext, 8)
	criteriaSelectionDisplayTable.SizingStretchSame = true
	criteriaSelectionDisplayTable.RowBg = true

	local charCriteriaHeaders = criteriaSelectionDisplayTable:AddRow()
	charCriteriaHeaders.Headers = true

	for _, criteriaType in ipairs(VanityCharacterCriteriaType) do
		charCriteriaHeaders:AddCell():AddText(criteriaType)
	end

	local function buildTable()
		for criteriaCompositeKey, _ in TableUtils:OrderedPairs(preset.Outfits) do
			local row = criteriaSelectionDisplayTable:AddRow()
			local parsedCriteriaTable = ParseCriteriaCompositeKey(criteriaCompositeKey)

			for _, criteriaType in ipairs(VanityCharacterCriteriaType) do
				local criteriaId = parsedCriteriaTable[criteriaType]
				local criteriaValue
				if criteriaId == "" then
					criteriaValue = "---"
				elseif criteriaType == "BodyType" then
					criteriaValue = criteriaId
				else
					local resourceType = (criteriaType == "Class" or criteriaType == "Subclass") and "ClassDescription" or criteriaType
					resourceType = criteriaType == "Subrace" and "Race" or resourceType
					resourceType = criteriaType == "Hireling" and "Origin" or resourceType

					---@type ResourceClassDescription|ResourceRace|ResourceOrigin
					local resource = Ext.StaticData.Get(criteriaId, resourceType)
					criteriaValue = resource.DisplayName:Get()
				end

				row:AddCell():AddText(criteriaValue)
			end

			local actionCell = row:AddCell()
			local deleteButton = actionCell:AddButton("X")
			deleteButton:SetColor("Button", { 0.6, 0.02, 0, 0.5 })
			deleteButton:SetColor("Text", { 1, 1, 1, 1 })
			deleteButton.OnClick = function()
				preset.Outfits[criteriaCompositeKey].delete = true
				Ext.Timer.WaitFor(350, function()
					Ext.ClientNet.PostMessageToServer(ModuleUUID .. "_PresetUpdated", "")
				end)
				row:Destroy()
			end
		end
	end

	buildTable()

	refreshButton.OnClick = function()
		for _, child in pairs(criteriaSelectionDisplayTable.Children) do
			if not child.Headers then
				child:Destroy()
			end
		end

		buildTable()
	end
end

---@type ExtuiWindow
local popup

---@param tabHeader ExtuiTreeParent
---@param preset VanityPreset
function VanityCharacterCriteria:BuildModule(tabHeader, preset)
	if not next(playableRaces) then
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

	local popupButton = criteriaGroup:AddButton("See Configured Character Criteria Combinations")

	if not popup then
		popup = Ext.IMGUI.NewWindow("Configured Character Criteria Combinations")
		popup.Closeable = true
		popup.AlwaysAutoResize = true
		popup.NoResize = true
		popup.Open = false
	end

	popupButton.OnClick = function()
		if not popup.Open then
			popup.Open = true
		end
		popup:SetFocus()
	end

	self:BuildConfiguredCriteriaCombinationsTable(preset, popup)

	local criteriaCollapse = criteriaGroup:AddCollapsingHeader("Select Character Criteria for Outfit")
	local criteriaSelectionTable = criteriaCollapse:AddTable("CharacterCriteraSelection", 7)
	criteriaSelectionTable.SizingStretchSame = true

	local criteriaSelectedDisplayTable = criteriaGroup:AddTable("CriteriaDisplayTable", 7)
	local criteriaDisplayHeaders = criteriaSelectedDisplayTable:AddRow()
	criteriaDisplayHeaders.Headers = true
	local selectedCriteriaDisplayRow = criteriaSelectedDisplayTable:AddRow()

	local criteriaSelectionHeaders = criteriaSelectionTable:AddRow()
	criteriaSelectionHeaders.Headers = true
	local criteriaSelectionRow = criteriaSelectionTable:AddRow()

	local activeCriteraTypes = {}

	---@param column ExtuiTableCell
	---@param selectedId string?
	local function resetSelectedInColumn(column, selectedId)
		for _, selectable in pairs(column.Children) do
			---@cast selectable ExtuiSelectable
			if selectable.UserData ~= selectedId then
				selectable.Selected = false
				selectable:SetColor("Text", { 219 / 255, 201 / 255, 173 / 255, 0.78 })
			end
			if not selectedId then
				activeCriteraTypes[column.UserData] = nil
				selectedCriteriaDisplayRow.Children[VanityCharacterCriteriaType[column.UserData]].Children[1].Label = "---"
			end
		end
	end

	---@param cell ExtuiTableCell
	---@param criteriaType VanityCharacterCriteriaType
	---@param resource ResourceRace|ResourceClassDescription|ResourceOrigin|number
	local function buildSelectable(cell, criteriaType, resource)
		---@type ExtuiSelectable
		local selectable = cell:AddSelectable(type(resource) ~= "number" and (resource.DisplayName:Get() or resource.Name) or resource)
		selectable.UserData = type(resource) ~= "number" and resource.ResourceUUID or resource
		selectable.IDContext = criteriaType .. selectable.UserData

		selectable.OnClick = function()
			activeCriteraTypes[criteriaType] = selectable.Selected and selectable.UserData or nil
			if selectable.Selected then
				selectable:SetColor("Text", { 219 / 255, 201 / 255, 173 / 255, 0.78 })
			end

			selectedCriteriaDisplayRow.Children[VanityCharacterCriteriaType[criteriaType]].Children[1].Label = selectable.Selected and selectable.Label or "---"

			resetSelectedInColumn(criteriaSelectionRow.Children[VanityCharacterCriteriaType[criteriaType]], selectable.UserData)

			if criteriaType == "Origin" or criteriaType == "Hireling" then
				resetSelectedInColumn(criteriaSelectionRow.Children[VanityCharacterCriteriaType[criteriaType == "Origin" and "Hireling" or "Origin"]])
			elseif criteriaType == "Race" or criteriaType == "Class" then
				local subColIndex = VanityCharacterCriteriaType[criteriaType] + 1
				activeCriteraTypes[VanityCharacterCriteriaType[subColIndex]] = nil

				selectedCriteriaDisplayRow.Children[subColIndex].Children[1].Label = "---"
				---@type ExtuiTableCell
				local subColumn = criteriaSelectionRow.Children[subColIndex]
				for _, child in pairs(subColumn.Children) do
					child:Destroy()
				end
				if selectable.Selected then
					for _, subResource in ipairs(criteriaType == "Race" and playableRaces[resource.ResourceUUID] or classesAndSubclasses[resource.ResourceUUID]) do
						buildSelectable(subColumn, VanityCharacterCriteriaType[subColIndex], subResource)
					end
				else

				end
			end

			local criteriaTableCopy = TableUtils:DeeplyCopyTable(activeCriteraTypes)

			for _, column in pairs(criteriaSelectionRow.Children) do
				if not criteriaTableCopy[column.UserData] then
					---@cast column ExtuiTableCell
					for _, otherSelectable in pairs(column.Children) do
						---@cast otherSelectable ExtuiSelectable

						criteriaTableCopy[column.UserData] = otherSelectable.UserData or nil

						if preset.Outfits[CreateCriteriaCompositeKey(criteriaTableCopy)] then
							otherSelectable:SetColor("Text", { 144 / 255, 238 / 255, 144 / 255, 1 })
						else
							otherSelectable:SetColor("Text", { 219 / 255, 201 / 255, 173 / 255, 0.78 })
						end
					end
					criteriaTableCopy[column.UserData] = nil
				end
			end

			VanityCharacterPanel:BuildModule(tabHeader, preset, CreateCriteriaCompositeKey(activeCriteraTypes))
		end
	end

	for _, criteriaType in ipairs(VanityCharacterCriteriaType) do
		criteriaSelectionHeaders:AddCell():AddText(criteriaType)
		criteriaDisplayHeaders:AddCell():AddText(criteriaType)

		selectedCriteriaDisplayRow:AddCell():AddText("---")

		local selectionCell = criteriaSelectionRow:AddCell()
		selectionCell.UserData = criteriaType

		if criteriaType == "Origin" or criteriaType == "Hireling" then
			for _, origin in ipairs(criteriaType == "Origin" and originCharacters or hirelings) do
				---@type ResourceOrigin
				local resource = Ext.StaticData.Get(origin, "Origin")

				buildSelectable(selectionCell, criteriaType, resource)
			end
		elseif criteriaType == "Class" then
			for class, _ in TableUtils:OrderedPairs(classesAndSubclasses, function(key) return Ext.StaticData.Get(key, "ClassDescription").Name end) do
				---@type ResourceClassDescription
				local resource = Ext.StaticData.Get(class, "ClassDescription")

				buildSelectable(selectionCell, criteriaType, resource)
			end
		elseif criteriaType == "Race" then
			for race, _ in TableUtils:OrderedPairs(playableRaces, function(key) return Ext.StaticData.Get(key, "Race").Name end) do
				---@type ResourceRace
				local resource = Ext.StaticData.Get(race, "Race")
				buildSelectable(selectionCell, criteriaType, resource)
			end
		elseif criteriaType == "BodyType" then
			for i = 1, 4 do
				buildSelectable(selectionCell, criteriaType, i)
			end
		end
	end

	local criteriaTableCopy = TableUtils:DeeplyCopyTable(activeCriteraTypes)
	for _, column in pairs(criteriaSelectionRow.Children) do
		if not criteriaTableCopy[column.UserData] then
			---@cast column ExtuiTableCell
			for _, otherSelectable in pairs(column.Children) do
				---@cast otherSelectable ExtuiSelectable

				criteriaTableCopy[column.UserData] = otherSelectable.UserData or nil

				if preset.Outfits[CreateCriteriaCompositeKey(criteriaTableCopy)] then
					otherSelectable:SetColor("Text", { 144 / 255, 238 / 255, 144 / 255, 1 })
				else
					otherSelectable:SetColor("Text", { 219 / 255, 201 / 255, 173 / 255, 0.78 })
				end
			end
			criteriaTableCopy[column.UserData] = nil
		end
	end
end

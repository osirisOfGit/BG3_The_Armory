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
local function buildConfiguredCriteriaCombinationsPopup(preset)
	local popupButton = criteriaGroup:AddButton("See Configured Character Criteria Combinations")

	local popup = Ext.IMGUI.NewWindow("Configured Character Criteria Combinations")
	popup.Closeable = true
	popup.AlwaysAutoResize = true
	popup.NoResize = true
	popup.Open = false

	local refreshButton = popup:AddButton("Refresh")

	local criteriaSelectionDisplayTable = popup:AddTable("ConfiguredCriteriaCombinations", 7)
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
					resourceType = criteriaType == "Hireling" and "Origin" or resourceType

					---@type ResourceClassDescription|ResourceRace|ResourceOrigin
					local resource = Ext.StaticData.Get(criteriaId, resourceType)
					criteriaValue = resource.DisplayName:Get()
				end

				row:AddCell():AddText(criteriaValue)
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

	popupButton.OnClick = function()
		popup.Open = true
	end
end

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

	buildConfiguredCriteriaCombinationsPopup(preset)

	local criteriaSelectionDisplayTable = criteriaGroup:AddTable("CharacterCriteraSelection", 7)
	criteriaSelectionDisplayTable.SizingStretchSame = true
	criteriaSelectionDisplayTable.NoPadInnerX = true

	local charCriteriaHeaders = criteriaSelectionDisplayTable:AddRow()
	charCriteriaHeaders.Headers = true

	local nameToUuid = {}

	local selectedCriteriaDisplayRow = criteriaSelectionDisplayTable:AddRow()
	for criteriaTypeIndex, criteriaType in ipairs(VanityCharacterCriteriaType) do
		charCriteriaHeaders:AddCell():AddText(criteriaType)
		local cell = selectedCriteriaDisplayRow:AddCell()
		cell.UserData = criteriaType
		cell:SetStyle("CellPadding", 0, 0)

		local criteriaCombo = cell:AddCombo("")
		criteriaCombo.IDContext = criteriaType
		criteriaCombo.WidthFitPreview = true

		local subResourceFunction

		local options = { "         " }
		if criteriaType == "Origin" or criteriaType == "Hireling" then
			for _, origin in pairs(criteriaType == "Origin" and originCharacters or hirelings) do
				---@type ResourceOrigin
				local resource = Ext.StaticData.Get(origin, "Origin")

				nameToUuid[resource.DisplayName:Get() or resource.Name] = resource.ResourceUUID
				table.insert(options, resource.DisplayName:Get() or resource.Name)
			end
			subResourceFunction = function()
				if criteriaType == "Origin" then
					---@type ExtuiCombo
					local hirelingCombo = selectedCriteriaDisplayRow.Children[VanityCharacterCriteriaType["Hireling"]].Children[1]

					hirelingCombo.SelectedIndex = -1
				else
					---@type ExtuiCombo
					local originCombo = selectedCriteriaDisplayRow.Children[VanityCharacterCriteriaType["Origin"]].Children[1]

					originCombo.SelectedIndex = -1
				end
			end
		elseif criteriaType == "Class" then
			for class, _ in pairs(classesAndSubclasses) do
				---@type ResourceClassDescription
				local resource = Ext.StaticData.Get(class, "ClassDescription")
				nameToUuid[resource.DisplayName:Get() or resource.Name] = class
				table.insert(options, resource.DisplayName:Get() or resource.Name)
			end

			subResourceFunction = function(className)
				---@type ExtuiCombo
				local subclassCombo = selectedCriteriaDisplayRow.Children[criteriaTypeIndex + 1].Children[1]
				subclassCombo.SelectedIndex = 0

				if criteriaCombo.SelectedIndex < 1 then
					subclassCombo.Options = {}
					subclassCombo.Visible = false
				else
					local subOptions = { "         " }
					for _, subClass in pairs(classesAndSubclasses[nameToUuid[className]]) do
						nameToUuid[subClass.ResourceUUID] = subClass.DisplayName:Get() or subClass.Name
						table.insert(subOptions, subClass.DisplayName:Get() or subClass.Name)
					end
					subclassCombo.Options = subOptions
					subclassCombo.Visible = #subclassCombo.Options > 1
				end
			end
		elseif criteriaType == "Race" then
			for race, _ in pairs(playableRaces) do
				---@type ResourceRace
				local resource = Ext.StaticData.Get(race, "Race")
				nameToUuid[resource.DisplayName:Get() or resource.Name] = race
				table.insert(options, resource.DisplayName:Get() or resource.Name)

				subResourceFunction = function(className)
					---@type ExtuiCombo
					local subRaceCombo = selectedCriteriaDisplayRow.Children[criteriaTypeIndex + 1].Children[1]
					subRaceCombo.SelectedIndex = 0

					if criteriaCombo.SelectedIndex < 1 then
						subRaceCombo.Options = {}
						subRaceCombo.Visible = false
					else
						local subOptions = { "         " }
						for _, subClass in pairs(playableRaces[nameToUuid[className]]) do
							nameToUuid[subClass.ResourceUUID] = subClass.DisplayName:Get() or subClass.Name
							table.insert(subOptions, subClass.DisplayName:Get() or subClass.Name)
						end
						subRaceCombo.Options = subOptions
						subRaceCombo.Visible = #subRaceCombo.Options > 1
					end
				end
			end
		elseif criteriaType == "BodyType" then
			options = { "         ", 1, 2, 3, 4 }
		else
			criteriaCombo.Visible = false
		end

		criteriaCombo.Options = options
		criteriaCombo.SelectedIndex = 0
		criteriaCombo.OnChange = function()
			if subResourceFunction then
				subResourceFunction(criteriaCombo.Options[criteriaCombo.SelectedIndex + 1])
			end

			local selectedCriteria = {}
			for index, criteriaCell in pairs(selectedCriteriaDisplayRow.Children) do
				---@type ExtuiCombo
				local combo = criteriaCell.Children[1]

				if combo.SelectedIndex > 0 then
					local chosenOption = combo.Options[combo.SelectedIndex + 1]
					-- 						If it's empty
					if chosenOption and not chosenOption:match("^%s*$") then
						selectedCriteria[VanityCharacterCriteriaType[index]] = index ~= VanityCharacterCriteriaType["BodyType"] and nameToUuid[chosenOption] or chosenOption
					end
				end
			end

			VanityCharacterPanel:BuildModule(tabHeader, preset, CreateCriteriaCompositeKey(selectedCriteria))
		end
	end
end

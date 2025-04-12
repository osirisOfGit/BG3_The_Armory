local itemIndex = {
	---@class SearchIndex
	equipment = {
		templateIdAndStat = {},
		templateIdAndTemplateName = {},
		modIdAndTemplateIds = {},
		mods = {}
	},
	dyes = {
		templateIdAndStat = {},
		templateIdAndTemplateName = {},
		modIdAndTemplateIds = {},
		mods = {}
	}
}

---@class PickerBaseClass
PickerBaseClass = {
	---@type "Equipment"|"Dyes"
	title = nil,
	---@type EquipmentSettings|DyeSettings
	settings = {},
	---@type ActualSlot
	slot = nil,
	---@type ExtuiMenu
	settingsMenu = nil,
	---@type string[]
	blacklistedItems = {},
	---@type SearchIndex
	itemIndex = {},
	---@type ExtuiGroup
	warningGroup = nil,
	---@type ExtuiChildWindow
	filterGroup = nil,
	---@type (fun(function))[]
	customFilters = {},
	---@type (fun(template: ItemTemplate): boolean)[]
	filterPredicates = {},
}

---@param title "Equipment"|"Dyes"
---@param instance table?
---@return PickerBaseClass instance
function PickerBaseClass:new(title, instance)
	instance = instance or {}

	setmetatable(instance, self)
	self.__index = self

	instance.title = title
	instance.rootsByName = {}
	instance.sortedTemplateNames = {}
	instance.templateNamesByModId = {}
	instance.modIdByModName = {}
	instance.settings = instance.settings or {}
	instance.blacklistedItems = {}
	instance.filterPredicates = {}
	instance.itemIndex = title == "Equipment" and itemIndex.equipment or itemIndex.dyes

	return instance
end

function PickerBaseClass:InitializeSearchBank()
	local startTime = Ext.Utils.MonotonicTime()
	local itemCount = 0
	local modCount = 0

	local modcache = {}

	local combinedStats = {}
	for _, statType in ipairs({ "Armor", "Weapon", "Object" }) do
		for _, stat in ipairs(Ext.Stats.GetStats(statType)) do
			table.insert(combinedStats, stat)
		end
	end
	for _, statString in ipairs(combinedStats) do
		---@type Weapon|Armor|Object
		local stat = Ext.Stats.Get(statString)

		local success, error = pcall(function(...)
			local indexShard

			if (stat.ModifierList == "Weapon" or stat.ModifierList == "Armor") then
				indexShard = itemIndex.equipment
			elseif string.match(stat.ObjectCategory, "Dye") then
				indexShard = itemIndex.dyes
			else
				return
			end

			if not stat.RootTemplate or stat.RootTemplate == "" or stat.RootTemplate == "00000000-0000-0000-0000-000000000000" then
				return
			end

			itemCount = itemCount + 1

			---@type ItemTemplate?
			local itemTemplate = stat.RootTemplate and Ext.ClientTemplate.GetRootTemplate(stat.RootTemplate) or nil
			if not itemTemplate then
				error(string.format("RootTemplate %s does not exist", stat.RootTemplate))
			end

			indexShard.templateIdAndStat[stat.RootTemplate] = statString
			indexShard.templateIdAndTemplateName[stat.RootTemplate] = itemTemplate.DisplayName:Get() or itemTemplate.Name

			if stat.ModId ~= "" or stat.OriginalModId ~= "" then
				local modId = stat.OriginalModId ~= "" and stat.OriginalModId or stat.ModId
				local modInfo = Ext.Mod.GetMod(modId).Info
				if not indexShard.mods[modInfo.Name] then
					if not modcache[modId] then
						modCount = modCount + 1
						modcache[modId] = true
					end
					indexShard.mods[modInfo.Name] = modId
					indexShard.modIdAndTemplateIds[modId] = {}
				end
				table.insert(indexShard.modIdAndTemplateIds[modId], itemTemplate.Id)
			end
		end)

		if not success then
			Logger:BasicWarning("Couldn't load stat %s (from Mod '%s') into the search table due to %s - please contact the mod author to fix this issue",
				stat.Name,
				stat.OriginalModId ~= "" and Ext.Mod.GetMod(stat.OriginalModId).Info.Name or "Unknown",
				error)
		end
	end

	local indexShard = itemIndex.equipment
	for _, template in pairs(Ext.Template.GetAllRootTemplates()) do
		if template.TemplateType == "item" and not template.Name:match("Timeline") then
			local success, error = pcall(function()
				---@cast template ItemTemplate

				if template.Equipment and template.Equipment.Slot and #template.Equipment.Slot > 0 and not indexShard.templateIdAndStat[template.Id] then
					if template.Stats and template.Stats ~= "" and template.Stats ~= "OBJ_GenericImmutableObject" then
						---@type Weapon|Armor
						local stat = Ext.Stats.Get(template.Stats)

						if stat and stat.Slot then
							itemCount = itemCount + 1

							indexShard.templateIdAndStat[template.Id] = template.Stats
							indexShard.templateIdAndTemplateName[template.Id] = template.DisplayName:Get() or template.Name

							local modName
							local modId
							if stat.RootTemplate == template.Id then
								modId = stat.OriginalModId ~= "" and stat.OriginalModId or stat.ModId
								local modInfo = Ext.Mod.GetMod(modId).Info
								modName = modInfo.Name
							else
								local modFolder = template.FileName:match("([^/]+)/RootTemplates/")
								if modFolder:match("_[0-9a-fA-F%-]+$") then
									modFolder = modFolder:gsub("_[0-9a-fA-F%-]+$", "")
								end
								modName = modFolder
								modId = modFolder
							end
							if not indexShard.mods[modName] then
								if not modcache[modId] then
									modCount = modCount + 1
									modcache[modId] = true
								end
								indexShard.mods[modName] = modId
								indexShard.modIdAndTemplateIds[modId] = {}
							elseif not indexShard.modIdAndTemplateIds[modId] then
								modId = indexShard.mods[modName]
							end
							table.insert(indexShard.modIdAndTemplateIds[modId], template.Id)
						end
					end
				end
			end)

			if not success then
				Logger:BasicWarning("Couldn't load template %s (in folder %s) into the search table due to %s - please contact the mod author to fix this issue",
					template.Name .. "_" .. template.Id,
					template.FileName:match("([^/]+)/RootTemplates/"),
					error)
			end
		end
	end

	for _, indexShard in pairs(itemIndex) do
		for _, templateIds in pairs(indexShard.modIdAndTemplateIds) do
			table.sort(templateIds, function(a, b)
				local tempA = Ext.Template.GetRootTemplate(a)
				local tempB = Ext.Template.GetRootTemplate(b)
				return (tempA.DisplayName:Get() or tempA.Name) < (tempB.DisplayName:Get() or tempB.Name)
			end)
		end
	end
	Logger:BasicInfo("Indexed %d armor/weapons and dyes from %d mods in %dms", itemCount, modCount, Ext.Utils.MonotonicTime() - startTime)
end

function PickerBaseClass:DisplayResult(templateName, group) end

function PickerBaseClass:OpenWindow(slot, customizeFunc, onCloseFunc)
	self.slot = slot

	if not self.window then
		if not next(itemIndex.dyes.mods) then
			PickerBaseClass:InitializeSearchBank()
		end

		self.window = Ext.IMGUI.NewWindow(self.title)
		self.window.Closeable = true
		self.window.MenuBar = true
		self.window.OnClose = function()
			Ext.Timer.WaitFor(60, function()
				onCloseFunc()
			end)
		end

		self.settingsMenu = self.window:AddMainMenu():AddMenu("Settings")
		self.settingsMenu:SetColor("PopupBg", { 0, 0, 0, 1 })

		self.settingsMenu:AddSeparator()
		self.settingsMenu:AddText("Show Item Names?")
		local showNameCheckbox = self.settingsMenu:AddCheckbox("", self.settings.showNames)
		showNameCheckbox.SameLine = true
		showNameCheckbox.OnChange = function()
			self.settings.showNames = showNameCheckbox.Checked
			self:RebuildDisplay()
		end

		self.settingsMenu:AddSeparator()

		self.settingsMenu:AddText("Image Size")
		local imageSizeSetting = self.settingsMenu:AddSliderInt("", self.settings.imageSize, 10, 200)
		imageSizeSetting.OnChange = function()
			self.settings.imageSize = imageSizeSetting.Value[1]
			self:RebuildDisplay()
		end

		self.separator = self.window:AddSeparatorText("")
		self.separator:SetStyle("SeparatorTextAlign", 0.5)
		self.separator.Font = "Large"

		local displayTable = self.window:AddTable("", 2)
		displayTable:AddColumn("", "WidthFixed", 400)
		displayTable:AddColumn("", "WidthStretch")

		local row = displayTable:AddRow()

		self.filterGroup = row:AddCell():AddChildWindow("Filters")

		local otherGroup = row:AddCell():AddChildWindow("RestOfTheOwl")

		self.warningGroup = otherGroup:AddGroup("WarningGroup")

		self.favoritesGroup = otherGroup:AddCollapsingHeader("Favorites")
		self.favoritesGroup.IDContext = self.title .. "Favorites"
		otherGroup:AddNewLine()

		self.resultSeparator = otherGroup:AddSeparatorText("Results")
		self.resultsGroup = otherGroup:AddGroup(self.title .. "Results")

		customizeFunc()
		self:BuildFilters()
	else
		if not self.window.Open then
			self.window.Open = true
		end
		self.window:SetFocus()
	end

	self.separator.Label = string.format("Searching for %s %s", slot, self.title)

	self:RebuildDisplay()
end

function PickerBaseClass:RebuildDisplay()
	Helpers:KillChildren(self.favoritesGroup, self.resultsGroup)

	for templateId, templateName in TableUtils:OrderedPairs(self.itemIndex.templateIdAndTemplateName, function(key)
		return self.itemIndex.templateIdAndTemplateName[key]
	end) do
		self:DisplayResult(templateId, self.favoritesGroup)

		---@type ItemTemplate
		local template = Ext.Template.GetRootTemplate(templateId)
		for _, predicate in ipairs(self.filterPredicates) do
			if not predicate(template) then
				goto continue
			end
		end
		self:DisplayResult(templateId, self.resultsGroup)
		::continue::
	end
end

--[[
BodyTypes = {
    HumanFemale = "71180b76-5752-4a97-b71f-911a69197f58",
    HumanMale = "7d73f501-f65e-46af-a13b-2cacf3985d05",
    HumanStrongFemale = "47c0315c-7dc6-4862-b39b-8bf3a10f8b54",
    HumanStrongMale = "e39505f7-f576-4e70-a99e-8e29cd381a11",
    TieflingFemale = "cf421f4e-107b-4ae6-86aa-090419c624a5",
    TieflingMale = "6503c830-9200-409a-bd26-895738587a4a",
    TieflingStrongMale = "f625476d-29ec-4a6d-9086-42209af0cf6f",
    TieflingStrongFemale = "a5789cd3-ecd6-411b-a53a-368b659bc04a",
    GithyankiFemale = "06aaae02-bb9e-4fa3-ac00-b08e13a5b0fa",
    GithyankiMale = "f07faafa-0c6f-4f79-a049-70e96b23d51b",
    ElfMale = "7dd0aa66-5177-4f65-b7d7-187c02531b0b",
    ElfFemale = "ad21d837-2db5-4e46-8393-7d875dd71287 ",
    HalfElfFemale = "541473b3-0bf3-4e68-b1ab-d85894d96d3e",
    HalfElfMale = "a0737289-ca84-4fde-bd52-25bae4fe8dea ",
    DwarfFemale = "b4a34ce7-41be-44d9-8486-938fe1472149",
    DwarfMale = "abf674d2-2ea4-4a74-ade0-125429f69f83",
    HalflingFemale = "8f00cf38-4588-433a-8175-8acdbbf33f33",
    HalflingMale = "a933e2a8-aee1-4ecb-80d2-8f47b706f024",
    GnomeFemale = "c491d027-4332-4fda-948f-4a3df6772baa",
    GnomeMale = "5640e766-aa53-428d-815b-6a0b4ef95aca",
    DragonbornFemale = "6d38f246-15cb-48b5-9b85-378016a7a78e",
    DragonbornMale = "9a8bbeba-850c-402f-bac5-ff15696e6497",
    HalforcFemale = "eb81b1de-985e-4e3a-8573-5717dc1fa15c",
    HalforcMale = "6dd3db4f-e2db-4097-b82e-12f379f94c2e",
}
]]
function PickerBaseClass:BuildFilters()
	--#region Search By Name
	self.filterGroup:AddText("By Name")
	local nameSearch = self.filterGroup:AddInputText("")
	nameSearch.Hint = "Case-insensitive, min 3 characters"
	nameSearch.AutoSelectAll = true
	nameSearch.EscapeClearsAll = true

	---@param itemTemplate ItemTemplate
	---@return boolean
	table.insert(self.filterPredicates, function(itemTemplate)
		if #nameSearch.Text >= 3 then
			local upperSearch = string.upper(nameSearch.Text)

			if not upperSearch or string.find(string.upper(self.itemIndex.templateIdAndTemplateName[itemTemplate.Id]), upperSearch) then
				return true
			end
		else
			return true
		end

		return false
	end)
	--#endregion

	--#region Search By Id
	self.filterGroup:AddText("By UUID")
	local idSearch = self.filterGroup:AddInputText("")
	idSearch.Hint = "Case-insensitive, min 3 characters"
	idSearch.AutoSelectAll = true
	idSearch.EscapeClearsAll = true

	---@param itemTemplate ItemTemplate
	---@return boolean
	table.insert(self.filterPredicates, function(itemTemplate)
		if #idSearch.Text >= 3 then
			local upperSearch = string.upper(idSearch.Text)

			if not upperSearch or string.find(string.upper(itemTemplate.Id), upperSearch) then
				return true
			end
		else
			return true
		end

		return false
	end)
	--#endregion

	self.filterGroup:AddNewLine()

	--#region Mod Picker
	local modTitleHeader = self.filterGroup:AddCollapsingHeader("By Mod")
	modTitleHeader.IDContext = "ByMod"
	modTitleHeader.DefaultOpen = true
	modTitleHeader:SetColor("Header", { 0, 0, 0, 0 })

	local modNameSearch = modTitleHeader:AddInputText("")
	modNameSearch.Hint = "Mod Name - Case-insensitive"
	modNameSearch.AutoSelectAll = true
	modNameSearch.EscapeClearsAll = true

	local clearSelected = Styler:ImageButton(modTitleHeader:AddImageButton("resetMods", "ico_reset_d", { 32, 32 }))
	clearSelected.SameLine = true
	clearSelected:Tooltip():AddText("\t Clear Selected Mods")

	local modFilterWindow = modTitleHeader:AddChildWindow("modFilters")

	local selected = {}
	local function buildModSelectables()
		Helpers:KillChildren(modFilterWindow)
		local upperSearch = string.upper(modNameSearch.Text)

		local selectedCount = 0

		for modName, modId in TableUtils:OrderedPairs(self.itemIndex.mods) do
			if not upperSearch or string.find(string.upper(modName), upperSearch) then
				local buildSelectable = false
				for _, templateId in pairs(self.itemIndex.modIdAndTemplateIds[modId]) do
					---@type ItemTemplate
					local itemTemplate = Ext.Template.GetRootTemplate(templateId)

					for index, predicate in ipairs(self.filterPredicates) do
						if index ~= 4 and not predicate(itemTemplate) then
							goto next_template
						end
					end

					buildSelectable = true
					goto build_selectable

					::next_template::
				end

				::build_selectable::
				if buildSelectable then
					---@type ExtuiSelectable
					local selectable = modFilterWindow:AddSelectable(modName)
					-- Selectable Active Bg inherits from the collapsible Header color, so resetting to default per
					-- https://github.com/Norbyte/bg3se/blob/f8b982125c6c1997ceab2d65cfaa3c1a04908ea6/BG3Extender/Extender/Client/IMGUI/IMGUI.cpp#L1901C34-L1901C60
					selectable:SetColor("Header", {0.36, 0.30, 0.27, 0.76})
					selectable.Selected = selected[modId] or false

					selectedCount = selectedCount + (selectable.Selected and 1 or 0)

					selectable.OnClick = function()
						selected[selectable.UserData] = selectable.Selected

						selectedCount = selectedCount + (selectable.Selected and 1 or -1)

						modTitleHeader.Label = ("By Mod(s)%s"):format(selectedCount > 0 and (" - " .. selectedCount .. " selected") or "")

						self:RebuildDisplay()
					end
					selectable.UserData = modId
				end
			end
		end

		modTitleHeader.Label = ("By Mod(s)%s"):format(selectedCount > 0 and (" - " .. selectedCount .. " selected") or "")
	end

	clearSelected.OnClick = function()
		selected = {}
		buildModSelectables()
		self:RebuildDisplay()
	end

	buildModSelectables()

	---@param itemTemplate ItemTemplate
	---@return boolean
	table.insert(self.filterPredicates, function(itemTemplate)
		local anySelected = false

		for _, selectable in ipairs(modFilterWindow.Children) do
			---@cast selectable ExtuiSelectable
			if selectable.Selected then
				anySelected = true
				if TableUtils:ListContains(self.itemIndex.modIdAndTemplateIds[selectable.UserData], itemTemplate.Id) then
					return true
				end
			end
		end

		return not anySelected and true or false
	end)
	--#endregion

	local timer

	local onChangeFunc = function()
		if timer then
			Ext.Timer.Cancel(timer)
		end
		timer = Ext.Timer.WaitFor(300, function()
			buildModSelectables()
			self:RebuildDisplay()
		end)
	end

	for _, customFilter in ipairs(self.customFilters) do
		customFilter(onChangeFunc)
	end

	modNameSearch.OnChange = function()
		onChangeFunc()
	end

	nameSearch.OnChange = function()
		if #nameSearch.Text == 0 or #nameSearch.Text >= 3 then
			onChangeFunc()
		end
	end
	idSearch.OnChange = function()
		if #idSearch.Text == 0 or #idSearch.Text >= 3 then
			onChangeFunc()
		end
	end
end

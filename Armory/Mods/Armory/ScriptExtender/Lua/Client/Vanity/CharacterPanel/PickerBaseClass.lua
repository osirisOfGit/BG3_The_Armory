Ext.Require("Client/Vanity/CharacterPanel/PickerBaseFilterClass.lua")

local itemIndex = {
	---@class SearchIndex
	equipment = {
		---@type {[string]: string}
		templateIdAndStat = {},
		---@type {[string]: string}
		templateIdAndTemplateName = {},
		---@type {[string]: string[]}
		modIdAndTemplateIds = {},
		---@type {[string]: string}
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
	---@type {[string]: PickerBaseFilterClass}
	customFilters = {},
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
	instance.customFilters = {}
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

function PickerBaseClass:DisplayResult(template, group) end

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
			self:ProcessFilters()
		end

		self.settingsMenu:AddSeparator()

		self.settingsMenu:AddText("Image Size")
		local imageSizeSetting = self.settingsMenu:AddSliderInt("", self.settings.imageSize, 10, 200)
		imageSizeSetting.OnChange = function()
			self.settings.imageSize = imageSizeSetting.Value[1]
			self:ProcessFilters()
		end

		self.separator = self.window:AddSeparatorText("")
		self.separator:SetStyle("SeparatorTextAlign", 0.5)
		self.separator.Font = "Large"

		local toggleFilterColumn = Styler:ImageButton(self.window:AddImageButton("filterCol", "ico_filter", { 40, 40 }))

		local displayTable = self.window:AddTable("", 2)
		displayTable:AddColumn("", "WidthFixed", 400)
		displayTable:AddColumn("", "WidthStretch")

		local row = displayTable:AddRow()

		self.filterGroup = row:AddCell():AddChildWindow("Filters")
		self.filterGroup.Visible = true

		-- Shoutout to Skiz for this
		local toggleTimer
		toggleFilterColumn.OnClick = function()
			if not toggleTimer then
				local cWidth = displayTable.ColumnDefs[1].Width
				local stepDelay = 10
				local function stepCollapse()
					if cWidth > 0 then
						cWidth = math.max(0, cWidth - (cWidth * 0.1)) -- Reduce by 10%
						cWidth = cWidth < 10 and 0 or cWidth

						displayTable.ColumnDefs[1].Width = cWidth
						stepDelay = math.min(50, stepDelay * 1.02) -- Increase delay per step to make it like soft-close drawer
						toggleTimer = Ext.Timer.WaitFor(stepDelay, stepCollapse)
					else
						toggleTimer = nil
						self.filterGroup.Visible = false
						-- EquipmentPicker auto determines entries per row based on childWindow size, Dyes don't
						if self.slot then
							self:ProcessFilters()
						end
					end
				end

				local widthStep = 1
				local function stepExpand()
					cWidth = cWidth == 0 and 1 or cWidth

					local max = math.min(350, Ext.Utils.Version() >= 23 and self.window.LastSize[1] * .3 or 350)

					self.filterGroup.Visible = true
					if cWidth < max then
						widthStep = math.max(0.01, widthStep - (widthStep * .125))

						cWidth = math.min(max, cWidth + (cWidth * widthStep))
						displayTable.ColumnDefs[1].Width = cWidth

						stepDelay = math.min(50, stepDelay)
						toggleTimer = Ext.Timer.WaitFor(stepDelay, stepExpand)
					else
						toggleTimer = nil
						-- EquipmentPicker auto determines entries per row based on childWindow size, Dyes don't
						if self.slot then
							self:ProcessFilters()
						end
					end
				end

				if not self.filterGroup.Visible then
					stepExpand()
				else
					if cWidth == 0 then
						cWidth = math.min(350, Ext.Utils.Version() >= 23 and self.window.LastSize[1] * .3 or 350)
					end
					stepCollapse()
				end
			else
				toggleTimer = false
			end
		end

		self.otherGroup = row:AddCell():AddGroup("RestOfTheOwl")

		self.warningGroup = self.otherGroup:AddGroup("WarningGroup")

		self.favoritesGroup = self.otherGroup:AddCollapsingHeader("Favorites")
		self.favoritesGroup.IDContext = self.title .. "Favorites"
		self.otherGroup:AddNewLine()

		if self.slot then
			local refreshViewButton = Styler:ImageButton(self.otherGroup:AddImageButton("", "ico_reset_d", { 32, 32 }))
			refreshViewButton:Tooltip():AddText("\t Refresh the display view, recomputing items per row")
			refreshViewButton.OnClick = function()
				self:ProcessFilters()
			end
		end
		self.resultSeparator = self.otherGroup:AddSeparatorText("Results")
		self.resultsGroup = self.otherGroup:AddChildWindow(self.title .. "Results")

		customizeFunc()
		self:BuildFilters()
	else
		if not self.window.Open then
			self.window.Open = true
		end
		self.window:SetFocus()
	end

	self.separator.Label = string.format("Searching for %s %s", slot, self.title)

	self:ProcessFilters()
end

local timer
function PickerBaseClass:ProcessFilters(listenerToIgnore)
	if timer then
		Ext.Timer.Cancel(timer)
	end
	timer = Ext.Timer.WaitFor(300, function()
		---@type {[string]: PickerBaseFilterClass}
		local filterBuildersToRun = {}

		for label, filter in pairs(self.customFilters) do
			if label ~= listenerToIgnore and filter.prepareFilterUI then
				filterBuildersToRun[label] = filter
				filter:initializeUIBuilder()
			end
		end

		Helpers:KillChildren(self.favoritesGroup, self.resultsGroup)
		local count = 0

		for templateId in TableUtils:OrderedPairs(self.itemIndex.templateIdAndTemplateName, function(key)
			return self.itemIndex.templateIdAndTemplateName[key]
		end) do
			---@type ItemTemplate
			local itemTemplate = Ext.Template.GetRootTemplate(templateId)

			local failedPredicate
			for label, filter in TableUtils:OrderedPairs(self.customFilters, function(key)
				return self.customFilters[key].priority
			end) do
				if not filter:apply(itemTemplate) then
					if not failedPredicate and filter.prepareFilterUI then
						failedPredicate = label
					else
						goto next_template
					end
				end
			end

			for label, filter in pairs(filterBuildersToRun) do
				if not failedPredicate or failedPredicate == label then
					filter:prepareFilterUI(itemTemplate)
				end
			end

			if not failedPredicate then
				self:DisplayResult(itemTemplate, self.favoritesGroup)
				self:DisplayResult(itemTemplate, self.resultsGroup)
				count = count + 1
			end

			::next_template::
		end

		for _, filter in pairs(filterBuildersToRun) do
			filter:buildUI()
		end

		self.resultSeparator.Label = ("%s Results"):format(count)
	end)
end

function PickerBaseClass:CreateCustomFilters() end

function PickerBaseClass:BuildFilters()
	local pickerInstance = self

	--#region Search By Name
	self.filterGroup:AddText("By Name")
	local nameSearch = self.filterGroup:AddInputText("")
	nameSearch.Hint = "Case-insensitive, min 3 characters"
	nameSearch.AutoSelectAll = true
	nameSearch.EscapeClearsAll = true
	nameSearch.OnChange = function()
		self:ProcessFilters()
	end

	local nameFilter = PickerBaseFilterClass:new({ label = "name", priority = 10 })
	self.customFilters[nameFilter.label] = nameFilter
	---@param itemTemplate ItemTemplate
	---@return boolean
	nameFilter.apply = function(self, itemTemplate)
		if #nameSearch.Text >= 3 then
			local upperSearch = string.upper(nameSearch.Text)

			if not upperSearch or string.find(string.upper(pickerInstance.itemIndex.templateIdAndTemplateName[itemTemplate.Id]), upperSearch) then
				return true
			else
				return false
			end
		else
			return true
		end
	end
	--#endregion

	--#region Search By Id
	self.filterGroup:AddText("By UUID")
	local idSearch = self.filterGroup:AddInputText("")
	idSearch.Hint = "Case-insensitive, min 3 characters"
	idSearch.AutoSelectAll = true
	idSearch.EscapeClearsAll = true
	idSearch.OnChange = function()
		self:ProcessFilters()
	end

	local idSearchFilter = PickerBaseFilterClass:new({ label = "id", priority = 10 })
	self.customFilters[idSearchFilter.label] = idSearchFilter

	---@param itemTemplate ItemTemplate
	---@return boolean
	idSearchFilter.apply = function(self, itemTemplate)
		if #idSearch.Text >= 3 then
			local upperSearch = string.upper(idSearch.Text)

			if not upperSearch or string.find(string.upper(itemTemplate.Id), upperSearch) then
				return true
			else
				return false
			end
		end
		return true
	end
	--#endregion

	self.filterGroup:AddNewLine()

	--#region Mod Picker
	local modTitleHeader, updateLabelWithCount = Styler:DynamicLabelTree(self.filterGroup:AddTree("By Mod(s)"))
	-- Stops empty tree from firing activation and deactivation events on one click
	modTitleHeader:AddDummy(0, 0)

	local modGroup = self.filterGroup:AddGroup("modGroupBecauseCollapseKeepsResettingScroll")

	modGroup.Visible = false
	modTitleHeader.OnExpand = function()
		modGroup.Visible = true
	end

	modTitleHeader.OnCollapse = function()
		modGroup.Visible = false
	end

	local modNameSearch = modGroup:AddInputText("")
	modNameSearch.Hint = "Mod Name - Case-insensitive"
	modNameSearch.AutoSelectAll = true
	modNameSearch.EscapeClearsAll = true
	modNameSearch.OnChange = function()
		self:ProcessFilters()
	end

	local clearSelected = Styler:ImageButton(modGroup:AddImageButton("resetMods", "ico_reset_d", { 32, 32 }))
	clearSelected.SameLine = true
	clearSelected:Tooltip():AddText("\t Clear Selected Mods")

	local modFilterWindow = modGroup:AddChildWindow("modFilters")
	modFilterWindow.NoResize = true

	modGroup:AddNewLine()

	local modFilter = PickerBaseFilterClass:new({ label = "ModFilter", priority = 99 })
	self.customFilters[modFilter.label] = modFilter

	local selectedCount = 0
	modFilter.initializeUIBuilder = function(self)
		selectedCount = 0
		local upperSearch = string.upper(modNameSearch.Text)
		self.filterBuilders = {}
		self.filterTable = {}
		for modName, modId in pairs(pickerInstance.itemIndex.mods) do
			if not upperSearch or string.find(string.upper(modName), upperSearch) then
				self.filterTable[modName] = pickerInstance.itemIndex.modIdAndTemplateIds[modId]
			end
		end
	end

	modFilter.selectedFilters = {}

	modFilter.buildUI = function(self)
		Helpers:KillChildren(modFilterWindow)
		for _, func in TableUtils:OrderedPairs(self.filterBuilders) do
			func()
		end
	end

	modFilter.prepareFilterUI =
	---@param self PickerBaseFilterClass
	---@param itemTemplate ItemTemplate
		function(self, itemTemplate)
			for modName, templateIds in pairs(self.filterTable) do
				if TableUtils:ListContains(templateIds, itemTemplate.Id) then
					self.filterTable[modName] = nil

					self.filterBuilders[modName] = function()
						---@type ExtuiSelectable
						local selectable = modFilterWindow:AddSelectable(modName)
						-- Selectable Active Bg inherits from the collapsible Header color, so resetting to default per
						-- https://github.com/Norbyte/bg3se/blob/f8b982125c6c1997ceab2d65cfaa3c1a04908ea6/BG3Extender/Extender/Client/IMGUI/IMGUI.cpp#L1901C34-L1901C60
						selectable:SetColor("Header", { 0.36, 0.30, 0.27, 0.76 })
						selectable.UserData = pickerInstance.itemIndex.mods[modName]
						selectable.Selected = self.selectedFilters[selectable.UserData] or false

						selectedCount = selectedCount + (selectable.Selected and 1 or 0)

						selectable.OnClick = function()
							self.selectedFilters[selectable.UserData] = selectable.Selected

							selectedCount = selectedCount + (selectable.Selected and 1 or -1)
							updateLabelWithCount(selectedCount)

							pickerInstance:ProcessFilters(self.label)
						end

						updateLabelWithCount(selectedCount)

						modFilterWindow.Size = { 0,
							Ext.Utils.Version() >= 23
							and math.max(130, (pickerInstance.window.LastSize[1] * .025) * #modFilterWindow.Children)
							or 0
						}
					end

					break
				end
			end
		end

	clearSelected.OnClick = function()
		modFilter.selectedFilters = {}
		Helpers:KillChildren(modFilterWindow)
		self:ProcessFilters()
	end

	modFilter.apply = function(self, itemTemplate)
		local anySelected = false

		for _, selectable in ipairs(modFilterWindow.Children) do
			---@cast selectable ExtuiSelectable
			if selectable.Selected then
				anySelected = true
				if TableUtils:ListContains(pickerInstance.itemIndex.modIdAndTemplateIds[selectable.UserData], itemTemplate.Id) then
					return true
				end
			end
		end

		return not anySelected and true or false
	end
	--#endregion

	self:CreateCustomFilters()
end

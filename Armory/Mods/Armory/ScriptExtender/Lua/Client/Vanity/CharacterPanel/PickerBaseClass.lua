local itemIndex = {
	---@class SearchIndex
	equipment = {
		statAndModId = {},
		statAndTemplateId = {},
		templateIdAndStat = {},
		templateIdAndTemplateName = {},
		modIdAndTemplateIds = {},
		mods = {}
	},
	dyes = {
		statAndModId = {},
		statAndTemplateId = {},
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

			indexShard.statAndTemplateId[statString] = stat.RootTemplate
			indexShard.templateIdAndStat[stat.RootTemplate] = statString
			indexShard.templateIdAndTemplateName[stat.RootTemplate] = itemTemplate.DisplayName:Get() or itemTemplate.Name

			if stat.ModId ~= "" then
				local modInfo = Ext.Mod.GetMod(stat.ModId).Info
				if not indexShard.mods[modInfo.Name] then
					if not modcache[stat.ModId] then
						modCount = modCount + 1
						modcache[stat.ModId] = true
					end
					indexShard.mods[modInfo.Name] = stat.ModId
					indexShard.modIdAndTemplateIds[stat.ModId] = {}
				end
				indexShard.statAndModId[statString] = stat.ModId
				table.insert(indexShard.modIdAndTemplateIds[stat.ModId], itemTemplate.Id)
			end
		end)

		if not success then
			Logger:BasicWarning("Couldn't load stat %s (from Mod '%s') into the search table due to %s - please contact the mod author to fix this issue",
				stat.Name,
				stat.ModId ~= "" and Ext.Mod.GetMod(stat.ModId).Info.Name or "Unknown",
				error)
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
			self.searchInput.Text = ""
			self.getAllForModCombo.SelectedIndex = -1
			Ext.Timer.WaitFor(60, function ()
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

		self.searchInput = self.window:AddInputText("")
		self.searchInput.Hint = "Case-insensitive, min 3 characters"
		self.searchInput.AutoSelectAll = true
		self.searchInput.EscapeClearsAll = true
		local delayTimer
		self.searchInput.OnChange = function()
			if delayTimer then
				Ext.Timer.Cancel(delayTimer)
			end

			self.getAllForModCombo.SelectedIndex = -1

			delayTimer = Ext.Timer.WaitFor(150, function()
				Helpers:KillChildren(self.resultsGroup)

				self.rowCount = 0
				local upperSearch
				if #self.searchInput.Text >= 3 then
					upperSearch = string.upper(self.searchInput.Text)
				end

				for templateId, templateName in TableUtils:OrderedPairs(self.itemIndex.templateIdAndTemplateName, function(key)
					return self.itemIndex.templateIdAndTemplateName[key]
				end) do
					if not upperSearch or string.find(string.upper(templateName), upperSearch) then
						self:DisplayResult(templateId, self.resultsGroup)
					end
				end
			end)
		end

		self.window:AddText("List all items by mod - will be cleared if above search is used")

		self.getAllForModCombo = self.window:AddCombo("")
		self.getAllForModCombo.WidthFitPreview = true
		local modOpts = {}
		for modName, _ in TableUtils:OrderedPairs(self.itemIndex.mods) do
			table.insert(modOpts, modName)
		end
		table.sort(modOpts)
		self.getAllForModCombo.Options = modOpts
		self.getAllForModCombo.OnChange = function()
			Helpers:KillChildren(self.resultsGroup)
			-- \[[[^_^]]]/
			for _, templateId in ipairs(self.itemIndex.modIdAndTemplateIds[self.itemIndex.mods[self.getAllForModCombo.Options[self.getAllForModCombo.SelectedIndex + 1]]]) do
				self:DisplayResult(templateId, self.resultsGroup)
			end
		end

		self.warningGroup = self.window:AddGroup("WarningGroup")

		self.favoritesGroup = self.window:AddCollapsingHeader("Favorites")
		self.favoritesGroup.IDContext = self.title .. "Favorites"
		self.window:AddNewLine()

		self.resultSeparator = self.window:AddSeparatorText("Results")
		self.resultsGroup = self.window:AddGroup(self.title .. "Results")

		customizeFunc()
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
	end

	if #self.searchInput.Text >= 3 then
		self.searchInput.OnChange()
	elseif self.getAllForModCombo.SelectedIndex > -1 then
		self.getAllForModCombo.OnChange()
	else
		for templateId, templateName in TableUtils:OrderedPairs(self.itemIndex.templateIdAndTemplateName, function(key)
			return self.itemIndex.templateIdAndTemplateName[key]
		end) do
			if self.title ~= "Dyes" or not string.find(templateName, "FOCUSDYES_MiraculousDye") then
				self:DisplayResult(templateId, self.resultsGroup)
			end
		end
	end
end

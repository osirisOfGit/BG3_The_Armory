---@class PickerBaseClass
PickerBaseClass = {
	---@type table<FixedString, ItemTemplate>
	rootsByName = {},
	---@type string[]
	sortedTemplateNames = {},
	---@type {[string]: Guid[]}
	templateNamesByModId = {},
	---@type {[string]: Guid}
	modIdByModName = {},
	---@type EquipmentSettings|DyeSettings
	settings = {},
	---@type ActualSlot
	slot = nil,
	---@type ExtuiMenu
	settingsMenu = nil,
	---@type string[]
	blacklistedItems = {}
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
	instance.slot = nil
	instance.settingsMenu = nil
	instance.blacklistedItems = {}

	return instance
end

function PickerBaseClass:InitializeSearchBank() end

function PickerBaseClass:DisplayResult(templateName, group) end

function PickerBaseClass:OpenWindow(slot, customizeFunc, onCloseFunc)
	self.slot = slot

	if not self.window then
		self:InitializeSearchBank()

		self.window = Ext.IMGUI.NewWindow(self.title)
		self.window.Closeable = true
		self.window.MenuBar = true
		self.window.OnClose = function()
			self.searchInput.Text = ""
			self.getAllForModCombo.SelectedIndex = -1
			onCloseFunc()
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
				if #self.searchInput.Text >= 3 then
					local upperSearch = string.upper(self.searchInput.Text)
					for _, templateName in ipairs(self.sortedTemplateNames) do
						if string.find(string.upper(templateName), upperSearch) then
							self:DisplayResult(templateName, self.resultsGroup)
						end
					end
				elseif #self.searchInput.Text == 0 then
					for _, templateName in ipairs(self.sortedTemplateNames) do
						self:DisplayResult(templateName, self.resultsGroup)
					end
				end
			end)
		end

		self.window:AddText("List all items by mod - will be cleared if above search is used")

		self.getAllForModCombo = self.window:AddCombo("")
		self.getAllForModCombo.WidthFitPreview = true
		local modOpts = {}
		for modId, _ in pairs(self.templateNamesByModId) do
			table.insert(modOpts, Ext.Mod.GetMod(modId).Info.Name)
		end
		table.sort(modOpts)
		self.getAllForModCombo.Options = modOpts
		self.getAllForModCombo.OnChange = function()
			Helpers:KillChildren(self.resultsGroup)
			-- \[[[^_^]]]/
			for _, templateName in ipairs(self.templateNamesByModId[self.modIdByModName[self.getAllForModCombo.Options[self.getAllForModCombo.SelectedIndex + 1]]]) do
				self:DisplayResult(templateName, self.resultsGroup)
			end
		end

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

	for _, templateName in pairs(self.sortedTemplateNames) do
		self:DisplayResult(templateName, self.favoritesGroup)
	end

	if #self.searchInput.Text >= 3 then
		self.searchInput.OnChange()
	elseif self.getAllForModCombo.SelectedIndex > -1 then
		self.getAllForModCombo.OnChange()
	else
		for _, templateName in pairs(self.sortedTemplateNames) do
			if self.title ~= "Dyes" or not string.find(templateName, "FOCUSDYES_MiraculousDye") then
				self:DisplayResult(templateName, self.resultsGroup)
			end
		end
	end
end

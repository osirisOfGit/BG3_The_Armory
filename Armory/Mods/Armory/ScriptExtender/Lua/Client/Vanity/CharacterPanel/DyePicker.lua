---@class DyePicker : PickerBaseClass
DyePicker = PickerBaseClass:new("Dyes", {
	settings = ConfigurationStructure.config.vanity.settings.dyes,
	---@type ExtuiGroup?
	activeDyeGroup = nil
})

function DyePicker:OpenWindow(itemTemplate, slot, onSelectFunc)
	PickerBaseClass.OpenWindow(self,
		slot,
		function()
			local resultTable = self.window:AddTable("Dyes", 2)
			resultTable.NoSavedSettings = true
			resultTable:AddColumn("Dyes", "WidthStretch")
			resultTable:AddColumn("Information", "WidthStretch")

			local row = resultTable:AddRow()
			local dyeCell = row:AddCell()

			local dyeWindow = dyeCell:AddChildWindow("DyeResults")
			dyeWindow.NoSavedSettings = true

			self.window:DetachChild(self.favoritesGroup)
			dyeWindow:AttachChild(self.favoritesGroup)
			self.favoritesGroup.SpanAvailWidth = true

			self.window:DetachChild(self.resultSeparator)
			dyeWindow:AttachChild(self.resultSeparator)
			self.window:DetachChild(self.resultsGroup)
			dyeWindow:AttachChild(self.resultsGroup)

			self.infoCell = row:AddCell()
		end,
		function()
			Ext.ClientNet.PostMessageToServer(ModuleUUID .. "_StopPreviewingDye", self.slot)
		end)

	self.onSelectFunc = onSelectFunc
end

---@param dyeTemplateId string
---@param displayGroup ExtuiGroup|ExtuiCollapsingHeader
function DyePicker:DisplayResult(dyeTemplateId, displayGroup)
	if TableUtils:ListContains(self.blacklistedItems, dyeTemplateId) then
		return
	end

	---@type ItemTemplate
	local dyeTemplate = Ext.Template.GetRootTemplate(dyeTemplateId)

	local isFavorited, favoriteIndex = TableUtils:ListContains(ConfigurationStructure.config.vanity.settings.dyes.favorites, dyeTemplate.Id)

	if displayGroup.Handle == self.favoritesGroup.Handle and not isFavorited then
		return
	end

	---@type ResourceMaterialPresetResource
	local materialPreset = Ext.Resource.Get(dyeTemplate.ColorPreset, "MaterialPreset")
	if not materialPreset then
		---@type Object
		local dyeStat = Ext.Stats.Get(self.itemIndex.templateIdAndStat[dyeTemplateId])
		local modInfo = Ext.Mod.GetMod(dyeStat.ModId).Info

		table.insert(self.blacklistedItems, dyeTemplateId)
		Logger:BasicWarning("Dye %s from Mod %s by %s does not have a materialPreset?", dyeTemplate.DisplayName:Get() or dyeTemplate.Name, modInfo.Name, modInfo.Author)
		return
	end

	local favoriteButton = displayGroup:AddImageButton("Favorite" .. dyeTemplateId, isFavorited and "star_fileld" or "star_empty", { 26, 26 })
	favoriteButton.Background = { 0, 0, 0, 0.5 }
	favoriteButton:SetColor("Button", { 0, 0, 0, 0.5 })

	local dyeImageButton = displayGroup:AddImageButton(dyeTemplateId, dyeTemplate.Icon, { self.settings.imageSize, self.settings.imageSize })
	dyeImageButton.UserData = materialPreset.Guid
	dyeImageButton.SameLine = true
	dyeImageButton.Background = { 0, 0, 0, 0.5 }

	if self.settings.showNames then
		displayGroup:AddText(dyeTemplate.DisplayName:Get() or dyeTemplate.Name).SameLine = true
	end

	dyeImageButton.OnClick = function()
		if self.activeDyeGroup then
			self.activeDyeGroup:Destroy()
		end
		local dyeInfoGroup = self.infoCell:AddGroup(dyeTemplateId .. dyeTemplate.Stats .. self.slot .. "dye")
		self.activeDyeGroup = dyeInfoGroup

		---@type Object
		local dyeStat = Ext.Stats.Get(dyeTemplate.Stats)
		local modInfo = Ext.Mod.GetMod(dyeStat.ModId)

		dyeInfoGroup:AddSeparatorText(dyeTemplate.DisplayName:Get() or dyeTemplate.Name)
		dyeInfoGroup:AddText(string.format("From '%s' by '%s'", modInfo.Info.Name, modInfo.Info.Author ~= '' and modInfo.Info.Author or "Larian"))
			:SetColor("Text", { 1, 1, 1, 0.5 })

		dyeInfoGroup:AddButton("Select").OnClick = function()
			self.activeDyeGroup:Destroy()
			self.activeDyeGroup = nil

			Ext.ClientNet.PostMessageToServer(ModuleUUID .. "_StopPreviewingDye", self.slot)
			self.onSelectFunc(dyeTemplate)
			self.window.Open = false
		end
		dyeInfoGroup:AddSeparator()

		---@type ResourcePresetDataVector3Parameter[]
		local materialColorParams = {}
		for _, setting in pairs(Ext.Resource.Get(dyeImageButton.UserData, "MaterialPreset").Presets.Vector3Parameters) do
			table.insert(materialColorParams, setting)
		end
		table.sort(materialColorParams, function(a, b)
			return a.Parameter < b.Parameter
		end)

		dyeInfoGroup:AddText("Values are not editable"):SetStyle("Alpha", 0.65)

		local dyeTable = dyeInfoGroup:AddTable(dyeTemplateId, 2)
		dyeTable.SizingStretchProp = true

		for _, colorSetting in pairs(materialColorParams) do
			if colorSetting.Color then
				local dyeRow = dyeTable:AddRow()
				dyeRow:AddCell():AddText(colorSetting.Parameter)
				if colorSetting.Enabled then
					dyeRow:AddCell():AddColorEdit("", colorSetting.Value).ItemReadOnly = true
				else
					dyeRow:AddCell():AddText("---")
				end
			end
		end

		Ext.ClientNet.PostMessageToServer(ModuleUUID .. "_PreviewDye", Ext.Json.Stringify({
			materialPreset = dyeImageButton.UserData,
			slot = self.slot
		}))
	end

	favoriteButton.OnClick = function()
		if not isFavorited then
			table.insert(ConfigurationStructure.config.vanity.settings.dyes.favorites, dyeTemplate.Id)
		else
			table.remove(ConfigurationStructure.config.vanity.settings.dyes.favorites, favoriteIndex)
		end
		self:RebuildDisplay()
	end
end

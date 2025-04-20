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
			local resultTable = self.otherGroup:AddTable("Dyes", 2)
			resultTable.NoSavedSettings = true
			resultTable:AddColumn("Dyes", "WidthStretch")
			resultTable:AddColumn("Information", "WidthStretch")

			local row = resultTable:AddRow()
			local dyeCell = row:AddCell()

			local dyeWindow = dyeCell:AddChildWindow("DyeResults")
			dyeWindow.NoSavedSettings = true

			self.otherGroup:DetachChild(self.favoritesGroup)
			dyeWindow:AttachChild(self.favoritesGroup)
			self.favoritesGroup.SpanAvailWidth = true

			self.otherGroup:DetachChild(self.resultSeparator)
			dyeWindow:AttachChild(self.resultSeparator)
			self.otherGroup:DetachChild(self.resultsGroup)
			dyeWindow:AttachChild(self.resultsGroup)

			self.infoCell = row:AddCell()
		end,
		function()
			Ext.ClientNet.PostMessageToServer(ModuleUUID .. "_StopPreviewingDye", self.slot)
		end)

	self.onSelectFunc = onSelectFunc
end

---@param color number[]
local function convertToRGB(color)
	local color = TableUtils:DeeplyCopyTable(color)
	for i, c in ipairs(color) do
		color[i] = c * 255
	end

	return color
end

local maxEuclideanValue = math.sqrt((255 ^ 2) + (255 ^ 2) + (255 ^ 2))
--- https://en.wikipedia.org/wiki/Color_difference
---@param baseColor number[]
---@param otherColor number[]
---@return number percentage difference between the two numbers
local function calculateEuclideanDistance(baseColor, otherColor)
	local r = (otherColor[1] - baseColor[1]) ^ 2
	local g = (otherColor[2] - baseColor[2]) ^ 2
	local b = (otherColor[3] - baseColor[3]) ^ 2

	return (math.sqrt(r + g + b) / maxEuclideanValue) * 100
end

--- http://www.easyrgb.com/en/math.php
---@param color number[] SRGB / 255
---@return number[]
local function convertToXYZ(color)
	color = TableUtils:DeeplyCopyTable(color)

	for i, c in ipairs(color) do
		color[i] = c > 0.04045 and (((c + 0.055) / 1.055) ^ 2.4) or (c / 12.92)
		color[i] = color[i] * 100
	end

	local x = (color[1] * 0.4124) + (color[2] * 0.3576) + (color[3] * 0.1805)
	local y = (color[1] * 0.2126) + (color[2] * 0.7152) + (color[3] * 0.0722)
	local z = (color[1] * 0.0193) + (color[2] * 0.1192) + (color[3] * 0.9505)

	return { x, y, z }
end

--- I     X2      Y2      Z2       X10       Y10     Z10
---D65	95.047	100.000	108.883	  94.811   100.000	107.304	     Daylight, sRGB, Adobe-RGB
---@param color number[] XYZ
local function convertToCIELAB(color)
	local standardized = { color[1] / 94.811, color[2] / 100, color[3] / 107.304 }

	for i, c in ipairs(standardized) do
		standardized[i] = c > 0.008856 and (c ^ (1 / 3)) or ((7.787 * c) + (16 / 116))
	end

	local L = (116 * standardized[2]) - 16
	local a = 500 * (standardized[1] - standardized[2])
	local b = 200 * (standardized[2] - standardized[3])

	return { L, a, b }
end

--- https://en.wikipedia.org/wiki/Color_difference
--- How the HELL did anyone come up with this
---@param baseCIE number[]
---@param otherCIE number[]
local function calculateCIE94Delta(baseCIE, otherCIE)
	local kL = 1
	local K1 = 0.045
	local K2 = 0.015
	local kC = 1
	local kH = 1

	local deltaL = baseCIE[1] - otherCIE[1]

	local C1 = math.sqrt((baseCIE[2] ^ 2) + (baseCIE[3] ^ 2))
	local C2 = math.sqrt((otherCIE[2] ^ 2) + (otherCIE[3] ^ 2))
	local deltaC = C1 - C2

	local deltaA = (baseCIE[2] - otherCIE[2]) ^ 2
	local deltaB = (baseCIE[3] - otherCIE[3]) ^ 2
	local deltaH = deltaA + deltaB - (deltaC ^ 2)
	deltaH = deltaH < 0 and 0 or math.sqrt(deltaH)

	local SL = 1
	local SC = 1 + (K1 * C1)
	local SH = 1 + (K2 * C1)

	local firstGroup = (deltaL / (kL * SL)) ^ 2
	local secondGroup = (deltaC / (kC * SC)) ^ 2
	local thirdGroup = (deltaH / (kH * SH)) ^ 2

	local delta = firstGroup + secondGroup + thirdGroup
	delta = delta < 0 and 0 or math.sqrt(delta)

	return delta
end

function DyePicker:CreateCustomFilters()
	local similarColourFilter = PickerBaseFilterClass:new({ label = "similarColor", priority = 1000 })
	self.customFilters[similarColourFilter.label] = similarColourFilter

	similarColourFilter.header, similarColourFilter.updateLabelWithCount = Styler:DynamicLabelTree(self.filterGroup:AddTree("Similar Color"))

	local baseColor = similarColourFilter.header:AddColorPicker("Base Color")
	baseColor.OnChange = function()
		self:ProcessFilters()
	end

	local maxDiffText = similarColourFilter.header:AddText("Max Delta")
	local maxDistance = similarColourFilter.header:AddSliderInt("", 15, 0, 100)
	maxDistance.OnChange = function()
		self:ProcessFilters()
	end

	local eucledianDistance = similarColourFilter.header:AddRadioButton("Euclidean Distance", false)
	eucledianDistance:Tooltip():AddText("\t Faster, less accurate")

	local cielab94Delta = similarColourFilter.header:AddRadioButton("CIE94 Delta", true)
	cielab94Delta:Tooltip():AddText("\t Slower, more accurate (Illuminant = D65, 10 degree observer, unity = 1)\n(don't @ me CIE2000 nerds, I ain't that smart)")

	eucledianDistance.OnActivate = function()
		cielab94Delta.Active = eucledianDistance.Active
		eucledianDistance.Active = not eucledianDistance.Active

		if cielab94Delta.Active then
			maxDiffText.Label = "Max Delta"
		else
			maxDiffText.Label = "Max Difference %"
		end

		self:ProcessFilters()
	end

	cielab94Delta.OnActivate = function()
		eucledianDistance.Active = cielab94Delta.Active
		cielab94Delta.Active = not cielab94Delta.Active

		if cielab94Delta.Active then
			maxDiffText.Label = "Max Delta"
		else
			maxDiffText.Label = "Max Difference %"
		end
		self:ProcessFilters()
	end

	similarColourFilter.header:AddSeparator():SetStyle("ItemSpacing", 20, 20)

	local resetButton = Styler:ImageButton(similarColourFilter.header:AddImageButton("resetColors", "ico_reset_d", { 32, 32 }))
	resetButton:Tooltip():AddText("\t Clear all selected")

	local selectedCount = 0
	local checkboxGroup = similarColourFilter.header:AddGroup("checkboxes")
	resetButton.OnClick = function()
		for _, checkbox in pairs(checkboxGroup.Children) do
			checkbox.Checked = false
		end

		selectedCount = 0
		similarColourFilter.updateLabelWithCount(selectedCount)
		self:ProcessFilters()
	end

	---@type ResourcePresetDataVector3Parameter[]
	local materialColorParams = {}
	for _, setting in pairs(Ext.Resource.Get("a8690bc5-9f17-5672-28e2-41c1ab3018ea", "MaterialPreset").Presets.Vector3Parameters) do
		table.insert(materialColorParams, setting)
	end
	for _, materialColor in TableUtils:OrderedPairs(materialColorParams, function(key)
		return materialColorParams[key].Parameter
	end) do
		local checkbox = checkboxGroup:AddCheckbox(materialColor.Parameter)

		checkbox.OnChange = function()
			selectedCount = selectedCount + (checkbox.Checked and 1 or -1)
			self:ProcessFilters()

			similarColourFilter.updateLabelWithCount(selectedCount)
		end
	end

	similarColourFilter.apply = function(self, itemTemplate)
		if TableUtils:ListContains(checkboxGroup.Children, function(value)
				---@cast value ExtuiCheckbox
				return value.Checked
			end)
		then
			---@type ResourceMaterialPresetResource
			local materialPreset = Ext.Resource.Get(itemTemplate.ColorPreset, "MaterialPreset")

			if not materialPreset then
				return false
			end

			for _, checkbox in pairs(checkboxGroup.Children) do
				---@cast checkbox ExtuiCheckbox
				if checkbox.Checked then
					for _, setting in pairs(materialPreset.Presets.Vector3Parameters) do
						if setting.Parameter == checkbox.Label and setting.Enabled == true then
							if cielab94Delta.Active then
								local delta = calculateCIE94Delta(
									convertToCIELAB(convertToXYZ(baseColor.Color)),
									convertToCIELAB(convertToXYZ(setting.Value)))

								if delta <= maxDistance.Value[1] then
									return true
								end
							elseif eucledianDistance.Active then
								local distance = calculateEuclideanDistance(
									convertToRGB(baseColor.Color),
									convertToRGB(setting.Value))

								if distance <= maxDistance.Value[1] then
									return true
								end
							end
						end
					end
				end
			end

			return false
		end

		return true
	end
end

---@param dyeTemplate ItemTemplate
---@param displayGroup ExtuiGroup|ExtuiCollapsingHeader
function DyePicker:DisplayResult(dyeTemplate, displayGroup)
	if TableUtils:ListContains(self.blacklistedItems, dyeTemplate.Id) then
		return
	end

	local isFavorited, favoriteIndex = TableUtils:ListContains(ConfigurationStructure.config.vanity.settings.dyes.favorites, dyeTemplate.Id)

	if displayGroup.Handle == self.favoritesGroup.Handle and not isFavorited then
		return
	end

	---@type ResourceMaterialPresetResource
	local materialPreset = Ext.Resource.Get(dyeTemplate.ColorPreset, "MaterialPreset")
	if not materialPreset then
		---@type Object
		local dyeStat = Ext.Stats.Get(self.itemIndex.templateIdAndStat[dyeTemplate.Id])
		local modInfo = Ext.Mod.GetMod(dyeStat.ModId).Info

		table.insert(self.blacklistedItems, dyeTemplate.Id)
		Logger:BasicWarning("Dye %s from Mod %s by %s does not have a materialPreset?", dyeTemplate.DisplayName:Get() or dyeTemplate.Name, modInfo.Name, modInfo.Author)
		return
	end

	local favoriteButton = Styler:ImageButton(displayGroup:AddImageButton("Favorite" .. dyeTemplate.Id, isFavorited and "star_fileld" or "star_empty", { 26, 26 }))

	local dyeImageButton = Styler:ImageButton(displayGroup:AddImageButton(dyeTemplate.Id, dyeTemplate.Icon, { self.settings.imageSize, self.settings.imageSize }))
	dyeImageButton.UserData = materialPreset.Guid
	dyeImageButton.SameLine = true

	if self.settings.showNames then
		displayGroup:AddText(dyeTemplate.DisplayName:Get() or dyeTemplate.Name).SameLine = true
	end

	dyeImageButton.OnClick = function()
		if self.activeDyeGroup then
			self.activeDyeGroup:Destroy()
		end
		local dyeInfoGroup = self.infoCell:AddGroup(dyeTemplate.Id .. dyeTemplate.Stats .. self.slot .. "dye")
		self.activeDyeGroup = dyeInfoGroup

		dyeInfoGroup:AddSeparatorText(dyeTemplate.DisplayName:Get() or dyeTemplate.Name)

		---@type Object
		local dyeStat = Ext.Stats.Get(dyeTemplate.Stats)
		if dyeStat then
			local modInfo = Ext.Mod.GetMod(dyeStat.ModId)

			dyeInfoGroup:AddText(string.format("From '%s' by '%s'", modInfo.Info.Name, modInfo.Info.Author ~= '' and modInfo.Info.Author or "Larian"))
				:SetColor("Text", { 1, 1, 1, 0.5 })
		else
			local modId = dyeTemplate.FileName:match("([^/]+)/RootTemplates/")
			if modId and modId:match("_[0-9a-fA-F%-]+$") then
				modId = modId:gsub("_[0-9a-fA-F%-]+$", "")
			end
			dyeInfoGroup:AddText(string.format("From folder %s", modId)):SetColor("Text", { 1, 1, 1, 0.5 })
		end

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

		local dyeTable = dyeInfoGroup:AddTable(dyeTemplate.Id, 2)
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
		self:ProcessFilters()
	end
end

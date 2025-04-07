ItemValidator = {}

---@type ExtuiWindow?
ItemValidator.Window = nil

---@class ValidationEntry
---@field type "Stat"|"Template"
---@field error string
---@field severity "Prevents Transmog"|"Prevents Dye"|"Has Built-In Workaround"
---@field subModId string?

---@type {[string]: ValidationEntry}
ItemValidator.Results = {}

--- Inserts a newline at the 1000th character or the next whitespace if the 1000th character is not a whitespace.
---@param text string
---@return string
function ItemValidator:InsertNewlineAtLimit(text)
	local limit = 100
	if #text <= limit then
		return text
	end

	local insertPos = limit
	while insertPos > 0 and text:sub(insertPos, insertPos) ~= " " do
		insertPos = insertPos - 1
	end

	if insertPos == 0 then
		insertPos = limit -- fallback to the limit if no whitespace is found
	end

	return text:sub(1, insertPos) .. "\n" .. text:sub(insertPos + 1)
end

---@param id string
---@param type "Stat"|"Template"
---@param entry Weapon|Armor|Object|ItemTemplate
---@param error string
---@param severity "Prevents Transmog"|"Prevents Dye"|"Has Built-In Workaround"
function ItemValidator:addEntry(id, entry, type, error, severity)
	local modId
	local subModId

	local stat
	if type == "Template" then
		if (entry.Stats and entry.Stats ~= "") then
			stat = Ext.Stats.Get(entry.Stats)
		else
			modId = entry.FileName:match("([^/]+)/RootTemplates/")
		end
	else
		stat = entry
	end

	if stat then
		if stat.OriginalModId and stat.OriginalModId ~= "" then
			modId = stat.OriginalModId
			subModId = stat.ModId ~= stat.OriginalModId and stat.ModId
		else
			modId = stat.ModId
		end
	elseif not modId then
		modId = "Unknown"
	end

	if not self.Results[modId] then
		self.Results[modId] = {}
	end

	self.Results[modId][id] = {
		id = id,
		-- Using TextWrapPos on the text in the cell wasn't working - onnly inserts the newline at the next whitespace
		error = error,
		type = type,
		severity = severity,
		subModId = subModId
	} --[[@as ValidationEntry]]
end

function ItemValidator:ValidateItems()
	if not next(self.Results) then
		for _, template in pairs(Ext.Template.GetAllRootTemplates()) do
			if template.TemplateType == "item" and not string.match(template.Name, "TimelineTemplate") then
				---@cast template ItemTemplate

				local success, error = pcall(function()
					if not template.Stats or template.Stats == "" then
						self:addEntry(template.Name .. "_" .. template.Id, template, "Template", "Does not have an associated Stat", "Prevents Transmog")
						return
					else
						---@type Weapon|Object|Armor
						local stat = Ext.Stats.Get(template.Stats)
						if not stat then
							self:addEntry(template.Name .. "_" .. template.Id,
								template,
								"Template",
								string.format("Points to stat %s which does not exist", template.Stats),
								"Prevents Transmog")
						else
							if not (stat.ModifierList == "Weapon" or stat.ModifierList == "Armor") and not string.match(stat.ObjectCategory, "Dye") then
								return
							end

							if not stat.RootTemplate or stat.RootTemplate == "" then
								self:addEntry(stat.Name, stat, "Stat", "Does not have a RootTemplate associated to it", "Prevents Transmog")
							elseif stat.RootTemplate ~= template.Id then
								local otherTemplate = Ext.Template.GetRootTemplate(stat.RootTemplate)

								self:addEntry(template.Name .. "_" .. template.Id,
									template,
									"Template",
									string.format(
										"Points to stat %s, but stat %s points to template %s - template should point to the same stat that points to the template",
										template.Stats,
										stat.Name,
										otherTemplate and (otherTemplate.Name .. "_" .. otherTemplate.Id) or (stat.RootTemplate .. "(Which doesn't exist)")),
									"Has Built-In Workaround")
							end
						end
					end
				end)
				if not success then
					self:addEntry(template.Name .. "_" .. template.Id, template, "Template", error or "Unknown error ocurred", "Prevents Transmog")
				end
			end
		end

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
				if not (stat.ModifierList == "Weapon" or stat.ModifierList == "Armor") and not string.match(stat.ObjectCategory, "Dye") then
					return
				end

				if (stat.ModifierList == "Weapon" or stat.ModifierList == "Armor") then
					if not stat.Slot or stat.Slot == "" then
						self:addEntry(stat.Name, stat, "Stat", "Does not have a Slot defined", "Prevents Transmog")
					end
				end

				if not stat.RootTemplate or stat.RootTemplate == "" then
					self:addEntry(stat.Name, stat, "Stat", "Does not have a RootTemplate defined", "Prevents Transmog")
				elseif not Ext.ClientTemplate.GetRootTemplate(stat.RootTemplate) then
					self:addEntry(stat.Name, stat, "Stat", string.format("RootTemplate %s does not exist", stat.RootTemplate), "Prevents Transmog")
				else
					---@type ItemTemplate
					local template = Ext.ClientTemplate.GetRootTemplate(stat.RootTemplate)

					if string.match(stat.ObjectCategory, "Dye") then
						if not template.ColorPreset or template.ColorPreset == "" then
							self:addEntry(template.Name .. "_" .. template.Id, template, "Template", "Does not have a ColorPreset defined", "Prevents Dye")
						elseif template.ColorPreset ~= "00000000-0000-0000-0000-000000000000" and not Ext.Resource.Get(template.ColorPreset, "MaterialPreset") then
							self:addEntry(template.Name .. "_" .. template.Id,
								template,
								"Template",
								string.format("ColorPreset %s does not exist", template.ColorPreset),
								"Prevents Dye")
						end
					end

					if not template.Stats or template.Stats == "" then
						self:addEntry(template.Name .. "_" .. template.Id, template, "Template", "Does not have a Stat defined", "Prevents Transmog")
					elseif template.Stats ~= stat.Name then
						self:addEntry(template.Name .. "_" .. template.Id,
							template,
							"Template",
							string.format("Points to stat %s, but stat %s points to this template - template should point to the same stat that points to the template",
								template.Stats, stat.Name),
							"Has Built-In Workaround")
					end
				end
			end)

			if not success then
				self:addEntry(stat.Name, stat, "Stat", error or "Unknown error ocurred", "Prevents Transmog")
			end
		end
	end

	for modId, _ in pairs(self.Results) do
		local mod = Ext.Mod.GetMod(modId)
		if mod then
			if self.Results[mod.Info.Name] then
				for _, results in pairs(self.Results[mod.Info.Name]) do
					table.insert(self.Results[modId], results)
				end
				self.Results[mod.Info.Name] = nil
			end
		end
	end
end

---@type ExtuiGroup?
local activeGroup
function ItemValidator:OpenReport()
	if not self.Window then
		self.Window = Ext.IMGUI.NewWindow("Validator Report")
		self.Window.Closeable = true
		self:ValidateItems()

		if next(self.Results) then
			local resultsTable = self.Window:AddTable("ValidationResults", 2)
			resultsTable:AddColumn("Mods", "WidthFixed")
			resultsTable:AddColumn("Results", "WidthStretch")

			local resultsRow = resultsTable:AddRow()
			local modsCol = resultsRow:AddCell():AddChildWindow("ModWindow")
			local resultsCol = resultsRow:AddCell():AddChildWindow("ValidationResults")
			resultsCol.AlwaysHorizontalScrollbar = true

			for modId, validationResults in TableUtils:OrderedPairs(self.Results, function(key)
				return Ext.Mod.GetMod(key) and Ext.Mod.GetMod(key).Info.Name or key
			end) do
				local mod = Ext.Mod.GetMod(modId) and Ext.Mod.GetMod(modId).Info or modId

				---@type ExtuiSelectable
				local selectable = modsCol:AddSelectable(mod and mod.Name or modId)

				selectable.OnClick = function()
					for _, child in pairs(modsCol.Children) do
						---@cast child ExtuiSelectable
						if child.Selected and child.Handle ~= selectable.Handle then
							child.Selected = false
						end
					end

					if activeGroup then
						activeGroup:Destroy()
					end

					activeGroup = resultsCol:AddGroup(selectable.Label)

					-- Lifetime of original var expires, so being lazy instead of serializing
					local mod = Ext.Mod.GetMod(modId) and Ext.Mod.GetMod(modId).Info or modId
					Styler:CheapTextAlign(mod.Name or modId, activeGroup, "Large")
					Styler:CheapTextAlign(mod.Name and (mod.Author or "Larian") or "Unknown Author", activeGroup)
					Styler:CheapTextAlign(mod.Name and (mod.ModVersion and ("v" .. table.concat(mod.ModVersion, "."))) or "Unknown Version", activeGroup)

					activeGroup:AddNewLine()

					local validationErrorsTable = activeGroup:AddTable("ValidationErrors" .. modId, 5)
					validationErrorsTable.Resizable = true
					validationErrorsTable.RowBg = true

					validationErrorsTable:AddColumn("", "WidthFixed")
					validationErrorsTable:AddColumn("", "WidthStretch")
					validationErrorsTable:AddColumn("", "WidthFixed")
					validationErrorsTable:AddColumn("", "WidthStretch")
					validationErrorsTable:AddColumn("", "WidthFixed")

					local headers = validationErrorsTable:AddRow()
					headers.Headers = true
					headers:AddCell():AddText("Severity")
					headers:AddCell():AddText("Id")
					headers:AddCell():AddText("Type")
					headers:AddCell():AddText("Error")
					headers:AddCell():AddText("Modified By")

					for id, validationError in TableUtils:OrderedPairs(validationResults) do
						local row = validationErrorsTable:AddRow()
						row:AddCell():AddText(validationError.severity)
						row:AddCell():AddText(id)
						row:AddCell():AddText(validationError.type)
						row:AddCell():AddText(self:InsertNewlineAtLimit(validationError.error))
						row:AddCell():AddText(validationError.subModId and Ext.Mod.GetMod(validationError.subModId).Info.Name or "---")
					end
				end
			end
		end
	elseif not self.Window.Open then
		self.Window.Open = true
		self.Window:SetFocus()
	end
end

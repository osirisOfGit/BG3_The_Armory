ItemValidator = {}

---@type ExtuiWindow?
ItemValidator.Window = nil

---@class ValidationEntry
---@field type "Stat"|"Template"
---@field error string
---@field severity "Prevents Transmog"|"Prevents Dye"|"Has Built-In Workaround"
---@field subModId string?

---@type {[string]: {[string]: ValidationEntry}}
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
			pcall(function(...)
				---@type Armor|Weapon|Object
				local tempStat = Ext.Stats.Get(entry.Stats)
				if tempStat and tempStat.RootTemplate == entry.Id then
					stat = Ext.Stats.Get(entry.Stats)
				end
			end)
		end

		if not stat then
			modId = entry.FileName:match("([^/]+)/RootTemplates/")
			if modId and modId:match("_[0-9a-fA-F%-]+$") then
				modId = modId:gsub("_[0-9a-fA-F%-]+$", "")
			end
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
		subModId = subModId and Ext.Mod.GetMod(subModId).Info.Name or "---"
	} --[[@as ValidationEntry]]
end

function ItemValidator:ValidateItems()
	if not next(self.Results) then
		for _, template in pairs(Ext.Template.GetAllRootTemplates()) do
			if template.TemplateType == "item" and template.Equipment and template.Equipment.Slot and #template.Equipment.Slot > 0 then
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
		self.Window.MenuBar = true

		self:ValidateItems()

		if next(self.Results) then
			---@type ExtuiMenu
			local filterMenu = self.Window:AddMainMenu():AddMenu("Filters")

			---@type ExtuiSelectable
			local showWorkaroundSelectable = filterMenu:AddSelectable("Show Issues That Have Built-In Workarounds")
			showWorkaroundSelectable.Selected = ConfigurationStructure.config.vanity.settings.general.itemValidator_ShowWorkaroundErrors

			local resultsTable = self.Window:AddTable("ValidationResults", 2)
			resultsTable:AddColumn("Mods", "WidthFixed")
			resultsTable:AddColumn("Results", "WidthStretch")

			local resultsRow = resultsTable:AddRow()
			local modsCol = resultsRow:AddCell():AddChildWindow("ModWindow")
			modsCol:SetSizeConstraints({ 400, 0 })
			resultsTable.ColumnDefs[1].Width = 400

			local resultsCol = resultsRow:AddCell():AddChildWindow("ValidationResults")
			resultsCol.AlwaysHorizontalScrollbar = true

			local function buildResults()
				for modId, validationResults in TableUtils:OrderedPairs(self.Results, function(key)
					return Ext.Mod.GetMod(key) and Ext.Mod.GetMod(key).Info.Name or key
				end) do
					local mod = Ext.Mod.GetMod(modId) and Ext.Mod.GetMod(modId).Info or modId

					if not ConfigurationStructure.config.vanity.settings.general.itemValidator_ShowWorkaroundErrors then
						local buildSelectable = false
						for _, validationError in pairs(validationResults) do
							if validationError.severity ~= "Has Built-In Workaround" then
								buildSelectable = true
							end
						end
						if not buildSelectable then
							goto continue
						end
					end

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

						Styler:MiddleAlignedColumnLayout(activeGroup,
							function(ele)
								Styler:CheapTextAlign(mod.Name or modId, ele, "Large")
							end,
							function(ele)
								Styler:CheapTextAlign(mod.Name and (mod.Author or "Larian") or "Unknown Author", ele)
							end,
							function(ele)
								Styler:CheapTextAlign(mod.Name and (mod.ModVersion and ("v" .. table.concat(mod.ModVersion, "."))) or "Unknown Version", ele)
							end,
							function(ele)
								local reportButton
								Styler:MiddleAlignedColumnLayout(ele, function(ele2)
									reportButton = ele2:AddButton("Generate Report")
								end)

								local text = ele:AddText("Successfully generated report at: %s")
								text.Visible = false

								reportButton.OnClick = function()
									local mod = Ext.Mod.GetMod(modId) and Ext.Mod.GetMod(modId).Info or modId
									text.Label = text.Label:format(self:ExportToReport(mod.Name or modId,
										mod.Name and (mod.ModVersion and ("v" .. table.concat(mod.ModVersion, "."))) or "Unknown Version",
										validationResults))
									text.Visible = true
								end
							end)

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
						headers:AddCell():AddText("Type")
						headers:AddCell():AddText("Id")
						headers:AddCell():AddText("Error")
						headers:AddCell():AddText("Modified By")

						for id, validationError in TableUtils:OrderedPairs(validationResults) do
							if ConfigurationStructure.config.vanity.settings.general.itemValidator_ShowWorkaroundErrors or validationError.severity ~= "Has Built-In Workaround" then
								local row = validationErrorsTable:AddRow()
								row:AddCell():AddText(validationError.severity)
								row:AddCell():AddText(validationError.type)
								row:AddCell():AddText(id)
								row:AddCell():AddText(self:InsertNewlineAtLimit(validationError.error))
								row:AddCell():AddText(validationError.subModId)
							end
						end
					end
					::continue::
				end
			end
			buildResults()

			showWorkaroundSelectable.OnClick = function()
				ConfigurationStructure.config.vanity.settings.general.itemValidator_ShowWorkaroundErrors = showWorkaroundSelectable.Selected
				if activeGroup then
					activeGroup:Destroy()
				end
				activeGroup = nil
				Helpers:KillChildren(modsCol, resultsCol)
				buildResults()
			end
		end
	elseif not self.Window.Open then
		self.Window.Open = true
		self.Window:SetFocus()
	end
end

---@param modName string
---@param validationResults {[string]: ValidationEntry}
function ItemValidator:ExportToReport(modName, modVersion, validationResults)
	local output = ([[
================ USER: READ THIS SECTION FIRST ================
This tool is not perfect by any stretch of the imagination - it has to make a lot of guesses based on available information, so it can be inaccurate depending on the type of issue.

Before providing this output to a mod author, please validate the following:
	1. Check the template/stat name - does it have words like "test", "template", or is numbers (like "1", "2")? If so, the reported issue is probably known and expected
	2. Make sure the mod reported for the template/stat makes sense - the SE provided modId isn't perfect, especially if multiple mods are modifying the same thing.
		Any "Overhaul" or "Rebalance" mods are likely not the true owner of the item, and may or may not be responsible for the issue.
		Any issues under Gustav or Shared are base-game items, so if they've been modified by a mod, disable that mod and see if the issue still occurs. If they haven't been modified, you'll need to patch the item yourself.
	3. Ensure you aren't missing any optional downloads/patches from the mod author - sometimes the base mod will house stats/templates that aren't intended to be used unless a patch/additional mod is downloaded
	4. Check the "Modified By" section and if present, ensure this issue persists without that mod loaded
	5. Check the mod description/bugs/posts section to see if these issues are known and/or already reported - don't be a spammer!

Also, please respect any author's decision to not fix any of the issues identified here, regardless of their reasons. Be polite!
Please don't bring these issues into the Larian discord / help channels unless you're looking to learn how to fix them yourself.

If the next section has a lot of reports, please upload it to https://pastebin.com first and provide the shareable link to the author so you don't bloat their mod page
===============================================================

================ PROVIDE THE BELOW TO THE MOD AUTHOR ================
Hello! This is an automatic report generated by Armory Auto-Transmog Vanity Outfit Manager - https://www.nexusmods.com/baldursgate3/mods/14717
The following issues have been identified for templates and/or stats that are associated with your mod (as identified by Script Extender). If this is incorrect (and the user has done their due diligence by following my instructions generated alongside this report), my bad - you can post on my mod page to let me know so I can figure out where I went wrong (I'll also happily accept any constructive feedback on this tool!)

| Mod Name: %s | Mod Version: %s |

]]):format(modName, modVersion or "Unknown")

	---@param outputString string
	---@param severeIssues boolean
	local function buildOutput(outputString, severeIssues)
		local issueHeaders = {
			["type"] = #"Type",
			["ID"] = #"ID",
			["error"] = #"Error",
			["subModId"] = #"Modified By"
		}

		local issues = {}

		for id, validationResult in TableUtils:OrderedPairs(validationResults) do
			if ((validationResult.severity == "Prevents Transmog" or validationResult.severity == "Prevents Dye") and severeIssues)
				or (validationResult.severity == "Has Built-In Workaround" and not severeIssues)
			then
				issues[id] = validationResult

				issueHeaders["ID"] = #tostring(id) > issueHeaders["ID"] and #tostring(id) or issueHeaders["ID"]
				for key, value in pairs(validationResult) do
					value = tostring(value or "N/A")
					issueHeaders[key] = issueHeaders[key] and (#value > issueHeaders[key] and #value or issueHeaders[key]) or nil
				end
			end
		end

		---@param inputString string
		---@param totalSpaces integer
		---@param alignment "center"|"left"?
		---@return string
		local function padStringWithSpaces(inputString, totalSpaces, alignment)
			inputString = tostring(inputString)
			alignment = alignment or "left"

			if alignment == "left" then
				return inputString .. string.rep(" ", totalSpaces - #inputString)
			elseif alignment == "center" then
				local halfSpaces = math.floor((totalSpaces - #inputString) / 2)
				halfSpaces = halfSpaces < 0 and 0 or halfSpaces

				local extraSpace = (totalSpaces - #inputString) % 2
				return string.rep(" ", halfSpaces) .. inputString .. string.rep(" ", halfSpaces + extraSpace)
			else
				error("Invalid alignment specified. Use 'left' or 'center'.")
			end
		end

		if next(issues) then
			outputString = outputString .. ("\n|%s|%s|%s|%s|"):format(
				padStringWithSpaces("Type", issueHeaders["type"], "center"),
				padStringWithSpaces("ID", issueHeaders["ID"], "center"),
				padStringWithSpaces("Error", issueHeaders["error"], "center"),
				padStringWithSpaces("Modified By", issueHeaders["subModId"], "center")
			)

			for id, validationResult in TableUtils:OrderedPairs(issues) do
				outputString = outputString .. ("\n|%s|%s|%s|%s|"):format(
					padStringWithSpaces(validationResult.type, issueHeaders["type"]),
					padStringWithSpaces(id, issueHeaders["ID"]),
					padStringWithSpaces(validationResult.error, issueHeaders["error"]),
					padStringWithSpaces(validationResult.subModId, issueHeaders["subModId"])
				)
			end

			output = output .. outputString .. "\n\n\n"
		end
	end

	local blockingIssueOutput = [[
================ ISSUES PREVENTING TRANSMOGGING/DYEING ================
These issues prevent the transmog/dyeing process from occurring correctly at some stage of the process, so the items are removed from the available pool.
	]]

	buildOutput(blockingIssueOutput, true)

	local workaroundIssueOutput = [[
================ ISSUES WITH BUILT-IN WORKAROUNDS ================
These issues have been accomodated in Armory's implementation, but are still generally bad practices that can lead to unintended behavior, and can't be guaranteed to operate exactly as implemented with Armory's workarounds.
	]]

	buildOutput(workaroundIssueOutput, false)

	local safeModName = modName:gsub("[^%w%s%-_]", ""):gsub("%s+", "_")
	FileUtils:SaveStringContentToFile("validationReports/" .. safeModName .. ".txt", output)

	return "%localappdata%\\Larian Studios\\Baldur's Gate 3\\Script Extender\\Armory\\validationReports\\" .. safeModName .. ".txt"
end

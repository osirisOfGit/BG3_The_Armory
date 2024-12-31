DataSearchHelper = {}

---@param input string
---@param callback function
---@param dataTable table
---@param displayNameFunc function
---@param searchMethod "ResourceId"|"DisplayName"
---@return boolean
local function BuildStatusesForData(input, callback, dataTable, displayNameFunc, searchMethod)
	local inputText = string.upper(input)
	local isWildcard = false
	if string.find(inputText, "*") then
		inputText = "^" .. string.gsub(inputText, "%*", ".*") .. "$"
		isWildcard = true
	end

	local recordCount = 0
	for _, name in pairs(dataTable) do
		local id
		if searchMethod == "ResourceId" then
			id = name
		elseif searchMethod == "DisplayName" then
			id = displayNameFunc(name)
			if not id then
				goto continue
			end
		end
		id = string.upper(id)

		if isWildcard then
			if string.find(id, inputText) then
				recordCount = recordCount + 1
				callback(name)
			end
		elseif id == inputText then
			callback(name)
			if searchMethod == "ResourceId" then
				return true
			else
				recordCount = recordCount + 1
			end
		end
		::continue::
	end

	return recordCount > 0
end

---@param parent ExtuiTabItem|ExtuiCollapsingHeader|ExtuiTreeParent
---@param dataTable table
---@param displayNameFunc function
---@param onClick function
function DataSearchHelper:BuildSearch(parent, dataTable, displayNameFunc, onClick)
	parent:AddText("Add New Row")

	local statusInput = parent:AddInputText("")
	statusInput.Hint = "Case-insensitive - use * to wildcard. Example: *ing*trap* for BURNING_TRAPWALL"
	statusInput.AutoSelectAll = true
	statusInput.EscapeClearsAll = true

	local searchId = parent:AddButton("Search by Resource ID (e.g. BURNING_TRAPWALL)")
	searchId.UserData = "ResourceId"

	local searchDisplayName = parent:AddButton("Search by Display Name (e.g. Burning)")
	searchDisplayName.UserData = "DisplayName"
	searchDisplayName:Tooltip():AddText("Depends on the resource having a Display Name set in the game resources and localization being implemented for your language")

	local errorText = parent:AddText("Error: Search returned no results")
	errorText:SetColor("Text", { 1, 0.02, 0, 1 })
	errorText.Visible = false

	local searchFunc = function(button)
		if not BuildStatusesForData(statusInput.Text, onClick, dataTable, displayNameFunc, button.UserData) then
			errorText.Visible = true
		end
	end
	searchId.OnClick = searchFunc
	searchDisplayName.OnClick = searchFunc

	statusInput.OnChange = function(inputElement, text)
		errorText.Visible = false
	end
end

---@param tooltip ExtuiTooltip
---@param status StatsObject
function DataSearchHelper:BuildStatusTooltip(tooltip, status)
	tooltip:AddText("\n")
	tooltip:AddText("Display Name: " .. Ext.Loca.GetTranslatedString(status.DisplayName, "N/A"))

	if status.Using ~= "" then
		tooltip:AddText("Using: " .. status.Using)
	end

	tooltip:AddText("StatusType: " .. status.StatusType)

	if status.TooltipDamage ~= "" then
		tooltip:AddText("Damage: " .. status.TooltipDamage)
	end

	if status.HealValue ~= "" then
		tooltip:AddText("Healing: |Value: " .. status.HealthValue .. " |Stat: " .. status.HealStat .. "|Multiplier: " .. status.HealMultiplier .. "|")
	end

	if status.TooltipSave ~= "" then
		tooltip:AddText("Save: " .. status.TooltipSave)
	end

	if status.TickType ~= "" then
		tooltip:AddText("TickType: " .. status.TickType)
	end

	local description = Ext.Loca.GetTranslatedString(status.Description, "N/A")
	-- Getting rid of all content contained in <>, like <LsTags../> and <br/>
	description = string.gsub(description, "<.->", "")
	local desc = tooltip:AddText("Description: " .. description)
	desc.TextWrapPos = 600

	if status.DescriptionParams ~= "" then
		tooltip:AddText("Description Params: " .. status.DescriptionParams)
	end

	if status.Boosts ~= "" then
		tooltip:AddText("Boosts: " .. status.Boosts).TextWrapPos = 600
	end
end

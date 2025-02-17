Ext.Require("Client/_FormBuilder.lua")

VanityPresetManager = {}
VanityPresetManager.userName = ""

Ext.RegisterNetListener(ModuleUUID .. "UserName", function(channel, payload, userID)
	VanityPresetManager.username = payload
end)

---@type ExtuiWindow
local presetWindow

---@type ExtuiChildWindow
local userPresetSection

---@type ExtuiChildWindow
local modPresetSection

---@type ExtuiTableCell
local presetInfoSection

---@type ExtuiGroup?
local presetActivelyViewing

---@param parent ExtuiTreeParent
---@param forPresetId string?
local function buildPresetForm(parent, forPresetId)
	---@type VanityPreset?
	local preset
	if forPresetId then
		preset = ConfigurationStructure.config.vanity.presets[forPresetId]
	end

	FormBuilder:CreateForm(parent, function(values)
			local presetID = forPresetId or FormBuilder:generateGUID()

			values.Outfits = preset and ConfigurationStructure:GetRealConfigCopy().vanity.presets[forPresetId].Outfits or {}

			if ConfigurationStructure.config.vanity.presets[presetID] then
				ConfigurationStructure.config.vanity.presets[presetID].delete = true
			end

			ConfigurationStructure.config.vanity.presets[presetID] = values

			parent.Visible = false
			VanityPresetManager:UpdatePresetView(presetID)
		end,
		{
			{
				label = "Author",
				defaultValue = preset and preset.Author or VanityPresetManager.username,
				type = "Text",
				errorMessageIfEmpty = "This is a required field",
			},
			{
				label = "Name",
				defaultValue = preset and preset.Name or nil,
				type = "Text",
				errorMessageIfEmpty = "This is a required field",
			},
			{
				label = "Version",
				defaultValue = preset and preset.Version or "1.0.0",
				type = "Text",
				errorMessageIfEmpty = "This is a required field",
			},
			{
				label = "NSFW",
				defaultValue = preset and preset.NSFW or true,
				type = "Checkbox",
			}
		}
	)
end

function VanityPresetManager:OpenManager()
	if presetWindow then
		presetWindow.Open = true
		presetWindow:SetFocus()
		VanityPresetManager:UpdatePresetView()
	elseif not presetWindow then
		Ext.Net.PostMessageToServer(ModuleUUID .. "UserName", "")
		presetWindow = Ext.IMGUI.NewWindow("Vanity Preset Manager")
		presetWindow.Closeable = true

		local createNewPresetButton = presetWindow:AddButton("Create a New Preset")
		local presetForm = presetWindow:AddGroup("NewPresetForm")
		presetForm.Visible = false

		createNewPresetButton.OnClick = function()
			buildPresetForm(presetForm)
			presetForm.Visible = not presetForm.Visible
		end

		local presetTable = presetWindow:AddTable("PresetTable", 2)
		presetTable.NoSavedSettings = true

		presetTable:AddColumn("PresetSelection", "WidthFixed")
		presetTable:AddColumn("PresetInfo", "WidthStretch")

		local row = presetTable:AddRow()

		local selectionCell = row:AddCell()

		local userPresetHeader = selectionCell:AddCollapsingHeader("Your Presets")
		userPresetSection = userPresetHeader:AddChildWindow("UserPresets")
		userPresetSection.NoSavedSettings = true

		local modPresetHeader = selectionCell:AddCollapsingHeader("Mod-Provided Presets")
		modPresetSection = modPresetHeader:AddChildWindow("ModPresets")
		modPresetSection.NoSavedSettings = true

		presetInfoSection = row:AddCell()

		VanityPresetManager:UpdatePresetView()
	end
end

---@param preset VanityPreset
---@param parent ExtuiTreeParent
local function buildDependencyTable(preset, parent)
	local cachedDeps = {
		dye = {},
		equipment = {}
	}

	for _, outfitSlot in pairs(preset.Outfits) do
		for _, vanityOutfit in pairs(outfitSlot) do
			if vanityOutfit.dye and vanityOutfit.dye.modDependency then
				if not cachedDeps[vanityOutfit.dye.modDependency.Guid] then
					table.insert(cachedDeps.dye, vanityOutfit.dye.modDependency)
					cachedDeps[vanityOutfit.dye.modDependency.Guid] = true
				end
			end
			if vanityOutfit.equipment and vanityOutfit.equipment.modDependency then
				if not cachedDeps[vanityOutfit.equipment.modDependency.Guid] then
					table.insert(cachedDeps.equipment, vanityOutfit.equipment.modDependency)
					cachedDeps[vanityOutfit.equipment.modDependency.Guid] = true
				end
			end
			if vanityOutfit.weaponTypes then
				for _, weaponSlot in pairs(vanityOutfit.weaponTypes) do
					if weaponSlot.equipment.modDependency and not cachedDeps[weaponSlot.equipment.modDependency.Guid] then
						table.insert(cachedDeps.equipment, weaponSlot.equipment.modDependency)
						cachedDeps[weaponSlot.equipment.modDependency.Guid] = true
					end
				end
			end
		end
	end

	---@param a ModDependency
	---@param b ModDependency
	table.sort(cachedDeps.dye, function(a, b)
		return a.Guid < b.Guid
	end)

	---@param a ModDependency
	---@param b ModDependency
	table.sort(cachedDeps.equipment, function(a, b)
		return a.Guid < b.Guid
	end)

	---@param key string
	---@param modlist ModDependency[]
	local function buildDepTab(key, modlist)
		parent:AddSeparatorText(key .. " Dependencies"):SetStyle("SeparatorTextAlign", 0.1)

		local dependencyTable = parent:AddTable(key .. preset.Name .. preset.Author, 4)
		dependencyTable.PreciseWidths = true
		dependencyTable.SizingStretchProp = true

		local headerRow = dependencyTable:AddRow()
		headerRow.Headers = true
		headerRow:AddCell():AddText("Name")
		headerRow:AddCell():AddText("Author")
		headerRow:AddCell():AddText("Version")

		for _, modDependency in ipairs(modlist) do
			local mod = Ext.Mod.GetMod(modDependency.Guid)

			if mod and mod.Info.Author ~= '' then
				local modRow = dependencyTable:AddRow()

				local nameText = modRow:AddCell():AddText(mod and mod.Info.Name or "Unknown - Mod Not Loaded")
				nameText.TextWrapPos = 0
				local authorText = modRow:AddCell():AddText(mod and (mod.Info.Author ~= '' and mod.Info.Author or "Larian") or "Unknown")
				authorText.TextWrapPos = 0

				if not mod then
					nameText:SetColor("Text", { 1, 0.02, 0, 1 })
					authorText:SetColor("Text", { 1, 0.02, 0, 1 })
				end

				modRow:AddCell():AddText(table.concat(modDependency.Version, "."))
			end
		end
	end

	buildDepTab("Dye", cachedDeps.dye)
	parent:AddNewLine()
	buildDepTab("Equipment", cachedDeps.equipment)
end

function VanityPresetManager:UpdatePresetView(presetID)
	for _, child in pairs(userPresetSection.Children) do
		child:Destroy()
	end

	if presetActivelyViewing then
		presetActivelyViewing:Destroy()
		presetActivelyViewing = nil
	end

	local activePreset = Ext.Vars.GetModVariables(ModuleUUID).ActivePreset
	for guid, preset in pairs(ConfigurationStructure.config.vanity.presets) do
		if preset.SFW then
			preset.NSFW = preset.SFW
			preset.SFW = nil
		end

		local presetButton = userPresetSection:AddButton(preset.Name)
		presetButton.OnClick = function()
			if presetActivelyViewing then
				presetActivelyViewing:Destroy()
			end

			local presetGroup = presetInfoSection:AddGroup(guid)
			presetActivelyViewing = presetGroup

			if activePreset ~= guid then
				presetGroup:AddButton("Activate (Save After)").OnClick = function()
					Vanity:ActivatePreset(guid)
					VanityPresetManager:UpdatePresetView(guid)
					presetWindow.Open = false
				end
			else
				presetGroup:AddButton("Deactivate (Save After)").OnClick = function()
					Vanity:ActivatePreset()
					VanityPresetManager:UpdatePresetView(guid)
				end
			end

			presetGroup:AddButton("Delete").OnClick = function()
				ConfigurationStructure.config.vanity.presets[guid].delete = true
				VanityPresetManager:UpdatePresetView()
				if activePreset == guid then
					Vanity:ActivatePreset()
				end
			end

			local editButton = presetGroup:AddButton("Edit")

			local infoGroup = presetGroup:AddGroup("info")
			infoGroup:AddText("Name: " .. preset.Name)
			infoGroup:AddText("Author: " .. preset.Author)
			infoGroup:AddText("Version: " .. preset.Version)
			infoGroup:AddText("Contains Skimpy Outfits/Nudity? " .. (preset.NSFW and "Yes" or "No"))

			editButton.OnClick = function()
				if editButton.UserData then
					VanityPresetManager:UpdatePresetView(guid)
				else
					editButton.UserData = true
					buildPresetForm(infoGroup, guid)
				end
			end

			presetGroup:AddSeparatorText("Mod Dependencies")
			buildDependencyTable(preset, presetGroup)

			presetGroup:AddNewLine()
			presetGroup:AddSeparatorText("Configured Outfits")
			-- Need to pass the proxy value so it can get deleted properly
			VanityCharacterCriteria:BuildConfiguredCriteriaCombinationsTable(ConfigurationStructure.config.vanity.presets[guid], presetGroup)
		end

		if presetID == guid then
			presetButton.OnClick()
		end
	end
end

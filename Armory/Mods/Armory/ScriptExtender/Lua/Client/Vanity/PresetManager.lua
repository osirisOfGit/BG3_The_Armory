VanityPresetManager = {}

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

function VanityPresetManager:OpenManager()
	if presetWindow then
		presetWindow.Open = true
		presetWindow:SetFocus()
		VanityPresetManager:UpdatePresetView()
	elseif not presetWindow then
		presetWindow = Ext.IMGUI.NewWindow("Vanity Preset Manager")
		presetWindow.Closeable = true

		--#region Create New Preset
		local createNewPresetButton = presetWindow:AddButton("Create a New Preset")
		local presetForm = presetWindow:AddGroup("NewPresetForm")
		presetForm.Visible = false

		local function generateFormInput(fieldId, defaultValue)
			presetForm:AddText(fieldId)
			local input = presetForm:AddInputText("", defaultValue)

			local authorError = presetForm:AddText("This is a required field and must be provided")
			authorError:SetColor("Text", { 1, 0.02, 0, 1 })
			authorError.Visible = false

			input.OnChange = function()
				authorError.Visible = false
			end

			return input, authorError
		end

		local authorInput, authorError = generateFormInput("Author", Vanity.username)
		local nameInput, nameError = generateFormInput("Name")
		local versionInput, versionError = generateFormInput("Version")

		presetForm:AddText("Does/Will this contain outfits that have skimpy/nude clothing?")
		local sfwCheckbox = presetForm:AddCheckbox("", true)

		local inputErrorTable = {
			[authorInput] = authorError,
			[nameInput] = nameError,
			[versionInput] = versionError
		}

		local function generateGUID()
			local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
			local guid = string.gsub(template, '[xy]', function(c)
				local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
				return string.format('%x', v)
			end)
			return guid
		end

		local newPresetSubmit = presetForm:AddButton("Submit")
		newPresetSubmit.OnClick = function()
			local hasErrors = false
			for input, errorText in pairs(inputErrorTable) do
				-- If it's empty
				if input.Text:match("^%s*$") then
					errorText.Visible = true
					hasErrors = true
				end
			end
			if hasErrors then
				return
			end

			local presetID = generateGUID()
			ConfigurationStructure.config.vanity.presets[presetID] = {
				Author = authorInput.Text,
				Name = nameInput.Text,
				Version = versionInput.Text,
				NSFW = sfwCheckbox.Checked,
				ModDependencies = {},
				Outfits = {}
			}

			presetForm.Visible = false
			VanityPresetManager:UpdatePresetView(presetID)
		end

		createNewPresetButton.OnClick = function()
			presetForm.Visible = not presetForm.Visible
		end
		--#endregion

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
			end

			presetGroup:AddButton("Delete").OnClick = function()
				ConfigurationStructure.config.vanity.presets[guid].delete = true
				VanityPresetManager:UpdatePresetView()
				if activePreset == guid then
					Vanity:ActivatePreset()
				end
			end

			presetGroup:AddText("Name: " .. preset.Name)
			presetGroup:AddText("Author: " .. preset.Author)
			presetGroup:AddText("Version: " .. preset.Version)
			presetGroup:AddText("Contains Skimpy Outfits/Nudity? " .. (preset.NSFW and "Yes" or "No"))

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

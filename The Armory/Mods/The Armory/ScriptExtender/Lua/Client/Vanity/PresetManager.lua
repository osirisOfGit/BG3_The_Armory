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
		presetForm:AddText("Notes")
		local notesInput = presetForm:AddInputText("")
		local versionInput, versionError = generateFormInput("Version")

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

			ConfigurationStructure.config.vanity.presets[generateGUID()] = {
				Author = authorInput.Text,
				Name = nameInput.Text,
				Notes = notesInput.Text,
				Version = versionInput.Text,
				ModDependencies = {},
				Outfits = {}
			}

			presetForm.Visible = false
		end

		createNewPresetButton.OnClick = function()
			presetForm.Visible = not presetForm.Visible
		end
		--#endregion

		local presetTable = presetWindow:AddTable("PresetTable", 2)
		presetTable.NoSavedSettings = true

		presetTable:AddColumn("PresetSelection", "WidthFixed")
		presetTable:AddColumn("PresetInfo", "WidthFixed")

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

function VanityPresetManager:UpdatePresetView()
	for _, child in pairs(userPresetSection.Children) do
		child:Destroy()
	end

	if presetActivelyViewing then
		presetActivelyViewing:Destroy()
		presetActivelyViewing = nil
	end

	for guid, preset in pairs(ConfigurationStructure.config.vanity.presets) do
		userPresetSection:AddButton(preset.Name).OnClick = function()
			if presetActivelyViewing then
				presetActivelyViewing:Destroy()
			end

			local presetGroup = presetInfoSection:AddGroup(guid)
			presetActivelyViewing = presetGroup
			
			presetGroup:AddButton("Activate This Preset").OnClick = function ()
				Vanity:ActivatePreset(preset)
			end
			presetGroup:AddButton("Delete This Preset").OnClick = function ()
				ConfigurationStructure.config.vanity.presets[guid].delete = true
				VanityPresetManager:UpdatePresetView()
			end

			presetGroup:AddText("Name: " .. preset.Name)
			presetGroup:AddText("Author: " .. preset.Author)
			presetGroup:AddText("Version: " .. preset.Version)
			presetGroup:AddText("Notes: " .. preset.Notes).TextWrapPos = 0
		end
	end
end

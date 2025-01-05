VanityPresetPicker = {}

function VanityPresetPicker:OpenPicker()
	local presetWindow = Ext.IMGUI.NewWindow("Vanity Preset Manager")
	presetWindow.Closeable = true

	--#region Create New Preset
	local createNewPresetButton = presetWindow:AddButton("Create a New Preset")
	local presetForm = presetWindow:AddGroup("NewPresetForm")
	presetForm.Visible = false

	local function generateFormInput(fieldId, defaultValue)
		presetForm:AddText(fieldId)
		local input = presetForm:AddInputText("", defaultValue)
		input.CharsNoBlank = true
		-- input.SameLine = true

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
	local notesInput, notesError = generateFormInput("Notes")
	notesInput.Multiline = true
	local versionInput, versionError = generateFormInput("Version")

	local inputErrorTable = {
		[authorInput] = authorError,
		[nameInput] = nameError,
		[notesInput] = notesError,
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
			if input.Text == "" then
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

	createNewPresetButton.OnClick = function ()
		presetForm.Visible = not presetForm.Visible
	end
	--#endregion

	local presetTable = presetWindow:AddTable("PresetTable", 2)
	presetTable.NoSavedSettings = true

	presetTable:AddColumn("PresetSelection", "WidthFixed")
	presetTable:AddColumn("PresetInfo", "WidthFixed")

	local row = presetTable:AddRow()

	local selectionCell = row:AddCell()

	local userPresets = selectionCell:AddChildWindow("UserPresets")
	userPresets.NoSavedSettings = true
	userPresets:AddSeparatorText("Your Presets")
	userPresets:AddButton("Test 1")

	local modPresets = selectionCell:AddChildWindow("ModPresets")
	modPresets.NoSavedSettings = true
	modPresets:AddSeparatorText("Mod-Added Presets")

	local infoCell = row:AddCell()
	local function buildInfoCell()

	end
end

Ext.Require("Client/Vanity/PresetManager.lua")
Ext.Require("Client/Vanity/CharacterCriteria.lua")

Vanity = {}

---@type VanityPreset?
Vanity.activePreset = nil
Vanity.userName = ""

Ext.RegisterNetListener(ModuleUUID .. "UserName", function(channel, payload, userID)
	Vanity.username = payload
end)

-- dirty hack to avoid warnings, fix later
pcall(function() Ext.Net.PostMessageToServer(ModuleUUID .. "UserName", "") end)

---@type ExtuiTreeParent
local mainParent

---@type ExtuiSeparatorText
local separator

Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Vanity",
	--- @param tabHeader ExtuiTreeParent
	function(tabHeader)
		mainParent = tabHeader
		--EventChannels.MCM_WINDOW_CLOSED = "MCM_Window_Closed"

		--#region Settings
		local settingsButton = tabHeader:AddButton("Settings")
		local settingsPopup = tabHeader:AddPopup("Settings")

		settingsButton.OnClick = function()
			settingsPopup:Open()
		end

		---@type ExtuiMenu
		local previewMenu = settingsPopup:AddMenu("Previewing")
		previewMenu:AddCheckbox("Apply Dyes When Previewing Equipment", true)
		--#endregion

		--#region Presets
		local presetPickerButton = tabHeader:AddButton("Preset Manager")
		presetPickerButton.OnClick = function()
			VanityPresetManager:OpenManager()
		end
		--#endregion

		separator = tabHeader:AddSeparatorText("Choose A Preset")
		separator:SetStyle("SeparatorTextAlign", 0.5)
	end)

---comment
---@param preset VanityPreset
function Vanity:ActivatePreset(preset)
	Vanity.activePreset = preset
	separator.Label = "Active Preset: " .. preset.Name

	VanityCharacterCriteria:BuildModule(mainParent, preset)
end

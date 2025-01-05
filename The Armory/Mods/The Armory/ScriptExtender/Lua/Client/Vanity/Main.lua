Ext.Require("Client/Vanity/PresetPicker.lua")
Ext.Require("Client/Vanity/CharacterCriteria.lua")
Ext.Require("Client/Vanity/CharacterPanel/CharacterPanel.lua")

Vanity = {}

---@type VanityPreset?
Vanity.activePreset = nil
Vanity.userName = ""

Ext.RegisterNetListener(ModuleUUID .. "UserName", function(channel, payload, userID)
	Vanity.username = payload
end)

Ext.Net.PostMessageToServer(ModuleUUID .. "UserName", "")

Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Vanity",
	--- @param tabHeader ExtuiTreeParent
	function(tabHeader)
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

		tabHeader.TextWrapPos = 0

		--#region Presets
		
		local presetPickerButton = tabHeader:AddButton("Select a Preset")
		presetPickerButton.OnClick = function ()
			VanityPresetPicker:OpenPicker()
		end
		--#endregion

		VanityCharacterCriteria:BuildModule(tabHeader)

		VanityCharacterPanel:BuildModule(tabHeader)
	end)

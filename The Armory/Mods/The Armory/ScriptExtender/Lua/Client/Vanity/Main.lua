Ext.Vars.RegisterModVariable(ModuleUUID, "ActivePreset", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true
})

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

		local activePresetUUID = Ext.Vars.GetModVariables(ModuleUUID).ActivePreset
		if activePresetUUID and ConfigurationStructure.config.vanity.presets[activePresetUUID] then
			Vanity:ActivatePreset(activePresetUUID)
		end
	end)

---comment
---@param presetId Guid
function Vanity:ActivatePreset(presetId)
	Ext.Vars.GetModVariables(ModuleUUID).ActivePreset = presetId

	Ext.Vars.SyncModVariables(ModuleUUID)

	Ext.Timer.WaitFor(100, function ()
		Ext.ClientNet.PostMessageToServer(ModuleUUID .. "_PresetUpdated", presetId)
	end)

	local preset = ConfigurationStructure.config.vanity.presets[presetId] 
	separator.Label = "Active Preset: " .. preset.Name

	VanityCharacterCriteria:BuildModule(mainParent, preset)
end

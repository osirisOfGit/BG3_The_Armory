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

---@param presetId Guid
---@param initializing boolean?
function Vanity:ActivatePreset(presetId, initializing)
	Ext.Vars.GetModVariables(ModuleUUID).ActivePreset = presetId

	Ext.Vars.SyncModVariables(ModuleUUID)

	if not initializing then
		Ext.Timer.WaitFor(100, function()
			Ext.ClientNet.PostMessageToServer(ModuleUUID .. "_PresetUpdated", presetId)
		end)
	end

	local preset = ConfigurationStructure.config.vanity.presets[presetId]
	separator.Label = "Active Preset: " .. preset.Name

	VanityCharacterCriteria:BuildModule(mainParent, preset)
end

-- Mod variables load in after the InsertModMenuTab function runs
Ext.Events.GameStateChanged:Subscribe(
---@param e EclLuaGameStateChangedEvent
	function(e)
		if tostring(e.ToState) == "Running" then
			local activePresetUUID = Ext.Vars.GetModVariables(ModuleUUID).ActivePreset
			if activePresetUUID and ConfigurationStructure.config.vanity.presets[activePresetUUID] then
				Vanity:ActivatePreset(activePresetUUID, true)
			end
		end
	end)

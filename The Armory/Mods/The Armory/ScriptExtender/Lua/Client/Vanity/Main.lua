Ext.Vars.RegisterModVariable(ModuleUUID, "ActivePreset", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true
})

Ext.Vars.RegisterUserVariable("TheArmory_Vanity_ActiveOutfit", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true,
	SyncOnWrite = true
})

Ext.Require("Client/Vanity/PresetManager.lua")
Ext.Require("Client/Vanity/CharacterCriteria.lua")

Vanity = {}
Vanity.userName = ""

Ext.RegisterNetListener(ModuleUUID .. "UserName", function(channel, payload, userID)
	Vanity.username = payload
end)

---@type ExtuiTreeParent
local mainParent

---@type ExtuiSeparatorText
local separator

Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Vanity",
	--- @param tabHeader ExtuiTreeParent
	function(tabHeader)
		mainParent = tabHeader
		--EventChannels.MCM_WINDOW_CLOSED = "MCM_Window_Closed"

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

local hasBeenActivated = false

Ext.ModEvents.BG3MCM["MCM_Mod_Tab_Activated"]:Subscribe(function(payload)
	if not hasBeenActivated then
		-- Mod variables load in after the InsertModMenuTab function runs
		if ModuleUUID == payload.modUUID then
			hasBeenActivated = true
			local activePresetUUID = Ext.Vars.GetModVariables(ModuleUUID).ActivePreset
			if activePresetUUID and ConfigurationStructure.config.vanity.presets[activePresetUUID] then
				Vanity:ActivatePreset(activePresetUUID, true)
			end

			Ext.Net.PostMessageToServer(ModuleUUID .. "UserName", "")
		end
	end
end)

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

---@type ExtuiTreeParent
local mainParent

---@type ExtuiSeparatorText
local separator

Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Vanity",
	--- @param tabHeader ExtuiTreeParent
	function(tabHeader)
		mainParent = tabHeader

		local helpTooltip = tabHeader:AddButton("Instructions"):Tooltip()
		helpTooltip:AddText("\t  Begin by creating a preset with the Preset Manager - you can have any amount of presets, but they must be activated to be applied (each preset manages the entire party - only one preset can be active per save). Once a preset is activated, it will only be active for that save (so save after activating it).").TextWrapPos = 800
		helpTooltip:AddText("The preset will only be active in saves that were created while it was active - if you load a save before you activated the preset, it must be activated for that specific save").TextWrapPos = 0
		helpTooltip:AddText("It's recommended you save and reload after finalizing your outfit, as parts of the Transmog process (e.g. Armory type), don't update the tooltips until a reload.").TextWrapPos = 0
		helpTooltip:AddText("\nAfter creating a preset, you can start defining outfits using the options below. You can select combination of criteria (one item from each column, though Hireling and Origin are mutually exclusive, and you don't have to use all columns) - each combination will create a unique outfit").TextWrapPos = 0
		helpTooltip:AddText("Party members are automatically matched to the _most specific_ outfit defined - the columns in the criteria table are ordered from most specific to least specific.").TextWrapPos = 0
		helpTooltip:AddText("For example, an outfit that only has Origin assigned to it will take precedence over an outfit that has Race/Subrace/BodyType, but Race/BodyType will take precedence over BodyType/Class/Subclass").TextWrapPos = 0
		helpTooltip:AddText("This matters less during this stage of the beta - future updates will allow you to export Presets to other users in the same session, or to a file that you can include with a mod that players will be able to import, in which case you may want to define more generic outfits to account for respecs/resculpts").TextWrapPos = 0
		helpTooltip:AddText("When an outfit is matched to a character, all equipped items will be automatically transmogged and/or dyed according to the outfit (if a non-weapon slot is empty and a vanity item is defined, a junk item will spawn in that slot to allow the vanity item to show)").TextWrapPos = 0
		helpTooltip:AddText("When an item is unequipped, it will be unmogged/undyed _unless_ it's not contained within an inventory (e.g. throwing or dropping). This is intentional while I figure out what the preferred behavior is").TextWrapPos = 0

		--#region Settings
		local generalSettings = ConfigurationStructure.config.vanity.settings.general
		local menu = tabHeader:AddButton("Settings")
		menu.UserData = "keep"
		local menuPopup = tabHeader:AddPopup("PanelSettings")
		menuPopup.UserData = "keep"
		menu.OnClick = function() return menuPopup:Open() end

		---@type ExtuiSelectable
		local contextMenuSetting = menuPopup:AddSelectable("Show Slot Context Menu only when holding Left Shift", "DontClosePopups")
		contextMenuSetting.Selected = generalSettings.showSlotContextMenuModifier ~= nil
		contextMenuSetting:Tooltip():AddText("If enabled the context menu that appears when clicking on a given slot/dye icon below will only show up if 'Left Shift' is being held down while clicking it").TextWrapPos = 600
		contextMenuSetting.OnClick = function()
			generalSettings.showSlotContextMenuModifier = contextMenuSetting.Selected and "LSHIFT" or nil
			SlotContextMenu:SubscribeToKeyEvents()
		end
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

---@param presetId Guid?
---@param initializing boolean?
function Vanity:ActivatePreset(presetId, initializing)
	Ext.Vars.GetModVariables(ModuleUUID).ActivePreset = presetId

	Ext.Vars.SyncModVariables(ModuleUUID)

	if not initializing then
		Vanity:UpdatePresetOnServer()
	end

	if presetId then
		local preset = ConfigurationStructure.config.vanity.presets[presetId]
		separator.Label = "Active Preset: " .. preset.Name
		VanityCharacterCriteria:BuildModule(mainParent, preset)
	else
		separator.Label = "Choose a Preset"
		VanityCharacterCriteria:BuildModule(mainParent)
	end
end

function Vanity:UpdatePresetOnServer()
	Ext.Timer.WaitFor(350, function()
		Ext.ClientNet.PostMessageToServer(ModuleUUID .. "_PresetUpdated", "")
	end)
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
		end
	end
end)

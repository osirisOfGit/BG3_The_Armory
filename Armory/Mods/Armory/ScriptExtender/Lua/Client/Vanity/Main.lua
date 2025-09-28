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

Ext.Require("Client/Vanity/PresetManagement/PresetManager.lua")
Ext.Require("Client/Vanity/CharacterCriteria.lua")
Ext.Require("Client/Vanity/ItemValidator.lua")

Vanity = {}

Vanity.ActivePresetId = nil

---@type ExtuiTreeParent
local mainParent

---@type ExtuiSeparatorText
local separator

Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Vanity",
	--- @param tabHeader ExtuiTreeParent
	function(tabHeader)
		mainParent = tabHeader

		local helpTooltip = tabHeader:AddButton("Instructions"):Tooltip()
		helpTooltip:AddText("\t  " .. Translator:translate("Begin by creating a preset with the Preset Manager - you can have any amount of presets, but they must be activated to be applied (each preset manages the entire party - only one preset can be active per save). Once a preset is activated, it will only be active for that save (so save after activating it).")).TextWrapPos = 800
		helpTooltip:AddText(Translator:translate("The preset will only be active in saves that were created while it was active - if you load a save before you activated the preset, it must be activated for that specific save")).TextWrapPos = 0
		helpTooltip:AddText(Translator:translate("It's recommended you save and reload after finalizing your outfit, as parts of the Transmog process don't fully complete until a reload (e.g. Armor type)")).TextWrapPos = 0
		helpTooltip:AddText("\n" .. Translator:translate("After creating a preset, you can start defining outfits using the options below. You can select combination of criteria (one item from each column, though Hireling and Origin are mutually exclusive, and you don't have to use all columns) - each combination will create a unique outfit")).TextWrapPos = 0
		helpTooltip:AddText(Translator:translate("Party members are automatically matched to the _most specific_ outfit defined - the columns in the criteria table are ordered from most specific to least specific.")).TextWrapPos = 0
		helpTooltip:AddText(Translator:translate("For example, an outfit that only has Origin assigned to it will take precedence over an outfit that has Race/Subrace/BodyType, but Race/BodyType will take precedence over BodyType/Class/Subclass")).TextWrapPos = 0
		helpTooltip:AddText(Translator:translate("This allows you to create Presets that support a wide variety of party compositions while still adhering to a consistent theme, which can be exported via the Preset Manager for users to manual import or to package with mods (which will be automatically read in by Armory when present in the load order)")).TextWrapPos = 0
		helpTooltip:AddText(Translator:translate("When an outfit is matched to a character, all equipped items will be automatically transmogged and/or dyed according to the outfit (if a non-weapon slot is empty and a vanity item is defined, a junk item will spawn in that slot to allow the vanity item to show)")).TextWrapPos = 0
		helpTooltip:AddText(Translator:translate("When an item is unequipped, it will be unmogged/undyed _unless_ it's not contained within an inventory (e.g. throwing or dropping). This is intentional while I figure out what the preferred behavior is")).TextWrapPos = 0

		--#region Presets
		local presetPickerButton = tabHeader:AddButton(Translator:translate("Preset Manager"))
		presetPickerButton.SameLine = true
		presetPickerButton.OnClick = function()
			PresetManager:OpenManager()
		end
		--#endregion

		local itemValidatorButton = tabHeader:AddButton(Translator:translate("Item Validation Report"))
		itemValidatorButton.SameLine = true
		itemValidatorButton.OnClick = function()
			ItemValidator:OpenReport()
		end

		--#region Settings
		local generalSettings = ConfigurationStructure.config.vanity.settings.general
		local menu = tabHeader:AddButton(Translator:translate("Settings"))
		menu.SameLine = true
		menu.UserData = "keep"
		local menuPopup = tabHeader:AddPopup("PanelSettings")
		menuPopup.UserData = "keep"
		menu.OnClick = function() return menuPopup:Open() end

		---@type ExtuiSelectable
		local contextMenuSetting = menuPopup:AddSelectable(Translator:translate("Show Slot Context Menu on Right Click"), "DontClosePopups")
		contextMenuSetting.Selected = generalSettings.showSlotContextMenuOnRightClick
		contextMenuSetting:Tooltip():AddText("\t " .. Translator:translate("If enabled the context menu that appears when clicking on a given slot/dye icon below will only show up if it's right clicked - otherwise, it will show on left click (and it will launch directly to the picker on right click)")).TextWrapPos = 600
		contextMenuSetting.OnClick = function()
			generalSettings.showSlotContextMenuOnRightClick = contextMenuSetting.Selected

			if Vanity.ActivePresetId then
				Vanity:ActivatePreset(Vanity.ActivePresetId)
			end
		end

		menuPopup:AddSeparator()

		---@type ExtuiSelectable
		local placeholderItemSetting = menuPopup:AddSelectable(Translator:translate("Generate Junk Items in Empty Slots For Transmog"))
		placeholderItemSetting.Selected = generalSettings.fillEmptySlots
		placeholderItemSetting:Tooltip():AddText(
			"\t " ..
			Translator:translate(
				"When enabled, if an item slot is configured for Transmogging but is currently empty, Armory will spawn a junk item to put in the slot so the transmog can occur."))
		placeholderItemSetting.OnClick = function()
			generalSettings.fillEmptySlots = placeholderItemSetting.Selected

			Vanity:UpdatePresetOnServer()
		end

		menuPopup:AddSeparator()
		---@type ExtuiSelectable
		local removeBladesongStatusOnLevelLoad = menuPopup:AddSelectable(Translator:translate("Remove Bladesong Impediment statuses on reload"))
		removeBladesongStatusOnLevelLoad.Selected = generalSettings.removeBladesongStatusOnReload
		removeBladesongStatusOnLevelLoad.OnClick = function()
			generalSettings.removeBladesongStatusOnReload = removeBladesongStatusOnLevelLoad.Selected

			Vanity:UpdatePresetOnServer()
		end
		--#endregion

		separator = tabHeader:AddSeparatorText(Translator:translate("Choose A Preset"))
		separator:SetStyle("SeparatorTextAlign", 0.5)

		Vanity:initialize()
	end)

---@param presetId Guid?
function Vanity:ActivatePreset(presetId)
	self.ActivePresetId = presetId

	if presetId then
		local preset = PresetProxy.presets[presetId]
		if type(preset) == "function" then
			preset(function(preset)
				separator.Label = Translator:translate("Active Preset:") .. " " .. preset.Name
				VanityCharacterCriteria:BuildModule(mainParent, preset)
				Vanity:UpdatePresetOnServer()
			end)
		elseif preset then
			separator.Label = Translator:translate("Active Preset:") .. " " .. preset.Name
			VanityCharacterCriteria:BuildModule(mainParent, preset)
			Vanity:UpdatePresetOnServer()
		else
			self.ActivePresetId = nil
			separator.Label = Translator:translate("Choose a Preset")
			VanityCharacterCriteria:BuildModule(mainParent)
			Vanity:UpdatePresetOnServer()
		end
	else
		separator.Label = Translator:translate("Choose a Preset")
		VanityCharacterCriteria:BuildModule(mainParent)
		Vanity:UpdatePresetOnServer()
	end
end

local updatePresetOnServerTimer

function Vanity:UpdatePresetOnServer()
	if updatePresetOnServerTimer then
		Ext.Timer.Cancel(updatePresetOnServerTimer)
	end

	updatePresetOnServerTimer = Ext.Timer.WaitFor(350, function()
		updatePresetOnServerTimer = nil

		---@type Vanity?
		local vanityPreset = {}
		if self.ActivePresetId then
			vanityPreset = VanityExportManager:ExportPresets({ self.ActivePresetId })
			if not vanityPreset then
				Logger:BasicDebug("Preset %s was not found - deactivating", self.ActivePresetId or "N/A")
				self.ActivePresetId = nil
				vanityPreset = {}
			end
		end

		vanityPreset.settings = {
			general = {
				fillEmptySlots = ConfigurationStructure.config.vanity.settings.general.fillEmptySlots,
				removeBladesongStatusOnReload = ConfigurationStructure.config.vanity.settings.general.removeBladesongStatusOnReload
			}
		}
		Channels.UpdateUserPreset:SendToServer({
			presetId = self.ActivePresetId,
			---@diagnostic disable-next-line: missing-fields
			vanityPreset = vanityPreset,
		})

		VanityBackupManager:BackupPresets({ self.ActivePresetId })
	end)
end

local hasInitialized = false
function Vanity:initialize()
	if hasInitialized then
		return
	end
	hasInitialized = true
	VanityModPresetManager:ImportPresetsFromMods()

	Logger:BasicDebug("User has started running game - running check")

	Channels.GetActiveUserPreset:RequestToServer({}, function(data)
		Vanity.ActivePresetId = data and data.presetId

		if Vanity.ActivePresetId then
			local function validatePreset()
				local preset = PresetProxy.presets[Vanity.ActivePresetId]

				if type(preset) == "function" then
					preset(function(preset)
						VanityModDependencyManager:DependencyValidator(PresetProxy, preset, function()
							local validationErrorWindow = Ext.IMGUI.NewWindow(string.format(Translator:translate("Armory: Validation of Active Vanity Preset [%s] failed!"),
								preset.Name))
							validationErrorWindow.Closeable = true

							validationErrorWindow:AddButton("Open Preset").OnClick = function()
								separator.Label = Translator:translate("Active Preset:") .. " " .. preset.Name
								VanityCharacterCriteria:BuildModule(mainParent, preset)

								Mods.BG3MCM.IMGUIAPI:OpenModPage("Vanity", ModuleUUID)
							end

							return validationErrorWindow
						end)
					end)
				else
					VanityModDependencyManager:DependencyValidator(PresetProxy, preset, function()
						local validationErrorWindow = Ext.IMGUI.NewWindow(string.format(Translator:translate("Armory: Validation of Active Vanity Preset [%s] failed!"),
							preset.Name))
						validationErrorWindow.Closeable = true

						validationErrorWindow:AddButton("Open Preset").OnClick = function()
							separator.Label = Translator:translate("Active Preset:") .. " " .. preset.Name
							VanityCharacterCriteria:BuildModule(mainParent, preset)

							Mods.BG3MCM.IMGUIAPI:OpenModPage("Vanity", ModuleUUID)
						end

						return validationErrorWindow
					end)
				end
			end

			if (not PresetProxy.presets[Vanity.ActivePresetId] or type(PresetProxy.presets[Vanity.ActivePresetId]) == "function")
				and VanityBackupManager:IsPresetInBackup(Vanity.ActivePresetId)
			then
				Logger:BasicDebug("Active preset not found in the config, but is in backup - launching restore prompt")

				local presetBackup = VanityBackupManager:GetPresetFromBackup(Vanity.ActivePresetId)
				local restoreBackupWindow = Ext.IMGUI.NewWindow(Translator:translate("Armory: Restore Backed Up Preset"))
				restoreBackupWindow.NoCollapse = true
				restoreBackupWindow.AlwaysAutoResize = true

				restoreBackupWindow:AddText(string.format(
					Translator:translate("Preset '%s' was detected as the active preset for this save, but is not loaded in the config - however, a backup was found. Restore?"),
					presetBackup.presets[Vanity.ActivePresetId].Name)).TextWrapPos = 0

				local restoreButton = restoreBackupWindow:AddButton(Translator:translate("Restore Preset"))
				restoreButton.PositionOffset = { 300, 0 }
				-- Green
				restoreButton:SetColor("Button", { 144 / 255, 238 / 255, 144 / 255, .5 })
				-- restoreButton:SetColor("Text", {0, 0, 0, 1})

				restoreButton.OnClick = function()
					VanityBackupManager:RestorePresetBackup(Vanity.ActivePresetId, presetBackup)
					restoreBackupWindow:Destroy()

					validatePreset()

					Vanity:ActivatePreset(Vanity.ActivePresetId)
				end

				local removeButton = restoreBackupWindow:AddButton(Translator:translate("Delete Backup and Deactivate Preset"))
				removeButton.SameLine = true
				removeButton.PositionOffset = { 200, 0 }
				-- Red
				removeButton:SetColor("Button", { 1, 0.02, 0, 0.5 })
				-- removeButton:SetColor("Text", {0, 0, 0, 1})

				removeButton.OnClick = function()
					Channels.ActivatePreset:SendToServer({})
					VanityBackupManager:RemovePresetsFromBackup({ Vanity.ActivePresetId })
					restoreBackupWindow:Destroy()
				end
			else
				validatePreset()
				Vanity:ActivatePreset(Vanity.ActivePresetId)
			end
		end
	end)
end

local validationCheck
validationCheck = Ext.Events.GameStateChanged:Subscribe(function(e)
	---@cast e EclLuaGameStateChangedEvent

	if e.ToState == "Running" then
		Vanity:initialize()
		Ext.Events.GameStateChanged:Unsubscribe(validationCheck)
	end
end)

MCM.SetKeybindingCallback('launch_vanity', function()
	MCM.OpenModPage("Vanity", ModuleUUID, true)
end)


Translator:RegisterTranslation({
	["Begin by creating a preset with the Preset Manager - you can have any amount of presets, but they must be activated to be applied (each preset manages the entire party - only one preset can be active per save). Once a preset is activated, it will only be active for that save (so save after activating it)."] =
	"h343957cb9d284aeb86930a5311c10f61a199",

	["The preset will only be active in saves that were created while it was active - if you load a save before you activated the preset, it must be activated for that specific save"] =
	"heeef36ef99d5401093a374888ccb2bc6b325",

	["It's recommended you save and reload after finalizing your outfit, as parts of the Transmog process don't fully complete until a reload (e.g. Armor type)"] =
	"hb7bc2ec3130d492f912d638fffa06869c7e6",

	["After creating a preset, you can start defining outfits using the options below. You can select combination of criteria (one item from each column, though Hireling and Origin are mutually exclusive, and you don't have to use all columns) - each combination will create a unique outfit"] =
	"h22045f1bbdb6459a811165f3a5c6631c546d",

	["Party members are automatically matched to the _most specific_ outfit defined - the columns in the criteria table are ordered from most specific to least specific."] =
	"hd4eba786a08645ee80fae2adccc984d6a80a",

	["For example, an outfit that only has Origin assigned to it will take precedence over an outfit that has Race/Subrace/BodyType, but Race/BodyType will take precedence over BodyType/Class/Subclass"] =
	"h8b54792743254ac2ad067581d9d3bace1923",

	["This allows you to create Presets that support a wide variety of party compositions while still adhering to a consistent theme, which can be exported via the Preset Manager for users to manual import or to package with mods (which will be automatically read in by Armory when present in the load order)"] =
	"hb2e0c6f036da4fc49b793294c8cc9b825f69",

	["When an outfit is matched to a character, all equipped items will be automatically transmogged and/or dyed according to the outfit (if a non-weapon slot is empty and a vanity item is defined, a junk item will spawn in that slot to allow the vanity item to show)"] =
	"hcade6027c785411682b9fdfa3666b2a5efa3",

	["When an item is unequipped, it will be unmogged/undyed _unless_ it's not contained within an inventory (e.g. throwing or dropping). This is intentional while I figure out what the preferred behavior is"] =
	"h3b3f53c38b1d4e62bb0c3f66e4dc9ffa5gfg",

	["Preset Manager"] = "he7ac5c315ea143849d7614f3eea5dc3c3ce6",
	["Item Validation Report"] = "h87bb9fb4d984424b90bf2a07018fce4b7bb9",
	["Settings"] = "h147cf2b184734696946b29f53af8634b2939",
	["Show Slot Context Menu on Right Click"] = "h3cd833c3ceaf423982e2a4e5ccc5cde2617a",
	["If enabled the context menu that appears when clicking on a given slot/dye icon below will only show up if it's right clicked - otherwise, it will show on left click (and it will launch directly to the picker on right click)"] =
	"h204c96c088344a14a75291a07a5f994a3527",
	["Remove Bladesong Impediment statuses on reload"] = "h2a832d8c75c24861977ba76a659d90c3b462",

	["Generate Junk Items in Empty Slots For Transmog"] = "h6477215a59964b258c51ae8cc3042963197a",
	["When enabled, if an item slot is configured for Transmogging but is currently empty, Armory will spawn a junk item to put in the slot so the transmog can occur."] =
	"hf5af20f3b67c4eefb3f6de7db8a8705973f2",

	["Choose A Preset"] = "hd7c30d7bd7824ca8b05690ed24cbba2575e4",
	["Active Preset:"] = "hfdd58b6fefd94e89babdb0cf39c26cb4fa6b",
	["Armory: Validation of Active Vanity Preset [%s] failed!"] = "h0d3f6797e7ed4d7ca30b60dfd2fb205a07b6",
	["Armory: Restore Backed Up Preset"] = "h1ce43e8d6ff945fa9e26629c56367aecg181",
	["Preset '%s' was detected as the active preset for this save, but is not loaded in the config - however, a backup was found. Restore?"] =
	"h2ad4ba32de41497e80215ea9d3fe88188d00",

	["Restore Preset"] = "h4243eab69148467d9787ab4a7f0e9927efe9",
	["Delete Backup and Deactivate Preset"] = "hb902441c10684c4bb6cf4299accdbf77e6cb",
})

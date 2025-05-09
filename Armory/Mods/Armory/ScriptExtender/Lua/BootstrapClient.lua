Ext.Require("Shared/Translator.lua")
Ext.Require("Shared/Utils/_TableUtils.lua")
Ext.Require("Shared/Utils/_FileUtils.lua")
Ext.Require("Shared/Utils/_ModUtils.lua")
Ext.Require("Shared/Utils/_Logger.lua")

Ext.Events.StatsLoaded:Subscribe(function()
	Logger:ClearLogFile()
end)

Ext.Require("Shared/Configurations/_ConfigurationStructure.lua")
ConfigurationStructure:InitializeConfig()

Ext.Require("Shared/Channels.lua")
Ext.Require("Shared/Vanity/UserPresetPoolManager.lua")
Ext.Require("Client/Vanity/PresetProxy.lua")


Ext.Require("Client/RandomHelpers.lua")
Ext.Require("Client/Styler.lua")
Ext.Require("Client/Vanity/Main.lua")

Ext.Vars.RegisterModVariable(ModuleUUID, "CharacterAssignedCache", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true,
})

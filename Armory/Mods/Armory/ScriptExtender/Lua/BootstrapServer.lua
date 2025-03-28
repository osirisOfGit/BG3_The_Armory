Ext.Require("Shared/Utils/_FileUtils.lua")
Ext.Require("Shared/Utils/_ModUtils.lua")
Ext.Require("Shared/Utils/_Logger.lua")
Ext.Require("Shared/Utils/_TableUtils.lua")

Ext.Require("Shared/Configurations/_ConfigurationStructure.lua")

Ext.Require("Server/Utility.lua")

Ext.Require("Server/Vanity/ItemPreview.lua")
Ext.Require("Server/Vanity/MiscClientHelpers.lua")
Ext.Require("Server/Vanity/DyePreview.lua")

Ext.Require("Server/Vanity/PartyOutfitManager.lua")
Ext.Require("Server/Vanity/Transmogger.lua")


Ext.Vars.RegisterModVariable(ModuleUUID, "SavedPresets", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true
})

Ext.Vars.RegisterModVariable(ModuleUUID, "PresetBackupRegistry", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true,
	SyncOnWrite = true
})

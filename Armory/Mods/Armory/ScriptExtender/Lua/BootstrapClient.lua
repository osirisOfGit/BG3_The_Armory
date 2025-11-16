Ext.Require("Utilities/Common/_Index.lua")
Ext.Require("Utilities/Client/IMGUI/_Index.lua")
Ext.Require("Utilities/Networking/Channels.lua")
Ext.Require("Shared/NetChannelRegistry.lua")

Ext.Events.StatsLoaded:Subscribe(function()
	Logger:ClearLogFile()
end)

Ext.Require("Shared/Configurations/_ConfigurationStructure.lua")
ConfigurationStructure:InitializeConfig()

Ext.Require("Shared/Vanity/UserPresetPoolManager.lua")
Ext.Require("Client/Vanity/PresetProxy.lua")


Ext.Require("Client/RandomHelpers.lua")
Ext.Require("Client/Vanity/Main.lua")

Ext.Vars.RegisterModVariable(ModuleUUID, "CharacterAssignedCache", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true,
})

Channels.RecordProfileId:SetHandler(function(profileId, user)
	FileUtils:SaveStringContentToFile("UserProfileId.txt", profileId)
end)

Channels.RecordProfileId:SetRequestHandler(function(_, _)
	return FileUtils:LoadFile("UserProfileId.txt")
end)

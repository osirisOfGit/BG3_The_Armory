ConfigManager = {}

ConfigManager.ConfigCopy = {}

ConfigManager.ConfigCopy = ConfigurationStructure:UpdateConfigForServer()
Ext.RegisterNetListener(ModuleUUID .. "_UpdateConfiguration", function(_, _, _)
	ConfigManager.ConfigCopy = ConfigurationStructure:UpdateConfigForServer()
end)

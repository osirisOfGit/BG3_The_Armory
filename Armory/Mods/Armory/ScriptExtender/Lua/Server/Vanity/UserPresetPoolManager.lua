UserPresetPoolManager = {}

Channels.GetUserPresetPool = Ext.Net.CreateChannel(ModuleUUID, "GetUserPresetPool")

local function initialize()
	
end

Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function(levelName, isEditorMode)
	initialize()
end)

Ext.Events.ResetCompleted:Subscribe(function(e)
	initialize()
end)

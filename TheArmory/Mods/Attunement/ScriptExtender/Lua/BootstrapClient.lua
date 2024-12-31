Ext.Require("Shared/Utils/_TableUtils.lua")
Ext.Require("Shared/Utils/_FileUtils.lua")
Ext.Require("Shared/Utils/_ModUtils.lua")
Ext.Require("Shared/Utils/_Logger.lua")

Ext.Events.StatsLoaded:Subscribe(function()
	Logger:ClearLogFile()
end)

Ext.Require("Shared/Translator.lua")
Ext.Require("Shared/Configurations/_ConfigurationStructure.lua")

ConfigurationStructure:InitializeConfig()

Ext.Require("Client/ItemConfig/ItemConfigMenu.lua")
Ext.Require("Client/Rules/RulesMenu.lua")

Ext.Events.StatsLoaded:Subscribe(function(e)
	---@type SpellData
	local isAttunedStat = Ext.Stats.Get("ATTUNEMENT_IS_ATTUNED_STATUS")
	if MCM.Get("enabled") then
		isAttunedStat.StatusPropertyFlags = {}
	else
		isAttunedStat.StatusPropertyFlags = { "DisableCombatlog", "DisablePortraitIndicator" }
	end

	---@type SpellData
	local requiresAttuningStat = Ext.Stats.Get("ATTUNEMENT_REQUIRES_ATTUNEMENT_STATUS")
	if MCM.Get("enabled") then
		requiresAttuningStat.StatusPropertyFlags = { "DisableOverhead", "DisableCombatlog" }
	else
		requiresAttuningStat.StatusPropertyFlags = { "DisableCombatlog", "DisablePortraitIndicator" }
	end
end)

Ext.Require("Shared/Utils/_FileUtils.lua")
Ext.Require("Shared/Utils/_ModUtils.lua")
Ext.Require("Shared/Utils/_Logger.lua")
Ext.Require("Shared/Utils/_TableUtils.lua")

Ext.Require("Shared/Configurations/_ConfigurationStructure.lua")
Ext.Require("Server/_ConfigManager.lua")
Ext.Require("Server/Rules/Main.lua")
Ext.Require("Server/Rules/BuildRelevantStatFunctions.lua")


Ext.ModEvents.BG3MCM["MCM_Setting_Saved"]:Subscribe(function(payload)
	if not payload or payload.modUUID ~= ModuleUUID or not payload.settingId then
		return
	end

	if payload.settingId == "enabled" then
		for statName, raritySetting in pairs(ConfigurationStructure.config.items.rarityOverrides) do
			local stat = Ext.Stats.Get(statName)
			stat.Rarity = payload.value and raritySetting.New or raritySetting.Original
			stat:Sync()
		end

		---@type SpellData
		local isAttunedStat = Ext.Stats.Get("ATTUNEMENT_IS_ATTUNED_STATUS")
		if payload.value then
			isAttunedStat.StatusPropertyFlags = {}
		else
			isAttunedStat.StatusPropertyFlags = { "DisableCombatlog", "DisablePortraitIndicator" }
		end
		isAttunedStat:Sync()

		---@type SpellData
		local requiresAttuningStat = Ext.Stats.Get("ATTUNEMENT_REQUIRES_ATTUNEMENT_STATUS")
		if payload.value then
			requiresAttuningStat.StatusPropertyFlags = {"DisableOverhead", "DisableCombatlog"}
		else
			requiresAttuningStat.StatusPropertyFlags = { "DisableCombatlog", "DisablePortraitIndicator" }
		end
		requiresAttuningStat:Sync()

		Logger:BasicInfo("Successfully %s item rarities", payload.value and "overwrote" or "reverted")
	end
end)

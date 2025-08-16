Ext.Require("Utilities/Common/_Index.lua")
Ext.Require("Utilities/Networking/Channels.lua")

Ext.Require("Shared/Configurations/_ConfigurationStructure.lua")
Ext.Require("Shared/Channels.lua")
Ext.Require("Shared/Vanity/ModPresetManager.lua")
Ext.Require("Shared/Vanity/UserPresetPoolManager.lua")

Ext.Require("Server/Utility.lua")

Ext.Require("Server/Vanity/ModEventManager.lua")
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

Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function(levelName, isEditorMode)
	if levelName == "SYS_CC_I" then return end

	for _, item in pairs(Ext.Entity.GetAllEntitiesWithComponent("Equipable")) do
		if item.ServerItem.Template.Id == item.Uuid.EntityUuid then
			local slot = Ext.Stats.Get(item.Data.StatsId).Slot
			if SlotEnum[slot] and (SlotEnum[slot] <= 7 and SlotEnum[slot] >= 13) then
				Osi.ApplyStatus(item.Uuid.EntityUuid, "ARMORY_VANITY_UNIQUE_ITEM", -1, 1)
			end
		end
	end
end)

Ext.Osiris.RegisterListener("AddedTo", 3, "after", function(object, inventoryHolder, addType)
	if Osi.IsEquipable(object) == 1 then
		---@type EntityHandle
		local item = Ext.Entity.Get(object)
		if item.ServerItem.Template.Id == item.Uuid.EntityUuid then
			local slot = Ext.Stats.Get(item.Data.StatsId).Slot
			if SlotEnum[slot] and (SlotEnum[slot] <= 7 and SlotEnum[slot] >= 13) then
				Osi.ApplyStatus(item.Uuid.EntityUuid, "ARMORY_VANITY_UNIQUE_ITEM", -1, 1)
			end
		end
	end
end)

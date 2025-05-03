ModEventsManager = {}

---@class TransmogCompleteEvent
---@field cosmeticItemId GUIDSTRING
---@field equippedItemTemplateId GUIDSTRING
---@field equippedItemId GUIDSTRING will be destroyed by the time this event fires
---@field character CHARACTER
---@field slot ActualSlot Shared/Vanity/MissingEnums - SE enum doesn't perfectly match OSI slot name

---@param payload TransmogCompleteEvent
function ModEventsManager:TransmogCompleted(payload)
	Ext.ModEvents['Armory']["TransmogCompleted"]:Throw(payload)
	Logger:BasicDebug("Fired TransmogCompleted event with %s", Ext.Json.Stringify(payload))
end

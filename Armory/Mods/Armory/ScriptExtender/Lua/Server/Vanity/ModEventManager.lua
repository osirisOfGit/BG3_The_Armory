ModEventsManager = {}

---@class TransmogCompleteEvent
---@field cosmeticItemId GUIDSTRING will be destroyed by the time TransmogRemoved event fires
---@field cosmeticTemplateItemId GUIDSTRING
---@field equippedItemTemplateId GUIDSTRING
---@field equippedItemId GUIDSTRING will be destroyed by the time TransmogComplete event fires
---@field character CHARACTER
---@field slot ActualSlot? Shared/Vanity/MissingEnums - SE enum doesn't perfectly match OSI slot name - can be nil if unequipped item goes back into inventory

---@param payload TransmogCompleteEvent
function ModEventsManager:TransmogCompleted(payload)
	Ext.ModEvents['Armory']["TransmogCompleted"]:Throw(payload)
	Logger:BasicDebug("Fired TransmogCompleted event with %s", Ext.Json.Stringify(payload))
end


---@param payload TransmogCompleteEvent
function ModEventsManager:TransmogRemoved(payload)
	Ext.ModEvents['Armory']["TransmogRemoved"]:Throw(payload)
	Logger:BasicDebug("Fired TransmogRemoved event with %s", Ext.Json.Stringify(payload))
end

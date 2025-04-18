---@class PickerBaseFilterClass
PickerBaseFilterClass = {
	---@type string
	label = "",
	priority = 50,
	---@type ExtuiTreeParent?
	header = nil,
	---@type fun(count: number)?
	updateLabelWithCount = nil,
	---@type {[string]: boolean}?
	selectedFilters = nil,
	-- A persistent coroutine.wrap function - must not be recreated after initialization to preserve imgui function references
	---@type fun(self: PickerBaseFilterClass, slot: string, itemTemplate: ItemTemplate)?
	buildFilterUI = nil,
	---@type fun(self: PickerBaseFilterClass, itemTemplate: ItemTemplate):boolean
	apply = nil,
}

---@param instance table?
---@return PickerBaseFilterClass instance
function PickerBaseFilterClass:new(instance)
	instance = instance or {}

	setmetatable(instance, self)
	self.__index = self

	return instance
end

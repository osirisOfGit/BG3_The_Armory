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
	filterTable = nil,
	-- A persistent coroutine.wrap function - must not be recreated after initialization to preserve imgui function references
	---@type fun(self: PickerBaseFilterClass, itemTemplate: ItemTemplate)?
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

-- I tried to use coroutines so i didn't have to maintain cross-function state,
-- but IMGUI had problems with such strictly encapsulated state and function refs
function PickerBaseFilterClass:initializeUIBuilder() end

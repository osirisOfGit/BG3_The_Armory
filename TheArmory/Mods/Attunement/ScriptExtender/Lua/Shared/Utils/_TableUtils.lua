--- @module "Utils._TableUtils"

TableUtils = {}

function TableUtils:AddItemToTable_AddingToExistingAmount(tarTable, key, amount)
	if not tarTable then
		tarTable = {}
	end
	if not tarTable[key] then
		tarTable[key] = amount
	else
		tarTable[key] = tarTable[key] + amount
	end
end

-- stolen from https://stackoverflow.com/questions/640642/how-do-you-copy-a-lua-table-by-value
local function copy(obj, seen, makeImmutable)
	if type(obj) ~= 'table' then return obj end
	if seen and seen[obj] then return seen[obj] end
	local s = seen or {}
	local res = setmetatable({}, getmetatable(obj))
	s[obj] = res
	for k, v in pairs(obj) do res[copy(k, s, makeImmutable)] = copy(v, s, makeImmutable) end

	if makeImmutable then
		res = setmetatable(res, {
			getmetatable(res) and table.unpack(getmetatable(res)),
			__newindex = function(...) error("Attempted to modify immutable table") end
		})
	end

	return res
end

--- If obj is a table, returns a deep clone of that table, otherwise return obj
---@param obj table
---@return table
function TableUtils:DeeplyCopyTable(obj)
	return copy(obj, nil, false)
end

--- Creates an immutable table
---@param tableName string
---@return table
function TableUtils:MakeImmutableTableCopy(myTable)
	return copy(myTable, nil, true)
end

---Compare two lists
---@param first
---@param second
---@treturn boolean true if the lists are equal
function TableUtils:CompareLists(first, second)
	for property, value in pairs(first) do
		if value ~= second[property] then
			return false
		end
	end

	for property, value in pairs(second) do
		if value ~= first[property] then
			return false
		end
	end

	return true
end

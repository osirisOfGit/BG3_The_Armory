ConfigurationStructure = {}

local real_config_table = {}

local initialized = false
local updateTimer

-- This allows us to react to any changes made to fields at any level in the structure and send a NetMessage
-- just by defining the base table, ConfigurationStructure.config. Client/* implementations can now
-- reference any slice of this table and allow their IMGUI elements to modify the table without
-- any additional logic for letting the server know there were changes. Only works for this implementation -
-- too fragile for general use
local function generate_recursive_metatable(proxy_table, real_table)
	return setmetatable(proxy_table, {
		-- don't use the proxy table during pairs() so we don't have to exclude any proxy fields
		__pairs = function(this_table)
			return next, real_table, nil
		end,
		__index = function(this_table, key)
			return real_table[key]
		end,
		__len = function(this_table)
			return #real_table
		end,
		__newindex = function(this_table, key, value)
			if key == "delete" then
				rawset(this_table._parent_proxy, this_table._parent_key, nil)
				this_table._parent_table[this_table._parent_key] = nil
			else
				real_table[key] = value

				if type(value) == "table" then
					rawset(proxy_table, key, generate_recursive_metatable(
						{
							_parent_key = key,
							_parent_table = real_table,
							_parent_proxy = proxy_table
						},
						real_table[key]))
					-- Accounting for setting a table that has tables in one assignment operation
					for child_key, child_value in pairs(value) do
						if type(child_value) == "table" then
							proxy_table[key][child_key] = child_value
						end
					end
				end
			end

			if initialized then
				if updateTimer then
					Ext.Timer.Cancel(updateTimer)
				end
				-- This triggers each time a slider moves, so need to wait for changes to be complete before updating
				updateTimer = Ext.Timer.WaitFor(250, function()
					-- Don't wanna deal with complex merge logic, and the payload size can get pretty massive,
					-- so instead of serializing and sending it via NetMessages we'll just have the client handle
					-- the file updates and let the server know when to read from it
					FileUtils:SaveTableToFile("config.json", real_config_table)
					Logger:BasicDebug("Configuration updates made - sending updated table to server")

					if Ext.ClientNet.IsHost() then
						Ext.ClientNet.PostMessageToServer(ModuleUUID .. "_UpdateConfiguration", "")
					else
						Logger:BasicWarning("You're not the host of this session, so not updating the server configs - your local config is still updated")
					end
				end)
			end
		end
	})
end

ConfigurationStructure.DynamicClassDefinitions = {}

--- @class Configuration
ConfigurationStructure.config = generate_recursive_metatable({}, real_config_table)

Ext.Require("Shared/RarityEnum.lua")
Ext.Require("Shared/ItemConfig/ItemConfig.lua")
Ext.Require("Shared/Rules/RulesConfig.lua")

local function CopyConfigsIntoReal(table_from_file, proxy_table)
	for key, value in pairs(table_from_file) do
		local default_value = proxy_table[key]
		-- if default_value then
		if type(value) == "table" then
			if not default_value then
				proxy_table[key] = {}
				default_value = proxy_table[key]
			end
			-- if type(default_value) == "table" then
			CopyConfigsIntoReal(value, default_value)
			-- else
			-- 	Logger:BasicWarning("Config property %s with value %s was loaded from the server and is a table, but the Config definition isn't a table - ignoring.",
			-- 		key,
			-- 		type(value) == "table" and Ext.Json.Stringify(value) or value)
			-- end
		else
			-- if type(default_value) ~= table then
			proxy_table[key] = value
			-- else
			-- 	Logger:BasicWarning("Config property %s with value %s was loaded from the server and is not a table, but the Config definition is a table - ignoring.",
			-- 		key,
			-- 		type(value) == "table" and Ext.Json.Stringify(value) or value)
			-- end
		end
		-- else
		-- 	Logger:BasicWarning("Config property %s with value %s was loaded from the server, but it's not in the Config definition - ignoring.",
		-- 		key,
		-- 		type(value) == "table" and Ext.Json.Stringify(value) or value)
		-- end
	end
end

---@return Configuration
function ConfigurationStructure:GetRealConfigCopy()
	return TableUtils:DeeplyCopyTable(real_config_table)
end

function ConfigurationStructure:InitializeConfig()
	local config = FileUtils:LoadTableFile("config.json")

	if not config then
		config = real_config_table
		FileUtils:SaveTableToFile("config.json", config)
	else
		CopyConfigsIntoReal(config, ConfigurationStructure.config)
	end

	initialized = true
	Logger:BasicInfo("Successfully loaded the config!")
end

function ConfigurationStructure:UpdateConfigForServer()
	local config = FileUtils:LoadTableFile("config.json")
	if config then
		real_config_table = config
		Logger:BasicDebug("Successfully updated config on server side!")
	end
	return ConfigurationStructure:GetRealConfigCopy()
end

if Ext.IsClient() then
	Ext.Events.SessionLoaded:Subscribe(function()
		Ext.ClientNet.PostMessageToServer(ModuleUUID .. "_UpdateConfiguration", "")
	end)
end

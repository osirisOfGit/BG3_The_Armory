UserPresetPoolManager = {}

---@type {[UserID] : Guid[]}
UserPresetPoolManager.PresetPool = {}

Channels.GetUserPresetPool = Ext.Net.CreateChannel(ModuleUUID, "GetUserPresetPool")
Channels.UpdateUserPresetPool = Ext.Net.CreateChannel(ModuleUUID, "UpdateUserPresetPool")
Channels.GetUserSpecificPreset = Ext.Net.CreateChannel(ModuleUUID, "GetUserSpecificPreset")

if Ext.IsServer() then
	local function initialize()
		local loadingLock = {}

		for _, player in pairs(Osi.DB_Players:Get(nil)) do
			local userId = Osi.GetReservedUserID(player[1])
			if userId and not loadingLock[userId] then
				loadingLock[userId] = true
				Channels.GetUserPresetPool:RequestToClient({},
					userId,
					function(data)
						Logger:BasicInfo("Loaded %s into the pool", Osi.GetUserName(userId))
						UserPresetPoolManager.PresetPool[userId] = data.presetIds
						loadingLock[userId] = nil
					end)
			end
		end
	end

	Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function(levelName, isEditorMode)
		initialize()
	end)

	Ext.Events.ResetCompleted:Subscribe(function(e)
		initialize()
	end)

	Channels.UpdateUserPreset:SetHandler(function(data, user)
		user = PeerToUserID(user)

		UserPresetPoolManager.PresetPool[user] = data.presetIds

		Channels.UpdateUserPreset:Broadcast({
			[user] = data.presetIds
		}, Osi.GetCurrentCharacter(user))
	end)

	Channels.GetUserPresetPool:SetRequestHandler(function(data, user)
		user = PeerToUserID(user)
		local presetTable = {}
		for otherUser, presetIds in pairs(UserPresetPoolManager.PresetPool) do
			if otherUser ~= user then
				presetTable[otherUser] = presetIds
			end
		end

		return presetTable
	end)

	Channels.GetUserSpecificPreset:SetRequestHandler(function(data, user)
		local presetID = data.presetId

		for user, presetIds in pairs(UserPresetPoolManager.PresetPool) do
			if TableUtils:ListContains(presetIds, presetID) then
				return { user = user }
			end
		end

		return {}
	end)
else
	Channels.GetUserPresetPool:SetRequestHandler(function(data, user)
		local presetTable = {}
		for presetId in pairs(ConfigurationStructure:GetRealConfigCopy().vanity.presets) do
			table.insert(presetTable, presetId)
		end

		return presetTable
	end)
end

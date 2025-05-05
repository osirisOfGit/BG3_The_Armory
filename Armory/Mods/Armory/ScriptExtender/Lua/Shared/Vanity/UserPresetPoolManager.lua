UserPresetPoolManager = {}

---@type {[UserID] : Guid[]}
UserPresetPoolManager.PresetPool = {}

Channels.GetUserPresetPool = Ext.Net.CreateChannel(ModuleUUID, "GetUserPresetPool")
Channels.SendOutPresetPools = Ext.Net.CreateChannel(ModuleUUID, "SendOutPresetPools")
Channels.UpdateUserPresetPool = Ext.Net.CreateChannel(ModuleUUID, "UpdateUserPresetPool")
Channels.GetUserSpecificPreset = Ext.Net.CreateChannel(ModuleUUID, "GetUserSpecificPreset")

if Ext.IsServer() then
	local loadingLock = {}

	function UserPresetPoolManager:hydrateClientsWithPools()
		if next(loadingLock) then
			Ext.Timer.WaitFor(20, function()
				self:hydrateClientsWithPools()
			end)
		else
			for user in pairs(self.PresetPool) do
				local presetPool = {}
				for otherUser, presetIds in pairs(self.PresetPool) do
					if user ~= otherUser then
						presetPool[otherUser] = presetIds
					end
				end


				Channels.SendOutPresetPools:SendToClient(presetPool, user)
			end
		end
	end

	local function initialize()
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

		UserPresetPoolManager:hydrateClientsWithPools()
	end

	Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function(levelName, isEditorMode)
		initialize()
	end)

	Ext.Events.ResetCompleted:Subscribe(function(e)
		initialize()
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

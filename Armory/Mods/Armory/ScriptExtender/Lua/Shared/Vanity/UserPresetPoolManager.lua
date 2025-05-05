UserPresetPoolManager = {}

---@type {[UserID] : Vanity}
UserPresetPoolManager.PresetPool = {}

Channels.GetUserPresetPool = Ext.Net.CreateChannel(ModuleUUID, "GetUserPresetPool")
Channels.GetUserVanity = Ext.Net.CreateChannel(ModuleUUID, "GetUserVanity")
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
				for otherUser, vanity in pairs(self.PresetPool) do
					if user ~= otherUser then
						presetPool[otherUser] = {}
						for presetId in pairs(vanity.presets) do
							table.insert(presetPool[otherUser], presetId)
						end
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
				Channels.GetUserVanity:RequestToClient({},
					userId,
					function(data)
						Logger:BasicInfo("Loaded %s into the pool", Osi.GetUserName(userId))
						UserPresetPoolManager.PresetPool[userId] = data
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

	Channels.GetUserPresetPool:SetHandler(function(data, user)
		user = PeerToUserID(user)
		local presetTable = {}
		for otherUser, vanity in pairs(UserPresetPoolManager.PresetPool) do
			if otherUser ~= user then
				presetTable[otherUser] = vanity
			end
		end

		Channels.UpdateUserPresetPool:Broadcast(presetTable, Osi.GetCurrentCharacter(user))
	end)

	Channels.GetUserSpecificPreset:SetRequestHandler(function(data, user)
		return UserPresetPoolManager.PresetPool[data.user]
	end)

	Channels.UpdateUserPresetPool:SetHandler(function(vanity, user)
		user = PeerToUserID(user)

		UserPresetPoolManager.PresetPool[user] = vanity

		UserPresetPoolManager:hydrateClientsWithPools()

		local presetPool = {}
		for otherUser, otherVanity in pairs(UserPresetPoolManager.PresetPool) do
			if user ~= otherUser then
				presetPool[otherUser] = otherVanity
			end
		end

		Channels.UpdateUserPresetPool:Broadcast(presetPool, Osi.GetCurrentCharacter(user))
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

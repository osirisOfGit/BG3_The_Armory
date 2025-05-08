UserPresetPoolManager = {}

---@type {[UserID] : Vanity}
UserPresetPoolManager.PresetPool = {}

Channels.GetUserPresetPool = Ext.Net.CreateChannel(ModuleUUID, "GetUserPresetPool")
Channels.GetUserVanity = Ext.Net.CreateChannel(ModuleUUID, "GetUserVanity")
Channels.SendOutPresetPools = Ext.Net.CreateChannel(ModuleUUID, "SendOutPresetPools")
Channels.UpdateUserVanityPool = Ext.Net.CreateChannel(ModuleUUID, "UpdateUserVanityPool")
Channels.GetUserSpecificPreset = Ext.Net.CreateChannel(ModuleUUID, "GetUserSpecificPreset")

if Ext.IsServer() then
	local loadingLock = {}

	function UserPresetPoolManager:GetVanitiesFromUsers(user)
		if Osi.GetUserCount() > 1 then
			if user then
				loadingLock[user] = true
				Logger:BasicDebug("Firing GetUserVanity to %s", Osi.GetUserName(user))
				Channels.GetUserVanity:RequestToClient({},
					user,
					function(data)
						Logger:BasicInfo("Loaded %s into the pool", Osi.GetUserName(user))
						UserPresetPoolManager.PresetPool[user] = data
						loadingLock[user] = nil
					end)
			else
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
			end

			UserPresetPoolManager:hydrateClientsWithPools()
		end
	end

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

				Logger:BasicDebug("Firing SendOutPresetPools to %s", Osi.GetUserName(user))
				Channels.SendOutPresetPools:SendToClient(presetPool, user)
			end

			UserPresetPoolManager:sendOutVanities(user, true)
		end
	end

	Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function(levelName, isEditorMode)
		UserPresetPoolManager:GetVanitiesFromUsers()
	end)

	Ext.Events.ResetCompleted:Subscribe(function(e)
		UserPresetPoolManager:GetVanitiesFromUsers()
	end)


	Channels.GetUserSpecificPreset:SetRequestHandler(function(data, user)
		Logger:BasicDebug("%s requested Vanity for %s", Osi.GetUserName(PeerToUserID(user)), Osi.GetUserName(tonumber(data.user)))
		return UserPresetPoolManager.PresetPool[tonumber(data.user)]
	end)

	function UserPresetPoolManager:sendOutVanities(user, broadcast)
		if Osi.GetUserCount() > 1 then
			local presetTable = {}

			if not broadcast then
				for otherUser, vanity in pairs(UserPresetPoolManager.PresetPool) do
					if otherUser ~= user then
						presetTable[otherUser] = vanity
					end
				end

				Logger:BasicDebug("Firing UpdateUserVanityPool to %s", Osi.GetUserName(user))
				Channels.UpdateUserVanityPool:SendToClient(presetTable, user)
			else
				for otherUser in pairs(UserPresetPoolManager.PresetPool) do
					if otherUser ~= user then
						local presetPool = {}
						for otherOtherUser in pairs(UserPresetPoolManager.PresetPool) do
							if otherUser ~= otherOtherUser then
								presetPool[otherOtherUser] = UserPresetPoolManager.PresetPool[otherOtherUser]
							end
						end
						Logger:BasicDebug("Firing UpdateUserVanityPool to %s", Osi.GetUserName(otherUser))
						Channels.UpdateUserVanityPool:SendToClient(presetPool, otherUser)
					end
				end
			end
		end
	end

	Ext.Osiris.RegisterListener("UserConnected", 3, "after", function(userID, userName, userProfileID)
		UserPresetPoolManager:GetVanitiesFromUsers()
		UserPresetPoolManager:sendOutVanities(userID, true)
	end)

	Ext.Osiris.RegisterListener("UserDisconnected", 3, "after", function(userID, userName, userProfileID)
		UserPresetPoolManager.PresetPool[userID] = nil
		UserPresetPoolManager:GetVanitiesFromUsers()
		UserPresetPoolManager:sendOutVanities(userID, true)
	end)

	Channels.GetUserPresetPool:SetHandler(function(data, user)
		UserPresetPoolManager:sendOutVanities(PeerToUserID(user))
	end)

	Channels.UpdateUserVanityPool:SetHandler(function(vanity, user)
		user = PeerToUserID(user)

		UserPresetPoolManager.PresetPool[user] = vanity

		UserPresetPoolManager:hydrateClientsWithPools()
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

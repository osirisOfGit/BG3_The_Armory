Ext.Vars.RegisterModVariable(ModuleUUID, "ActivePreset", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true,
})

Ext.Vars.RegisterModVariable(ModuleUUID, "CharacterAssignedCache", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true,
})

ServerPresetManager = {}

---@alias UserID string

---@type {[string]: Vanity}
ServerPresetManager.ActiveVanityPresets = {}

local activePresets
local function initialize()
	activePresets = Ext.Vars.GetModVariables(ModuleUUID).ActivePreset or {}
	if type(activePresets) == "string" then
		local hostId = Osi.GetReservedUserID(Osi.GetHostCharacter())
		activePresets = { [Osi.GetUserProfileID(hostId)] = activePresets }
	end

	local loadingLock = {}

	for _, player in pairs(Osi.DB_Players:Get(nil)) do
		local userId = Osi.GetReservedUserID(player[1])
		if userId and not loadingLock[userId] then
			local userPreset = activePresets[Osi.GetUserProfileID(userId)]
			if userPreset then
				Logger:BasicDebug("Retrieving preset %s for user %s", userPreset, Osi.GetUserName(userId))
				loadingLock[userId] = true
				Channels.GetActiveUserPreset:RequestToClient(Ext.Json.Parse(Ext.Json.Stringify({
						presetId = userPreset
					}, { Binary = true }), true),
					userId,
					function(data)
						ServerPresetManager.ActiveVanityPresets[userId] = data
						loadingLock[userId] = nil
					end)
			end
		end
	end

	local function initiateTransmog()
		if next(loadingLock) then
			Ext.Timer.WaitFor(20, function()
				initiateTransmog()
			end)
		else
			Ext.Vars.GetModVariables(ModuleUUID).ActivePreset = activePresets

			Logger:BasicDebug("Initialization completed - applying transmogs")
			Transmogger.saveLoadLock = true
			PartyOutfitManager:ApplyTransmogsPerPreset()
		end
	end

	initiateTransmog()
end

---@param character string
---@return VanityPreset?, string UserId
function ServerPresetManager:GetCharacterPreset(character)
	local charAssignedCache = Ext.Vars.GetModVariables(ModuleUUID).CharacterAssignedCache or {}

	local charUserId = Osi.GetReservedUserID(character)

	charUserId = tonumber(charUserId) > 0 and charUserId or nil

	---@type Vanity?
	local vanity = self.ActiveVanityPresets[charUserId]

	if not charUserId then
		if charAssignedCache[character] then
			if not self.ActiveVanityPresets[charAssignedCache[character]] then
				charAssignedCache[character] = Osi.GetReservedUserID(Osi.GetHostCharacter())
			end
		else
			charAssignedCache[character] = Osi.GetReservedUserID(Osi.GetHostCharacter())
		end

		vanity = self.ActiveVanityPresets[charAssignedCache[character]]
		charUserId = charAssignedCache[character]
	else
		charAssignedCache[character] = charUserId
	end

	Ext.Vars.GetModVariables(ModuleUUID).CharacterAssignedCache = charAssignedCache

	Logger:BasicDebug("%s is assigned to user %s", character, Osi.GetUserName(charUserId))

	return (vanity and vanity.presets and vanity.presets[activePresets[Osi.GetUserProfileID(charUserId)]]), charUserId
end

Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function(levelName, isEditorMode)
	initialize()
end)

Ext.Events.ResetCompleted:Subscribe(function(e)
	initialize()
end)

Channels.GetActiveUserPreset:SetRequestHandler(function(_, user)
	local data = Ext.Json.Parse(Ext.Json.Stringify({
		presetId = activePresets[Osi.GetUserProfileID(PeerToUserID(user))]
	}, { Binary = true }), true)
	Logger:BasicInfo("Active preset id %s", data)
	return data
end)

Channels.UpdateUserPreset:SetHandler(function(data, user)
	if activePresets then
		user = PeerToUserID(user)

		activePresets[Osi.GetUserProfileID(user)] = data.presetId
		Ext.Vars.GetModVariables(ModuleUUID).ActivePreset = activePresets

		ServerPresetManager.ActiveVanityPresets[user] = data.vanityPreset

		if data.vanityPreset.presets then
			Logger:BasicInfo("User %s updated preset %s", Osi.GetUserName(user), data.vanityPreset.presets[data.presetId].Name)
		else
			Logger:BasicInfo("User %s deactivated preset", Osi.GetUserName(user))
		end

		PartyOutfitManager:ApplyTransmogsPerPreset(user)

		for otherUser, vanity in pairs(UserPresetPoolManager.PresetPool) do
			if vanity.presets[data.presetId] and otherUser == user then
				UserPresetPoolManager:GetVanitiesFromUsers(user)
				break
			end
		end
	end
end)

Ext.Osiris.RegisterListener("CharacterReservedUserIDChanged", 3, "after", function(character, oldUserID, newUserID)
	if activePresets then
		Logger:BasicDebug("UserID changed for character %s from %s to %s", character, oldUserID, newUserID)
		PartyOutfitManager:ApplyTransmogsPerPreset(newUserID)
	end
end)

Ext.Osiris.RegisterListener("UserConnected", 3, "after", function(userID, userName, userProfileID)
	Logger:BasicDebug("User %s connected with profile ID %s", userName, userProfileID)
	initialize()
end)

Ext.Osiris.RegisterListener("UserDisconnected", 3, "after", function(userID, userName, userProfileID)
	if activePresets then
		Logger:BasicDebug("User %s disconnected with profile ID %s", userName, userProfileID)
		ServerPresetManager.ActiveVanityPresets[userID] = nil
		PartyOutfitManager:ApplyTransmogsPerPreset()
	end
end)

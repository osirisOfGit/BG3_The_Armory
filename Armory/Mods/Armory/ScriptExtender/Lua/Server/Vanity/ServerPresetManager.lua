Ext.Vars.RegisterModVariable(ModuleUUID, "ActivePreset", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true
})

ServerPresetManager = {}

---@alias UserID string

---@type {[string]: Vanity}
ServerPresetManager.ActiveVanityPresets = {}

local function initialize()
	VanityModPresetManager:ImportPresetsFromMods()

	local activePreset = Ext.Vars.GetModVariables(ModuleUUID).ActivePreset
	if type(activePreset) == "string" then
		local hostId = Osi.GetReservedUserID(Osi.GetHostCharacter())
		Ext.Vars.GetModVariables(ModuleUUID).ActivePreset = { [Osi.GetUserProfileID(hostId)] = activePreset }
		activePreset = Ext.Vars.GetModVariables(ModuleUUID).ActivePreset
	end

	local loadingLock = {}

	for _, player in pairs(Osi.DB_Players:Get(nil)) do
		local userId = Osi.GetReservedUserID(player[1])
		if userId and not loadingLock[userId] then
			loadingLock[userId] = true
			local userPreset = activePreset[Osi.GetUserProfileID(userId)]
			if userPreset then
				Channels.GetUserPreset:RequestToClient({
						presetId = userPreset
					},
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
			Transmogger.saveLoadLock = true
			PartyOutfitManager:ApplyTransmogsPerPreset()
			Transmogger.saveLoadLock = false
		end
	end

	initiateTransmog()
end

---@param character string
---@return VanityPreset?
function ServerPresetManager:GetCharacterPreset(character)
	local charUserId = Osi.GetReservedUserID(character)

	Logger:BasicDebug("%s is assigned to user %s", character, Osi.GetUserName(charUserId))
	
	---@type Vanity?
	local vanity = self.ActiveVanityPresets[charUserId]

	return vanity and vanity.presets[Ext.Vars.GetModVariables(ModuleUUID).ActivePreset[Osi.GetUserProfileID(charUserId)]]
end

Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function(levelName, isEditorMode)
	initialize()
end)

Ext.Events.ResetCompleted:Subscribe(function(e)
	initialize()
end)

Channels.GetUserPreset:SetRequestHandler(function(data, user)
	return {
		presetId = Ext.Vars.GetModVariables(ModuleUUID).ActivePreset[Osi.GetUserProfileID(PeerToUserID(user))]
	}
end)

Channels.UpdateUserPreset:SetHandler(function(data, user)
	user = PeerToUserID(user)
	local activePresets = Ext.Vars.GetModVariables(ModuleUUID).ActivePreset or {}
	activePresets[Osi.GetUserProfileID(user)] = data.presetId
	Ext.Vars.GetModVariables(ModuleUUID).ActivePreset = activePresets

	ServerPresetManager.ActiveVanityPresets[user] = data.vanityPreset

	if data.vanityPreset then
		Logger:BasicInfo("User %s updated preset %s", Osi.GetUserName(user), data.vanityPreset.presets[data.presetId].Name)
	else
		Logger:BasicInfo("User %s deactivated preset", Osi.GetUserName(user))
	end

	PartyOutfitManager:ApplyTransmogsPerPreset()
end)

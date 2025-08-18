-- Credit: LaughingLeader

---@class ExtenderNetChannel
---@field Module string
---@field Channel string
---@field RequestHandler fun(data:any?, user:integer):any?
---@field MessageHandler fun(data:any?, user:integer)
---@field SendToServer fun(self:ExtenderNetChannel, data:any?)
---@field SendToClient fun(self:ExtenderNetChannel, data:any?, user:integer|Guid)
---@field Broadcast fun(self:ExtenderNetChannel, data:any?, excludeCharacter?:Guid)
local NetChannel = {}

---Sets MessageHandler
---@param callback fun(data:any?, user:integer)
function NetChannel:SetHandler(callback) end

---Sets RequestHandler
---@param callback fun(data:any?, user:integer):any?
function NetChannel:SetRequestHandler(callback) end

---@param data any?
---@param replyCallback fun(data:any?)
function NetChannel:RequestToServer(data, replyCallback) end

---@param data any?
---@param user integer|Guid
---@param replyCallback fun(data:any?)
function NetChannel:RequestToClient(data, user, replyCallback) end

---@type {[string]: ExtenderNetChannel}
TestChannels = {}

TestChannels.UpdateStatusEffect = Ext.Net.CreateChannel(ModuleUUID, "UpdateStatusEffect_TEST")

--#region Testing with just Sync
Ext.RegisterConsoleCommand("statusfxtest", function(cmd)
	local stat = Ext.Stats.Create("TEST_STATUSEFFECT_1", "StatusData", "_PASSIVES") --[[@as StatusData]]
	stat.StatusEffect = "ceeda0ca-0739-4588-a449-d024389f0c2a" -- poison
	stat.StackId = "TEST_STATUSEFFECT_1"
	stat:Sync()
	Ext.Timer.WaitForRealtime(1000, function()
		Osi.ApplyStatus(Osi.GetHostCharacter(), "TEST_STATUSEFFECT_1", -1, 1, Osi.GetHostCharacter())
	end)
end, { NumArgs = 1, DefaultArgs = { 1 } })
--#endregion

TestChannels.UpdateStatusEffect:SetRequestHandler(function(data, user)
	local stat = Ext.Stats.Create("TEST_STATUSEFFECT_1", "StatusData", "_PASSIVES") --[[@as StatusData]]
	stat.StatusEffect = "ceeda0ca-0739-4588-a449-d024389f0c2a" -- poison
	stat.StackId = "TEST_STATUSEFFECT_1"
end)

--#region Testing with manual replication, no immediate client access
Ext.RegisterConsoleCommand("statusfxtest_manual_repl", function(cmd)
	local stat = Ext.Stats.Create("TEST_STATUSEFFECT_1", "StatusData", "_PASSIVES") --[[@as StatusData]]
	stat.StatusEffect = "ceeda0ca-0739-4588-a449-d024389f0c2a" -- poison
	stat.StackId = "TEST_STATUSEFFECT_1"
	stat:Sync()
	Ext.Timer.WaitForRealtime(1000, function()
		TestChannels.UpdateStatusEffect:Broadcast("")
		Osi.ApplyStatus(Osi.GetHostCharacter(), "TEST_STATUSEFFECT_1", -1, 1, Osi.GetHostCharacter())
	end)
end, { NumArgs = 1, DefaultArgs = { 1 } })
--#endregion

--#region Testing with manual replication, with immediate client access
Ext.RegisterConsoleCommand("statusfxtest_manual_repl_and_access", function(cmd)
	local stat = Ext.Stats.Create("TEST_STATUSEFFECT_1", "StatusData", "_PASSIVES") --[[@as StatusData]]
	stat.StatusEffect = "ceeda0ca-0739-4588-a449-d024389f0c2a" -- poison
	stat.StackId = "TEST_STATUSEFFECT_1"
	stat:Sync()
	Ext.Timer.WaitForRealtime(1000, function()
		TestChannels.UpdateStatusEffect:Broadcast("")
		Osi.ApplyStatus(Osi.GetHostCharacter(), "TEST_STATUSEFFECT_1", -1, 1, Osi.GetHostCharacter())

		Ext.Timer.WaitFor(1000, function ()
			_D(Ext.Stats.Get("TEST_STATUSEFFECT_1"))
		end)
	end)
end, { NumArgs = 1, DefaultArgs = { 1 } })
--#endregion

Ext.RegisterConsoleCommand("dumpstatusfxtest", function(cmd, guid)
	if guid == nil or guid == "" then
		guid = _C().Uuid.EntityUuid
	end
	local entity = Ext.Entity.Get(guid) --[[@as EntityHandle]]
	local statusHandle = nil
	for _, v in pairs(entity.ClientCharacter.StatusManager.Statuses) do
		print("Statuses", v.StatusId, v.StatusHandle)
		if v.StatusId == "TEST_STATUSEFFECT_1" then
			statusHandle = v.StatusHandle
		end
	end
	if statusHandle then
		for _, v in pairs(entity.ClientCharacter.StatusManager.StatusFX) do
			for e, fx in pairs(v.VFX) do
				print("StatusFX.VFX", e, fx.Status)
				if fx.Status == statusHandle then
					_DS(v)
				end
			end
		end
	else
		Ext.Log.PrintError("Failed to find status 'TEST_STATUSEFFECT_1' in ClientCharacter.StatusManager.Statuses")
	end
end)

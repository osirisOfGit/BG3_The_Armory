Ext.RegisterNetListener(ModuleUUID .. "UserName", function(channel, payload, peerId)
	Ext.Net.PostMessageToUser(peerId, ModuleUUID .. "UserName", Osi.GetUserName(PeerToUserID(peerId)))
end)

Channels.GetUserName:SetRequestHandler(function(data, user)
	if data.user then
		user = data.user
	else
		user = PeerToUserID(user)
	end

	return {
		username = Osi.GetUserName(user)
	}
end)

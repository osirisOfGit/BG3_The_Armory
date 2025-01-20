function PeerToUserID(peerID)
	-- usually just userid+1
	return (peerID & 0xffff0000) | 0x0001
end

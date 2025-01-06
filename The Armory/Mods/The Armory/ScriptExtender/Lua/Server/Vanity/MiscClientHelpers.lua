Ext.RegisterNetListener(ModuleUUID .. "UserName", function(channel, payload, peerId)
	Ext.Net.PostMessageToUser(peerId, ModuleUUID .. "UserName", Osi.GetUserName(PeerToUserID(peerId)))
end)

local did = false
Ext.Osiris.RegisterListener("Equipped", 2, "before", function(item, character)
	if not did then
		-- CopyCharacterEquipment(target, source) end

		---@type EntityHandle
		local itemEntity = Ext.Entity.Get(item)

		---@type ItemTemplate
		local lyreTemplate = Ext.Template.GetTemplate("5e7030e9-d59c-4edf-8278-8981a8e8baef")

		itemEntity.GameObjectVisual.RootTemplateId = lyreTemplate.Id
		itemEntity.GameObjectVisual.Icon = lyreTemplate.Icon
		itemEntity:Replicate("GameObjectVisual")

		Osi.Unequip(character, item)
		Osi.Equip(character, item, 1, 0)

		-- ---@type ItemTemplate
		-- local itemTemplate = Ext.Template.GetTemplate(string.sub(Osi.GetTemplate(item), -36))

		-- local visualTemplate = itemTemplate.VisualTemplate
		-- local physicsTemplate = itemTemplate.PhysicsTemplate

		-- itemTemplate.VisualTemplate = lyreTemplate.VisualTemplate
		-- itemTemplate.PhysicsTemplate = lyreTemplate.PhysicsTemplate

		-- Osi.CopyCharacterEquipment("0133f2ad-e121-4590-b5f0-a79413919805", character)
		-- Osi.CopyCharacterEquipment(character, "0133f2ad-e121-4590-b5f0-a79413919805")
		-- Osi.UnloadItem(item)

		-- local newGuid = Osi.CreateAt(itemTemplate.Id, 0, 0, 0, 0, 0, "")
		-- Osi.Equip(Osi.GetHostCharacter(), newGuid, 1)

		-- Ext.Timer.WaitFor(1000, function()
		-- 	itemTemplate.VisualTemplate = visualTemplate
		-- 	itemTemplate.PhysicsTemplate = physicsTemplate
		-- end)
		did = true
	end
end)

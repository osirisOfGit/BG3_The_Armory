SlotContextMenu = {}

---@type ExtuiPopup
SlotContextMenu.Popup = nil

---@param parent ExtuiTreeParent
function SlotContextMenu:initialize(parent)
	self.Popup = parent:AddPopup("VanitySlotContextMenu")
	self:SubscribeToKeyEvents()
end

---@param outfitSlot VanityOutfitSlot
---@param slotButton ExtuiImageButton
---@param buttonType "dye"|"equipment"
---@param onCloseFunc function
function SlotContextMenu:buildMenuForSlot(outfitSlot, slotButton, buttonType, onCloseFunc)
	local oldFunc = slotButton.OnClick

	slotButton.OnClick = function()
		local settings = ConfigurationStructure.config.vanity.settings.general
		if self.LastKeyPressed == settings.showSlotContextMenuModifier then
			Helpers:KillChildren(self.Popup)

			---@type ExtuiSelectable
			local modifierSelectable = self.Popup:AddSelectable("Only show this menu when 'Left Shift' is pressed while clicking", "DontClosePopups")
			modifierSelectable.Selected = settings.showSlotContextMenuModifier ~= nil
			modifierSelectable.OnClick = function()
				settings.showSlotContextMenuModifier = modifierSelectable.Selected and "LSHIFT" or nil
				if not modifierSelectable.Selected then
					Ext.Events.KeyInput:Unsubscribe(self.Subscription)
					self.LastKeyPressed = nil
					self.Subscription = nil
				else
					self:SubscribeToKeyEvents()
				end
			end

			self.Popup:AddSelectable("Edit").OnActivate = oldFunc

			if slotButton.UserData then
				self.Popup:AddSelectable("Clear").OnActivate = function()
					outfitSlot[buttonType].delete = true
					if not outfitSlot() then
						outfitSlot.delete = true
					end

					onCloseFunc()
				end
			end

			self.Popup:Open()
			self.LastKeyPressed = nil
		else
			oldFunc()
		end
	end
end

function SlotContextMenu:SubscribeToKeyEvents()
	if not self.Subscription and ConfigurationStructure.config.vanity.settings.general.showSlotContextMenuModifier then
		---@param key EclLuaKeyInputEvent
		self.Subscription = Ext.Events.KeyInput:Subscribe(function(key)
			if key.Event == "KeyDown" then
				self.LastKeyPressed = key.Key
			end
		end)
	end
end

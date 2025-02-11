SlotContextMenu = {}

---@type ExtuiPopup
SlotContextMenu.Popup = nil

---@param parent ExtuiTreeParent
function SlotContextMenu:initialize(parent)
	if self.Popup then
		self.Popup:Destroy()
	end
	self.Popup = parent:AddPopup("VanitySlotContextMenu")
end

---@param outfitSlot VanityOutfitSlot
---@param slotButton ExtuiImageButton
---@param buttonType "dye"|"equipment"
---@param onCloseFunc function
function SlotContextMenu:buildMenuForSlot(outfitSlot, slotButton, buttonType, onCloseFunc)
	local oldFunc = slotButton.OnClick
	slotButton.OnClick = function()
		Helpers:KillChildren(self.Popup)
		self.Popup:AddSelectable("Edit").OnActivate = oldFunc

		if slotButton.UserData then
			self.Popup:AddSelectable("Clear").OnActivate = function()
				outfitSlot[buttonType].delete = true
				if not outfitSlot() then
					outfitSlot.delete = true
				end

				Ext.Timer.WaitFor(350, function()
					Ext.ClientNet.PostMessageToServer(ModuleUUID .. "_PresetUpdated", "")
				end)

				onCloseFunc()
			end
		end

		self.Popup:Open()
	end
end

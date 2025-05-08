Ext.Require("Shared/Vanity/EffectManager.lua")

SlotContextMenu = {
	itemSlot = nil,
	weaponType = nil,
	outfitSlot = nil,
	buttonType = nil
}

---@type ExtuiPopup
SlotContextMenu.Popup = nil

---@param parent ExtuiTreeParent
function SlotContextMenu:initialize(parent)
	self.Popup = parent:AddPopup("VanitySlotContextMenu")
	self:SubscribeToKeyEvents()
end

---@return VanityOutfitItemEntry
function SlotContextMenu:GetOutfitSlot()
	local outfitSlot = VanityCharacterPanel:InitializeOutfitSlot(self.itemSlot, self.weaponType)
	if not outfitSlot[self.buttonType] then
		outfitSlot[self.buttonType] = {}
	end

	return outfitSlot[self.buttonType]
end

---@param itemSlot string
---@param weaponType string?
---@param outfitSlot VanityOutfitSlot?
---@param slotButton ExtuiImageButton
---@param buttonType "dye"|"equipment"
---@param defaultFunc function
---@param onCloseFunc function
function SlotContextMenu:buildMenuForSlot(itemSlot, weaponType, outfitSlot, slotButton, buttonType, defaultFunc, onCloseFunc)
	slotButton.OnClick = function()
		local settings = ConfigurationStructure.config.vanity.settings.general
		if self.LastKeyPressed == settings.showSlotContextMenuModifier then
			if not outfitSlot then
				local outfit = VanityCharacterPanel.activePreset.Outfits[VanityCharacterPanel.criteriaCompositeKey]
				if outfit then
					outfitSlot = outfit[itemSlot]
					if weaponType and outfitSlot then
						outfitSlot = outfitSlot[weaponType]
					end
				end
			end

			self.itemSlot = itemSlot
			self.weaponType = weaponType
			self.outfitSlot = outfitSlot
			self.buttonType = buttonType

			Helpers:KillChildren(self.Popup)

			self.Popup:AddSelectable(buttonType == "equipment" and Translator:translate("Pick Vanity Item") or Translator:translate("Pick Dye")).OnActivate = defaultFunc

			if slotButton.UserData then
				self.Popup:AddSelectable(Translator:translate("Clear")).OnActivate = function()
					outfitSlot[buttonType].delete = true
					Helpers:ClearEmptyTablesInProxyTree(outfitSlot)

					onCloseFunc()
				end
			end

			if buttonType == "equipment" then
				if not weaponType and not string.match(itemSlot, "Weapon") then
					---@type ExtuiSelectable
					local hideAppearanceSelectable = self.Popup:AddSelectable(Translator:translate("Hide Appearance"))
					hideAppearanceSelectable.Selected = (outfitSlot and outfitSlot[buttonType]) and outfitSlot[buttonType].guid == "Hide Appearance" or false
					if hideAppearanceSelectable.Selected then
						hideAppearanceSelectable.Label = Translator:translate("Show Appearance")
					end
					hideAppearanceSelectable.OnActivate = function()
						local outfitSlot = self:GetOutfitSlot()
						if outfitSlot.guid == "Hide Appearance" then
							outfitSlot.delete = true
						else
							outfitSlot.guid = "Hide Appearance"
							if outfitSlot.modDependency then
								outfitSlot.modDependency.delete = true
							end
						end

						onCloseFunc()
					end
				end
				VanityEffect:buildSlotContextMenuEntries(self.Popup, outfitSlot and outfitSlot[buttonType] or nil, onCloseFunc)
			end

			self.Popup:Open()
			self.LastKeyPressed = nil
		else
			self.itemSlot = nil
			self.weaponType = nil
			self.outfitSlot = nil
			self.buttonType = nil
			defaultFunc()
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
	elseif self.Subscription then
		Ext.Events.KeyInput:Unsubscribe(self.Subscription)
		self.LastKeyPressed = nil
		self.Subscription = nil
	end
end

Translator:RegisterTranslation({
	["Pick Vanity Item"] = "h260010c7678342f89f5a09832dd2ca101b0e",
	["Pick Dye"] = "h7e4abc9883f2456585775e7b548c67f7eb86",
	["Clear"] = "h770ae7fb135c42b09168469f28c9d4c0714c",
	["Hide Appearance"] = "h6363d1da247f4d5d9999da5f43aa382bcf2b",
	["Show Appearance"] = "h9a821af9dcff45c4b304e8a97265fb5a28e5",
})

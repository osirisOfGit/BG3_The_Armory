Styler = {}

---@param imageButton ExtuiImageButton
function Styler:ImageButton(imageButton)
	imageButton.Background = { 0, 0, 0, 0 }
	imageButton:SetColor("Button", { 0, 0, 0, 0 })

	return imageButton
end

---@param text string
---@param parent ExtuiTreeParent
---@param font string?
function Styler:CheapTextAlign(text, parent, font)
	---@type ExtuiSelectable
	local selectable = parent:AddSelectable(text)
	if font then
		selectable.Font = font
	end
	selectable:SetStyle("SelectableTextAlign", 0.5)
	selectable.Disabled = true
end

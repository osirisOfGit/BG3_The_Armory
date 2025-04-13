Styler = {}

---@param header ExtuiCollapsingHeader
---@return ExtuiCollapsingHeader
function Styler:CollapsingHeader(header)
	header.DefaultOpen = false
	header:SetColor("Header", { 0, 0, 0, 0 })

	return header
end

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

---@param parent ExtuiTreeParent
---@param ... fun(ele: ExtuiTableCell)|string
function Styler:MiddleAlignedColumnLayout(parent, ...)
	local table = parent:AddTable("", 3)
	table.NoSavedSettings = true

	table:AddColumn("", "WidthStretch")
	table:AddColumn("", "WidthFixed")
	table:AddColumn("", "WidthStretch")

	for _, uiElement in pairs({ ... }) do
		local row = table:AddRow()
		row:AddCell()

		if type(uiElement) == "function" then
			uiElement(row:AddCell())
		elseif type(uiElement) == "string" then
			row:AddCell():AddText(uiElement)
		end

		row:AddCell()
	end
end

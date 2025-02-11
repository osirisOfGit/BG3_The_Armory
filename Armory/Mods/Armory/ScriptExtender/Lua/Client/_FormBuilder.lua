---@class FormBuilder
FormBuilder = {
}

function FormBuilder:generateGUID()
	local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
	local guid = string.gsub(template, '[xy]', function(c)
		local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
		return string.format('%x', v)
	end)
	return guid
end

---@class FormStructure
---@field label string
---@field propertyField string?
---@field type "Text"|"NumericText"|"Multiline"|"Checkbox"
---@field defaultValue string|boolean?
---@field dependsOn string?
---@field errorMessageIfEmpty string?
---@field input ExtuiInputText|ExtuiCheckbox?
---@field authorError ExtuiText?

---@param parent ExtuiTreeParent
---@param onSubmitFunc function
---@param ... FormStructure
function FormBuilder:CreateForm(parent, onSubmitFunc, ...)
	Helpers:KillChildren(parent)

	local formInputs = { ... }

	for _, formInput in pairs(formInputs) do
		parent:AddText(formInput.label)
		local input
		if formInput.type == "Text" or formInput.type == "NumericText" or formInput.type == "Multiline" then
			input = parent:AddInputText("", formInput.defaultValue or "")

			if formInput.type == "NumericText" then
				input.CharsDecimal = true
			elseif formInput.type == "Multiline" then
				input.Multiline = true
			end
		elseif formInput.type == "Checkbox" then
			input = parent:AddCheckbox("", formInput.defaultValue or false)
		end
		formInput.input = input

		if formInput.errorMessageIfEmpty then
			local authorError = parent:AddText(formInput.errorMessageIfEmpty)
			authorError:SetColor("Text", { 1, 0.02, 0, 1 })
			authorError.Visible = false

			input.OnChange = function()
				authorError.Visible = false
			end
			formInput.authorError = authorError
		end
	end

	local submit = parent:AddButton("Submit")
	submit.OnClick = function()
		local hasErrors
		local inputs = {}
		for _, formInput in pairs(formInputs) do
			if formInput.authorError then
				-- If it's empty
				if formInput.input.Text and formInput.input.Text:match("^%s*$") then
					formInput.authorError.Visible = true
					hasErrors = true
					goto continue
				end
			end
			if formInput.type == "Text" or formInput.type == "NumericText" or formInput.type == "Multiline" then
				inputs[formInput.propertyField or formInput.label] = formInput.input.Text
			elseif formInput.type == "Checkbox" then
				inputs[formInput.propertyField or formInput.label] = formInput.input.Checked
			end
			::continue::
		end

		if hasErrors then
			return
		end

		onSubmitFunc(inputs)
	end
end

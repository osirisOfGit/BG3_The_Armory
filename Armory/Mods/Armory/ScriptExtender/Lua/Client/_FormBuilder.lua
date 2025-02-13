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
---@field enumTable function?

---@param parent ExtuiTreeParent
---@param onSubmitFunc function
---@param ... FormStructure
function FormBuilder:CreateForm(parent, onSubmitFunc, ...)
	Helpers:KillChildren(parent)

	local formInputs = type(...) == "table" and ... or { ... }
	for _, formInput in pairs(formInputs) do
		parent:AddText(formInput.label)
		local input
		if formInput.type == "Text" or formInput.type == "NumericText" or formInput.type == "Multiline" then
			input = parent:AddInputText("", formInput.defaultValue or nil)
			input.AutoSelectAll = true

			if formInput.type == "NumericText" then
				input.CharsDecimal = true
				input.Hint = "Numeric only"
			elseif formInput.type == "Multiline" then
				input.Multiline = true
			end
		elseif formInput.type == "Checkbox" then
			input = parent:AddCheckbox("", formInput.defaultValue or false)
		end
		formInput.input = input

		if formInput.enumTable then
			formInput.input.Hint = (formInput.input.Hint and "; " or "") .. "Must select from the list that appears on focus"
			local displayToKeyMap, displayOrderedMap = formInput.enumTable()

			local resultsView = parent:AddChildWindow(formInput.propertyField or formInput.label)
			resultsView.AutoResizeY = true
			resultsView.NoSavedSettings = true
			resultsView.Visible = false
			formInput.input.OnChange = function()
				formInput.input.UserData = nil

				Helpers:KillChildren(resultsView)
				resultsView.Visible = true
				for _, enumValue in ipairs(displayOrderedMap or displayToKeyMap) do
					if #input.Text == 0 or string.match(string.upper(enumValue), string.upper(input.Text)) then
						---@type ExtuiSelectable
						local enumSelectable = resultsView:AddSelectable(enumValue, "DontClosePopups")

						enumSelectable.OnActivate = function()
							formInput.input.UserData = displayOrderedMap and displayToKeyMap[enumSelectable.Label] or enumSelectable.Label
							formInput.input.Text = enumSelectable.Label
							resultsView.Visible = false
						end
					end
				end
			end

			input.OnActivate = function()
				formInput.input.OnChange()
			end
			input.OnDeactivate = function()
				if formInput.input.UserData == nil then
					formInput.input.Text = ""
				end
				resultsView.Visible = false
			end
		end

		if formInput.errorMessageIfEmpty then
			local authorError = parent:AddText(formInput.errorMessageIfEmpty)
			authorError:SetColor("Text", { 1, 0.02, 0, 1 })
			authorError.Visible = false

			local oldOnChange = input.OnChange
			input.OnChange = function()
				if oldOnChange then
					oldOnChange()
				end
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
				local dependsHasContent = nil
				if formInput.dependsOn then
					for _, inputToDependOn in pairs(formInputs) do
						if inputToDependOn.label == formInput.dependsOn then
							if inputToDependOn.input.Text and not inputToDependOn.input.Text:match("^%s*$") then
								dependsHasContent = true
							else
								dependsHasContent = false
							end
							break
						end
					end
					if dependsHasContent == true and (not formInput.input.Text or formInput.input.Text:match("^%s*$")) then
						formInput.authorError.Visible = true
						hasErrors = true
						goto continue
					end
				else
					-- If it's empty
					if not formInput.input.Text or formInput.input.Text:match("^%s*$") then
						formInput.authorError.Visible = true
						hasErrors = true
						goto continue
					end
				end
			end
			if formInput.type == "Text" or formInput.type == "NumericText" or formInput.type == "Multiline" then
				inputs[formInput.propertyField or formInput.label] = formInput.input.UserData or formInput.input.Text
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

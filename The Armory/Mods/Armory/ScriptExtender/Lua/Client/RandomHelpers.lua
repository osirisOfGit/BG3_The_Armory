Helpers = {}

---@param tooltip ExtuiTooltip
---@param itemName string?
---@param itemStat Object|Weapon|Armor
function Helpers:BuildTooltip(tooltip, itemName, itemStat)
	if itemName then
		tooltip:AddText("\t " .. itemName)
	else
		tooltip:AddText("\n")
	end

	if itemStat.ModId ~= "" then
		local mod = Ext.Mod.GetMod(itemStat.ModId).Info
		tooltip:AddText(string.format("From mod '%s' by '%s'", mod.Name, mod.Author ~= "" and mod.Author or "Larian")).TextWrapPos = 600
	end

	if itemStat.OriginalModId ~= "" and itemStat.OriginalModId ~= itemStat.ModId then
		local mod = Ext.Mod.GetMod(itemStat.OriginalModId).Info
		tooltip:AddText(string.format("Originally from mod '%s' by '%s'", mod.Name, mod.Author ~= "" and mod.Author or "Larian")).TextWrapPos = 600
	end
end

---@param ... ExtuiTreeParent
function Helpers:KillChildren(...)
	for _, parent in pairs({...}) do
		for _, child in pairs(parent.Children) do
			if child.UserData ~= "keep" then
				child:Destroy()
			end
		end
	end
end

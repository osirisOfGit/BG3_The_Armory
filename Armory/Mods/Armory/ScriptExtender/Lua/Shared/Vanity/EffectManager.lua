---@class VanityEffect
VanityEffect = {
	---@type string
	Name = "",
	---@class VanityEffectProperties
	effectProps = {
		---@type integer?
		AuraRadius = 0,
		---@type string?
		AuraFX = "",
		---@type string?
		BeamEffect = "",
		---@type string?
		Material = "",
		---@type string?
		MaterialType = "",
		---@type string?
		SoundLoop = "",
		---@type string?
		SoundStart = "",
		---@type string?
		SoundStop = "",
		---@type string?
		SoundVocalLoop = "",
		---@type string?
		SoundVocalStart = "",
		---@type string?
		SoundVocalEnd = "",
		---@type string?
		StatusEffect = "",
	}
}

---@param instance table
---@param name string
---@param effectProps VanityEffectProperties
---@return VanityEffect
function VanityEffect:new(instance, name, effectProps)
	instance = instance or {}
	setmetatable(instance, self)
	self.__index = self
	instance.Name = "ARMORY_VANITY_EFFECT_" .. name

	effectProps.Name = nil
	instance.effectProps = TableUtils:DeeplyCopyTable(effectProps)

	return instance
end

if Ext.IsServer() then
	function VanityEffect:buildStat()
		if not Ext.Stats.Get(self.Name) then
			local newStat = Ext.Stats.Create(self.Name, "EFFECT", "_PASSIVES")
			for key, value in pairs(self.effectProps) do
				newStat[key] = value
			end
			newStat:Sync()
		end
	end
end

if Ext.IsClient() then
	Ext.Require("Client/_FormBuilder.lua")

	function VanityEffect:buildForm(parent)
		---@type FormStructure[]
		local formInputs = {}
		for effectProp, value in pairs(self.effectProps) do
			table.insert(formInputs, {
				label = effectProp,
				type = type(value) == "number" and "NumericText" or "Text"
			} --[[@as FormStructure]])
		end

		FormBuilder:CreateForm(parent, function(inputs)
			local newEffect = VanityEffect:new({}, inputs.Name, inputs)
			ConfigurationStructure.config.vanity.effects[newEffect.Name] = newEffect
		end)
	end
end

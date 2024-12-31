-- https://bg3.norbyte.dev/search?q=rarity#result-f23802a9083da2ad18665deb188a569752dc7900

---@enum Rarity
RarityEnum = {
	Uncommon = 1,
	Rare = 2,
	VeryRare = 3,
	Legendary = 4,
	[1] = "Uncommon",
	[2] = "Rare",
	[3] = "VeryRare",
	[4] = "Legendary"
}

RarityColors = {
	Uncommon = { 0.00, 0.66, 0.00, 1.0 },
	Rare = { 0.20, 0.80, 1.00, 1.0 },
	VeryRare = { 0.64, 0.27, 0.91, 1.0 },
	Legendary = { 0.92, 0.78, 0.03, 1.0 },
}

if Ext.IsClient() then
	Translator:RegisterTranslation({
		["Uncommon"] = "hd547009b37a14dc2b8a5140db50ac5013050",
		["Rare"] = "h1e84b7f41e9c477f9cbf104b0c01f5170g1d",
		["VeryRare"] = "hccaa2492212e4dba8dbed27aa5e9f2c6d97g",
		["Legendary"] = "h8e755293e99f4772b83589687d07154e0b4c",
	})
end

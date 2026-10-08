-- Appearance IDs, not shop progression. Gold does not shift saved Sword tiers.
local Palette = {}
Palette.order = { "Iron", "Steel", "Gold", "Frost", "Flame", "Storm", "Fusion", "Void", "Prismatic" }
-- Runtime appearance only: saved sword numbers and server prices are unchanged.
Palette.gameOrder = { "Iron", "Steel", "Gold", "Frost", "Flame", "Storm", "Fusion", "Void" }
Palette.legacy = { "Iron", "Steel", "Frost", "Flame", "Storm", "Prismatic" }
Palette.colors = {
	Iron = Color3.fromRGB(191, 215, 241), Steel = Color3.fromRGB(220, 240, 255),
	Gold = Color3.fromRGB(255, 202, 48), Frost = Color3.fromRGB(83, 226, 255),
	Flame = Color3.fromRGB(255, 104, 35), Storm = Color3.fromRGB(255, 225, 35),
	Prismatic = Color3.fromRGB(255, 57, 201),
	Fusion = Color3.fromRGB(95, 220, 255),
	Void = Color3.fromRGB(181, 82, 255),
	-- Import catalogue only: saved ranks/shop progression remain unchanged.
	TigerClaw = Color3.fromRGB(255, 157, 45), HyenaFang = Color3.fromRGB(222, 169, 83),
	TrexJaw = Color3.fromRGB(224, 100, 46), Meteorite = Color3.fromRGB(255, 97, 38),
}
function Palette.id(value: any): string
	if type(value) == "string" and Palette.colors[value] then return value end
	return Palette.legacy[math.clamp(math.floor(tonumber(value) or 1), 1, #Palette.legacy)]
end
function Palette.color(value: any, phase: number?): Color3
	local id = Palette.id(value)
	if id == "Prismatic" and phase then return Color3.fromHSV(phase % 1, 0.84, 1) end
	return Palette.colors[id]
end
function Palette.sequence(value: any): ColorSequence
	if Palette.id(value) == "Fusion" then
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 100, 25)),
			ColorSequenceKeypoint.new(0.46, Color3.fromRGB(255, 214, 130)),
			ColorSequenceKeypoint.new(0.54, Color3.fromRGB(190, 249, 255)),
			ColorSequenceKeypoint.new(1, Palette.colors.Fusion),
		})
	end
	if Palette.id(value) ~= "Prismatic" then return ColorSequence.new(Palette.color(value)) end
	local keys = {}
	for i = 0, 6 do table.insert(keys, ColorSequenceKeypoint.new(i / 6, Palette.color(value, i / 7))) end
	return ColorSequence.new(keys)
end
return Palette

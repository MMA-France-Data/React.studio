-- Appearance IDs, not shop progression. Gold does not shift saved Sword tiers.
local Palette = {}
Palette.order = { "Iron", "Steel", "Gold", "Frost", "Flame", "Storm", "Prismatic" }
Palette.legacy = { "Iron", "Steel", "Frost", "Flame", "Storm", "Prismatic" }
Palette.colors = {
	Iron = Color3.fromRGB(191, 215, 241), Steel = Color3.fromRGB(220, 240, 255),
	Gold = Color3.fromRGB(255, 202, 48), Frost = Color3.fromRGB(83, 226, 255),
	Flame = Color3.fromRGB(255, 104, 35), Storm = Color3.fromRGB(255, 225, 35),
	Prismatic = Color3.fromRGB(255, 57, 201),
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
	if Palette.id(value) ~= "Prismatic" then return ColorSequence.new(Palette.color(value)) end
	local keys = {}
	for i = 0, 6 do table.insert(keys, ColorSequenceKeypoint.new(i / 6, Palette.color(value, i / 7))) end
	return ColorSequence.new(keys)
end
return Palette

-- Affichage des très grands nombres : 950 · 1.5K · 12.3M · 4.56B · 7.8T · 1.1Qa …
local NumberFormat = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function NumberFormat.short(value: number): string
	if value ~= value then
		return "0"
	end
	local sign = if value < 0 then "-" else ""
	value = math.abs(value)
	if value < 1000 then
		return sign .. tostring(math.floor(value))
	end

	local tier = math.min(math.floor(math.log10(value) / 3), #SUFFIXES - 1)
	local scaled = value / 10 ^ (tier * 3)
	-- 3 chiffres significatifs : 1.23K, 12.3K, 123K
	local text = if scaled >= 100
		then string.format("%d", math.floor(scaled + 1e-6))
		elseif scaled >= 10 then string.format("%.1f", math.floor(scaled * 10 + 1e-6) / 10)
		else string.format("%.2f", math.floor(scaled * 100 + 1e-6) / 100)
	if text:find("%.") then
		text = text:gsub("0+$", ""):gsub("%.$", "")
	end
	return sign .. text .. SUFFIXES[tier + 1]
end

return NumberFormat

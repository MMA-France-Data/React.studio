-- Affichage des très grands nombres : 950 · 1.5K · 12.3M · 4.56B · 7.8T · 1.1Qa …
local NumberFormat = {}

-- Un suffixe tous les x1000, jusqu'à 10^93 (Tg). Au-delà : notation scientifique (1.23e96).
local SUFFIXES = {
	"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", -- jusqu'à 10^30
	"Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", -- 10^33 à 10^60
	"Vg", "Uvg", "Dvg", "Tvg", "Qavg", "Qivg", "Sxvg", "Spvg", "Ocvg", "Novg", -- 10^63 à 10^90
	"Tg", -- 10^93
}

function NumberFormat.short(value: number): string
	if value ~= value then
		return "0"
	end
	local sign = if value < 0 then "-" else ""
	value = math.abs(value)
	if value < 1000 then
		return sign .. tostring(math.floor(value))
	end
	if value == math.huge then
		return sign .. "MAX"
	end

	local tier = math.floor(math.log10(value) / 3)
	if tier >= #SUFFIXES then
		local exponent = math.floor(math.log10(value))
		local mantissa = string.format("%.2f", math.floor(value / 10 ^ exponent * 100 + 1e-6) / 100)
		mantissa = mantissa:gsub("0+$", ""):gsub("%.$", "")
		return sign .. mantissa .. "e" .. exponent
	end
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

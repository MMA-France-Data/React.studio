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

-- Très grands nombres dans un classement (OrderedDataStore, classement solo : SoloLeaderboard.luau). Un
-- OrderedDataStore ne garde que des nombres ENTIERS (jusqu'à ~9,2e18), alors qu'un DPS peut dépasser 1e100.
-- Code = exposant x 1000 + les 3 premiers chiffres du nombre :
--   1 234 567 (1,23... x 10^6) -> 6 x 1000 + 123 = 6123 ;   20 -> 1 x 1000 + 200 = 1200 ;   7,25 -> 0 x 1000 + 725 = 725
-- Un nombre plus grand a toujours un code plus grand ou égal : le tri du classement reste juste (deux nombres qui ont
-- les mêmes 3 premiers chiffres sont à égalité). fromRankCode redonne 1 230 000, 20 et 7,25 : short les affiche
-- exactement comme les vrais nombres (« 1.23M », « 20 », « 7 »), car short ne montre lui aussi que 3 chiffres.
-- nil pour un nombre sous 1 (rien à classer), pas un nombre ou NaN. L'infini (short : « MAX ») a son propre code, au-dessus
-- de tous les autres (INFINITE_CODE, exposant 309 : aucun nombre fini n'y arrive).
local MAX_NUMBER = 1.7976931348623157e308
local INFINITE_CODE = 309100

-- Les 3 premiers chiffres (100 à 999) d'un nombre d'exposant `exponent`, arrondis en dessous comme short.
local function firstDigits(value: number, exponent: number): number
	if exponent >= 3 then
		-- (petite marge 1e-6 comme short : 1,2299999999 x 10^6 affiche « 1.23M », son code aussi)
		return math.floor(value / 10 ^ (exponent - 2) + 1e-6)
	end
	-- Sous 1 000, short affiche la partie entière sans marge : pareil ici (15,9999 -> 159 -> « 15 »).
	return math.floor(value * 10 ^ (2 - exponent))
end

function NumberFormat.toRankCode(value: any): number?
	if type(value) ~= "number" or value ~= value or value < 1 then
		return nil
	elseif value == math.huge then
		return INFINITE_CODE
	end
	local exponent = math.floor(math.log10(value))
	local digits = firstDigits(value, exponent)
	-- Petites erreurs d'arrondi de log10 (ex. 999,99999... vu comme 10^3) : on corrige l'exposant.
	if digits >= 1000 then
		exponent += 1
		digits = firstDigits(value, exponent)
	elseif digits < 100 then
		exponent -= 1
		digits = firstDigits(value, exponent)
	end
	return exponent * 1000 + math.clamp(digits, 100, 999)
end

-- Nombre retrouvé depuis un code de toRankCode (ses 3 premiers chiffres), 0 si le code est abîmé.
function NumberFormat.fromRankCode(code: any): number
	if type(code) ~= "number" or code ~= code or code < 100 then
		return 0
	end
	code = math.floor(code)
	if code >= INFINITE_CODE then
		return math.huge
	end
	local exponent = math.floor(code / 1000)
	local digits = code - exponent * 1000
	if exponent >= 2 then
		return math.min(digits * 10 ^ (exponent - 2), MAX_NUMBER)
	end
	return digits / 10 ^ (2 - exponent)
end

-- Un prix : comme short, mais arrondi AU-DESSUS sous 1 000. Un lancer de l'autel peut coûter 7,0035 pièces
-- (+0,05 % par lancer) : il affiche 8, pas 7 (avec 7 pièces, on ne peut pas le payer). math.huge -> "MAX".
function NumberFormat.price(value: number): string
	if value == value and value >= 0 and value < 1000 then
		return NumberFormat.short(math.ceil(value))
	end
	return NumberFormat.short(value)
end

return NumberFormat

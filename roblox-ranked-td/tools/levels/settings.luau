-- Arguments des outils de réglage (sim, lazy, tune, curve, worth) : "nom=valeur".
--   regler=Levels.CHAMP=valeur;IdleTowers.Defs.Rocket.damage=120   essaie des réglages sans toucher à src.
--     Deux tables se règlent : Levels (src/shared/Levels.luau) et IdleTowers (src/shared/IdleTowers.luau).
--     « * » = toutes les entrées d'une table : Levels.DEFINITIONS.*.gold=80
--     Une table absente en chemin est créée : Levels.TOWER_TWEAKS.Orbital.stunDuration=1
local IdleTowers = require("./gen/shared/IdleTowers")

local Settings = {}

-- Valeur de l'argument "name=..." (nil s'il est absent ou vide).
function Settings.argument(name: string, ...): string?
	for index = 1, select("#", ...) do
		local value = string.match(tostring(select(index, ...)), "^" .. name .. "=(.*)$")
		if value and value ~= "" then
			return value
		end
	end
	return nil
end

-- Applique l'argument "regler=..." aux tables Levels et IdleTowers (et affiche chaque réglage). À appeler avant de
-- jouer : les stats des tours sont gardées en mémoire dès leur premier calcul.
function Settings.apply(Levels, ...)
	local settings = Settings.argument("regler", ...)
	if not settings then
		return
	end
	local roots = { Levels = Levels, IdleTowers = IdleTowers }
	for assignment in string.gmatch(settings, "[^;]+") do
		local rootName, path, value = string.match(assignment, "^%s*(%a+)%.([%w_%.%*]+)%s*=%s*([^%s]+)%s*$")
		assert(rootName and roots[rootName], "Réglage illisible : " .. assignment)
		local targets = { roots[rootName] }
		local keys = string.split(path, ".")
		for i = 1, #keys - 1 do
			local nextTargets = {}
			for _, target in targets do
				if keys[i] == "*" then
					for _, entry in target do
						table.insert(nextTargets, entry)
					end
				else
					local key = tonumber(keys[i]) or keys[i]
					if target[key] == nil then
						target[key] = {}
					end
					table.insert(nextTargets, target[key])
				end
			end
			targets = nextTargets
		end
		local key = keys[#keys]
		for _, target in targets do
			target[tonumber(key) or key] = tonumber(value)
		end
		print(`Réglage : {rootName}.{path} = {value}`)
	end
end

return Settings

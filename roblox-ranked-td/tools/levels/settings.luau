-- Arguments des outils de réglage (sim, lazy, tune, curve, explore) : "nom=valeur".
--   regler=Levels.CHAMP=valeur;Levels.Autre.champ=valeur   essaie des réglages sans toucher à src.
--     « * » = toutes les entrées d'une table : Levels.DEFINITIONS.*.ramp.1=0.5
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

-- Applique l'argument "regler=..." à la table Levels (et affiche chaque réglage).
function Settings.apply(Levels, ...)
	local settings = Settings.argument("regler", ...)
	if not settings then
		return
	end
	for assignment in string.gmatch(settings, "[^;]+") do
		local path, value = string.match(assignment, "^%s*Levels%.([%w_%.%*]+)%s*=%s*([^%s]+)%s*$")
		assert(path, "Réglage illisible : " .. assignment)
		local targets = { Levels }
		local keys = string.split(path, ".")
		for i = 1, #keys - 1 do
			local nextTargets = {}
			for _, target in targets do
				if keys[i] == "*" then
					for _, entry in target do
						table.insert(nextTargets, entry)
					end
				else
					table.insert(nextTargets, target[tonumber(keys[i]) or keys[i]])
				end
			end
			targets = nextTargets
		end
		local key = keys[#keys]
		for _, target in targets do
			target[tonumber(key) or key] = tonumber(value)
		end
		print(`Réglage : Levels.{path} = {value}`)
	end
end

return Settings

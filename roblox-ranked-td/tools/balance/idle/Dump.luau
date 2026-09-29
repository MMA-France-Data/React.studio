--!optimize 2
-- Calcul en parallèle (run.ps1 -Paralleles) : chaque partie (scénario, graine) est jouée par son propre
-- processus luau ("travail=1"), qui écrit ses résultats sous forme de texte Luau (une table) ; un dernier
-- processus ("assembler=...") relit toutes les parties et écrit le rapport, exactement comme s'il les avait
-- jouées lui-même. Ce module transforme une partie terminée en texte Luau (sur une seule ligne).
local Dump = {}

-- Champs d'une partie qui ne servent pas au rapport (caches, tirages, journal) : pas écrits.
Dump.SKIP = {
	scenario = true, -- remis par l'assembleur (Run.SCENARIOS[scenarioId])
	rng = true,
	journal = true,
	compiledList = true,
	memo = true,
	recent = true,
	typesCache = true,
	powers = true,
	unlockValues = true,
	failLeak = true,
	pendingCycle = true,
}

local function isIdentifier(key: string): boolean
	return string.match(key, "^[%a_][%w_]*$") ~= nil
		and key ~= "and" and key ~= "break" and key ~= "do" and key ~= "else" and key ~= "elseif"
		and key ~= "end" and key ~= "false" and key ~= "for" and key ~= "function" and key ~= "if"
		and key ~= "in" and key ~= "local" and key ~= "nil" and key ~= "not" and key ~= "or"
		and key ~= "repeat" and key ~= "return" and key ~= "then" and key ~= "true" and key ~= "until"
		and key ~= "while" and key ~= "continue"
end

local function quote(text: string): string
	text = string.gsub(text, "\\", "\\\\")
	text = string.gsub(text, "\"", "\\\"")
	text = string.gsub(text, "%c", function(char)
		return string.format("\\%03d", string.byte(char))
	end)
	return "\"" .. text .. "\""
end

local function number(value: number): string
	if value ~= value then
		return "(0/0)"
	elseif value == math.huge then
		return "math.huge"
	elseif value == -math.huge then
		return "(-math.huge)"
	elseif value == math.floor(value) and math.abs(value) < 1e15 then
		return string.format("%d", value)
	end
	return string.format("%.17g", value)
end

-- Texte Luau d'une valeur (tables : récursif ; fonctions et objets inconnus : ignorés). Une table déjà en
-- cours d'écriture (boucle) arrête tout avec son chemin : ajouter le champ à Dump.SKIP.
local function write(value: any, out: { string }, visiting: { [any]: boolean }, path: string, top: boolean)
	local kind = type(value)
	if kind == "number" then
		table.insert(out, number(value))
	elseif kind == "string" then
		table.insert(out, quote(value))
	elseif kind == "boolean" then
		table.insert(out, if value then "true" else "false")
	elseif kind == "table" then
		if visiting[value] then
			error(`Dump : boucle dans la partie (champ {path}) : ajoute-le à Dump.SKIP`)
		end
		visiting[value] = true
		table.insert(out, "{")
		for key, item in value do
			local itemKind = type(item)
			if (top and type(key) == "string" and Dump.SKIP[key]) or itemKind == "function" or itemKind == "userdata" or itemKind == "thread" then
				continue
			end
			local keyKind = type(key)
			if keyKind == "string" then
				if isIdentifier(key) then
					table.insert(out, key)
				else
					table.insert(out, "[" .. quote(key) .. "]")
				end
			elseif keyKind == "number" then
				table.insert(out, "[" .. number(key) .. "]")
			elseif keyKind == "boolean" then
				table.insert(out, if key then "[true]" else "[false]")
			else
				continue -- clé table ou fonction : jamais utilisée par le rapport
			end
			table.insert(out, "=")
			write(item, out, visiting, path .. "." .. tostring(key), false)
			table.insert(out, ",")
		end
		table.insert(out, "}")
		visiting[value] = nil
	else
		table.insert(out, "nil")
	end
end

-- Partie terminée -> texte Luau d'une table (une seule ligne), avec scenarioId pour la relire.
function Dump.run(run, scenarioId: string): string
	local out = table.create(4096)
	write(run, out, {}, "partie", true)
	-- scenarioId ajouté à la fin de la table (avant l'accolade fermante)
	out[#out] = `scenarioId={quote(scenarioId)},}`
	return table.concat(out)
end

return Dump

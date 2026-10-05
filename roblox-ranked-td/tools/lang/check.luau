-- Vérifie les dictionnaires (anglais, espagnol, portugais) sans ouvrir Studio (depuis le dossier roblox-ranked-td) :
--   luau.exe tools/lang/check.luau
--       -> nombre de traductions chargées dans chaque langue et problèmes (doublons, modèles impossibles, ligne de
--          LangEN absente de LangES ou de LangPT, ou l'inverse, {n} différents de l'anglais...)
--   luau.exe tools/lang/check.luau -a "Niv. 5" "Impossible de charger tes donn\u{e9}es. R\u{e9}essaie dans une minute."
--       -> traduit aussi ces textes dans les 3 langues (écrire \n pour un retour à la ligne). Le terminal de Windows
--          abîme souvent les accents passés ainsi : écrire \u{e8} pour è, \u{e9} pour é, \u{e0} pour à... ou, mieux,
--          écrire ses textes dans un petit fichier .luau qui fait  local Lang = require("<chemin>/tools/lang/load")
--          (fichier en UTF-8).
-- Sortie : 0 si aucun problème, 1 sinon (les textes sans traduction ne sont pas des problèmes : ils sont listés).
local Lang = require("./load")

local FILES = { "Glossary", "Game" } -- (comme dans load.luau)
local OTHERS = { "es", "pt" }

local problems = Lang.getProblems()

-- Les {n} d'un texte, triés : « {2} … {1} » -> "1,2".
local function placeholders(text: string): string
	local list = {}
	for number in string.gmatch(text, "{(%d+)}") do
		table.insert(list, number)
	end
	table.sort(list)
	return table.concat(list, ",")
end

-- Chaque ligne de LangEN doit être dans le même fichier de LangES et de LangPT, avec les mêmes {n} ; et rien de plus.
for _, name in FILES do
	local english = require("../../src/shared/LangEN/" .. name)
	for _, language in OTHERS do
		local folder = Lang.FOLDERS[language]
		local other = require(`../../src/shared/{folder}/{name}`)
		for key, value in english do
			local translated = other[key]
			if translated == nil then
				table.insert(problems, `{folder}/{name} : ligne absente (le joueur verra l'anglais) : « {key} »`)
			elseif placeholders(translated) ~= placeholders(value) then
				table.insert(problems, folder .. "/" .. name .. " : pas les mêmes {n} que l'anglais : « " .. key .. " »")
			end
		end
		for key in other do
			if english[key] == nil then
				table.insert(problems, `{folder}/{name} : ligne absente de LangEN/{name} (à y ajouter aussi) : « {key} »`)
			end
		end
	end
end

print(`{Lang.entryCount("en")} traductions en anglais, {Lang.entryCount("es")} en espagnol, {Lang.entryCount("pt")} en portugais, {#problems} problème(s)`)
for _, message in problems do
	print("  PROBLÈME : " .. message)
end

for index = 1, select("#", ...) do
	local text = string.gsub(select(index, ...), "\\n", "\n")
	text = string.gsub(text, "\\u{(%x+)}", function(code)
		return utf8.char(tonumber(code, 16))
	end)
	print(`« {text} »`)
	for _, language in { "en", "es", "pt" } do
		print(`  {language} -> « {Lang.translate(text, language)} »`)
	end
end

for _, language in { "en", "es", "pt" } do
	local misses = Lang.getMisses(language)
	if #misses > 0 then
		print(`{#misses} texte(s) sans traduction ({language}) :`)
		for _, text in misses do
			print("  « " .. text .. " »")
		end
	end
end

if #problems > 0 then
	error(`{#problems} problème(s) dans les dictionnaires`, 0)
end

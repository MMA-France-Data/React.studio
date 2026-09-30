-- Vérifie les dictionnaires anglais sans ouvrir Studio (depuis le dossier roblox-ranked-td) :
--   luau.exe tools/lang/check.luau
--       -> nombre de traductions chargées et problèmes (doublons, modèles impossibles...)
--   luau.exe tools/lang/check.luau -a "Vague 5" "Il te faut 1.5K pi\u{e8}ces pour x10"
--       -> traduit aussi ces textes (écrire \n pour un retour à la ligne). Le terminal de Windows abîme souvent les
--          accents passés ainsi : écrire \u{e8} pour è, \u{e9} pour é, \u{e0} pour à... ou, mieux, écrire ses textes
--          dans un petit fichier .luau qui fait  local Lang = require("<chemin>/tools/lang/load")  (fichier en UTF-8).
-- Sortie : 0 si aucun problème, 1 sinon (les textes sans traduction ne sont pas des problèmes : ils sont listés).
local Lang = require("./load")

local problems = Lang.getProblems()
print(`{Lang.entryCount()} traductions chargées, {#problems} problème(s)`)
for _, message in problems do
	print("  PROBLÈME : " .. message)
end

for index = 1, select("#", ...) do
	local text = string.gsub(select(index, ...), "\\n", "\n")
	text = string.gsub(text, "\\u{(%x+)}", function(code)
		return utf8.char(tonumber(code, 16))
	end)
	print(`« {text} »`)
	print(`  -> « {Lang.translate(text, "en")} »`)
end

local misses = Lang.getMisses()
if #misses > 0 then
	print(`{#misses} texte(s) sans traduction :`)
	for _, text in misses do
		print("  « " .. text .. " »")
	end
end

if #problems > 0 then
	error(`{#problems} problème(s) dans les dictionnaires`, 0)
end

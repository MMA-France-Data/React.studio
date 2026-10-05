-- Charge la traduction du jeu HORS de Roblox (pour luau.exe) : Shared/Lang.luau et tous les dictionnaires de
-- src/shared/LangEN (anglais), LangES (espagnol) et LangPT (portugais), dans le même ordre que dans le jeu (le
-- Glossaire d'abord). Renvoie Lang.
--   local Lang = require("./load")          (depuis un script de ce dossier)
--   print(Lang.translate("Niv. 5", "en"))   (ou "es", "pt")
-- Un nouveau fichier dans src/shared/LangEN (et donc dans LangES et LangPT) : l'ajouter aussi dans la liste FILES
-- ci-dessous.
-- Vérifications : check.luau (problèmes des dictionnaires, lignes manquantes en espagnol ou en portugais), tests.luau
-- (le traducteur), samples.luau (les textes du jeu et leur traduction attendue).
local Lang = require("../../src/shared/Lang")

local FILES = { "Glossary", "Game" }
local LANGUAGES = { "en", "es", "pt" }

Lang.setRecordMisses(true) -- (comme dans Studio : les textes sans traduction sont notés, Lang.getMisses)
for _, language in LANGUAGES do
	local folder = Lang.FOLDERS[language]
	for _, name in FILES do
		Lang.addDictionary(require(`../../src/shared/{folder}/{name}`), `{folder}/{name}`, language)
	end
end

return Lang

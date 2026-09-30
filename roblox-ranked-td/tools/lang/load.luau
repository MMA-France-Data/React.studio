-- Charge la traduction du jeu HORS de Roblox (pour luau.exe) : Shared/Lang.luau et tous les dictionnaires de
-- src/shared/LangEN, dans le même ordre que dans le jeu (le Glossaire d'abord). Renvoie Lang.
--   local Lang = require("./load")          (depuis un script de ce dossier)
--   print(Lang.translate("Vague 5", "en"))
-- Un nouveau fichier dans src/shared/LangEN : l'ajouter aussi dans la liste FILES ci-dessous.
local Lang = require("../../src/shared/Lang")

local FILES = { "Glossary", "Machines", "Plot", "Server", "Social" }

Lang.setRecordMisses(true) -- (comme dans Studio : les textes sans traduction sont notés, Lang.getMisses)
for _, name in FILES do
	Lang.addDictionary(require("../../src/shared/LangEN/" .. name), name)
end

return Lang

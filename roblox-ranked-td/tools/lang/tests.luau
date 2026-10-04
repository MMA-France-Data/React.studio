-- Tests du traducteur (Shared/Lang.luau) sans Studio, avec un petit dictionnaire de test (depuis roblox-ranked-td) :
--   luau.exe tools/lang/tests.luau
-- Puis les vrais dictionnaires (src/shared/LangEN) doivent se charger sans problème. Sortie 1 si un test échoue.
local Lang = require("../../src/shared/Lang")

local passed, failed = 0, 0
local function check(ok: boolean, label: string, detail: string?)
	if ok then
		passed += 1
	else
		failed += 1
		print("[FAIL] " .. label .. (if detail then " : " .. detail else ""))
	end
end
local function same(label: string, got: any, expected: any)
	check(got == expected, label, `obtenu « {tostring(got)} », attendu « {tostring(expected)} »`)
end
local function en(text: string): string
	return Lang.translate(text, "en")
end
local function hasValue(list: { string }, value: string): boolean
	return table.find(list, value) ~= nil
end

Lang.reset()
Lang.setRecordMisses(true)
Lang.addDictionary({
	-- noms (comme le Glossaire)
	["Archer du rempart"] = "Rampart Archer",
	["Oracle de la foudre"] = "Lightning Oracle",
	["Légendaire"] = "Legendary",
	["Écuyer"] = "Squire",
	-- textes exacts
	["Suivant"] = "Next",
	["⚔ JOUER AU NIVEAU"] = "⚔ PLAY THE LEVEL",
	["Ligne un\nLigne deux"] = "Line one\nLine two",
	["<b>Rejouer</b>"] = "<b>Replay</b>",
	["Tu gardes tout le reste :"] = "You keep everything else:",
	-- modèles
	["Vague {1}"] = "Wave {1}",
	["Vague {1} requise"] = "Wave {1} required",
	["Il te faut {1} pièces pour {2}"] = "You need {1} coins for {2}",
	["Niveau {1} de {2}"] = "{2} level {1}",
	["Maximum {1} {2} sur ta parcelle ({3})"] = "Max {1} {2} on your plot ({3})",
	["{1} : vends-en une pour en poser une autre"] = "{1}: sell one to place another",
	["Prochain lancer : +{1} % à chaque achat"] = "Next roll: +{1}% per purchase",
	["Étourdit {1} s"] = "Stuns {1} s",
	["Dégâts <b>{1}</b> par coup"] = "Damage <b>{1}</b> per hit",
	["+{1} % de pièces"] = "+{1}% coins",
	["Zone rayon {1}"] = "Area radius {1}",
	["Ralentit {1} %"] = "Slows {1}%",
	["{1} monstres"] = "{1} monsters",
	["{1} contre {2}"] = "{1} vs {2}",
	["Adversaire : {1}"] = "Opponent: {1}",
	["déjà {1} lancers"] = "already {1} rolls",
	["Améliorer [E] • {1}"] = "Upgrade [E] • {1}",
	['<font color="#D8AA4C">Effets :</font> {1}'] = '<font color="#D8AA4C">Effects:</font> {1}',
	["x20 dégâts"] = "x20 damage",
	["x2 vitesse"] = "x2 speed",
	["Titre {1}\nDétail {2}"] = "Title {1}\nDetail {2}",
})

-- Langues
same("fromLocale fr-fr", Lang.fromLocale("fr-fr"), "fr")
same("fromLocale FR-CA", Lang.fromLocale("FR-CA"), "fr")
same("fromLocale en-us", Lang.fromLocale("en-us"), "en")
same("fromLocale es-es", Lang.fromLocale("es-es"), "en")
same("fromLocale vide", Lang.fromLocale(""), "en")
same("fromLocale nil", Lang.fromLocale(nil), "en")
same("current hors de Roblox", Lang.current(), "fr")
same("translate sans langue hors de Roblox = français", Lang.translate("Suivant"), "Suivant")

-- Français : rien ne change
same("français inchangé", Lang.translate("Vague 5", "fr"), "Vague 5")
same("fr-ca inchangé", Lang.translate("Suivant", "fr-ca"), "Suivant")
same("en-us = anglais", Lang.translate("Suivant", "en-us"), "Next")

-- Exact
same("exact", en("Suivant"), "Next")
same("exact avec emoji et accents", en("⚔ JOUER AU NIVEAU"), "⚔ PLAY THE LEVEL")
same("exact sur 2 lignes", en("Ligne un\nLigne deux"), "Line one\nLine two")
same("exact avec RichText", en("<b>Rejouer</b>"), "<b>Replay</b>")
same("nom seul", en("Archer du rempart"), "Rampart Archer")

-- Modèles
same("modèle 1 valeur", en("Vague 12"), "Wave 12")
same("modèle le plus précis gagne", en("Vague 15 requise"), "Wave 15 required")
same("modèle 2 valeurs", en("Il te faut 1.5K pièces pour x10"), "You need 1.5K coins for x10")
same("modèle 2 valeurs dans l'autre ordre", en("Niveau 3 de Archer du rempart"), "Rampart Archer level 3")
same(
	"modèle 3 valeurs, noms traduits",
	en("Maximum 2 Oracle de la foudre sur ta parcelle (Légendaire)"),
	"Max 2 Lightning Oracle on your plot (Legendary)"
)
same(
	"valeur qui est elle-même un modèle",
	en("Maximum 2 Oracle de la foudre sur ta parcelle (Légendaire) : vends-en une pour en poser une autre"),
	"Max 2 Lightning Oracle on your plot (Legendary): sell one to place another"
)
same("modèle qui commence par {1}", en("12 monstres"), "12 monsters")
same("modèle qui commence et finit par {n}", en("Archer du rempart contre Écuyer"), "Rampart Archer vs Squire")
same("valeur inconnue gardée", en("Adversaire : Bot42"), "Opponent: Bot42")

-- Virgules des nombres
same("virgule -> point", en("Prochain lancer : +0,05 % à chaque achat"), "Next roll: +0.05% per purchase")
same("virgule -> point (2)", en("Étourdit 0,5 s"), "Stuns 0.5 s")
same("nombre sans virgule inchangé", en("Étourdit 2 s"), "Stuns 2 s")

-- RichText
same("modèle avec balises", en("Dégâts <b>1.5K</b> par coup"), "Damage <b>1.5K</b> per hit")
same(
	"texte entier dans une balise",
	en('<font color="#ECC069">+1,5 % de pièces</font>'),
	'<font color="#ECC069">+1.5% coins</font>'
)
same("balise autour d'un texte exact", en("<i>Suivant</i>"), "<i>Next</i>")

-- Espaces autour, lignes, morceaux
same("espaces autour", en("  Suivant  "), "  Next  ")
same("ligne par ligne", en("Vague 5\nSuivant"), "Wave 5\nNext")
same("morceaux « · »", en("Zone rayon 7 · Ralentit 60 %"), "Area radius 7 · Slows 60%")
same("morceaux « • » avec espaces", en("Vague 3  •  déjà 12 lancers"), "Wave 3  •  already 12 rolls")
same("lignes et morceaux", en("Suivant\nZone rayon 7 · Ralentit 60 %"), "Next\nArea radius 7 · Slows 60%")
same("modèle avec « • » dans ses mots fixes", en("Améliorer [E] • 1.5K"), "Upgrade [E] • 1.5K")
same(
	"ligne d'effets (balises, morceaux, valeurs dans des balises)",
	en('<font color="#D8AA4C">Effets :</font> <b>x20 dégâts</b>  •  <b>x2 vitesse</b>'),
	'<font color="#D8AA4C">Effects:</font> <b>x20 damage</b>  •  <b>x2 speed</b>'
)
same("modèle sur 2 lignes", en("Titre A\nDétail B"), "Title A\nDetail B")

-- Symboles, emoji, étoiles ou nombres au début ou à la fin : le milieu est traduit, le reste est remis
same("emoji devant un nom", en("🔒 Archer du rempart"), "🔒 Rampart Archer")
same("étoiles derrière un nom", en("Archer du rempart ★★"), "Rampart Archer ★★")
same("numéro devant, étoiles derrière", en("1. Archer du rempart ★★"), "1. Rampart Archer ★★")
same("emoji devant un modèle qui finit par un nombre", en("🔒 Vague 5"), "🔒 Wave 5")
same("guillemets autour d'un mot", en("« Suivant »"), "« Next »")
same("nombre à virgule devant un mot", en("+0,3 Suivant"), "+0.3 Next")
same("emoji devant un texte exact qui a déjà sa ligne", en("⚔ JOUER AU NIVEAU"), "⚔ PLAY THE LEVEL")
same("dans un morceau", en("🔒 Archer du rempart • Vague 3"), "🔒 Rampart Archer • Wave 3")
same("ponctuation à l'anglaise après le milieu", en("Suivant !"), "Next!")
same("ponctuation à l'anglaise (2)", en("🔒 Suivant : 3"), "🔒 Next: 3")
same("plusieurs lignes : chaque ligne à part", en("Suivant :\n+32 💵"), "Next:\n+32 💵")
Lang.clearMisses()
same("emoji devant un texte inconnu : gardé", en("🔒 Tour inconnue ★"), "🔒 Tour inconnue ★")
check(hasValue(Lang.getMisses(), "🔒 Tour inconnue ★"), "emoji devant un texte inconnu : noté")

-- Textes sans mot : jamais cherchés, jamais notés
Lang.clearMisses()
for _, text in { "1.5K", "💰 1.5K", "x10", "×3", "12:34", "+5", "1e96", "✓", "", "10s" } do
	same(`sans mot inchangé « {text} »`, en(text), text)
end
same("sans mot : aucun manque noté", #Lang.getMisses(), 0)
same("sans mot : rien en mémoire", Lang.cacheSize("en"), 0)
check(Lang.hasWords("Niv. 3"), "hasWords « Niv. 3 »")
check(not Lang.hasWords("2.3Qa"), "hasWords « 2.3Qa »")
-- Nombres seuls écrits à la française (ex. chiffres de la fiche d'une tour) : en anglais, virgule -> point, pas d'espace
-- avant « % », et rien de noté
same("nombre seul : virgule -> point", en("7,5"), "7.5")
same("nombre seul : pourcentage", en("2,5 %"), "2.5%")
same("nombre seul : en français inchangé", Lang.translate("7,5", "fr"), "7,5")
same("ligne sans mot dans un texte", en("Vague 5\n2,5 %"), "Wave 5\n2.5%")
same("morceau sans mot dans une ligne", en("Zone rayon 7 · 2,5 %"), "Area radius 7 · 2.5%")
same("nombres seuls : aucun manque noté", #Lang.getMisses(), 0)

-- Textes inconnus : gardés en français et notés une seule fois
Lang.clearMisses()
same("inconnu gardé", en("Texte inconnu"), "Texte inconnu")
en("Texte inconnu")
local misses = Lang.getMisses()
check(#misses == 1 and misses[1] == "Texte inconnu", "inconnu noté une fois", table.concat(misses, " | "))
same("ligne inconnue gardée", en("Vague 5\nAutre ligne"), "Wave 5\nAutre ligne")
check(hasValue(Lang.getMisses(), "Autre ligne"), "ligne inconnue notée seule")
same("morceau inconnu gardé", en("Zone rayon 7 · Morceau inconnu"), "Area radius 7 · Morceau inconnu")
check(hasValue(Lang.getMisses(), "Morceau inconnu"), "morceau inconnu noté seul")
check(not hasValue(Lang.getMisses(), "Zone rayon 7 · Morceau inconnu"), "ligne à moitié traduite pas notée entière")

-- Mémoire (cache)
Lang.clearMisses()
same("mémoire vide après clearMisses", Lang.cacheSize("en"), 0)
en("Vague 7")
en("Vague 7")
same("mémoire : un texte gardé une fois", Lang.cacheSize("en"), 1)
same("mémoire : même résultat", en("Vague 7"), "Wave 7")
for wave = 1, 4100 do
	en(`Vague {wave}`)
end
check(Lang.cacheSize("en") <= 4000, "mémoire bornée", `{Lang.cacheSize("en")} textes`)
same("mémoire bornée : traduction toujours juste", en("Vague 4100"), "Wave 4100")

-- Problèmes des dictionnaires
Lang.addDictionary({
	["Suivant"] = "Continue", -- doublon avec une autre traduction
	["{1} {2}"] = "{1} {2}", -- aucun mot fixe
	["Gain {1}"] = "Gain {2}", -- {2} absent du français
	["Sans trou"] = "No {1}", -- {1} dans la traduction seulement
}, "Test2")
local problems = Lang.getProblems()
same("problèmes trouvés", #problems, 4)
same("doublon : la première traduction gagne", en("Suivant"), "Next")
same("modèle sans mot fixe ignoré", en("Oracle Écuyer"), "Oracle Écuyer")

-- Rapidité : 500 modèles, 3000 textes différents (ni exacts, ni en mémoire)
Lang.reset()
Lang.setRecordMisses(false)
local big = {}
for index = 1, 500 do
	big["Phrase numéro " .. index .. " avec {1} pièces et {2}"] = "Sentence " .. index .. " with {1} coins and {2}"
end
Lang.addDictionary(big, "Gros")
same("gros dictionnaire", en("Phrase numéro 250 avec 1.5K pièces et x10"), "Sentence 250 with 1.5K coins and x10")
local started = os.clock()
for index = 1, 3000 do
	en(`Phrase numéro {index % 500 + 1} avec {index} pièces et x{index}`)
end
local perText = (os.clock() - started) / 3000 * 1e6
print(string.format("rapidité : %.1f µs par texte nouveau (500 modèles)", perText))
check(perText < 300, "rapidité", string.format("%.1f µs par texte", perText))
started = os.clock()
for index = 1, 3000 do
	en(`Texte jamais vu numéro {index} sans modèle`)
end
perText = (os.clock() - started) / 3000 * 1e6
print(string.format("rapidité : %.1f µs par texte inconnu (500 modèles)", perText))
check(perText < 300, "rapidité (inconnus)", string.format("%.1f µs par texte", perText))

-- Les vrais dictionnaires (src/shared/LangEN) se chargent sans problème.
Lang.reset()
local Real = require("./load")
local realProblems = Real.getProblems()
check(#realProblems == 0, "vrais dictionnaires sans problème", table.concat(realProblems, " | "))
print(`vrais dictionnaires : {Real.entryCount()} traductions`)
same("glossaire chargé", Real.translate("Trébuchet royal", "en"), "Royal Trebuchet")

print(`{passed} tests réussis, {failed} ratés`)
if failed > 0 then
	error(`{failed} test(s) raté(s)`, 0)
end

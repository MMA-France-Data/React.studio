-- Glossaire : les noms du jeu et LEUR traduction anglaise, la même partout (panneaux, fenêtres, messages...).
-- Les autres dictionnaires de ce dossier reprennent exactement ces mots anglais. Ce fichier est lu en premier : en
-- cas de doublon, sa traduction gagne (voir Shared/Lang.luau).
-- Chaque nom seul est une clé exacte : il est traduit quand il s'affiche seul (ex. le nom d'une tour sur son
-- emplacement du camp), et quand il est la valeur d'un {n} dans une phrase.
-- Style de l'anglais : court, clair, amical, le même ton que le français (« tu » -> « you »), aussi court ou plus
-- court (boutons !), mêmes emoji et balises, nombres et suffixes inchangés (1.5K, 2.3M...).
return {
	-- Tours (IdleTowers.luau)
	["Archer du rempart"] = "Rampart Archer",
	["Totem de givre"] = "Frost Totem",
	["Catapulte"] = "Catapult",
	["Mage des tempêtes"] = "Storm Mage",
	["Baliste lourde"] = "Heavy Ballista",
	["Sorcier des arcanes"] = "Arcane Sorcerer",
	["Oracle de la foudre"] = "Lightning Oracle",
	["Trébuchet royal"] = "Royal Trebuchet",

	-- Monstres (Enemies.luau)
	["Écuyer"] = "Squire",
	["Fantassin"] = "Footman",
	["Cavalier"] = "Rider",
	["Chevalier lourd"] = "Heavy Knight",
	["Chevalier colossal"] = "Colossal Knight",
	["Seigneur de guerre"] = "Warlord",
}

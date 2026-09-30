-- Glossaire : les noms du jeu et LEUR traduction anglaise, la même partout (fenêtres, fiches, messages, tuto...).
-- Les autres dictionnaires de ce dossier reprennent exactement ces mots anglais. Ce fichier est lu en premier : en
-- cas de doublon, sa traduction gagne (voir Shared/Lang.luau).
-- Chaque nom seul est une clé exacte : il est traduit quand il s'affiche seul (ex. titre d'une carte de tour), et
-- quand il est la valeur d'un {n} dans une phrase (« Maximum {1} {2} sur ta parcelle ({3}) »).
-- Style de l'anglais : court, clair, amical, le même ton que le français (« tu » -> « you »), aussi court ou plus
-- court (boutons !), mêmes emoji et balises, nombres et suffixes inchangés (1.5K, 2.3M, Qa...).
-- « fief » -> keep et « parcelle » -> plot : dire « plot » dans les consignes, « keep » seulement là où le français
-- dit « fief ». « record » -> best wave ou record selon la phrase (pas de ligne ici : le sens dépend de la phrase).
return {
	-- Tours du mode solo (IdleTowers.luau)
	["Archer du rempart"] = "Rampart Archer",
	["Totem de givre"] = "Frost Totem",
	["Catapulte"] = "Catapult",
	["Mage des tempêtes"] = "Storm Mage",
	["Baliste lourde"] = "Heavy Ballista",
	["Sorcier des arcanes"] = "Arcane Sorcerer",
	["Oracle de la foudre"] = "Lightning Oracle",
	["Trébuchet royal"] = "Royal Trebuchet",

	-- Raretés (IdleConfig.RARITIES)
	["Commune"] = "Common",
	["Rare"] = "Rare",
	["Épique"] = "Epic",
	["Légendaire"] = "Legendary",

	-- Machines et menus
	["Autel des héros"] = "Heroes' Altar",
	["Forge runique"] = "Rune Forge",
	["Renaissance"] = "Rebirth",
	["Classé"] = "Ranked",
	["Défis"] = "Challenges",
	["Boutique"] = "Shop",

	-- Ennemis (Enemies.luau)
	["Écuyer"] = "Squire",
	["Fantassin"] = "Footman",
	["Cavalier"] = "Rider",
	["Chevalier lourd"] = "Heavy Knight",
	["Chevalier colossal"] = "Colossal Knight",
	["Seigneur de guerre"] = "Warlord",

	-- Passes de jeu (Robux, mode solo)
	["Pass"] = "Pass",
	["Vitesse x2"] = "Speed x2",
	["Pièces x2"] = "Coins x2",
	["Ramassage auto"] = "Auto collect",

	-- Mots du jeu
	["rune"] = "rune",
	["runes"] = "runes",
	["doublon"] = "duplicate",
	["doublons"] = "duplicates",
	["fief"] = "keep",
	["parcelle"] = "plot",
	["vague"] = "wave",
	["Vague"] = "Wave",
	["pièces"] = "coins",
	["Pièces"] = "Coins",
	["MMR"] = "MMR",
	["saison"] = "season",
	["Saison"] = "Season",
	["tuto"] = "tutorial",
	["Tuto"] = "Tutorial",
}

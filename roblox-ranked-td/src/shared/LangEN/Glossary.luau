-- Glossaire : les noms du jeu et LEUR traduction anglaise, la même partout (panneaux, fenêtres, messages...).
-- Les autres dictionnaires de ce dossier reprennent exactement ces mots anglais. Ce fichier est lu en premier : en
-- cas de doublon, sa traduction gagne (voir Shared/Lang.luau).
-- Chaque nom seul est une clé exacte : il est traduit quand il s'affiche seul (ex. le nom d'une tour sur son
-- emplacement du camp), quand il est la valeur d'un {n} dans une phrase, et quand il est entouré de symboles
-- (« 🔒 Totem de givre », « Archer du rempart ★★ », « 1. Catapulte »).
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
	-- Tours de palier 2 (œufs)
	["Archer enflammé"] = "Flaming Archer",
	["Totem du blizzard"] = "Blizzard Totem",
	["Catapulte de magma"] = "Magma Catapult",
	["Archimage des tempêtes"] = "Storm Archmage",
	["Baliste du dragon"] = "Dragon Ballista",
	["Sorcier du néant"] = "Void Sorcerer",
	["Oracle du tonnerre"] = "Thunder Oracle",
	["Trébuchet céleste"] = "Celestial Trebuchet",

	-- Noms courts des tours, sur la barre d'un niveau (client/LevelsUI.luau, SHORT_NAMES ; « Catapulte » : plus haut)
	["Archer"] = "Archer",
	["Totem"] = "Totem",
	["Mage"] = "Mage",
	["Baliste"] = "Ballista",
	["Sorcier"] = "Sorcerer",
	["Oracle"] = "Oracle",
	["Trébuchet"] = "Trebuchet",
	["Enflammé"] = "Flaming",
	["Blizzard"] = "Blizzard",
	["Magma"] = "Magma",
	["Archimage"] = "Archmage",
	["Dragon"] = "Dragon",
	["Néant"] = "Void",
	["Tonnerre"] = "Thunder",
	["Céleste"] = "Celestial",

	-- Monstres (Enemies.luau)
	["Écuyer"] = "Squire",
	["Fantassin"] = "Footman",
	["Cavalier"] = "Rider",
	["Chevalier lourd"] = "Heavy Knight",
	["Chevalier colossal"] = "Colossal Knight",
	["Seigneur de guerre"] = "Warlord",

	-- Territoires : le nom de leur carte (Levels.MAPS)
	["La vallée du Roi carmin"] = "The Crimson King's Valley",
	["Le col des Pillards de cuivre"] = "The Copper Raiders' Pass",
	["La forêt des Gardiens des ronces"] = "The Bramble Wardens' Forest",
	["Le glacier de la Légion du givre"] = "The Frost Legion's Glacier",
	["Le désert des Gardes des dunes"] = "The Dune Guards' Desert",
	["La nécropole de la Légion des os"] = "The Bone Legion's Necropolis",
	["La citadelle de la Garde de la tempête"] = "The Storm Guard's Citadel",
	["Le volcan des Chevaliers d'obsidienne"] = "The Obsidian Knights' Volcano",
	["Les marais de la Horde gobeline"] = "The Goblin Horde's Swamp",
	["Le repaire de la Couvée du dragon"] = "The Dragon Brood's Lair",

	-- Évolutions des tours (Levels.PERKS : name)
	["Flèches enflammées"] = "Flaming arrows",
	["Longue-vue"] = "Spyglass",
	["Tir rapide"] = "Rapid fire",
	["Givre mordant"] = "Biting frost",
	["Grande aura"] = "Wide aura",
	["Gel profond"] = "Deep freeze",
	["Gros rochers"] = "Big rocks",
	["Bras long"] = "Long arm",
	["Rechargement rapide"] = "Quick reload",
	["Éclair large"] = "Wide bolt",
	["Long regard"] = "Far sight",
	["Tempête"] = "Tempest",
	["Carreau perçant"] = "Piercing bolt",
	["Tir tendu"] = "Flat shot",
	["Treuil graissé"] = "Greased winch",
	["Concentration"] = "Focus",
	["Long rayon"] = "Long beam",
	["Surchauffe"] = "Overheat",
	["Éclair bondissant"] = "Leaping bolt",
	["Vision lointaine"] = "Distant vision",
	["Orage"] = "Thunderstorm",
	["Pierre géante"] = "Giant stone",
	["Onde de choc"] = "Shockwave",
	["Contrepoids"] = "Counterweight",
}

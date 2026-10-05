-- Glossaire espagnol : les noms du jeu et LEUR traduction espagnole, la même partout (panneaux, fenêtres, messages...).
-- Mêmes lignes (même texte français) que src/shared/LangEN/Glossary.luau : une ligne ajoutée là s'ajoute aussi ici
-- (sinon le joueur hispanophone voit l'anglais, et tools/lang/check.luau le signale). Ce fichier est lu en premier :
-- en cas de doublon, sa traduction gagne (voir Shared/Lang.luau).
-- Style : espagnol d'Amérique latine, simple et amical, avec « tú » (comme le « tu » du français), aussi court que
-- possible (boutons !), mêmes emoji et balises, nombres et suffixes inchangés (1.5K, 2.3M...).
return {
	-- Tours (IdleTowers.luau)
	["Archer du rempart"] = "Arquero de la muralla",
	["Totem de givre"] = "Tótem de escarcha",
	["Catapulte"] = "Catapulta",
	["Mage des tempêtes"] = "Mago de las tormentas",
	["Baliste lourde"] = "Balista pesada",
	["Sorcier des arcanes"] = "Hechicero arcano",
	["Oracle de la foudre"] = "Oráculo del rayo",
	["Trébuchet royal"] = "Trebuchet real",
	-- Tours de palier 2 (œufs)
	["Archer enflammé"] = "Arquero en llamas",
	["Totem du blizzard"] = "Tótem de ventisca",
	["Catapulte de magma"] = "Catapulta de magma",
	["Archimage des tempêtes"] = "Archimago de las tormentas",
	["Baliste du dragon"] = "Balista del dragón",
	["Sorcier du néant"] = "Hechicero del vacío",
	["Oracle du tonnerre"] = "Oráculo del trueno",
	["Trébuchet céleste"] = "Trebuchet celestial",
	-- Tours spéciales (une par territoire, dans son œuf spécial)
	["Arc carmin"] = "Arco carmesí",
	["Arbalète de cuivre"] = "Ballesta de cobre",
	["Lance-ronces"] = "Lanzaespinas",
	["Catapulte de givre"] = "Catapulta de escarcha",

	-- Noms courts des tours, sur la barre d'un niveau (client/LevelsUI.luau, SHORT_NAMES ; « Catapulte » : plus haut)
	["Archer"] = "Arquero",
	["Totem"] = "Tótem",
	["Mage"] = "Mago",
	["Baliste"] = "Balista",
	["Sorcier"] = "Hechicero",
	["Oracle"] = "Oráculo",
	["Trébuchet"] = "Trebuchet",
	["Enflammé"] = "En llamas",
	["Blizzard"] = "Ventisca",
	["Magma"] = "Magma",
	["Archimage"] = "Archimago",
	["Dragon"] = "Dragón",
	["Néant"] = "Vacío",
	["Tonnerre"] = "Trueno",
	["Céleste"] = "Celestial",
	["Carmin"] = "Carmesí",
	["Cuivre"] = "Cobre",
	["Ronces"] = "Espinas",
	["Givre"] = "Escarcha",

	-- Monstres (Enemies.luau)
	["Écuyer"] = "Escudero",
	["Fantassin"] = "Soldado",
	["Cavalier"] = "Jinete",
	["Chevalier lourd"] = "Caballero pesado",
	["Chevalier colossal"] = "Caballero colosal",
	["Colosse géant"] = "Coloso gigante",
	["Seigneur de guerre"] = "Señor de la guerra",

	-- Territoires : le nom de leur carte (Levels.MAPS)
	["La vallée du Roi carmin"] = "El valle del Rey Carmesí",
	["Le col des Pillards de cuivre"] = "El paso de los Saqueadores de cobre",
	["La forêt des Gardiens des ronces"] = "El bosque de los Guardianes de las espinas",
	["Le glacier de la Légion du givre"] = "El glaciar de la Legión de escarcha",
	["Le désert des Gardes des dunes"] = "El desierto de los Guardias de las dunas",
	["La nécropole de la Légion des os"] = "La necrópolis de la Legión de los huesos",
	["La citadelle de la Garde de la tempête"] = "La ciudadela de la Guardia de la tormenta",
	["Le volcan des Chevaliers d'obsidienne"] = "El volcán de los Caballeros de obsidiana",
	["Les marais de la Horde gobeline"] = "Los pantanos de la Horda goblin",
	["Le repaire de la Couvée du dragon"] = "La guarida de la Cría del dragón",
}

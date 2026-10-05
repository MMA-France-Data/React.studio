-- Glossaire portugais (du Brésil) : les noms du jeu et LEUR traduction portugaise, la même partout (panneaux,
-- fenêtres, messages...). Mêmes lignes (même texte français) que src/shared/LangEN/Glossary.luau : une ligne ajoutée
-- là s'ajoute aussi ici (sinon le joueur lusophone voit l'anglais, et tools/lang/check.luau le signale). Ce fichier
-- est lu en premier : en cas de doublon, sa traduction gagne (voir Shared/Lang.luau).
-- Style : portugais du Brésil, simple et amical, avec « você », aussi court que possible (boutons !), mêmes emoji et
-- balises, nombres et suffixes inchangés (1.5K, 2.3M...).
return {
	-- Tours (IdleTowers.luau)
	["Archer du rempart"] = "Arqueiro da muralha",
	["Totem de givre"] = "Totem de gelo",
	["Catapulte"] = "Catapulta",
	["Mage des tempêtes"] = "Mago das tempestades",
	["Baliste lourde"] = "Balista pesada",
	["Sorcier des arcanes"] = "Feiticeiro arcano",
	["Oracle de la foudre"] = "Oráculo do raio",
	["Trébuchet royal"] = "Trabuco real",
	-- Tours de palier 2 (œufs)
	["Archer enflammé"] = "Arqueiro flamejante",
	["Totem du blizzard"] = "Totem da nevasca",
	["Catapulte de magma"] = "Catapulta de magma",
	["Archimage des tempêtes"] = "Arquimago das tempestades",
	["Baliste du dragon"] = "Balista do dragão",
	["Sorcier du néant"] = "Feiticeiro do vazio",
	["Oracle du tonnerre"] = "Oráculo do trovão",
	["Trébuchet céleste"] = "Trabuco celestial",
	-- Tours spéciales (une par territoire, dans son œuf spécial)
	["Arc carmin"] = "Arco carmesim",
	["Arbalète de cuivre"] = "Besta de cobre",
	["Lance-ronces"] = "Lança-espinhos",
	["Catapulte de givre"] = "Catapulta de gelo",
	["Totem des sables"] = "Totem de areia",

	-- Noms courts des tours, sur la barre d'un niveau (client/LevelsUI.luau, SHORT_NAMES ; « Catapulte » : plus haut)
	["Archer"] = "Arqueiro",
	["Totem"] = "Totem",
	["Mage"] = "Mago",
	["Baliste"] = "Balista",
	["Sorcier"] = "Feiticeiro",
	["Oracle"] = "Oráculo",
	["Trébuchet"] = "Trabuco",
	["Enflammé"] = "Flamejante",
	["Blizzard"] = "Nevasca",
	["Magma"] = "Magma",
	["Archimage"] = "Arquimago",
	["Dragon"] = "Dragão",
	["Néant"] = "Vazio",
	["Tonnerre"] = "Trovão",
	["Céleste"] = "Celestial",
	["Carmin"] = "Carmesim",
	["Cuivre"] = "Cobre",
	["Ronces"] = "Espinhos",
	["Givre"] = "Gelo",
	["Sables"] = "Areia",

	-- Monstres (Enemies.luau)
	["Écuyer"] = "Escudeiro",
	["Fantassin"] = "Soldado",
	["Cavalier"] = "Batedor",
	["Chevalier lourd"] = "Cavaleiro pesado",
	["Chevalier colossal"] = "Cavaleiro colossal",
	["Colosse géant"] = "Colosso gigante",
	["Seigneur de guerre"] = "Senhor da guerra",

	-- Territoires : le nom de leur carte (Levels.MAPS)
	["La vallée du Roi carmin"] = "O vale do Rei Carmesim",
	["Le col des Pillards de cuivre"] = "O desfiladeiro dos Saqueadores de cobre",
	["La forêt des Gardiens des ronces"] = "A floresta dos Guardiões dos espinhos",
	["Le glacier de la Légion du givre"] = "A geleira da Legião do gelo",
	["Le désert des Gardes des dunes"] = "O deserto dos Guardas das dunas",
	["La nécropole de la Légion des os"] = "A necrópole da Legião dos ossos",
	["La citadelle de la Garde de la tempête"] = "A cidadela da Guarda da tempestade",
	["Le volcan des Chevaliers d'obsidienne"] = "O vulcão dos Cavaleiros de obsidiana",
	["Les marais de la Horde gobeline"] = "Os pântanos da Horda goblin",
	["Le repaire de la Couvée du dragon"] = "O covil da Ninhada do dragão",
}

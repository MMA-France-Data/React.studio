-- CARTES D'ÉQUIPE (« JOUER EN ÉQUIPE », Shared/Levels.luau). Demande du propriétaire (03/10/2026) : « chacun a
-- son couloir qui se rejoint ensuite, exemple à 2 ça fait une map un peu en Y, adapté à chaque monde ».
-- Une carte par territoire et par nombre de joueurs : « Valley_2 », « Valley_3 », « Valley_4 »... Chaque joueur a SON
-- couloir (lanes[n], de son entrée au château : le joueur n de la partie défend le couloir n) ; les couloirs se
-- rejoignent ensuite (mêmes points = même chemin) et finissent au même château. Le flot de monstres est partagé
-- entre les couloirs, chacun son tour (Levels.buildQueue). Mêmes règles que les cartes seules : tronçons droits,
-- entrées sur un bord, tours posées où on veut ; spots = bons endroits (joueur simulé, essais).
-- FICHIER ÉCRIT PAR tools/team-maps/generer.py (les cartes sont dans tools/team-maps/cartes.py) : ne pas le
-- modifier à la main, il serait écrasé.
return {
	Valley_2 = {
		-- Deux couloirs en créneaux (en haut et en bas) qui se rejoignent au milieu, puis les créneaux du château.
		-- Couloirs de 222 / 222 studs (de l'entrée au château).
		displayName = "La vallée du Roi carmin",
		width = 120,
		depth = 64,
		lanes = {
			{ Vector3.new(-60, 0, -24), Vector3.new(-34, 0, -24), Vector3.new(-34, 0, -8), Vector3.new(-18, 0, -8), Vector3.new(-18, 0, -24), Vector3.new(-2, 0, -24), Vector3.new(-2, 0, 0), Vector3.new(12, 0, 0), Vector3.new(12, 0, -14), Vector3.new(28, 0, -14), Vector3.new(28, 0, 14), Vector3.new(44, 0, 14), Vector3.new(44, 0, 0), Vector3.new(50, 0, 0) },
			{ Vector3.new(-60, 0, 24), Vector3.new(-34, 0, 24), Vector3.new(-34, 0, 8), Vector3.new(-18, 0, 8), Vector3.new(-18, 0, 24), Vector3.new(-2, 0, 24), Vector3.new(-2, 0, 0), Vector3.new(12, 0, 0), Vector3.new(12, 0, -14), Vector3.new(28, 0, -14), Vector3.new(28, 0, 14), Vector3.new(44, 0, 14), Vector3.new(44, 0, 0), Vector3.new(50, 0, 0) },
		},
		base = Vector3.new(54, 0, 0),
		spots = { Vector3.new(18, 0, 2), Vector3.new(34, 0, -2), Vector3.new(18, 0, -8), Vector3.new(34, 0, 8), Vector3.new(4, 0, -14), Vector3.new(10, 0, 8), Vector3.new(-12, 0, -6), Vector3.new(-12, 0, 6), Vector3.new(12, 0, -20), Vector3.new(22, 0, 12), Vector3.new(34, 0, -12), Vector3.new(-20, 0, 0) },
	},
	Valley_3 = {
		-- Un couloir par la gauche, un par le haut, un par le bas : ils se rejoignent au milieu, puis les créneaux.
		-- Couloirs de 218 / 218 / 218 studs (de l'entrée au château).
		displayName = "La vallée du Roi carmin",
		width = 128,
		depth = 76,
		lanes = {
			{ Vector3.new(-16, 0, -38), Vector3.new(-16, 0, -14), Vector3.new(-2, 0, -14), Vector3.new(-2, 0, -33), Vector3.new(12, 0, -33), Vector3.new(12, 0, 0), Vector3.new(26, 0, 0), Vector3.new(26, 0, -18), Vector3.new(40, 0, -18), Vector3.new(40, 0, 18), Vector3.new(54, 0, 18), Vector3.new(54, 0, 0) },
			{ Vector3.new(-64, 0, 0), Vector3.new(-50, 0, 0), Vector3.new(-50, 0, -14), Vector3.new(-36, 0, -14), Vector3.new(-36, 0, 0), Vector3.new(12, 0, 0), Vector3.new(26, 0, 0), Vector3.new(26, 0, -18), Vector3.new(40, 0, -18), Vector3.new(40, 0, 18), Vector3.new(54, 0, 18), Vector3.new(54, 0, 0) },
			{ Vector3.new(-16, 0, 38), Vector3.new(-16, 0, 14), Vector3.new(-2, 0, 14), Vector3.new(-2, 0, 33), Vector3.new(12, 0, 33), Vector3.new(12, 0, 0), Vector3.new(26, 0, 0), Vector3.new(26, 0, -18), Vector3.new(40, 0, -18), Vector3.new(40, 0, 18), Vector3.new(54, 0, 18), Vector3.new(54, 0, 0) },
		},
		base = Vector3.new(54, 0, -4),
		spots = { Vector3.new(32, 0, -2), Vector3.new(46, 0, 2), Vector3.new(32, 0, -12), Vector3.new(26, 0, 6), Vector3.new(20, 0, -12), Vector3.new(46, 0, 12), Vector3.new(34, 0, 12), Vector3.new(46, 0, -10), Vector3.new(28, 0, -24), Vector3.new(24, 0, 16), Vector3.new(44, 0, 24), Vector3.new(6, 0, -6) },
	},
	Valley_4 = {
		-- Les deux couloirs de gauche se rejoignent d'abord ; ceux du haut et du bas les rejoignent plus loin.
		-- Couloirs de 216 / 216 / 216 / 216 studs (de l'entrée au château).
		displayName = "La vallée du Roi carmin",
		width = 136,
		depth = 88,
		lanes = {
			{ Vector3.new(-68, 0, -28), Vector3.new(-56, 0, -28), Vector3.new(-56, 0, -14), Vector3.new(-28, 0, -14), Vector3.new(-28, 0, 0), Vector3.new(14, 0, 0), Vector3.new(28, 0, 0), Vector3.new(28, 0, -16), Vector3.new(42, 0, -16), Vector3.new(42, 0, 16), Vector3.new(56, 0, 16), Vector3.new(56, 0, 0) },
			{ Vector3.new(-14, 0, -44), Vector3.new(-14, 0, -14), Vector3.new(0, 0, -14), Vector3.new(0, 0, -33), Vector3.new(14, 0, -33), Vector3.new(14, 0, 0), Vector3.new(28, 0, 0), Vector3.new(28, 0, -16), Vector3.new(42, 0, -16), Vector3.new(42, 0, 16), Vector3.new(56, 0, 16), Vector3.new(56, 0, 0) },
			{ Vector3.new(-14, 0, 44), Vector3.new(-14, 0, 14), Vector3.new(0, 0, 14), Vector3.new(0, 0, 33), Vector3.new(14, 0, 33), Vector3.new(14, 0, 0), Vector3.new(28, 0, 0), Vector3.new(28, 0, -16), Vector3.new(42, 0, -16), Vector3.new(42, 0, 16), Vector3.new(56, 0, 16), Vector3.new(56, 0, 0) },
			{ Vector3.new(-68, 0, 28), Vector3.new(-56, 0, 28), Vector3.new(-56, 0, 14), Vector3.new(-28, 0, 14), Vector3.new(-28, 0, 0), Vector3.new(14, 0, 0), Vector3.new(28, 0, 0), Vector3.new(28, 0, -16), Vector3.new(42, 0, -16), Vector3.new(42, 0, 16), Vector3.new(56, 0, 16), Vector3.new(56, 0, 0) },
		},
		base = Vector3.new(56, 0, -4),
		spots = { Vector3.new(34, 0, 0), Vector3.new(34, 0, -10), Vector3.new(48, 0, 2), Vector3.new(26, 0, 6), Vector3.new(22, 0, -10), Vector3.new(36, 0, 10), Vector3.new(48, 0, -10), Vector3.new(30, 0, -22), Vector3.new(28, 0, 16), Vector3.new(46, 0, 22), Vector3.new(8, 0, -6), Vector3.new(8, 0, 6) },
	},
	Pass_2 = {
		-- Chaque couloir longe le bord puis fait une épingle ; la partie commune traverse tout le terrain et revient
		-- vers le centre.
		-- Couloirs de 250 / 250 studs (de l'entrée au château).
		displayName = "Le col des Pillards de cuivre",
		width = 120,
		depth = 66,
		lanes = {
			{ Vector3.new(-60, 0, -28), Vector3.new(-8, 0, -28), Vector3.new(-8, 0, -14), Vector3.new(-44, 0, -14), Vector3.new(-44, 0, 0), Vector3.new(48, 0, 0), Vector3.new(48, 0, -14), Vector3.new(20, 0, -14) },
			{ Vector3.new(-60, 0, 28), Vector3.new(-8, 0, 28), Vector3.new(-8, 0, 14), Vector3.new(-44, 0, 14), Vector3.new(-44, 0, 0), Vector3.new(48, 0, 0), Vector3.new(48, 0, -14), Vector3.new(20, 0, -14) },
		},
		base = Vector3.new(16, 0, -14),
		spots = { Vector3.new(32, 0, -7), Vector3.new(42, 0, -7), Vector3.new(-28, 0, -7), Vector3.new(-28, 0, 7), Vector3.new(22, 0, -7), Vector3.new(-18, 0, -7), Vector3.new(-18, 0, 7), Vector3.new(-38, 0, -7), Vector3.new(-38, 0, 7), Vector3.new(-8, 0, -7), Vector3.new(-8, 0, 7), Vector3.new(2, 0, -9) },
	},
	Pass_3 = {
		-- Les couloirs du haut et du bas longent le bord ; la partie commune fait le tour de la droite et revient
		-- vers le centre.
		-- Couloirs de 250 / 246 / 250 studs (de l'entrée au château).
		displayName = "Le col des Pillards de cuivre",
		width = 128,
		depth = 76,
		lanes = {
			{ Vector3.new(-58, 0, -38), Vector3.new(-58, 0, -28), Vector3.new(-10, 0, -28), Vector3.new(-10, 0, 0), Vector3.new(14, 0, 0), Vector3.new(14, 0, 20), Vector3.new(54, 0, 20), Vector3.new(54, 0, -20), Vector3.new(28, 0, -20), Vector3.new(28, 0, -6) },
			{ Vector3.new(-64, 0, 0), Vector3.new(-50, 0, 0), Vector3.new(-50, 0, -14), Vector3.new(-36, 0, -14), Vector3.new(-36, 0, 0), Vector3.new(-10, 0, 0), Vector3.new(14, 0, 0), Vector3.new(14, 0, 20), Vector3.new(54, 0, 20), Vector3.new(54, 0, -20), Vector3.new(28, 0, -20), Vector3.new(28, 0, -6) },
			{ Vector3.new(-58, 0, 38), Vector3.new(-58, 0, 28), Vector3.new(-10, 0, 28), Vector3.new(-10, 0, 0), Vector3.new(14, 0, 0), Vector3.new(14, 0, 20), Vector3.new(54, 0, 20), Vector3.new(54, 0, -20), Vector3.new(28, 0, -20), Vector3.new(28, 0, -6) },
		},
		base = Vector3.new(28, 0, -2),
		spots = { Vector3.new(42, 0, -8), Vector3.new(2, 0, 14), Vector3.new(22, 0, 6), Vector3.new(8, 0, 6), Vector3.new(-4, 0, 6), Vector3.new(38, 0, 10), Vector3.new(28, 0, 14), Vector3.new(46, 0, 4), Vector3.new(48, 0, 14), Vector3.new(16, 0, -6), Vector3.new(0, 0, -6), Vector3.new(38, 0, -26) },
	},
	Pass_4 = {
		-- Longs couloirs ; la partie commune fait le tour de la droite et revient vers le centre.
		-- Couloirs de 244 / 246 / 246 / 244 studs (de l'entrée au château).
		displayName = "Le col des Pillards de cuivre",
		width = 136,
		depth = 88,
		lanes = {
			{ Vector3.new(-68, 0, -30), Vector3.new(-48, 0, -30), Vector3.new(-48, 0, -14), Vector3.new(-34, 0, -14), Vector3.new(-34, 0, 0), Vector3.new(2, 0, 0), Vector3.new(34, 0, 0), Vector3.new(34, 0, -30), Vector3.new(60, 0, -30), Vector3.new(60, 0, 14), Vector3.new(48, 0, 14) },
			{ Vector3.new(-20, 0, -44), Vector3.new(-20, 0, -30), Vector3.new(20, 0, -30), Vector3.new(20, 0, -14), Vector3.new(2, 0, -14), Vector3.new(2, 0, 0), Vector3.new(34, 0, 0), Vector3.new(34, 0, -30), Vector3.new(60, 0, -30), Vector3.new(60, 0, 14), Vector3.new(48, 0, 14) },
			{ Vector3.new(-20, 0, 44), Vector3.new(-20, 0, 30), Vector3.new(20, 0, 30), Vector3.new(20, 0, 14), Vector3.new(2, 0, 14), Vector3.new(2, 0, 0), Vector3.new(34, 0, 0), Vector3.new(34, 0, -30), Vector3.new(60, 0, -30), Vector3.new(60, 0, 14), Vector3.new(48, 0, 14) },
			{ Vector3.new(-68, 0, 30), Vector3.new(-48, 0, 30), Vector3.new(-48, 0, 14), Vector3.new(-34, 0, 14), Vector3.new(-34, 0, 0), Vector3.new(2, 0, 0), Vector3.new(34, 0, 0), Vector3.new(34, 0, -30), Vector3.new(60, 0, -30), Vector3.new(60, 0, 14), Vector3.new(48, 0, 14) },
		},
		base = Vector3.new(44, 0, 14),
		spots = { Vector3.new(46, 0, -18), Vector3.new(18, 0, -8), Vector3.new(26, 0, -16), Vector3.new(50, 0, -2), Vector3.new(28, 0, -6), Vector3.new(18, 0, 6), Vector3.new(42, 0, 4), Vector3.new(54, 0, -24), Vector3.new(54, 0, -12), Vector3.new(42, 0, -8), Vector3.new(8, 0, -6), Vector3.new(8, 0, 6) },
	},
	Forest_2 = {
		-- Deux couloirs en S, puis des S jusqu'au château, dans le coin en bas à droite.
		-- Couloirs de 296 / 296 studs (de l'entrée au château).
		displayName = "La forêt des Gardiens des ronces",
		width = 120,
		depth = 66,
		lanes = {
			{ Vector3.new(-60, 0, -28), Vector3.new(-16, 0, -28), Vector3.new(-16, 0, -14), Vector3.new(-38, 0, -14), Vector3.new(-38, 0, 0), Vector3.new(12, 0, 0), Vector3.new(12, 0, 22), Vector3.new(26, 0, 22), Vector3.new(26, 0, -22), Vector3.new(54, 0, -22), Vector3.new(54, 0, 22) },
			{ Vector3.new(-60, 0, 28), Vector3.new(-16, 0, 28), Vector3.new(-16, 0, 14), Vector3.new(-38, 0, 14), Vector3.new(-38, 0, 0), Vector3.new(12, 0, 0), Vector3.new(12, 0, 22), Vector3.new(26, 0, 22), Vector3.new(26, 0, -22), Vector3.new(54, 0, -22), Vector3.new(54, 0, 22) },
		},
		base = Vector3.new(54, 0, 26),
		spots = { Vector3.new(18, 0, 5), Vector3.new(40, 0, -11), Vector3.new(18, 0, 15), Vector3.new(18, 0, -5), Vector3.new(-2, 0, 11), Vector3.new(-22, 0, -7), Vector3.new(-22, 0, 7), Vector3.new(6, 0, 17), Vector3.new(-32, 0, -7), Vector3.new(-32, 0, 7), Vector3.new(32, 0, -5), Vector3.new(48, 0, -5) },
	},
	Forest_3 = {
		-- Trois couloirs qui se rejoignent, puis de grands S jusqu'au château, en bas à droite.
		-- Couloirs de 274 / 276 / 274 studs (de l'entrée au château).
		displayName = "La forêt des Gardiens des ronces",
		width = 128,
		depth = 76,
		lanes = {
			{ Vector3.new(-52, 0, -38), Vector3.new(-52, 0, -28), Vector3.new(-10, 0, -28), Vector3.new(-10, 0, 0), Vector3.new(16, 0, 0), Vector3.new(16, 0, 26), Vector3.new(36, 0, 26), Vector3.new(36, 0, -26), Vector3.new(54, 0, -26), Vector3.new(54, 0, 26) },
			{ Vector3.new(-64, 0, 0), Vector3.new(-50, 0, 0), Vector3.new(-50, 0, -14), Vector3.new(-36, 0, -14), Vector3.new(-36, 0, 0), Vector3.new(-10, 0, 0), Vector3.new(16, 0, 0), Vector3.new(16, 0, 26), Vector3.new(36, 0, 26), Vector3.new(36, 0, -26), Vector3.new(54, 0, -26), Vector3.new(54, 0, 26) },
			{ Vector3.new(-52, 0, 38), Vector3.new(-52, 0, 28), Vector3.new(-10, 0, 28), Vector3.new(-10, 0, 0), Vector3.new(16, 0, 0), Vector3.new(16, 0, 26), Vector3.new(36, 0, 26), Vector3.new(36, 0, -26), Vector3.new(54, 0, -26), Vector3.new(54, 0, 26) },
		},
		base = Vector3.new(54, 0, 30),
		spots = { Vector3.new(26, 0, 10), Vector3.new(44, 0, -10), Vector3.new(42, 0, 10), Vector3.new(26, 0, 20), Vector3.new(4, 0, 12), Vector3.new(42, 0, -20), Vector3.new(42, 0, 0), Vector3.new(26, 0, 0), Vector3.new(42, 0, 20), Vector3.new(26, 0, -10), Vector3.new(0, 0, -6), Vector3.new(26, 0, 32) },
	},
	Forest_4 = {
		-- Quatre couloirs, puis un grand S jusqu'au château, en bas à droite.
		-- Couloirs de 252 / 254 / 254 / 252 studs (de l'entrée au château).
		displayName = "La forêt des Gardiens des ronces",
		width = 136,
		depth = 88,
		lanes = {
			{ Vector3.new(-68, 0, -30), Vector3.new(-48, 0, -30), Vector3.new(-48, 0, -14), Vector3.new(-34, 0, -14), Vector3.new(-34, 0, 0), Vector3.new(2, 0, 0), Vector3.new(34, 0, 0), Vector3.new(34, 0, -30), Vector3.new(60, 0, -30), Vector3.new(60, 0, 34) },
			{ Vector3.new(-20, 0, -44), Vector3.new(-20, 0, -30), Vector3.new(20, 0, -30), Vector3.new(20, 0, -14), Vector3.new(2, 0, -14), Vector3.new(2, 0, 0), Vector3.new(34, 0, 0), Vector3.new(34, 0, -30), Vector3.new(60, 0, -30), Vector3.new(60, 0, 34) },
			{ Vector3.new(-20, 0, 44), Vector3.new(-20, 0, 30), Vector3.new(20, 0, 30), Vector3.new(20, 0, 14), Vector3.new(2, 0, 14), Vector3.new(2, 0, 0), Vector3.new(34, 0, 0), Vector3.new(34, 0, -30), Vector3.new(60, 0, -30), Vector3.new(60, 0, 34) },
			{ Vector3.new(-68, 0, 30), Vector3.new(-48, 0, 30), Vector3.new(-48, 0, 14), Vector3.new(-34, 0, 14), Vector3.new(-34, 0, 0), Vector3.new(2, 0, 0), Vector3.new(34, 0, 0), Vector3.new(34, 0, -30), Vector3.new(60, 0, -30), Vector3.new(60, 0, 34) },
		},
		base = Vector3.new(60, 0, 38),
		spots = { Vector3.new(46, 0, -18), Vector3.new(18, 0, -8), Vector3.new(26, 0, -16), Vector3.new(28, 0, -6), Vector3.new(44, 0, -8), Vector3.new(18, 0, 6), Vector3.new(54, 0, -24), Vector3.new(54, 0, -12), Vector3.new(50, 0, 0), Vector3.new(8, 0, -6), Vector3.new(8, 0, 6), Vector3.new(28, 0, -26) },
	},
	Glacier_2 = {
		-- Chaque couloir fait des passages verticaux serrés ; la partie commune aussi, jusqu'au château.
		-- Couloirs de 296 / 296 studs (de l'entrée au château).
		displayName = "Le glacier de la Légion du givre",
		width = 120,
		depth = 66,
		lanes = {
			{ Vector3.new(-60, 0, -28), Vector3.new(-50, 0, -28), Vector3.new(-50, 0, -14), Vector3.new(-36, 0, -14), Vector3.new(-36, 0, -28), Vector3.new(-22, 0, -28), Vector3.new(-22, 0, -14), Vector3.new(-8, 0, -14), Vector3.new(-8, 0, 0), Vector3.new(6, 0, 0), Vector3.new(6, 0, -22), Vector3.new(20, 0, -22), Vector3.new(20, 0, 22), Vector3.new(34, 0, 22), Vector3.new(34, 0, -22), Vector3.new(48, 0, -22), Vector3.new(48, 0, 0) },
			{ Vector3.new(-60, 0, 28), Vector3.new(-50, 0, 28), Vector3.new(-50, 0, 14), Vector3.new(-36, 0, 14), Vector3.new(-36, 0, 28), Vector3.new(-22, 0, 28), Vector3.new(-22, 0, 14), Vector3.new(-8, 0, 14), Vector3.new(-8, 0, 0), Vector3.new(6, 0, 0), Vector3.new(6, 0, -22), Vector3.new(20, 0, -22), Vector3.new(20, 0, 22), Vector3.new(34, 0, 22), Vector3.new(34, 0, -22), Vector3.new(48, 0, -22), Vector3.new(48, 0, 0) },
		},
		base = Vector3.new(48, 0, 4),
		spots = { Vector3.new(12, 0, -5), Vector3.new(26, 0, 5), Vector3.new(26, 0, -13), Vector3.new(40, 0, -5), Vector3.new(12, 0, -15), Vector3.new(0, 0, -17), Vector3.new(10, 0, 5), Vector3.new(26, 0, 15), Vector3.new(40, 0, -15), Vector3.new(0, 0, -7), Vector3.new(26, 0, -23), Vector3.new(4, 0, 13) },
	},
	Glacier_3 = {
		-- Passages verticaux serrés partout, jusqu'au château, au milieu à droite.
		-- Couloirs de 234 / 230 / 234 studs (de l'entrée au château).
		displayName = "Le glacier de la Légion du givre",
		width = 128,
		depth = 76,
		lanes = {
			{ Vector3.new(-20, 0, -38), Vector3.new(-20, 0, -14), Vector3.new(-6, 0, -14), Vector3.new(-6, 0, -33), Vector3.new(8, 0, -33), Vector3.new(8, 0, 0), Vector3.new(22, 0, 0), Vector3.new(22, 0, -22), Vector3.new(36, 0, -22), Vector3.new(36, 0, 22), Vector3.new(50, 0, 22), Vector3.new(50, 0, 0) },
			{ Vector3.new(-64, 0, 0), Vector3.new(-50, 0, 0), Vector3.new(-50, 0, -14), Vector3.new(-36, 0, -14), Vector3.new(-36, 0, 0), Vector3.new(8, 0, 0), Vector3.new(22, 0, 0), Vector3.new(22, 0, -22), Vector3.new(36, 0, -22), Vector3.new(36, 0, 22), Vector3.new(50, 0, 22), Vector3.new(50, 0, 0) },
			{ Vector3.new(-20, 0, 38), Vector3.new(-20, 0, 14), Vector3.new(-6, 0, 14), Vector3.new(-6, 0, 33), Vector3.new(8, 0, 33), Vector3.new(8, 0, 0), Vector3.new(22, 0, 0), Vector3.new(22, 0, -22), Vector3.new(36, 0, -22), Vector3.new(36, 0, 22), Vector3.new(50, 0, 22), Vector3.new(50, 0, 0) },
		},
		base = Vector3.new(50, 0, -4),
		spots = { Vector3.new(28, 0, -6), Vector3.new(42, 0, 6), Vector3.new(26, 0, 6), Vector3.new(28, 0, -16), Vector3.new(16, 0, -16), Vector3.new(42, 0, 16), Vector3.new(16, 0, -6), Vector3.new(20, 0, 14), Vector3.new(42, 0, -10), Vector3.new(24, 0, -28), Vector3.new(30, 0, 16), Vector3.new(14, 0, 6) },
	},
	Glacier_4 = {
		-- Passages verticaux serrés, jusqu'au château, au milieu à droite.
		-- Couloirs de 240 / 240 / 240 / 240 studs (de l'entrée au château).
		displayName = "Le glacier de la Légion du givre",
		width = 136,
		depth = 88,
		lanes = {
			{ Vector3.new(-68, 0, -28), Vector3.new(-56, 0, -28), Vector3.new(-56, 0, -14), Vector3.new(-28, 0, -14), Vector3.new(-28, 0, 0), Vector3.new(14, 0, 0), Vector3.new(28, 0, 0), Vector3.new(28, 0, -22), Vector3.new(42, 0, -22), Vector3.new(42, 0, 22), Vector3.new(56, 0, 22), Vector3.new(56, 0, 0) },
			{ Vector3.new(-14, 0, -44), Vector3.new(-14, 0, -14), Vector3.new(0, 0, -14), Vector3.new(0, 0, -33), Vector3.new(14, 0, -33), Vector3.new(14, 0, 0), Vector3.new(28, 0, 0), Vector3.new(28, 0, -22), Vector3.new(42, 0, -22), Vector3.new(42, 0, 22), Vector3.new(56, 0, 22), Vector3.new(56, 0, 0) },
			{ Vector3.new(-14, 0, 44), Vector3.new(-14, 0, 14), Vector3.new(0, 0, 14), Vector3.new(0, 0, 33), Vector3.new(14, 0, 33), Vector3.new(14, 0, 0), Vector3.new(28, 0, 0), Vector3.new(28, 0, -22), Vector3.new(42, 0, -22), Vector3.new(42, 0, 22), Vector3.new(56, 0, 22), Vector3.new(56, 0, 0) },
			{ Vector3.new(-68, 0, 28), Vector3.new(-56, 0, 28), Vector3.new(-56, 0, 14), Vector3.new(-28, 0, 14), Vector3.new(-28, 0, 0), Vector3.new(14, 0, 0), Vector3.new(28, 0, 0), Vector3.new(28, 0, -22), Vector3.new(42, 0, -22), Vector3.new(42, 0, 22), Vector3.new(56, 0, 22), Vector3.new(56, 0, 0) },
		},
		base = Vector3.new(56, 0, -4),
		spots = { Vector3.new(34, 0, -6), Vector3.new(48, 0, 6), Vector3.new(32, 0, 6), Vector3.new(34, 0, -16), Vector3.new(48, 0, 16), Vector3.new(22, 0, -16), Vector3.new(22, 0, -6), Vector3.new(26, 0, 14), Vector3.new(48, 0, -10), Vector3.new(36, 0, 16), Vector3.new(32, 0, -28), Vector3.new(20, 0, 6) },
	},
	Desert_2 = {
		-- Deux longs couloirs droits jusqu'au bout du terrain ; la partie commune revient par le milieu (un crochet)
		-- jusqu'au château, près des entrées.
		-- Couloirs de 242 / 242 studs (de l'entrée au château).
		displayName = "Le désert des Gardes des dunes",
		width = 120,
		depth = 66,
		lanes = {
			{ Vector3.new(-60, 0, -28), Vector3.new(40, 0, -28), Vector3.new(40, 0, 0), Vector3.new(20, 0, 0), Vector3.new(20, 0, -14), Vector3.new(-6, 0, -14), Vector3.new(-6, 0, 14), Vector3.new(-32, 0, 14) },
			{ Vector3.new(-60, 0, 28), Vector3.new(40, 0, 28), Vector3.new(40, 0, 0), Vector3.new(20, 0, 0), Vector3.new(20, 0, -14), Vector3.new(-6, 0, -14), Vector3.new(-6, 0, 14), Vector3.new(-32, 0, 14) },
		},
		base = Vector3.new(-36, 0, 14),
		spots = { Vector3.new(6, 0, -3), Vector3.new(28, 0, -13), Vector3.new(4, 0, -21), Vector3.new(-16, 0, -1), Vector3.new(-16, 0, 21), Vector3.new(28, 0, 11), Vector3.new(14, 0, -21), Vector3.new(-6, 0, -21), Vector3.new(-6, 0, 21), Vector3.new(-22, 0, 7), Vector3.new(14, 0, 3), Vector3.new(-12, 0, -13) },
	},
	Desert_3 = {
		-- Longs couloirs droits ; la partie commune va au bout du terrain et revient avec un crochet jusqu'au château,
		-- en bas.
		-- Couloirs de 246 / 242 / 246 studs (de l'entrée au château).
		displayName = "Le désert des Gardes des dunes",
		width = 128,
		depth = 76,
		lanes = {
			{ Vector3.new(-58, 0, -38), Vector3.new(-58, 0, -28), Vector3.new(-10, 0, -28), Vector3.new(-10, 0, 0), Vector3.new(54, 0, 0), Vector3.new(54, 0, 28), Vector3.new(34, 0, 28), Vector3.new(34, 0, 14), Vector3.new(14, 0, 14), Vector3.new(14, 0, 28) },
			{ Vector3.new(-64, 0, 0), Vector3.new(-50, 0, 0), Vector3.new(-50, 0, -14), Vector3.new(-36, 0, -14), Vector3.new(-36, 0, 0), Vector3.new(-10, 0, 0), Vector3.new(54, 0, 0), Vector3.new(54, 0, 28), Vector3.new(34, 0, 28), Vector3.new(34, 0, 14), Vector3.new(14, 0, 14), Vector3.new(14, 0, 28) },
			{ Vector3.new(-58, 0, 38), Vector3.new(-58, 0, 28), Vector3.new(-10, 0, 28), Vector3.new(-10, 0, 0), Vector3.new(54, 0, 0), Vector3.new(54, 0, 28), Vector3.new(34, 0, 28), Vector3.new(34, 0, 14), Vector3.new(14, 0, 14), Vector3.new(14, 0, 28) },
		},
		base = Vector3.new(14, 0, 32),
		spots = { Vector3.new(42, 0, 14), Vector3.new(24, 0, 6), Vector3.new(36, 0, 6), Vector3.new(6, 0, 10), Vector3.new(28, 0, 22), Vector3.new(48, 0, 22), Vector3.new(48, 0, 6), Vector3.new(28, 0, 32), Vector3.new(-2, 0, 16), Vector3.new(44, 0, 34), Vector3.new(60, 0, 12), Vector3.new(0, 0, -6) },
	},
	Desert_4 = {
		-- Longs couloirs ; la partie commune va au bout du terrain et revient au château, en bas.
		-- Couloirs de 210 / 212 / 212 / 210 studs (de l'entrée au château).
		displayName = "Le désert des Gardes des dunes",
		width = 136,
		depth = 88,
		lanes = {
			{ Vector3.new(-68, 0, -30), Vector3.new(-48, 0, -30), Vector3.new(-48, 0, -14), Vector3.new(-34, 0, -14), Vector3.new(-34, 0, 0), Vector3.new(2, 0, 0), Vector3.new(58, 0, 0), Vector3.new(58, 0, 34), Vector3.new(38, 0, 34) },
			{ Vector3.new(-20, 0, -44), Vector3.new(-20, 0, -30), Vector3.new(20, 0, -30), Vector3.new(20, 0, -14), Vector3.new(2, 0, -14), Vector3.new(2, 0, 0), Vector3.new(58, 0, 0), Vector3.new(58, 0, 34), Vector3.new(38, 0, 34) },
			{ Vector3.new(-20, 0, 44), Vector3.new(-20, 0, 30), Vector3.new(20, 0, 30), Vector3.new(20, 0, 14), Vector3.new(2, 0, 14), Vector3.new(2, 0, 0), Vector3.new(58, 0, 0), Vector3.new(58, 0, 34), Vector3.new(38, 0, 34) },
			{ Vector3.new(-68, 0, 30), Vector3.new(-48, 0, 30), Vector3.new(-48, 0, 14), Vector3.new(-34, 0, 14), Vector3.new(-34, 0, 0), Vector3.new(2, 0, 0), Vector3.new(58, 0, 0), Vector3.new(58, 0, 34), Vector3.new(38, 0, 34) },
		},
		base = Vector3.new(34, 0, 34),
		spots = { Vector3.new(48, 0, 16), Vector3.new(42, 0, 6), Vector3.new(52, 0, 6), Vector3.new(18, 0, -6), Vector3.new(18, 0, 6), Vector3.new(52, 0, 26), Vector3.new(8, 0, -6), Vector3.new(8, 0, 6), Vector3.new(42, 0, 24), Vector3.new(64, 0, 16), Vector3.new(28, 0, -6), Vector3.new(28, 0, 6) },
	},
	Necropolis_2 = {
		-- Chaque couloir descend deux marches ; la partie commune fait le tour d'une couronne et plonge vers le
		-- château, au centre.
		-- Couloirs de 276 / 276 studs (de l'entrée au château).
		displayName = "La nécropole de la Légion des os",
		width = 120,
		depth = 66,
		lanes = {
			{ Vector3.new(-60, 0, -28), Vector3.new(-46, 0, -28), Vector3.new(-46, 0, -14), Vector3.new(-32, 0, -14), Vector3.new(-32, 0, 0), Vector3.new(-18, 0, 0), Vector3.new(-18, 0, 28), Vector3.new(26, 0, 28), Vector3.new(26, 0, 14), Vector3.new(40, 0, 14), Vector3.new(40, 0, -14), Vector3.new(26, 0, -14), Vector3.new(26, 0, -28), Vector3.new(0, 0, -28), Vector3.new(0, 0, -4) },
			{ Vector3.new(-60, 0, 28), Vector3.new(-46, 0, 28), Vector3.new(-46, 0, 14), Vector3.new(-32, 0, 14), Vector3.new(-32, 0, 0), Vector3.new(-18, 0, 0), Vector3.new(-18, 0, 28), Vector3.new(26, 0, 28), Vector3.new(26, 0, 14), Vector3.new(40, 0, 14), Vector3.new(40, 0, -14), Vector3.new(26, 0, -14), Vector3.new(26, 0, -28), Vector3.new(0, 0, -28), Vector3.new(0, 0, -4) },
		},
		base = Vector3.new(0, 0, 0),
		spots = { Vector3.new(12, 0, -17), Vector3.new(30, 0, -1), Vector3.new(-24, 0, 17), Vector3.new(-26, 0, 7), Vector3.new(-10, 0, 11), Vector3.new(32, 0, -23), Vector3.new(32, 0, 21), Vector3.new(-4, 0, 19), Vector3.new(10, 0, 19), Vector3.new(20, 0, 19), Vector3.new(-18, 0, -9), Vector3.new(-38, 0, -3) },
	},
	Necropolis_3 = {
		-- Trois couloirs qui se rejoignent ; la partie commune tourne autour du château, au milieu d'une couronne.
		-- Couloirs de 244 / 244 / 244 studs (de l'entrée au château).
		displayName = "La nécropole de la Légion des os",
		width = 128,
		depth = 76,
		lanes = {
			{ Vector3.new(-16, 0, -38), Vector3.new(-16, 0, -14), Vector3.new(-2, 0, -14), Vector3.new(-2, 0, -33), Vector3.new(12, 0, -33), Vector3.new(12, 0, 0), Vector3.new(26, 0, 0), Vector3.new(26, 0, -22), Vector3.new(56, 0, -22), Vector3.new(56, 0, 22), Vector3.new(40, 0, 22), Vector3.new(40, 0, 8) },
			{ Vector3.new(-64, 0, 0), Vector3.new(-50, 0, 0), Vector3.new(-50, 0, -14), Vector3.new(-36, 0, -14), Vector3.new(-36, 0, 0), Vector3.new(12, 0, 0), Vector3.new(26, 0, 0), Vector3.new(26, 0, -22), Vector3.new(56, 0, -22), Vector3.new(56, 0, 22), Vector3.new(40, 0, 22), Vector3.new(40, 0, 8) },
			{ Vector3.new(-16, 0, 38), Vector3.new(-16, 0, 14), Vector3.new(-2, 0, 14), Vector3.new(-2, 0, 33), Vector3.new(12, 0, 33), Vector3.new(12, 0, 0), Vector3.new(26, 0, 0), Vector3.new(26, 0, -22), Vector3.new(56, 0, -22), Vector3.new(56, 0, 22), Vector3.new(40, 0, 22), Vector3.new(40, 0, 8) },
		},
		base = Vector3.new(40, 0, 4),
		spots = { Vector3.new(40, 0, -10), Vector3.new(50, 0, 6), Vector3.new(20, 0, -16), Vector3.new(20, 0, -6), Vector3.new(50, 0, 16), Vector3.new(32, 0, -4), Vector3.new(50, 0, -6), Vector3.new(32, 0, -16), Vector3.new(26, 0, 10), Vector3.new(48, 0, -16), Vector3.new(40, 0, -28), Vector3.new(46, 0, 28) },
	},
	Necropolis_4 = {
		-- Quatre couloirs ; la partie commune tourne autour du château, au milieu d'une couronne.
		-- Couloirs de 266 / 266 / 266 / 266 studs (de l'entrée au château).
		displayName = "La nécropole de la Légion des os",
		width = 136,
		depth = 88,
		lanes = {
			{ Vector3.new(-68, 0, -28), Vector3.new(-56, 0, -28), Vector3.new(-56, 0, -14), Vector3.new(-28, 0, -14), Vector3.new(-28, 0, 0), Vector3.new(14, 0, 0), Vector3.new(28, 0, 0), Vector3.new(28, 0, -26), Vector3.new(60, 0, -26), Vector3.new(60, 0, 26), Vector3.new(44, 0, 26), Vector3.new(44, 0, 10) },
			{ Vector3.new(-14, 0, -44), Vector3.new(-14, 0, -14), Vector3.new(0, 0, -14), Vector3.new(0, 0, -33), Vector3.new(14, 0, -33), Vector3.new(14, 0, 0), Vector3.new(28, 0, 0), Vector3.new(28, 0, -26), Vector3.new(60, 0, -26), Vector3.new(60, 0, 26), Vector3.new(44, 0, 26), Vector3.new(44, 0, 10) },
			{ Vector3.new(-14, 0, 44), Vector3.new(-14, 0, 14), Vector3.new(0, 0, 14), Vector3.new(0, 0, 33), Vector3.new(14, 0, 33), Vector3.new(14, 0, 0), Vector3.new(28, 0, 0), Vector3.new(28, 0, -26), Vector3.new(60, 0, -26), Vector3.new(60, 0, 26), Vector3.new(44, 0, 26), Vector3.new(44, 0, 10) },
			{ Vector3.new(-68, 0, 28), Vector3.new(-56, 0, 28), Vector3.new(-56, 0, 14), Vector3.new(-28, 0, 14), Vector3.new(-28, 0, 0), Vector3.new(14, 0, 0), Vector3.new(28, 0, 0), Vector3.new(28, 0, -26), Vector3.new(60, 0, -26), Vector3.new(60, 0, 26), Vector3.new(44, 0, 26), Vector3.new(44, 0, 10) },
		},
		base = Vector3.new(44, 0, 6),
		spots = { Vector3.new(44, 0, -16), Vector3.new(54, 0, 10), Vector3.new(22, 0, -16), Vector3.new(54, 0, 20), Vector3.new(34, 0, -16), Vector3.new(22, 0, -6), Vector3.new(52, 0, -10), Vector3.new(54, 0, -20), Vector3.new(28, 0, 6), Vector3.new(44, 0, -4), Vector3.new(44, 0, -32), Vector3.new(54, 0, 0) },
	},
	Storm_2 = {
		-- Deux couloirs à dents profondes, puis un grand crochet jusqu'au château, en bas à droite.
		-- Couloirs de 270 / 270 studs (de l'entrée au château).
		displayName = "La citadelle de la Garde de la tempête",
		width = 120,
		depth = 64,
		lanes = {
			{ Vector3.new(-60, 0, -24), Vector3.new(-48, 0, -24), Vector3.new(-48, 0, -7), Vector3.new(-34, 0, -7), Vector3.new(-34, 0, -24), Vector3.new(-20, 0, -24), Vector3.new(-20, 0, -7), Vector3.new(-6, 0, -7), Vector3.new(-6, 0, -24), Vector3.new(8, 0, -24), Vector3.new(8, 0, 0), Vector3.new(22, 0, 0), Vector3.new(22, 0, -22), Vector3.new(52, 0, -22), Vector3.new(52, 0, 22) },
			{ Vector3.new(-60, 0, 24), Vector3.new(-48, 0, 24), Vector3.new(-48, 0, 7), Vector3.new(-34, 0, 7), Vector3.new(-34, 0, 24), Vector3.new(-20, 0, 24), Vector3.new(-20, 0, 7), Vector3.new(-6, 0, 7), Vector3.new(-6, 0, 24), Vector3.new(8, 0, 24), Vector3.new(8, 0, 0), Vector3.new(22, 0, 0), Vector3.new(22, 0, -22), Vector3.new(52, 0, -22), Vector3.new(52, 0, 22) },
		},
		base = Vector3.new(52, 0, 26),
		spots = { Vector3.new(36, 0, -12), Vector3.new(14, 0, -16), Vector3.new(14, 0, -6), Vector3.new(0, 0, -6), Vector3.new(0, 0, 6), Vector3.new(28, 0, -6), Vector3.new(44, 0, -6), Vector3.new(-8, 0, 0), Vector3.new(46, 0, -16), Vector3.new(-28, 0, -6), Vector3.new(-28, 0, 6), Vector3.new(14, 0, 6) },
	},
	Storm_3 = {
		-- Trois couloirs qui se rejoignent, puis un grand crochet jusqu'au château, en bas à droite.
		-- Couloirs de 220 / 220 / 220 studs (de l'entrée au château).
		displayName = "La citadelle de la Garde de la tempête",
		width = 128,
		depth = 76,
		lanes = {
			{ Vector3.new(-16, 0, -38), Vector3.new(-16, 0, -14), Vector3.new(-2, 0, -14), Vector3.new(-2, 0, -33), Vector3.new(12, 0, -33), Vector3.new(12, 0, 0), Vector3.new(26, 0, 0), Vector3.new(26, 0, -22), Vector3.new(56, 0, -22), Vector3.new(56, 0, 28) },
			{ Vector3.new(-64, 0, 0), Vector3.new(-50, 0, 0), Vector3.new(-50, 0, -14), Vector3.new(-36, 0, -14), Vector3.new(-36, 0, 0), Vector3.new(12, 0, 0), Vector3.new(26, 0, 0), Vector3.new(26, 0, -22), Vector3.new(56, 0, -22), Vector3.new(56, 0, 28) },
			{ Vector3.new(-16, 0, 38), Vector3.new(-16, 0, 14), Vector3.new(-2, 0, 14), Vector3.new(-2, 0, 33), Vector3.new(12, 0, 33), Vector3.new(12, 0, 0), Vector3.new(26, 0, 0), Vector3.new(26, 0, -22), Vector3.new(56, 0, -22), Vector3.new(56, 0, 28) },
		},
		base = Vector3.new(56, 0, 32),
		spots = { Vector3.new(40, 0, -12), Vector3.new(20, 0, -16), Vector3.new(20, 0, -6), Vector3.new(32, 0, -6), Vector3.new(48, 0, -6), Vector3.new(50, 0, -16), Vector3.new(20, 0, 6), Vector3.new(40, 0, -28), Vector3.new(28, 0, -28), Vector3.new(40, 0, 0), Vector3.new(6, 0, -6), Vector3.new(6, 0, 6) },
	},
	Storm_4 = {
		-- Quatre couloirs, puis un grand crochet jusqu'au château, en bas à droite.
		-- Couloirs de 240 / 240 / 240 / 240 studs (de l'entrée au château).
		displayName = "La citadelle de la Garde de la tempête",
		width = 136,
		depth = 88,
		lanes = {
			{ Vector3.new(-68, 0, -28), Vector3.new(-56, 0, -28), Vector3.new(-56, 0, -14), Vector3.new(-28, 0, -14), Vector3.new(-28, 0, 0), Vector3.new(14, 0, 0), Vector3.new(28, 0, 0), Vector3.new(28, 0, -26), Vector3.new(58, 0, -26), Vector3.new(58, 0, 34) },
			{ Vector3.new(-14, 0, -44), Vector3.new(-14, 0, -14), Vector3.new(0, 0, -14), Vector3.new(0, 0, -33), Vector3.new(14, 0, -33), Vector3.new(14, 0, 0), Vector3.new(28, 0, 0), Vector3.new(28, 0, -26), Vector3.new(58, 0, -26), Vector3.new(58, 0, 34) },
			{ Vector3.new(-14, 0, 44), Vector3.new(-14, 0, 14), Vector3.new(0, 0, 14), Vector3.new(0, 0, 33), Vector3.new(14, 0, 33), Vector3.new(14, 0, 0), Vector3.new(28, 0, 0), Vector3.new(28, 0, -26), Vector3.new(58, 0, -26), Vector3.new(58, 0, 34) },
			{ Vector3.new(-68, 0, 28), Vector3.new(-56, 0, 28), Vector3.new(-56, 0, 14), Vector3.new(-28, 0, 14), Vector3.new(-28, 0, 0), Vector3.new(14, 0, 0), Vector3.new(28, 0, 0), Vector3.new(28, 0, -26), Vector3.new(58, 0, -26), Vector3.new(58, 0, 34) },
		},
		base = Vector3.new(58, 0, 38),
		spots = { Vector3.new(42, 0, -16), Vector3.new(22, 0, -16), Vector3.new(34, 0, -10), Vector3.new(22, 0, -6), Vector3.new(50, 0, -10), Vector3.new(52, 0, -20), Vector3.new(42, 0, -32), Vector3.new(42, 0, -4), Vector3.new(22, 0, 6), Vector3.new(22, 0, -26), Vector3.new(64, 0, -16), Vector3.new(8, 0, -6) },
	},
	Obsidian_2 = {
		-- Deux couloirs à grands passages ; la partie commune longe le haut puis redescend au château, en bas.
		-- Couloirs de 264 / 264 studs (de l'entrée au château).
		displayName = "Le volcan des Chevaliers d'obsidienne",
		width = 120,
		depth = 64,
		lanes = {
			{ Vector3.new(-60, 0, -26), Vector3.new(-46, 0, -26), Vector3.new(-46, 0, -7), Vector3.new(-30, 0, -7), Vector3.new(-30, 0, -26), Vector3.new(-2, 0, -26), Vector3.new(-2, 0, 0), Vector3.new(12, 0, 0), Vector3.new(12, 0, -22), Vector3.new(52, 0, -22), Vector3.new(52, 0, 8), Vector3.new(30, 0, 8), Vector3.new(30, 0, 22) },
			{ Vector3.new(-60, 0, 26), Vector3.new(-46, 0, 26), Vector3.new(-46, 0, 7), Vector3.new(-30, 0, 7), Vector3.new(-30, 0, 26), Vector3.new(-2, 0, 26), Vector3.new(-2, 0, 0), Vector3.new(12, 0, 0), Vector3.new(12, 0, -22), Vector3.new(52, 0, -22), Vector3.new(52, 0, 8), Vector3.new(30, 0, 8), Vector3.new(30, 0, 22) },
		},
		base = Vector3.new(30, 0, 26),
		spots = { Vector3.new(40, 0, -8), Vector3.new(4, 0, -16), Vector3.new(22, 0, -6), Vector3.new(4, 0, -6), Vector3.new(40, 0, 2), Vector3.new(14, 0, 6), Vector3.new(18, 0, -16), Vector3.new(28, 0, -16), Vector3.new(46, 0, 14), Vector3.new(46, 0, -16), Vector3.new(24, 0, 4), Vector3.new(4, 0, 6) },
	},
	Obsidian_3 = {
		-- Trois couloirs ; la partie commune longe le haut puis redescend au château, en bas.
		-- Couloirs de 234 / 234 / 234 studs (de l'entrée au château).
		displayName = "Le volcan des Chevaliers d'obsidienne",
		width = 128,
		depth = 76,
		lanes = {
			{ Vector3.new(-16, 0, -38), Vector3.new(-16, 0, -14), Vector3.new(-2, 0, -14), Vector3.new(-2, 0, -33), Vector3.new(12, 0, -33), Vector3.new(12, 0, 0), Vector3.new(26, 0, 0), Vector3.new(26, 0, -22), Vector3.new(56, 0, -22), Vector3.new(56, 0, 8), Vector3.new(42, 0, 8), Vector3.new(42, 0, 28) },
			{ Vector3.new(-64, 0, 0), Vector3.new(-50, 0, 0), Vector3.new(-50, 0, -14), Vector3.new(-36, 0, -14), Vector3.new(-36, 0, 0), Vector3.new(12, 0, 0), Vector3.new(26, 0, 0), Vector3.new(26, 0, -22), Vector3.new(56, 0, -22), Vector3.new(56, 0, 8), Vector3.new(42, 0, 8), Vector3.new(42, 0, 28) },
			{ Vector3.new(-16, 0, 38), Vector3.new(-16, 0, 14), Vector3.new(-2, 0, 14), Vector3.new(-2, 0, 33), Vector3.new(12, 0, 33), Vector3.new(12, 0, 0), Vector3.new(26, 0, 0), Vector3.new(26, 0, -22), Vector3.new(56, 0, -22), Vector3.new(56, 0, 8), Vector3.new(42, 0, 8), Vector3.new(42, 0, 28) },
		},
		base = Vector3.new(42, 0, 32),
		spots = { Vector3.new(42, 0, -10), Vector3.new(20, 0, -16), Vector3.new(40, 0, 0), Vector3.new(50, 0, -4), Vector3.new(32, 0, -6), Vector3.new(20, 0, -6), Vector3.new(30, 0, 6), Vector3.new(32, 0, -16), Vector3.new(50, 0, -16), Vector3.new(50, 0, 14), Vector3.new(24, 0, 14), Vector3.new(40, 0, -28) },
	},
	Obsidian_4 = {
		-- Quatre couloirs ; la partie commune longe le haut puis redescend au château, en bas.
		-- Couloirs de 258 / 258 / 258 / 258 studs (de l'entrée au château).
		displayName = "Le volcan des Chevaliers d'obsidienne",
		width = 136,
		depth = 88,
		lanes = {
			{ Vector3.new(-68, 0, -28), Vector3.new(-56, 0, -28), Vector3.new(-56, 0, -14), Vector3.new(-28, 0, -14), Vector3.new(-28, 0, 0), Vector3.new(14, 0, 0), Vector3.new(28, 0, 0), Vector3.new(28, 0, -26), Vector3.new(60, 0, -26), Vector3.new(60, 0, 8), Vector3.new(44, 0, 8), Vector3.new(44, 0, 34) },
			{ Vector3.new(-14, 0, -44), Vector3.new(-14, 0, -14), Vector3.new(0, 0, -14), Vector3.new(0, 0, -33), Vector3.new(14, 0, -33), Vector3.new(14, 0, 0), Vector3.new(28, 0, 0), Vector3.new(28, 0, -26), Vector3.new(60, 0, -26), Vector3.new(60, 0, 8), Vector3.new(44, 0, 8), Vector3.new(44, 0, 34) },
			{ Vector3.new(-14, 0, 44), Vector3.new(-14, 0, 14), Vector3.new(0, 0, 14), Vector3.new(0, 0, 33), Vector3.new(14, 0, 33), Vector3.new(14, 0, 0), Vector3.new(28, 0, 0), Vector3.new(28, 0, -26), Vector3.new(60, 0, -26), Vector3.new(60, 0, 8), Vector3.new(44, 0, 8), Vector3.new(44, 0, 34) },
			{ Vector3.new(-68, 0, 28), Vector3.new(-56, 0, 28), Vector3.new(-56, 0, 14), Vector3.new(-28, 0, 14), Vector3.new(-28, 0, 0), Vector3.new(14, 0, 0), Vector3.new(28, 0, 0), Vector3.new(28, 0, -26), Vector3.new(60, 0, -26), Vector3.new(60, 0, 8), Vector3.new(44, 0, 8), Vector3.new(44, 0, 34) },
		},
		base = Vector3.new(44, 0, 38),
		spots = { Vector3.new(44, 0, -16), Vector3.new(50, 0, -8), Vector3.new(22, 0, -16), Vector3.new(44, 0, 0), Vector3.new(34, 0, -16), Vector3.new(22, 0, -6), Vector3.new(32, 0, 6), Vector3.new(50, 0, 14), Vector3.new(54, 0, 2), Vector3.new(54, 0, -20), Vector3.new(56, 0, 22), Vector3.new(34, 0, -4) },
	},
	Goblin_2 = {
		-- On entre par le haut et par le bas ; les deux couloirs se rejoignent, puis serpentent jusqu'au château.
		-- Couloirs de 283 / 283 studs (de l'entrée au château).
		displayName = "Les marais de la Horde gobeline",
		width = 120,
		depth = 66,
		lanes = {
			{ Vector3.new(-52, 0, -33), Vector3.new(-52, 0, -14), Vector3.new(-38, 0, -14), Vector3.new(-38, 0, -28), Vector3.new(-24, 0, -28), Vector3.new(-24, 0, 0), Vector3.new(-10, 0, 0), Vector3.new(-10, 0, -22), Vector3.new(6, 0, -22), Vector3.new(6, 0, 22), Vector3.new(22, 0, 22), Vector3.new(22, 0, -22), Vector3.new(38, 0, -22), Vector3.new(38, 0, 0) },
			{ Vector3.new(-52, 0, 33), Vector3.new(-52, 0, 14), Vector3.new(-38, 0, 14), Vector3.new(-38, 0, 28), Vector3.new(-24, 0, 28), Vector3.new(-24, 0, 0), Vector3.new(-10, 0, 0), Vector3.new(-10, 0, -22), Vector3.new(6, 0, -22), Vector3.new(6, 0, 22), Vector3.new(22, 0, 22), Vector3.new(22, 0, -22), Vector3.new(38, 0, -22), Vector3.new(38, 0, 0) },
		},
		base = Vector3.new(38, 0, 4),
		spots = { Vector3.new(-2, 0, -5), Vector3.new(14, 0, 5), Vector3.new(30, 0, -5), Vector3.new(14, 0, -13), Vector3.new(-16, 0, -17), Vector3.new(-4, 0, -15), Vector3.new(14, 0, 15), Vector3.new(28, 0, -15), Vector3.new(-16, 0, -7), Vector3.new(-6, 0, 5), Vector3.new(14, 0, -23), Vector3.new(28, 0, 5) },
	},
	Goblin_3 = {
		-- Un couloir entre au milieu du bord gauche, les autres par le haut et le bas ; ils serpentent jusqu'au château.
		-- Couloirs de 246 / 244 / 246 studs (de l'entrée au château).
		displayName = "Les marais de la Horde gobeline",
		width = 128,
		depth = 76,
		lanes = {
			{ Vector3.new(-18, 0, -38), Vector3.new(-18, 0, -14), Vector3.new(-2, 0, -14), Vector3.new(-2, 0, -33), Vector3.new(14, 0, -33), Vector3.new(14, 0, 0), Vector3.new(28, 0, 0), Vector3.new(28, 0, -24), Vector3.new(42, 0, -24), Vector3.new(42, 0, 24), Vector3.new(56, 0, 24), Vector3.new(56, 0, 0) },
			{ Vector3.new(-64, 0, 0), Vector3.new(-50, 0, 0), Vector3.new(-50, 0, -14), Vector3.new(-36, 0, -14), Vector3.new(-36, 0, 0), Vector3.new(14, 0, 0), Vector3.new(28, 0, 0), Vector3.new(28, 0, -24), Vector3.new(42, 0, -24), Vector3.new(42, 0, 24), Vector3.new(56, 0, 24), Vector3.new(56, 0, 0) },
			{ Vector3.new(-18, 0, 38), Vector3.new(-18, 0, 14), Vector3.new(-2, 0, 14), Vector3.new(-2, 0, 33), Vector3.new(14, 0, 33), Vector3.new(14, 0, 0), Vector3.new(28, 0, 0), Vector3.new(28, 0, -24), Vector3.new(42, 0, -24), Vector3.new(42, 0, 24), Vector3.new(56, 0, 24), Vector3.new(56, 0, 0) },
		},
		base = Vector3.new(56, 0, -4),
		spots = { Vector3.new(34, 0, -8), Vector3.new(48, 0, 8), Vector3.new(32, 0, 6), Vector3.new(22, 0, -16), Vector3.new(34, 0, -18), Vector3.new(48, 0, 18), Vector3.new(22, 0, -6), Vector3.new(26, 0, 14), Vector3.new(48, 0, -10), Vector3.new(30, 0, -30), Vector3.new(36, 0, 16), Vector3.new(20, 0, 6) },
	},
	Goblin_4 = {
		-- Quatre couloirs ; ils serpentent jusqu'au château.
		-- Couloirs de 260 / 260 / 260 / 260 studs (de l'entrée au château).
		displayName = "Les marais de la Horde gobeline",
		width = 136,
		depth = 88,
		lanes = {
			{ Vector3.new(-68, 0, -28), Vector3.new(-56, 0, -28), Vector3.new(-56, 0, -14), Vector3.new(-28, 0, -14), Vector3.new(-28, 0, 0), Vector3.new(14, 0, 0), Vector3.new(30, 0, 0), Vector3.new(30, 0, -26), Vector3.new(46, 0, -26), Vector3.new(46, 0, 26), Vector3.new(60, 0, 26), Vector3.new(60, 0, 0) },
			{ Vector3.new(-14, 0, -44), Vector3.new(-14, 0, -14), Vector3.new(0, 0, -14), Vector3.new(0, 0, -33), Vector3.new(14, 0, -33), Vector3.new(14, 0, 0), Vector3.new(30, 0, 0), Vector3.new(30, 0, -26), Vector3.new(46, 0, -26), Vector3.new(46, 0, 26), Vector3.new(60, 0, 26), Vector3.new(60, 0, 0) },
			{ Vector3.new(-14, 0, 44), Vector3.new(-14, 0, 14), Vector3.new(0, 0, 14), Vector3.new(0, 0, 33), Vector3.new(14, 0, 33), Vector3.new(14, 0, 0), Vector3.new(30, 0, 0), Vector3.new(30, 0, -26), Vector3.new(46, 0, -26), Vector3.new(46, 0, 26), Vector3.new(60, 0, 26), Vector3.new(60, 0, 0) },
			{ Vector3.new(-68, 0, 28), Vector3.new(-56, 0, 28), Vector3.new(-56, 0, 14), Vector3.new(-28, 0, 14), Vector3.new(-28, 0, 0), Vector3.new(14, 0, 0), Vector3.new(30, 0, 0), Vector3.new(30, 0, -26), Vector3.new(46, 0, -26), Vector3.new(46, 0, 26), Vector3.new(60, 0, 26), Vector3.new(60, 0, 0) },
		},
		base = Vector3.new(60, 0, -4),
		spots = { Vector3.new(36, 0, -10), Vector3.new(52, 0, 10), Vector3.new(36, 0, -20), Vector3.new(36, 0, 0), Vector3.new(22, 0, -16), Vector3.new(52, 0, 20), Vector3.new(30, 0, 8), Vector3.new(20, 0, -6), Vector3.new(40, 0, 10), Vector3.new(52, 0, -10), Vector3.new(20, 0, 6), Vector3.new(36, 0, -32) },
	},
	Dragon_2 = {
		-- Chaque couloir fait la moitié du grand tour (l'un en haut, l'autre en bas) ; la partie commune fait le petit
		-- tour jusqu'au château, presque au centre.
		-- Couloirs de 350 / 350 studs (de l'entrée au château).
		displayName = "Le repaire de la Couvée du dragon",
		width = 120,
		depth = 66,
		lanes = {
			{ Vector3.new(-60, 0, -28), Vector3.new(52, 0, -28), Vector3.new(52, 0, 0), Vector3.new(38, 0, 0), Vector3.new(38, 0, -14), Vector3.new(-48, 0, -14), Vector3.new(-48, 0, 14), Vector3.new(20, 0, 14) },
			{ Vector3.new(-60, 0, 28), Vector3.new(52, 0, 28), Vector3.new(52, 0, 0), Vector3.new(38, 0, 0), Vector3.new(38, 0, -14), Vector3.new(-48, 0, -14), Vector3.new(-48, 0, 14), Vector3.new(20, 0, 14) },
		},
		base = Vector3.new(24, 0, 14),
		spots = { Vector3.new(-38, 0, -1), Vector3.new(44, 0, -17), Vector3.new(44, 0, -7), Vector3.new(24, 0, -3), Vector3.new(34, 0, -21), Vector3.new(-40, 0, -21), Vector3.new(-40, 0, 21), Vector3.new(22, 0, -21), Vector3.new(-32, 0, 7), Vector3.new(44, 0, 11), Vector3.new(-30, 0, -21), Vector3.new(-30, 0, 21) },
	},
	Dragon_3 = {
		-- Trois couloirs se rejoignent, puis la partie commune s'enroule autour du château.
		-- Couloirs de 290 / 290 / 290 studs (de l'entrée au château).
		displayName = "Le repaire de la Couvée du dragon",
		width = 128,
		depth = 76,
		lanes = {
			{ Vector3.new(-16, 0, -38), Vector3.new(-16, 0, -14), Vector3.new(-2, 0, -14), Vector3.new(-2, 0, -33), Vector3.new(12, 0, -33), Vector3.new(12, 0, 0), Vector3.new(26, 0, 0), Vector3.new(26, 0, -28), Vector3.new(58, 0, -28), Vector3.new(58, 0, 28), Vector3.new(40, 0, 28), Vector3.new(40, 0, -10) },
			{ Vector3.new(-64, 0, 0), Vector3.new(-50, 0, 0), Vector3.new(-50, 0, -14), Vector3.new(-36, 0, -14), Vector3.new(-36, 0, 0), Vector3.new(12, 0, 0), Vector3.new(26, 0, 0), Vector3.new(26, 0, -28), Vector3.new(58, 0, -28), Vector3.new(58, 0, 28), Vector3.new(40, 0, 28), Vector3.new(40, 0, -10) },
			{ Vector3.new(-16, 0, 38), Vector3.new(-16, 0, 14), Vector3.new(-2, 0, 14), Vector3.new(-2, 0, 33), Vector3.new(12, 0, 33), Vector3.new(12, 0, 0), Vector3.new(26, 0, 0), Vector3.new(26, 0, -28), Vector3.new(58, 0, -28), Vector3.new(58, 0, 28), Vector3.new(40, 0, 28), Vector3.new(40, 0, -10) },
		},
		base = Vector3.new(40, 0, -14),
		spots = { Vector3.new(48, 0, 12), Vector3.new(20, 0, -16), Vector3.new(50, 0, -12), Vector3.new(30, 0, 6), Vector3.new(46, 0, 22), Vector3.new(52, 0, 2), Vector3.new(32, 0, -6), Vector3.new(46, 0, -22), Vector3.new(32, 0, -20), Vector3.new(20, 0, -6), Vector3.new(24, 0, 14), Vector3.new(34, 0, 16) },
	},
	Dragon_4 = {
		-- Quatre couloirs se rejoignent, puis la partie commune s'enroule autour du château.
		-- Couloirs de 304 / 304 / 304 / 304 studs (de l'entrée au château).
		displayName = "Le repaire de la Couvée du dragon",
		width = 136,
		depth = 88,
		lanes = {
			{ Vector3.new(-68, 0, -28), Vector3.new(-56, 0, -28), Vector3.new(-56, 0, -14), Vector3.new(-28, 0, -14), Vector3.new(-28, 0, 0), Vector3.new(14, 0, 0), Vector3.new(28, 0, 0), Vector3.new(28, 0, -30), Vector3.new(60, 0, -30), Vector3.new(60, 0, 30), Vector3.new(42, 0, 30), Vector3.new(42, 0, -10) },
			{ Vector3.new(-14, 0, -44), Vector3.new(-14, 0, -14), Vector3.new(0, 0, -14), Vector3.new(0, 0, -33), Vector3.new(14, 0, -33), Vector3.new(14, 0, 0), Vector3.new(28, 0, 0), Vector3.new(28, 0, -30), Vector3.new(60, 0, -30), Vector3.new(60, 0, 30), Vector3.new(42, 0, 30), Vector3.new(42, 0, -10) },
			{ Vector3.new(-14, 0, 44), Vector3.new(-14, 0, 14), Vector3.new(0, 0, 14), Vector3.new(0, 0, 33), Vector3.new(14, 0, 33), Vector3.new(14, 0, 0), Vector3.new(28, 0, 0), Vector3.new(28, 0, -30), Vector3.new(60, 0, -30), Vector3.new(60, 0, 30), Vector3.new(42, 0, 30), Vector3.new(42, 0, -10) },
			{ Vector3.new(-68, 0, 28), Vector3.new(-56, 0, 28), Vector3.new(-56, 0, 14), Vector3.new(-28, 0, 14), Vector3.new(-28, 0, 0), Vector3.new(14, 0, 0), Vector3.new(28, 0, 0), Vector3.new(28, 0, -30), Vector3.new(60, 0, -30), Vector3.new(60, 0, 30), Vector3.new(42, 0, 30), Vector3.new(42, 0, -10) },
		},
		base = Vector3.new(42, 0, -14),
		spots = { Vector3.new(50, 0, 14), Vector3.new(44, 0, -24), Vector3.new(32, 0, 6), Vector3.new(48, 0, 24), Vector3.new(52, 0, -14), Vector3.new(54, 0, 4), Vector3.new(22, 0, -16), Vector3.new(34, 0, -20), Vector3.new(34, 0, -6), Vector3.new(22, 0, -6), Vector3.new(48, 0, -4), Vector3.new(54, 0, -24) },
	},
}

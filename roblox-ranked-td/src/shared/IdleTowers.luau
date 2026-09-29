-- Tours du mode infini (ta parcelle). Indépendantes des tours du ranked.
-- Au départ seul l'Archer du rempart est débloqué ; les autres se gagnent à la machine à tours
-- (rareté = chance de l'obtenir). Doublons et bonus de la machine à bonus s'appliquent en plus.
--
-- Équilibrage (réglé avec tools/balance, qui simule maintenant les projectiles, le feu des flèches, la petite
-- zone du Mage et le rayon du Sorcier exactement comme PlotGame.luau : voir tools/balance/RESULTS.md). Toutes
-- les tours ont le même prix d'amélioration à un niveau donné, donc à niveau égal on compare leurs stats.
-- Chacune a son rôle (banc d'essai, une seule fuite = vague ratée) :
--   Archer du rempart   -> tireur rapide à longue portée (21) et flèches enflammées : fort contre les files
--                          d'ennemis et sur les vagues de boss (il tue aussi l'escorte) ; garde un vrai rôle
--                          toute la partie (le joueur simulé l'améliore encore après la vague 100)
--   Totem de givre      -> tour de CONTRÔLE : ralentit tout (-60 %) et rend les ennemis de son aura
--                          FRAGILES (+X % de dégâts reçus des autres tours, sauf le Mage des tempêtes, X
--                          monte avec son niveau) ; ses propres dégâts restent faibles (pas de « tout givre »)
--   Catapulte           -> grosse zone contre les foules tassées
--   Mage des tempêtes   -> contrôle : petite zone (3) + ralentissement TRÈS fort (-90 %) mais court
--   Baliste lourde      -> gros carreaux PERÇANTS à longue portée (30) : vise le plus résistant, et le
--                          carreau touche tous les ennemis sur sa ligne
--   Sorcier des arcanes -> rayon qui monte : bat la Baliste contre les lents (boss, colosse, chevaliers
--                          lourds), perd contre les rapides ; très fort avec un Totem de givre
--   Oracle / Trébuchet  -> légendaires, rares : bien plus fortes à niveau égal (elles ont peu de doublons) ;
--                          le Trébuchet écrase le plus gros groupe du chemin et l'étourdit (faible contre
--                          un boss seul, exprès)
-- Les tours communes reçoivent beaucoup plus de doublons que les légendaires, ce qui les garde utiles.
-- La portée compte énormément : 30 pour la Baliste couvre ~2 fois plus de chemin que 21 pour l'Archer,
-- 70 pour le Trébuchet couvre tout le chemin ; ces tours ont donc moins de dégâts par seconde.
-- Projectiles (flèches, rochers, carreaux, pierres) : la tour vise l'endroit où sera l'ennemi, et les dégâts
-- tombent à l'impact, pas au moment du tir (voir PlotGame.luau). Archer, Catapulte et Baliste SUIVENT leur
-- cible : à l'impact, l'effet tombe là où elle est vraiment (si elle vit encore et n'est pas trop loin du
-- point prévu, voir followDistance), même si un ralentissement arrivé pendant le vol l'a retardée. Le
-- Trébuchet royal garde son point prévu (il vise une foule, pas un ennemi).
--
-- CONTRÔLES (règle du propriétaire : « aucun cumul de ralentissement ») : un ennemi ne subit qu'UN SEUL effet
-- de contrôle à la fois (ralentissement du Totem de givre, ralentissement du Mage des tempêtes,
-- étourdissement du Trébuchet royal), et sa force ne se multiplie jamais. Un autre type de tour ne peut rien
-- tant que l'effet en cours dure (premier arrivé, premier servi). Totem de givre et Mage des tempêtes ne se
-- cumulent donc pas : le joueur choisit. La fragilité du Totem n'est PAS un contrôle (elle s'applique toujours).
-- FATIGUE des contrôles courts (retour du propriétaire à la vague 148 : plein de Mages avec la rune x2 vitesse
-- gelaient tout, « un peu de la triche ») : le Mage et le Trébuchet ne prolongent JAMAIS leur effet en cours,
-- et quand il se termine, l'ennemi est immunisé contre ce type de tour pendant slowImmunity / stunImmunity
-- secondes. Le Totem de givre (aura faite pour durer) n'a pas d'immunité : un autre Totem prolonge son effet.
-- Détails : applyControl dans PlotGame.luau.
--
-- Façons de toucher (kind) :
--   "Single" : une cible ; "Splash" : une zone autour du point d'impact (rayon `splash`) ;
--   "Pierce" : un carreau qui transperce tout sur la ligne tour -> point d'impact (demi-largeur `pierceWidth`) ;
--   "Aura" : tous les ennemis à portée ; "Chain" : un éclair qui rebondit ; "Beam" : rayon continu.
-- Façons de viser (targeting) : "First" = le plus avancé, "Strongest" = le plus résistant, "Crowd" = le point
-- du chemin où la zone touchera le plus d'ennemis (Trébuchet, voir PlotGame:pickCrowdTarget).
-- Avec projectileSpeed (studs par seconde), la tour lance un projectile (temps de vol : flightTime) ;
-- sans, elle touche tout de suite.
-- Effets : slow + slowDuration = ralentissement (contrôle) ; stunDuration = étourdissement (contrôle, vitesse
-- 0) ; slowImmunity / stunImmunity = contrôle COURT : jamais prolongé, puis immunité (fatigue, voir plus haut) ;
-- fragilityBase/PerLevel/Max = fragilité du Totem ; ignoresFragility = ses dégâts ne profitent pas de la
-- fragilité. idealAgainst = ligne « Idéale contre : ... » de la fiche de la tour.
local IdleConfig = require(script.Parent.IdleConfig)

local IdleTowers = {}

IdleTowers.ORDER = { "MachineGun", "Frost", "Bomb", "Tesla", "Rocket", "Laser", "Chain", "Orbital" }

-- Temps de vol maximal d'un projectile, en secondes de simulation : il voyage sur 1 octet (en centièmes
-- de seconde, 2,55 s au plus) dans le paquet des tirs (PlotGame.luau). Un réglage plus long est coupé ici.
IdleTowers.MAX_FLIGHT_TIME = 2.5
-- Flèche dont la cible est morte pendant le vol : elle touche l'ennemi vivant le plus proche du point
-- d'impact s'il est à moins de ce rayon (en studs), sinon elle est perdue (mais enflamme quand même le sol).
IdleTowers.PROJECTILE_CATCH_RADIUS = 1.5
-- Projectiles qui SUIVENT leur cible (Archer, Catapulte, Baliste ; bug vu par le propriétaire : la Catapulte
-- tirait trop loin quand l'ennemi était ralenti pendant le vol). À l'impact, l'effet tombe sur la position
-- réelle de la cible si elle vit encore et qu'elle est à moins de (sa zone + cette marge) studs du point prévu
-- au tir (voir followDistance) ; sinon au point prévu. 6 : l'ennemi le plus rapide (13 studs/s) arrêté juste
-- après le tir perd au plus ~13 studs sur le plus long vol de la Catapulte (~1 s) : zone 7 + 6 = 13.
IdleTowers.PROJECTILE_FOLLOW_MARGIN = 6
-- Zones de feu actives au plus sur une parcelle (toutes tours confondues) : au-delà, la plus vieille s'éteint.
IdleTowers.FIRE_MAX_PER_PLOT = 30

IdleTowers.Defs = {
	MachineGun = {
		rarity = "Common",
		displayName = "Archer du rempart",
		description = "", -- écrite plus bas (elle cite fireDamageRatio)
		kind = "Single",
		targeting = "First",
		color = Color3.fromRGB(72, 126, 70),
		placeCost = 10,
		damage = 3,
		-- 21 (15 avant) : le banc d'essai le laissait au niveau 1 vers la vague 40, le Mage et le Sorcier
		-- faisaient plus de dégâts par pièce. Il couvre maintenant ~2 fois plus de chemin.
		range = 21,
		cooldown = 0.2,
		projectileSpeed = 90, -- flèche rapide : ~0,1 à 0,25 s de vol
		-- Flèches enflammées : chaque flèche laisse au sol, là où elle tombe, une petite zone de feu qui
		-- brûle tous les ennemis dedans. Dégâts du feu par seconde = fireDamageRatio x dégâts de la flèche
		-- (niveaux, doublons et runes de dégâts comptent donc aussi pour le feu), un coup toutes les fireTick s.
		-- Une flèche qui tombe dans une zone de la même tour la ravive (elle repart pour fireDuration s) au
		-- lieu d'en créer une autre ; fireMaxPatches zones par tour au plus (la plus vieille s'éteint).
		-- Réglé avec tools/balance (voir tools/balance/RESULTS.md) : à 10 % par seconde et rayon 2,25, le feu ne
		-- changeait presque rien (+5 % de puissance contre les files d'ennemis) ; à 40 % et rayon 2,5, il rend
		-- l'Archer ~30 % plus fort contre les Escarmouches, les Charges et les Levées. Rayon < 4 : un ennemi à
		-- 4 studs de l'impact ne brûle pas (test Studio).
		fireRadius = 2.5,
		fireDuration = 2,
		fireDamageRatio = 0.4,
		fireTick = 0.5,
		fireMaxPatches = 5,
		idealAgainst = "les files d'ennemis et l'escorte des boss (le feu brûle ceux qui suivent)",
	},
	Frost = {
		rarity = "Common",
		displayName = "Totem de givre",
		description = "", -- écrite plus bas (elle cite la fragilité)
		kind = "Aura",
		color = Color3.fromRGB(150, 230, 255),
		placeCost = 25,
		-- Tour de CONTRÔLE d'abord (demande du propriétaire : à niveau égal, il faisait plus de dégâts que la
		-- Catapulte). Touche tous les ennemis proches à chaque impulsion, mais ses dégâts restent faibles :
		-- 2 (6 avant). Réglé avec tools/balance : à 3, une tour seule faisait encore 1,2 fois les dégâts de la
		-- Catapulte contre une foule de 30 écuyers (même niveau) ; à 2, 0,8 fois. Il ne doit JAMAIS permettre une
		-- partie « tout givre » : sa force vient de la fragilité, qui renforce les AUTRES tours.
		damage = 2,
		range = 11,
		cooldown = 1,
		-- -60 % de vitesse. Dure 2,5 s : plus que le temps entre deux impulsions (1 s), donc un ennemi dans
		-- l'aura reste ralenti tout le temps, et encore un peu après. C'est un CONTRÔLE : un seul à la fois par
		-- ennemi (voir plus haut) ; deux Totems = un seul -60 %, jamais plus.
		slow = 0.6,
		slowDuration = 2.5,
		-- FRAGILITÉ : les ennemis dans l'aura prennent +X % de dégâts de TOUTES les AUTRES tours sauf le Mage des
		-- tempêtes (pas de synergie Givre + Mage, demande du propriétaire). X monte avec le niveau du Totem,
		-- pour que l'améliorer vaille toujours le coup :
		--   X = min(fragilityMax, fragilityBase + fragilityPerLevel x (niveau - 1))
		--   niveau 1 : +10 %, niveau 11 : +30 %, niveau 46 : +100 %, +300 % au plus (niveau 146).
		-- Gardé après l'équilibrage (tools/balance/RESULTS.md) : le joueur simulé pose 3 à 5 Totems et continue
		-- d'en améliorer un (niveau ~68 et +144 % vers la vague 100) ; à +1,5 %/niveau et +200 % au plus, rien de
		-- mieux. Deux Totems ne s'additionnent pas : le plus fort
		-- gagne. Elle suit l'aura : elle dure encore fragilityDuration s après la sortie (comme le ralentissement).
		-- Doublons et runes ne la changent pas (seulement le niveau).
		fragilityBase = 0.1,
		fragilityPerLevel = 0.02,
		fragilityMax = 3,
		fragilityDuration = 2.5,
		-- Les dégâts des Totems ne profitent pas de la fragilité (ni la sienne, ni celle d'un autre Totem) : sinon,
		-- avec +300 % au plus, un Totem ferait jusqu'à 4 fois ses dégâts et une partie « tout givre » redeviendrait
		-- la meilleure (ses dégâts doivent rester faibles). Mettre false pour qu'ils en profitent.
		ignoresFragility = true,
		idealAgainst = "les Charges de cavalerie et les Levées ; rend tes autres tours plus fortes",
	},
	Bomb = {
		rarity = "Rare",
		displayName = "Catapulte",
		description = "Projette des rochers sur une zone : idéale contre les hordes.",
		kind = "Splash",
		targeting = "First",
		color = Color3.fromRGB(240, 130, 50),
		placeCost = 40,
		damage = 17, -- ses rochers écrasent les foules : bonne contre les Levées d'écuyers dès le début
		range = 14,
		cooldown = 1.8,
		splash = 7,
		-- Tir en cloche : vol = distance / 24 studs par seconde, 0,45 s au moins (~0,45 à 0,65 s).
		projectileSpeed = 24,
		projectileMinFlight = 0.45,
		idealAgainst = "les foules tassées (Levées d'écuyers)",
	},
	Tesla = {
		rarity = "Rare",
		displayName = "Mage des tempêtes",
		description = "", -- écrite plus bas (elle cite le ralentissement)
		-- La foudre tombe tout de suite (pas de projectile) sur l'ennemi de tête, et touche aussi ceux
		-- qui sont collés à lui : tous prennent les dégâts ET le ralentissement (s'ils ne subissent pas déjà
		-- le contrôle d'une autre tour, voir « CONTRÔLES » plus haut).
		kind = "Splash",
		targeting = "First",
		color = Color3.fromRGB(250, 230, 80),
		placeCost = 50,
		-- Réglé avec tools/balance : avec sa zone, le ralentissement touche plusieurs ennemis à chaque éclair.
		-- À 14 dégâts, -60 % pendant 1,2 s et rayon 3, plusieurs Mages ralentissaient TOUTE la vague : il était
		-- 4 à 10 fois meilleur que les autres tours contre les Escarmouches, Levées et Charges (banc d'essai) et
		-- remplaçait tout, Catapulte comprise. Avec les réglages plus bas (et la fatigue), une équipe de Mages
		-- seuls reste la meilleure tour non légendaire contre ces 3 vagues au banc d'essai (vagues 50+), mais le
		-- joueur simulé n'en pose que 1 à 3, et « tout Mage » finit 4 à 7 vagues derrière son mélange
		-- (tools/balance/RESULTS.md).
		damage = 10, -- inchangé (demande du propriétaire)
		range = 16,
		cooldown = 0.8,
		-- Petite zone : moins de la moitié de la Catapulte (7) ; touche les ennemis collés à sa cible. 3 (2,5
		-- avant la fatigue, voir plus bas) : chaque éclair ralentit un peu plus d'ennemis du groupe.
		splash = 3,
		-- Ralentissement COURT mais bien plus fort que celui du Totem (-90 % contre -60 %) : le joueur choisit
		-- entre le Totem et le Mage, ils ne se cumulent pas (un seul contrôle à la fois). Anciens réglages :
		-- -30 % pendant 0,8 s au tout début, puis -85 % pendant 0,4 s (à 0,5 s, « tout Mage » allait aussi loin
		-- que le mélange du joueur : les Mages se relayaient sans fin ; la fatigue plus bas l'empêche maintenant).
		slow = 0.9, -- 0,9 au plus (demande du propriétaire)
		slowDuration = 0.6,
		-- FATIGUE (retour du propriétaire à la vague 148 : « mes Mages avec vitesse x2, j'en mets un max : full
		-- freeze », avec des Catapultes derrière) : un éclair ne prolonge jamais un ralentissement du Mage en
		-- cours, et quand il se termine, l'ennemi est immunisé contre les ralentissements du Mage pendant
		-- slowImmunity secondes (les dégâts tombent toujours). Donc 0,6 s ralenti sur 1,4 s au plus (43 % du
		-- temps), quel que soit le nombre de Mages et leurs runes (100 % avant). Le Totem de givre, lui, peut
		-- prendre le relais. Un Mage seul (un éclair toutes les 0,8 s) ralentit sa cible 0,6 s sur 1,6 s.
		-- Réglé avec tools/balance (RESULTS.md) : avec la fatigue et les anciens chiffres (-85 %, 0,4 s, 1 s
		-- d'immunité, zone 2,5), le joueur simulé posait encore le Mage mais ne l'améliorait plus (« sinon le
		-- Mage était un peu obsolète », disait le propriétaire). Chaque éclair vaut maintenant ~1,6 fois plus
		-- (0,54 s de marche perdue au lieu de 0,34), et « tout Mage » comme « Mages x2 vitesse + Catapultes »
		-- restent derrière le mélange du joueur. Durée + immunité = 1,4 s, exprès pas un multiple de 0,8 s (le
		-- temps entre deux éclairs) : sinon un éclair tomberait pile à la fin de l'immunité, et selon les images
		-- il ralentirait ou non.
		slowImmunity = 0.8,
		-- Ses dégâts ne profitent pas de la fragilité du Totem de givre (pas de synergie Givre + Mage).
		ignoresFragility = true,
		idealAgainst = "les petits groupes rapides (cavaliers) : coups de frein très forts",
	},
	Rocket = {
		rarity = "Epic",
		displayName = "Baliste lourde",
		description = "Un carreau perçant à longue portée : il vise le plus résistant et transperce tous les ennemis sur sa ligne.",
		-- Carreau PERÇANT : la Baliste vise toujours l'ennemi le plus résistant, mais à l'impact, TOUS les
		-- ennemis à moins de pierceWidth studs du segment tour -> point d'impact prennent les dégâts (sa
		-- cible comprise, touchée même si un ralentissement l'a fait dévier). Remplace sa toute petite zone
		-- (rayon 2) : elle doit servir au milieu de partie, pas seulement contre les boss.
		kind = "Pierce",
		targeting = "Strongest",
		color = Color3.fromRGB(200, 60, 60),
		placeCost = 80,
		-- 50 (40 avant) : le Sorcier des arcanes, aussi Épique, faisait mieux qu'elle contre tous les types de
		-- vague (banc d'essai) ; maintenant elle le bat contre les Levées d'écuyers au début.
		damage = 50,
		range = 30,
		cooldown = 4, -- tire rarement : excellente contre les gros
		-- Demi-largeur du carreau perçant, en studs. 1,25 (1,5 au premier essai : la Baliste faisait jusqu'à 90 %
		-- des dégâts des vagues 26-50 ; tools/balance). Pas moins : le test Studio place un ennemi à 1 stud du
		-- trait, qui doit être touché. Ses dégâts (50) ne bougent pas : les duels Sorcier / Baliste contre un
		-- seul ennemi restent les mêmes.
		pierceWidth = 1.25,
		projectileSpeed = 75, -- carreau lourd, tir tendu : ~0,15 à 0,45 s de vol
		idealAgainst = "les chevaliers lourds, les boss et les ennemis alignés",
	},
	Laser = {
		rarity = "Epic",
		displayName = "Sorcier des arcanes",
		description = "", -- écrite plus bas (elle cite beamRampMax)
		-- Rayon continu : il s'accroche à l'ennemi le plus résistant à portée et le GARDE tant qu'il est
		-- vivant et à portée (il ne change jamais de cible pour un ennemi plus fort : ça remettrait la
		-- montée à zéro). Dégâts par seconde = damage x montée, montée = min(beamRampMax, 1 + beamRampRate x
		-- secondes sur cette cible), à chaque pas de simulation. Les ennemis lents (boss, colosses, chevaliers
		-- lourds, ennemis gelés par le Totem) restent assez longtemps pour prendre la montée entière ; les
		-- cavaliers traversent sa portée avant qu'il chauffe. Il est plus fort dans un virage du chemin, où
		-- la cible reste longtemps à portée.
		-- Niveaux, doublons et runes de dégâts multiplient `damage` ; la rune x2 vitesse d'attaque double la
		-- vitesse de montée, voir effectiveStats.
		-- Réglé avec tools/balance (duels du rapport : UNE tour contre UN ennemi qui traverse tout le chemin,
		-- même niveau, 3 meilleurs emplacements). Montée lente et haute : peu de dégâts au début (7/s, moins
		-- que la Baliste), beaucoup après quelques secondes sur la même cible. Les ennemis lents restent assez
		-- longtemps pour la prendre, les rapides non. Duels contre la Baliste lourde : Seigneur de guerre x1,7,
		-- colosse x2,1, chevalier lourd x1,35, mais fantassin x0,95, cavalier x0,8, écuyer x0,8 ; avec un Totem
		-- de givre à côté : x3 contre les boss. Sur une vraie vague de boss (6 fantassins d'escorte à tuer aussi,
		-- une seule fuite = ratée), il fait à peu près comme la Baliste : pas de victoire automatique.
		-- Avant : 20/s, +1,5/s, x6 : il battait la Baliste contre TOUT, cavaliers compris (x1,75). À 6,5/s, le
		-- joueur simulé ne s'en servait plus après la vague 50 ; à 7,5/s, il devenait presque aussi bon que la
		-- Baliste contre les cavaliers (x0,85).
		kind = "Beam",
		targeting = "Strongest", -- seulement pour choisir une nouvelle cible
		color = Color3.fromRGB(255, 70, 200),
		placeCost = 120,
		damage = 7, -- dégâts PAR SECONDE au début du rayon (montée x1) : la Baliste fait 12,5/s
		range = 14, -- 18 avant : les ennemis rapides la traversent plus vite
		beamRampRate = 2, -- +2 par seconde sur la même cible
		beamRampMax = 25, -- x25 au plus (175/s au niveau 1), atteint après 12 s sur la même cible
		idealAgainst = "les boss, les colosses et les ennemis lents",
	},
	Chain = {
		rarity = "Legendary",
		displayName = "Oracle de la foudre",
		description = "Un éclair ancien rebondit entre quatre ennemis.",
		kind = "Chain",
		targeting = "First",
		color = Color3.fromRGB(150, 110, 255),
		placeCost = 250,
		-- par ennemi touché (4 ennemis par éclair). 50 (18 avant) : les légendaires sont maintenant rares (la
		-- première vers la vague 65-70, IdleConfig.TOWER_SPIN_TIERS) et ont très peu de doublons, alors que les
		-- tours communes en ont des centaines à ce moment-là (+200 à +600 % de dégâts). À 18, 32 ou 40, le joueur
		-- simulé ne la posait jamais (0 % des dégâts). À niveau égal et sans doublons, elle est la meilleure
		-- contre les Escarmouches, les Levées, les Charges et les boss ; avec les doublons du joueur, à égalité
		-- avec le Totem de givre.
		damage = 50,
		range = 20,
		cooldown = 1.2,
		chains = 4,
		idealAgainst = "les vagues nombreuses (4 ennemis par éclair)",
	},
	Orbital = {
		rarity = "Legendary",
		displayName = "Trébuchet royal",
		description = "Une pierre runique écrase le plus gros groupe d'ennemis à portée et les étourdit un instant.",
		-- Vise le point du chemin où sa GRANDE zone touchera le plus d'ennemis (positions prévues à l'arrivée
		-- de la pierre ; à égalité, le groupe le plus avancé), partout à portée (70 : tout le chemin). Une
		-- légendaire doit être puissante contre les foules au milieu de partie ; contre un boss seul, elle est
		-- faible, exprès (avant : elle visait le plus résistant avec une zone de 5).
		kind = "Splash",
		targeting = "Crowd",
		color = Color3.fromRGB(120, 240, 255),
		placeCost = 400,
		-- 35 (70 au premier essai de la visée « foule ») : légendaire rare, peu de doublons (voir l'Oracle).
		-- Réglé avec tools/balance : à 70, avec sa portée qui couvre tout le chemin, il était AUSSI le meilleur
		-- contre un colosse ou un boss seul (2 fois la Baliste en duel) et faisait 90 à 100 % des dégâts
		-- après la vague 60 (le joueur simulé en posait 10) ; à 20-25, le joueur ne le posait presque plus.
		damage = 35,
		range = 70,
		cooldown = 5,
		splash = 10, -- grande zone (5 avant ; la Catapulte : 7)
		-- Étourdit (vitesse 0) tous les ennemis de la zone pendant stunDuration s. C'est un CONTRÔLE : refusé
		-- sur un ennemi déjà ralenti par une autre tour (les dégâts, eux, tombent toujours).
		stunDuration = 0.5,
		-- FATIGUE (comme le Mage) : une pierre ne prolonge jamais un étourdissement en cours, et quand il se
		-- termine, l'ennemi est immunisé contre les étourdissements pendant stunImmunity secondes : plusieurs
		-- Trébuchets ne peuvent pas enchaîner les étourdissements (0,5 s sur 2 s au plus).
		stunImmunity = 1.5,
		-- Grande cloche : vol = distance / 45 studs par seconde, 0,8 s au moins (~0,8 à 1,6 s).
		projectileSpeed = 45,
		projectileMinFlight = 0.8,
		idealAgainst = "les grosses foules, n'importe où sur le chemin (faible contre un boss seul)",
	},
}

-- Nombre écrit à la française : 0.1 -> "0,1", 7 -> "7".
local function frenchNumber(value: number): string
	return (string.gsub(string.format("%g", value), "%.", ","))
end

-- Textes qui citent des réglages : écrits ici pour rester justes quand on change les chiffres.
do
	local archer = IdleTowers.Defs.MachineGun
	archer.description = `Flèches enflammées : chaque flèche laisse une petite zone de feu qui brûle les ennemis ({frenchNumber(archer.fireDamageRatio * 100)} % de ses dégâts par seconde).`
	local sorcerer = IdleTowers.Defs.Laser
	sorcerer.description = `Rayon continu : ses dégâts montent tant qu'il reste sur la même cible (jusqu'à x{frenchNumber(sorcerer.beamRampMax)}). Terrible contre les boss et les colosses, faible contre les ennemis rapides.`
	local frost = IdleTowers.Defs.Frost
	frost.description = `Ralentit de {frenchNumber(frost.slow * 100)} % tout ce qui passe dans son aura et rend ces ennemis fragiles : +{frenchNumber(frost.fragilityBase * 100)} % de dégâts reçus de tes autres tours (sauf le Mage des tempêtes), +{frenchNumber(frost.fragilityPerLevel * 100)} % par niveau.`
	local mage = IdleTowers.Defs.Tesla
	mage.description = `Foudroie une petite zone et ralentit très fort (-{frenchNumber(mage.slow * 100)} %) mais brièvement les ennemis touchés. Ne se cumule pas avec le Totem de givre.`
end

-- Améliorations : niveaux illimités. Chaque niveau multiplie les dégâts, et chaque
-- amélioration coûte plus cher que la précédente (réglages dans IdleConfig).
-- Le prix est le même pour toutes les tours : avant, il suivait le prix de pose, et à dépense égale
-- l'Archer (10 pièces) finissait 5 fois plus fort qu'un Trébuchet (400 pièces).
local statsCache = {}

-- Fragilité donnée par une tour à ce niveau (0 si elle n'en donne pas) : +0,1 = +10 % de dégâts reçus.
--   min(fragilityMax, fragilityBase + fragilityPerLevel x (niveau - 1)), toujours un nombre fini.
function IdleTowers.fragilityAt(def, level: number): number
	if not def.fragilityBase then
		return 0
	end
	local steps = math.max(0, (tonumber(level) or 1) - 1)
	return math.clamp(def.fragilityBase + def.fragilityPerLevel * steps, 0, def.fragilityMax)
end

-- Stats effectives d'une tour à un niveau donné (dégâts multipliés par le niveau). En plus des champs de sa
-- définition : towerType (sa clé, ex. "Frost" : la règle des contrôles compare les types de tours), level,
-- et fragility (Totem de givre, voir fragilityAt).
function IdleTowers.stats(towerType: string, level: number)
	local key = towerType .. ":" .. level
	local cached = statsCache[key]
	if cached then
		return cached
	end
	local def = IdleTowers.Defs[towerType]
	local stats = table.clone(def)
	stats.towerType = towerType
	stats.level = level
	stats.damage = def.damage * IdleConfig.UPGRADE_DAMAGE ^ (level - 1)
	if def.fragilityBase then
		stats.fragility = IdleTowers.fragilityAt(def, level)
	end
	statsCache[key] = stats
	return stats
end

-- Prix pour passer du niveau `level` au niveau `level + 1` : 20, 27, 36... (x1,35 par niveau), le même
-- pour toutes les tours. towerType est gardé pour les appels existants (PlotGame, PlotUI).
-- Niveau 100 -> 160 T, niveau 1000 -> 3,2e131 : toujours un nombre fini.
function IdleTowers.upgradeCost(_towerType: string, level: number): number
	local raw = IdleConfig.UPGRADE_COST_BASE * IdleConfig.UPGRADE_COST_GROWTH ^ (level - 1)
	if raw >= math.huge then
		-- Au-delà du niveau ~2 350 le prix devient infini : « MAX », jamais payable (sans ce test, l'arrondi
		-- ci-dessous donnerait NaN : « pièces < NaN » est faux, l'achat passerait et les pièces deviendraient NaN).
		return math.huge
	end
	local magnitude = 10 ^ math.max(0, math.floor(math.log10(raw)) - 1)
	return math.floor(raw / magnitude + 0.5) * magnitude
end

-- Pas de rune (effectiveStats) : toujours la même table vide, jamais modifiée.
local NO_RUNES = table.freeze({})

-- Stats finales d'une tour posée : niveau + doublons (+2 % chacun, IdleConfig.DUPLICATE_DAMAGE_BONUS)
-- + runes de la forge. Une tour a 2 emplacements de rune qui se CUMULENT (IdleConfig.RUNE_SLOTS) : la rune de
-- dégâts multiplie les dégâts (le feu des flèches suit), la rune de vitesse d'attaque divise le temps entre
-- deux attaques (x2 vitesse = 2 fois plus d'attaques par seconde). Ex. Archer niveau 1 (3 dégâts, 5 atq/s)
-- avec x20 dégâts et x2 vitesse : 60 dégâts par coup, 10 atq/s.
-- runes = les runes posées, dans un format de IdleConfig.parseRunes : texte de l'attribut « Bonus » du modèle
-- ("Damage20,Speed2", un seul id marche aussi), ou table d'ids ({ Damage = "Damage20", Speed = "Speed2" }) ;
-- nil ou "" = aucune. Le tableau renvoyé ne doit jamais être modifié (il peut être partagé).
function IdleTowers.effectiveStats(towerType: string, level: number, dupes: number?, runes: any?)
	local base = IdleTowers.stats(towerType, level)
	local found = if runes == nil or runes == "" then NO_RUNES else IdleConfig.parseRunes(runes)
	local damageRune, speedRune = found.Damage, found.Speed
	if (dupes or 0) == 0 and not damageRune and not speedRune then
		return base
	end
	local stats = table.clone(base)
	stats.damage *= 1 + (dupes or 0) * IdleConfig.DUPLICATE_DAMAGE_BONUS
	if damageRune then
		stats.damage *= damageRune.mult
	end
	if speedRune then
		if stats.kind == "Beam" then
			-- Rayon continu : pas de coups à accélérer, la rune fait chauffer le rayon plus vite
			-- (x2 vitesse : la montée va 2 fois plus vite, le maximum ne change pas).
			stats.beamRampRate *= speedRune.mult
		else
			stats.cooldown /= speedRune.mult
		end
	end
	return stats
end

-- Dégâts par seconde sur UNE cible (une Foudre en chaîne compte ses 4 cibles). Les tours de zone (Catapulte,
-- Mage, Trébuchet), la Baliste perçante et le Totem (aura) touchent souvent plusieurs ennemis à chaque coup :
-- ce n'est pas compté ici (les fiches affichent plutôt dégâts par coup, attaques par seconde et zone).
-- Rayon continu : au début (x1), voir beamMaxDps pour le maximum. Le feu des flèches n'est pas compté (voir
-- fireDps), la fragilité du Totem non plus (elle renforce les autres tours). Sert au panneau du fief
-- (PlotBoard.luau) : toujours un nombre fini pour toutes les tours.
function IdleTowers.dpsOf(stats): number
	if stats.kind == "Beam" then
		return stats.damage
	end
	return stats.damage * (stats.chains or 1) / stats.cooldown
end

-- Attaques par seconde (nil pour le rayon continu : afficher « continu »).
function IdleTowers.attacksPerSecond(stats): number?
	if stats.kind == "Beam" then
		return nil
	end
	return 1 / stats.cooldown
end

-- Effet de contrôle de la tour pour sa fiche : { kind = "Slow" | "Stun", strength (0,6 = -60 % ; 1 pour un
-- étourdissement), duration (s), immunity (s d'immunité après la fin, 0 = aucune : voir « FATIGUE ») }, ou
-- nil. Un seul contrôle à la fois par ennemi (voir « CONTRÔLES »).
function IdleTowers.controlOf(stats)
	if stats.stunDuration then
		return { kind = "Stun", strength = 1, duration = stats.stunDuration, immunity = stats.stunImmunity or 0 }
	elseif stats.slow then
		return { kind = "Slow", strength = stats.slow, duration = stats.slowDuration, immunity = stats.slowImmunity or 0 }
	end
	return nil
end

----------------------------------------------------------------------
-- Rayon continu (Sorcier des arcanes)
----------------------------------------------------------------------

-- Multiplicateur de dégâts après `seconds` secondes sur la même cible : 1 au début, puis +beamRampRate
-- par seconde, jamais plus de beamRampMax.
function IdleTowers.beamRamp(stats, seconds: number): number
	return math.min(stats.beamRampMax, 1 + stats.beamRampRate * math.max(0, seconds))
end

-- Dégâts par seconde quand le rayon est au maximum.
function IdleTowers.beamMaxDps(stats): number
	return stats.damage * stats.beamRampMax
end

-- Secondes sur la même cible pour atteindre le maximum.
function IdleTowers.beamRampSeconds(stats): number
	return (stats.beamRampMax - 1) / stats.beamRampRate
end

-- Dégâts totaux du rayon entre 0 et `seconds` secondes sur la même cible (intégrale de la montée).
-- Sert aux tests et au banc d'essai ; le jeu applique la même chose pas à pas (PlotGame:beamStep).
function IdleTowers.beamDamage(stats, seconds: number): number
	seconds = math.max(0, seconds)
	local rampTime = IdleTowers.beamRampSeconds(stats)
	if seconds <= rampTime then
		return stats.damage * (seconds + stats.beamRampRate * seconds * seconds / 2)
	end
	local rising = rampTime + stats.beamRampRate * rampTime * rampTime / 2
	return stats.damage * (rising + (seconds - rampTime) * stats.beamRampMax)
end

----------------------------------------------------------------------
-- Projectiles et flèches enflammées
----------------------------------------------------------------------

-- Vrai si la tour lance un projectile (dégâts à l'impact) ; faux si elle touche tout de suite.
function IdleTowers.isProjectile(stats): boolean
	return stats.projectileSpeed ~= nil
end

-- Temps de vol, en secondes de simulation, jusqu'à un point à `distance` studs du haut de la tour.
function IdleTowers.flightTime(stats, distance: number): number
	local flight = math.max(stats.projectileMinFlight or 0, distance / stats.projectileSpeed)
	return math.clamp(flight, 0.05, IdleTowers.MAX_FLIGHT_TIME)
end

-- Vrai si le projectile de la tour SUIT sa cible (Archer, Catapulte, Baliste) : à l'impact, l'effet tombe là où
-- la cible est vraiment (voir followDistance). Faux pour les tirs instantanés et pour le Trébuchet royal
-- (« Crowd » : il vise le point de la foule, pas un ennemi).
function IdleTowers.followsTarget(stats): boolean
	return stats.projectileSpeed ~= nil and stats.targeting ~= "Crowd"
end

-- Distance (en studs, à plat) jusqu'à laquelle un projectile suit sa cible : si, à l'impact, elle est plus loin
-- que ça du point prévu au tir, l'effet tombe au point prévu. = sa zone (rayon de la Catapulte, rayon du feu de
-- l'Archer, demi-largeur du carreau de la Baliste) + PROJECTILE_FOLLOW_MARGIN. Même règle pour le serveur
-- (impactCenter dans PlotGame.luau), le simulateur (Engine.luau) et l'affichage (PlotRenderer).
function IdleTowers.followDistance(stats): number
	return math.max(stats.splash or 0, stats.fireRadius or 0, stats.pierceWidth or 0) + IdleTowers.PROJECTILE_FOLLOW_MARGIN
end

-- Dégâts par seconde d'une zone de feu (0 si la tour n'a pas de flèches enflammées).
function IdleTowers.fireDps(stats): number
	return if stats.fireRadius then stats.damage * stats.fireDamageRatio else 0
end

function IdleTowers.dps(towerType: string, level: number): number
	return IdleTowers.dpsOf(IdleTowers.stats(towerType, level))
end

function IdleTowers.ofRarity(rarity: string): { string }
	local list = {}
	for _, towerType in IdleTowers.ORDER do
		if IdleTowers.Defs[towerType].rarity == rarity then
			table.insert(list, towerType)
		end
	end
	return list
end

return IdleTowers

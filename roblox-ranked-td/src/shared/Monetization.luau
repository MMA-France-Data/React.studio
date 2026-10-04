-- LES ACHATS EN ROBUX. Demandes du propriétaire (04/10/2026) : « passer le temps des couveuses en Robux aussi, 1 Robux
-- les 5 min », « une 3e couveuse d'une autre couleur, incubation 2 fois plus rapide, à payer en Robux, pas cher, disons
-- 99 Robux » (elle remplace la 3e couveuse à pièces : sa réponse à ma question), « la couveuse 3 est invisible,
-- mets-la en or », puis « x2 XP 99 Robux aussi, et x2 argent 199 Robux ».
-- C'est le propriétaire qui crée les pass et les produits sur le Hub Création (son jeu > Monétisation) et qui donne
-- leurs numéros : ils s'écrivent ici. Tant qu'un numéro vaut 0, cet achat n'est pas proposé dans le jeu (rien ne
-- casse : il affiche « bientôt »). Le serveur : Hub/Shop.luau ; la fenêtre : onglet « 🛒 BOUTIQUE » (LevelsUI).
local Monetization = {}

-- Les pass (une fois pour toutes). id = son numéro sur Roblox ; price = le prix mis sur le Hub Création, seulement
-- affiché (la fenêtre d'achat de Roblox montre toujours le vrai prix).
Monetization.PASSES = {
	-- La couveuse royale : la 3e couveuse, dorée, où les œufs éclosent 2 fois plus vite (Levels.ROYAL). Sur le Hub
	-- Création : « Incubateur royal » (créé par le propriétaire le 05/10/2026).
	Royal = { id = 2006325409, price = 99 },
	-- XP x2 : toute l'XP d'entraînement gagnée est doublée (camp, niveaux joués, doublons des œufs ; pas l'XP achetée
	-- avec le bouton ⚡ : Levels.XP_PASS_MULTIPLIER).
	Xp = { id = 2006337360, price = 99 },
	-- Argent x2 : les pièces de niveau gagnées en jouant les niveaux sont doublées (Levels.COINS_PASS_MULTIPLIER).
	Coins = { id = 2006229395, price = 199 },
}
Monetization.PASS_ORDER = { "Royal", "Xp", "Coins" } -- (l'ordre de la boutique)

-- Produits « Finir l'œuf » (à chaque achat) : [prix en Robux] = numéro du produit. Le bouton prend le plus grand de
-- ces prix qui ne dépasse pas 1 Robux par tranche de 5 min qui reste (Levels.robuxSkipPrice) ; au démarrage, le
-- serveur vérifie sur Roblox que chaque produit a bien ce prix (sinon il n'est pas proposé).
Monetization.SKIP_PRODUCTS = {
	[1] = 0,
	[2] = 0,
	[3] = 0,
	[6] = 0,
	[12] = 0,
	[24] = 0,
	[48] = 0,
}

return Monetization

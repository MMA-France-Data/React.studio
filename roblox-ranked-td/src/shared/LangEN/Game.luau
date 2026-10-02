-- Dictionnaire anglais : les textes du jeu (tout sauf les noms, qui sont dans Glossary.luau).
-- Le jeu écrit toujours en français ; le client de chaque joueur anglais traduit en affichant (AutoTranslate).
-- Une ligne : ["texte français exact"] = "English", ; un texte qui change : {1}, {2}... (mode d'emploi en haut de
-- Shared/Lang.luau). Vérifier : luau.exe tools/lang/check.luau (depuis roblox-ranked-td).
-- PAS ENCORE TRADUITS (à faire avant de rendre le jeu public) : les écrans des niveaux et du camp
-- (src/client/LevelsUI.luau, marqués NoTranslate : ils restent en français pour tout le monde), les panneaux du camp
-- (Hub/Camp.luau, Hub/PlotBoard.luau, Hub/HubMap.luau) et les messages des niveaux (Hub/LevelsService.luau).
return {
	----------------------------------------------------------------------
	-- Hub/PlotIdentity.luau : plaque à l'entrée de chaque parcelle (nom et vignette du propriétaire)
	----------------------------------------------------------------------
	["FIEF {1}  /  DOMAINE"] = "KEEP {1}  /  DOMAIN", -- {1} = numéro de la parcelle (01 à 06)
	["Fief libre"] = "Unclaimed keep",
	["Un domaine prêt à accueillir son seigneur"] = "A domain awaiting its lord",
	["PARCELLE DISPONIBLE"] = "PLOT AVAILABLE",

	----------------------------------------------------------------------
	-- Hub/PlotBoard.luau et Hub/Plots.luau : parcelle sans joueur
	----------------------------------------------------------------------
	["Parcelle libre"] = "Unclaimed plot",
	["En attente d'un propriétaire"] = "Waiting for an owner",

	----------------------------------------------------------------------
	-- Invites (ProximityPrompt) des bâtiments et des emplacements du camp : Hub/HubMap.luau, Hub/Camp.luau
	----------------------------------------------------------------------
	["Ouvrir"] = "Open",

	----------------------------------------------------------------------
	-- Niveau d'une tour, au-dessus d'elle (client/PlotRenderer.luau) ; avec ses étoiles d'évolution : « ★★ Niv. 3 »
	----------------------------------------------------------------------
	["Niv. {1}"] = "Lv. {1}",
	["{1} Niv. {2}"] = "{1} Lv. {2}",

	----------------------------------------------------------------------
	-- Refus du serveur pendant un niveau (Hub/LevelGame.luau), affichés en petit message
	----------------------------------------------------------------------
	["Pas assez d'or"] = "Not enough gold",
	["Niveau maximum atteint"] = "Max level reached",

	----------------------------------------------------------------------
	-- Bouton « SON » et ses 3 réglages (client/SoundManager.luau, Sounds.MODE_LABELS)
	----------------------------------------------------------------------
	["SON"] = "SOUND",
	["tout"] = "all",
	["effets seuls"] = "effects only",
	["muet"] = "muted",
	["Son : {1}"] = "Sound: {1}",

	----------------------------------------------------------------------
	-- PlayerData.luau : messages de player:Kick. Le client ne peut pas les traduire : le serveur appelle lui-même
	-- Lang.translate(texte, Lang.forPlayer(player)).
	----------------------------------------------------------------------
	["Impossible de charger tes données. Réessaie dans une minute."] = "Couldn't load your data. Try again in a minute.",
	["Ta session a été ouverte sur un autre serveur."] = "Your session was opened on another server.",
}

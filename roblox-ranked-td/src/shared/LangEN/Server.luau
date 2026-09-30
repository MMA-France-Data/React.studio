-- Dictionnaire anglais : tout ce que le SERVEUR écrit et que les joueurs voient.
-- Le serveur écrit toujours en français ; le client de chaque joueur anglais traduit en affichant (AutoTranslate).
-- Messages (remote « Notify ») et textes du monde de src/server/Hub/** : PlotGame.luau (messages de la parcelle),
-- init.luau (messages, tableau du classement), HubMap.luau (panneaux, noms des machines, invites « Ouvrir » :
-- ActionText / ObjectText), PlotBoard.luau (tableau « CHRONIQUES DU FIEF »), PlotIdentity.luau (panneau d'entrée des
-- parcelles), RankedBoardDisplay.luau (panneaux du classé), SoloBoard.luau (panneaux du classement solo), Plots.luau,
-- Tutorial.luau, ChallengeRewards.luau ; et
-- src/server/Match/** (textes du match, raison de la fin, ligne des défis), Matchmaking.luau (inscription, match
-- proposé...), Leaderboard.luau, PlayerData.luau.
-- Un texte que le client ne peut pas traduire (ex. message de player:Kick) : le serveur le traduit lui-même avec
-- Lang.translate(texte, Lang.forPlayer(player)).
-- Une ligne : ["texte français exact"] = "English", ; un texte qui change : {1}, {2}... (mode d'emploi en haut de
-- Shared/Lang.luau). Noms du jeu : Glossary.luau.
-- Les noms mis dans un {n} (tours, ennemis...) sont traduits par le Glossaire. En anglais, « » devient “ ” (comme
-- dans Social.luau).
-- Textes du serveur traduits AILLEURS (une seule ligne par texte : ils s'affichent aussi côté client) :
--   * Machines.luau : « AUTEL DES HÉROS », « FORGE RUNIQUE » (aussi dans Social), « Il te faut {1} pièces »,
--     « Prix trop élevé (MAX) : ... », forge bloquée (IdleConfig.FORGE_NO_TOWER, FORGE_ALL_BEST), noms des runes ;
--   * Social.luau : refus du bouton « Récupérer » (Challenges.findClaimable), raisons d'un match qui ne compte pas
--     (Challenges.REASON_...), morceaux des récompenses (« +{1} pièces », « +{1} lancers d'autel »...), noms des rangs ;
--   * Plot.luau : limite de tours identiques (IdleTowers.copiesLimitMessage), « Cette tour est déjà posée ici »,
--     « Pas assez d'or » et refus de pose du match (Placement.luau), forge bloquée et noms des runes (aussi Machines) ;
--   * Social.luau : classé fermé (RankedGate.SOON_TITLE « BIENTÔT DISPONIBLE » et SOON_TEXT : tableau du classement,
--     plaques, refus d'une inscription ou d'un « Récupérer »).
return {
	----------------------------------------------------------------------
	-- Hub/PlotBoard.luau : tableau « CHRONIQUES DU FIEF » au fond de chaque parcelle
	----------------------------------------------------------------------
	["CHRONIQUES DU FIEF"] = "CHRONICLES OF THE KEEP", -- (« KEEP CHRONICLES » se lisait comme un ordre : « garde des chroniques »)
	["Parcelle libre"] = "Unclaimed plot", -- (aussi Plots.luau et PlotIdentity.luau)
	["VAGUE ACTUELLE"] = "CURRENT WAVE",
	["RECORD DE VAGUE"] = "BEST WAVE",
	["DPS TOTAL"] = "TOTAL DPS",
	["En attente d'un propriétaire"] = "Waiting for an owner",
	["Installe tes défenses pour écrire ton histoire"] = "Set up your defenses and write your story",
	["DPS théorique · niveaux, doublons, bonus et cadence inclus"] = "Theoretical DPS · levels, duplicates, runes and attack speed included",
	["Hors cibles supplémentaires touchées par les attaques de zone"] = "Not counting extra targets hit by area attacks",
	["Fief de {1}"] = "{1}'s keep", -- {1} = nom du joueur
	["DÉFENSE EN COURS · {1} ennemis restants"] = "DEFENDING · {1} enemies left",
	["RÉPIT · Prépare tes défenses"] = "RESPITE · Get your defenses ready",
	-- tours, renaissances, bonus de pièces, vitesse (1 ou 2)
	["{1} tours  ·  {2} renaissances  ·  +{3} % pièces  ·  Vitesse x{4}"] = "{1} towers  ·  {2} rebirths  ·  +{3}% coins  ·  Speed x{4}",

	----------------------------------------------------------------------
	-- Hub/PlotIdentity.luau : plaque à l'entrée de chaque parcelle (nom et vignette du propriétaire)
	----------------------------------------------------------------------
	["FIEF {1}  /  DOMAINE"] = "KEEP {1}  /  DOMAIN", -- {1} = numéro de la parcelle (01 à 06)
	["Fief libre"] = "Unclaimed keep",
	["Un domaine prêt à accueillir son seigneur"] = "A domain awaiting its lord",
	["DÉFENDS TON ROYAUME"] = "DEFEND YOUR KINGDOM",
	["PARCELLE DISPONIBLE"] = "PLOT AVAILABLE",

	----------------------------------------------------------------------
	-- Hub/HubMap.luau : invites « Ouvrir » des machines (ActionText ; ObjectText et noms au-dessus : Machines.luau)
	----------------------------------------------------------------------
	["Ouvrir"] = "Open",

	----------------------------------------------------------------------
	-- Hub/RankedBoardDisplay.luau : petites plaques à côté du classement
	----------------------------------------------------------------------
	["DUEL ÉQUITABLE"] = "FAIR DUEL",
	["Rejoins le sceau\nau centre de la cour"] = "Head to the seal\nin the middle of the courtyard",

	----------------------------------------------------------------------
	-- Hub/init.luau : classement du centre, messages (bouton x2, cercle du classé, machines des autres)
	-- Leaderboard.luau : nom d'un joueur introuvable
	----------------------------------------------------------------------
	["CLASSEMENT RANKED — SAISON {1}"] = "RANKED LEADERBOARD — SEASON {1}",
	-- une ligne du classement : place, nom, MMR, rang (le rang est traduit par le dictionnaire Social)
	["  #{1}   {2}   —   {3} MMR ({4})"] = "  #{1}   {2}   —   {3} MMR ({4})",
	["  Aucun joueur classé pour l'instant"] = "  No ranked players yet",
	["Joueur {1}"] = "Player {1}", -- {1} = numéro du joueur (UserId) ; aussi sur les panneaux du classement solo

	----------------------------------------------------------------------
	-- Hub/SoloBoard.luau : panneaux du classement SOLO (record de vague et DPS, tous les serveurs)
	-- (les colonnes « DPS » et « Money » de la liste des joueurs sont déjà en anglais pour tout le monde)
	----------------------------------------------------------------------
	["CLASSEMENT SOLO"] = "SOLO LEADERBOARD",
	["MEILLEURE VAGUE"] = "BEST WAVE",
	["MEILLEUR DPS"] = "BEST DPS",
	["JOUEUR"] = "PLAYER",
	["VAGUE"] = "WAVE",
	["DPS"] = "DPS",
	["Aucun record pour l'instant"] = "No records yet",
	["Tous les serveurs · mis à jour chaque minute"] = "All servers · updated every minute",
	["Il te faut le pass Vitesse x2 (bouton « Boutique »)"] = "You need the Speed x2 pass (“Shop” button)",
	["Vitesse x2 allumée"] = "Speed x2 on",
	["Vitesse normale"] = "Normal speed",
	["Entre dans le cercle de l'arène pour t'inscrire au classé"] = "Step into the arena circle to join Ranked",
	["Cet autel appartient à un autre fief !"] = "This altar belongs to another keep!",

	----------------------------------------------------------------------
	-- Hub/PlotGame.luau : messages de ta parcelle (vagues, renaissance, tours, emplacements, autel, forge)
	----------------------------------------------------------------------
	-- {2} = nom de l'ennemi (Glossaire) ; « un ennemi » a sa propre ligne (« an enemy », pas « a enemy »)
	["Vague {1} ratée : un {2} a atteint ta base ! Retour à la vague {3}"] = "Wave {1} failed: a {2} reached your base! Back to wave {3}",
	["Vague {1} ratée : un ennemi a atteint ta base ! Retour à la vague {2}"] = "Wave {1} failed: an enemy reached your base! Back to wave {2}",
	["Réussis la vague {1} pour renaître (meilleure vague de la run : {2})"] = "Clear wave {1} to rebirth (best wave this run: {2})",
	["Renaissance ! +{1} % de pièces • bonus total : +{2} %"] = "Rebirth! +{1}% coins • total bonus: +{2}%",
	-- {1} = nom de la tour (Glossaire)
	["{1} n'est pas encore débloquée : invoque-la à l'autel des héros !"] = "{1} isn't unlocked yet: summon it at the Heroes' Altar!",
	["Il y a déjà une tour ici : clique dessus puis « Remplacer… »"] = "There's already a tower here: click it, then “Replace…”",
	["Pas assez de pièces"] = "Not enough coins",
	-- (« Cette tour est déjà posée ici » : Plot.luau, aussi affiché par PlotUI)
	["{1} posé • ancienne tour revendue +{2}"] = "{1} placed • old tower sold +{2}",
	["Tour vendue : +{1} pièces"] = "Tower sold: +{1} coins",
	["Cet emplacement est déjà débloqué"] = "This spot is already unlocked",
	["Emplacement {1} débloqué !"] = "Spot {1} unlocked!",
	-- Autel des héros : « lancer » -> spin (comme Machines.luau et Social.luau)
	["Atteins la vague {1} pour lancer x{2} d'un coup"] = "Reach wave {1} to spin x{2} at once",
	["Nombre de lancers invalide"] = "Invalid number of spins",
	["Ton inventaire de bonus est plein"] = "Your rune inventory is full",
	-- rune posée sur une tour : « Bonus x20 dégâts posé ! » ({1} = nom de la rune, traduit par Machines.luau)
	["Bonus {1} posé !"] = "{1} rune placed!",

	----------------------------------------------------------------------
	-- Hub/ChallengeRewards.luau : bouton « Récupérer » des défis classés et message à l'arrivée
	----------------------------------------------------------------------
	["Tes données sont encore en cours de chargement"] = "Your data is still loading",
	["Ton fief se prépare : réessaie dans un instant"] = "Your keep is getting ready: try again in a moment",
	-- « Défi réussi ! +1.2M pièces • +10 lancers d'autel » : {1} = « +1.2M pièces », puis chaque morceau après un
	-- « • » est traduit par Social.luau (« +{1} lancers d'autel »...)
	["Défi réussi ! {1}"] = "Challenge complete! {1}",
	["Défis classés : 1 récompense à récupérer (bouton ⚔ DÉFIS)"] = "Ranked challenges: 1 reward to claim (⚔ CHALLENGES button)",
	["Défis classés : {1} récompenses à récupérer (bouton ⚔ DÉFIS)"] = "Ranked challenges: {1} rewards to claim (⚔ CHALLENGES button)",

	----------------------------------------------------------------------
	-- Match/init.luau : serveur du match classé (défis qui ne comptent pas, match annulé, fin du match)
	----------------------------------------------------------------------
	-- « Défis classés : » + la raison (Challenges.REASON_..., traduite par Social.luau)
	["Défis classés : {1}"] = "Ranked challenges: {1}",
	-- match annulé (écran de fin du match)
	["Le serveur s'est arrêté. Aucun MMR perdu."] = "The server shut down. No MMR lost.",
	["Ton adversaire ne s'est pas connecté. Aucun MMR perdu."] = "Your opponent didn't connect. No MMR lost.",
	["En attente..."] = "Waiting...",
	["Fin du match (Studio) : pas de retour au lobby possible ici."] = "Match over (Studio): can't go back to the lobby from here.",
	-- messages de player:Kick : le client ne peut pas les traduire, le serveur doit appeler
	-- Lang.translate(texte, Lang.forPlayer(player)) (aussi pour ceux de PlayerData.luau plus bas)
	["Match terminé ! Relance le jeu pour revenir au lobby."] = "Match over! Restart the game to go back to the lobby.",
	["Ce serveur est réservé à un match ranked."] = "This server is reserved for a ranked match.",

	----------------------------------------------------------------------
	-- Match/Game.luau et Match/MapBuilder.luau : messages du match classé, nom au-dessus des bases
	----------------------------------------------------------------------
	-- (« Pas assez d'or » et les refus de pose de Placement.luau : Plot.luau, aussi affichés par TowerPlacement)
	["Nombre maximum de tours atteint"] = "Tower limit reached",
	["Impossible de poser la tour"] = "Can't place the tower",
	["Niveau maximum atteint"] = "Max level reached",
	["Forteresse {1}"] = "Fortress {1}", -- {1} = 1 ou 2

	----------------------------------------------------------------------
	-- Matchmaking.luau : inscription au classé, match proposé, téléportation (« s'inscrire » -> join, comme Social)
	----------------------------------------------------------------------
	["Tu es inscrit au classé ! Tu peux partir jouer : on te propose le match dès qu'un adversaire est trouvé."] = "You're in the ranked queue! Go play: we'll offer you the match as soon as an opponent is found.",
	["Tu n'es plus inscrit au classé"] = "You're no longer in the ranked queue",
	["Tu as refusé le match"] = "You declined the match",
	["Match non accepté à temps : tu es retiré de la file"] = "Match not accepted in time: you're out of the queue",
	["Ton adversaire n'a pas accepté : retour dans la file"] = "Your opponent didn't accept: back in the queue",
	["Le match n'a pas pu être créé : retour dans la file"] = "The match couldn't be created: back in the queue",
	["La téléportation a échoué. Réinscris-toi dans le cercle de l'arène."] = "Teleport failed. Join again from the arena circle.",
	["Studio : les deux joueurs ont accepté ! Dans le jeu publié, la téléportation vers le match partirait maintenant."] = "Studio: both players accepted! In the published game, the teleport to the match would start now.",
	["Match accepté ! Téléportation vers le match…"] = "Match accepted! Teleporting to the match…",
	["Ta réponse n'est pas partie, réessaie"] = "Your answer didn't go through, try again",
	["Tu es déjà inscrit au classé"] = "You're already in the ranked queue",
	["Le matchmaking est indisponible pour le moment."] = "Matchmaking is unavailable right now.",
	["Attends un instant avant de te réinscrire"] = "Wait a moment before joining again",
	["Tes données sont encore en cours de chargement."] = "Your data is still loading.",
	["Le matchmaking est indisponible, réessaie."] = "Matchmaking is unavailable, try again.",
	["Adversaire factice {1}"] = "Fake opponent {1}", -- tests Studio seulement

	----------------------------------------------------------------------
	-- PlayerData.luau : messages de player:Kick (à traduire par le serveur, voir plus haut)
	----------------------------------------------------------------------
	["Impossible de charger tes données. Réessaie dans une minute."] = "Couldn't load your data. Try again in a minute.",
	["Ta session a été ouverte sur un autre serveur."] = "Your session was opened on another server.",
}

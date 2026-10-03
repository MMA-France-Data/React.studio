-- Dictionnaire anglais : les textes du jeu (tout sauf les noms, qui sont dans Glossary.luau).
-- Le jeu écrit toujours en français ; le client de chaque joueur anglais traduit en affichant (AutoTranslate).
-- Une ligne : ["texte français exact"] = "English", ; un texte qui change : {1}, {2}... (mode d'emploi en haut de
-- Shared/Lang.luau). Un texte entouré de symboles ou de nombres (« ⚔ NIVEAUX », « 🔒 EMPLACEMENT 2 », « +0,3 XP »)
-- est traduit par son milieu : pas besoin d'une ligne pour chacun.
-- Vérifier : luau.exe tools/lang/check.luau et luau.exe tools/lang/samples.luau (depuis roblox-ranked-td), puis le
-- test Studio « run.ps1 -Test english » (aucun texte ne doit rester en français).
return {
	----------------------------------------------------------------------
	-- Mots seuls gardés tels quels (ils s'affichent avec des nombres ou des symboles : « 10 / 40 XP », « 👑 BOSS »)
	----------------------------------------------------------------------
	["X"] = "X",
	["X ?"] = "X?",
	["XP"] = "XP",
	["XP/min"] = "XP/min",
	["MAX"] = "MAX",
	["BOSS"] = "BOSS",
	["MINI-BOSS"] = "MINI-BOSS",

	----------------------------------------------------------------------
	-- client/LevelsUI.luau : bouton de la map principale et fenêtre du camp
	----------------------------------------------------------------------
	["NIVEAUX"] = "LEVELS", -- « ⚔ NIVEAUX »
	["Niveaux"] = "Levels",
	["Boutique"] = "Shop",
	["Entraînement"] = "Training",
	["Mes tours"] = "My towers",
	-- Onglet « Niveaux »
	["TERRITOIRE {1}"] = "TERRITORY {1}",
	["réussis le niveau {1}"] = "clear level {1}", -- « 🔒 réussis le niveau 10 »
	["NIVEAU {1}"] = "LEVEL {1}",
	["{1} monstres"] = "{1} monsters",
	["Rejouer :"] = "Replay:",
	["Victoire :"] = "Win:",
	["REJOUER"] = "REPLAY",
	["JOUER"] = "PLAY", -- « ▶ JOUER »
	["Chaque niveau est un flot de monstres sans pause, de plus en plus forts : pose et améliore tes tours sans arrêt avec l'or qu'ils donnent, protège ton château ({1} vies). Gagner rapporte des pièces de niveau 🏅 pour acheter d'autres tours et améliorer ton camp d'entraînement."] = "Each level is a non-stop stream of monsters that keep getting stronger: place and upgrade your towers all the time with the gold they drop, and protect your castle ({1} lives). Winning earns level coins 🏅 to buy more towers and upgrade your training camp.",
	["Victoires : {1}"] = "Wins: {1}",
	["Défaites : {1}"] = "Losses: {1}",
	-- Onglet « Boutique » (rôles des tours : ROLES)
	["Tireur rapide à longue portée. Ta tour de base."] = "Fast long-range shooter. Your basic tower.",
	["Ralentit de {1} % tout ce qui passe près de lui."] = "Slows everything near it by {1}%.",
	["Ses rochers écrasent les groupes serrés."] = "Its rocks crush tight groups.",
	["Foudre sur un petit groupe, gros coup de frein."] = "Lightning on a small group, and a hard brake.",
	["Gros carreau contre les monstres résistants."] = "A big bolt against tough monsters.",
	["Rayon qui chauffe : terrible contre les boss."] = "A beam that heats up: deadly against bosses.",
	["Un éclair qui rebondit sur 4 monstres."] = "A bolt that bounces across 4 monsters.",
	["Une pierre géante sur le plus gros groupe."] = "A giant stone on the biggest group.",
	["En niveau : {1}"] = "In a level: {1}",
	["{1} au plus"] = "{1} max",
	["✓ À TOI"] = "✓ OWNED",
	["ACHETER {1}"] = "BUY {1}",
	["{1} (il manque {2})"] = "{1} (need {2} more)",
	-- Tours pas encore achetées, dans les listes « Entraînement » et « Mes tours »
	["{1} dans la Boutique"] = "{1} in the Shop",
	["BOUTIQUE"] = "SHOP",
	-- Onglet « Entraînement »
	["EMPLACEMENT {1}"] = "SLOT {1}",
	["niveau {1}"] = "level {1}",
	["Vide : choisis une tour à droite"] = "Empty: pick a tower on the right",
	["+{1} XP par minute"] = "+{1} XP per minute",
	["Améliorer {1}"] = "Upgrade {1}",
	["NIVEAU MAX"] = "MAX LEVEL",
	["Une tour de plus à l'entraînement"] = "One more tower in training",
	["Ouvre d'abord le précédent"] = "Open the previous one first",
	["Ouvrir {1}"] = "Open {1}",
	["Une tour dans un emplacement gagne de l'XP tout le temps, même quand tu es parti ({1} h au plus). Chaque niveau joué donne aussi de l'XP aux tours posées. Chaque niveau d'entraînement : +{2} % de dégâts, et de nouvelles améliorations. Le bouton ⚡ achète avec tes pièces l'XP qui manque pour le niveau suivant."] = "A tower in a slot earns XP all the time, even while you're away (up to {1} h). Every level you play also gives XP to the towers you placed. Each training level: +{2}% damage, and new upgrades. The ⚡ button buys the XP missing for the next level with your coins.",
	["NIVEAU"] = "LEVEL", -- « ⚡ +1 NIVEAU » (bouton ⚡ de l'onglet Entraînement)
	["Entraînement {1}/{2}"] = "Training {1}/{2}",
	["Prochaine évolution (entraînement {1}) : {2}. {3}"] = "Next evolution (training {1}): {2}. {3}",
	["Toutes ses évolutions sont débloquées."] = "All its evolutions are unlocked.",
	["✓ S'ENTRAÎNE (retirer)"] = "✓ TRAINING (remove)",
	["Empl. {1} → {2}"] = "Slot {1} → {2}",
	["ENTRAÎNER"] = "TRAIN",
	-- Onglet « Mes tours »
	["Toutes tes tours peuvent être posées dans un niveau. Cet ordre est celui de ta barre rapide (▲ ▼ pour le changer)."] = "All your towers can be placed in a level. This is the order of your quick bar (▲ ▼ to change it).",
	["entraînement {1}"] = "training {1}",
	-- Ligne de stats d'une tour (statsLine, UI.towerSpeed)
	["Dégâts {1}"] = "Damage {1}",
	["{1} atq/s"] = "{1} atk/s",
	["continu"] = "continuous",
	["Portée {1}"] = "Range {1}",

	----------------------------------------------------------------------
	-- client/LevelsUI.luau : écran d'un niveau
	----------------------------------------------------------------------
	["Monstres : {1} / {2}"] = "Monsters: {1} / {2}",
	["ANNULER"] = "CANCEL",
	-- Conseils au-dessus de la barre des tours
	["Ton Archer tire déjà ! Touche un « + » pour en poser un deuxième"] = "Your Archer is already shooting! Tap a “+” to place a second one",
	["Touche une tour pour l'améliorer avec ton or"] = "Tap a tower to upgrade it with your gold",
	["Touche le terrain (ou un « + ») pour poser : {1}. Changer d'avis : « Annuler »"] = "Tap the ground (or a “+”) to place: {1}. Changed your mind? “Cancel”",
	["Ne garde pas ton or : pose ou améliore une tour, les monstres deviennent de plus en plus forts !"] = "Don't sit on your gold: place or upgrade a tower, the monsters keep getting stronger!",
	-- Menu d'une tour posée
	["niv. {1}"] = "lv. {1}",
	["Niveau suivant : dégâts {1}"] = "Next level: damage {1}",
	["Vendre +{1}"] = "Sell +{1}",
	-- Écran de fin
	["VICTOIRE !"] = "VICTORY!",
	["DÉFAITE"] = "DEFEAT",
	["Niveau {1} réussi pour la première fois !"] = "Level {1} cleared for the first time!",
	["Niveau {1} réussi une fois de plus."] = "Level {1} cleared once more.",
	["Vies restantes : {1}/{2}"] = "Lives left: {1}/{2}",
	["Niveau {1} : {2} monstres éliminés sur {3}."] = "Level {1}: {2} of {3} monsters defeated.",
	["Il te restait {1} : dépense ton or au fur et à mesure, les monstres deviennent plus forts sans arrêt."] = "You had {1} left: spend your gold as you go, the monsters never stop getting stronger.",
	["Les monstres deviennent plus forts sans arrêt : pose et améliore tes tours du début à la fin, sans garder ton or."] = "The monsters never stop getting stronger: place and upgrade towers from start to finish, and don't sit on your gold.",
	["La boutique et le camp d'entraînement aident aussi."] = "The shop and the training camp help too.",
	["Un gros monstre est passé : la Baliste lourde et le Sorcier des arcanes visent toujours le plus gros."] = "A big monster got through: the Heavy Ballista and the Arcane Sorcerer always aim at the biggest one.",
	["Tu peux acheter une nouvelle tour à la boutique !"] = "You can buy a new tower in the shop!", -- « 🏅 Tu peux... »
	["Nouveau territoire ouvert : {1} !"] = "New territory unlocked: {1}!", -- « 🗺 Nouveau territoire... »
	["Tes tours posées gagnent +{1} XP d'entraînement."] = "Your placed towers gain +{1} training XP.",
	["ÉVOLUTION ! {1} : {2}"] = "EVOLUTION! {1}: {2}", -- « ⭐ ÉVOLUTION ! Archer du rempart : Flèches enflammées »
	["Tour"] = "Tower",
	["Niveau {1} ▶"] = "Level {1} ▶",
	["Tous les niveaux sont réussis !"] = "All levels cleared!",
	["Réessayer"] = "Try again",
	["Rejouer"] = "Replay",
	["Retour au camp"] = "Back to camp", -- « ⛺ Retour au camp »
	-- Petits messages
	["Appuie encore sur X pour abandonner ce niveau"] = "Tap X again to give up this level",
	["Impossible de poser ici"] = "Can't place here",
	["{1} : entraînement {2} (+{3} % de dégâts)"] = "{1}: training {2} (+{3}% damage)",

	----------------------------------------------------------------------
	-- client/TutorialUI.luau : les mots de la flèche du tuto
	----------------------------------------------------------------------
	["APPUIE ICI"] = "TAP HERE",
	["LES NIVEAUX"] = "THE LEVELS",
	["JOUE ICI"] = "PLAY HERE",
	["PRENDS UN ARCHER"] = "TAKE AN ARCHER",
	["PRENDS UNE CATAPULTE"] = "TAKE A CATAPULT",
	["PRENDS CETTE TOUR"] = "TAKE THIS TOWER",
	["POSE-LA ICI"] = "PLACE IT HERE",
	["TOUCHE CETTE TOUR"] = "TAP THIS TOWER",
	["AMÉLIORE"] = "UPGRADE",
	["CONTINUE"] = "CONTINUE",
	["RÉESSAIE"] = "TRY AGAIN",
	["NOUVELLE TOUR !"] = "NEW TOWER!",
	["LA BOUTIQUE"] = "THE SHOP",
	["ACHÈTE-LA"] = "BUY IT",
	["Passer le tuto"] = "Skip tutorial",
	["Confirmer ?"] = "Confirm?",
	["Tuto passé : bonne partie !"] = "Tutorial skipped: have fun!",

	----------------------------------------------------------------------
	-- Shared/Levels.luau : évolutions des tours (PERKS : text ; leurs noms sont dans le Glossaire)
	----------------------------------------------------------------------
	["Chaque flèche laisse une petite zone de feu."] = "Each arrow leaves a small patch of fire.",
	["+{1} de portée."] = "+{1} range.",
	["+{1} % de vitesse d'attaque."] = "+{1}% attack speed.",
	["Les ennemis ralentis prennent plus de dégâts des autres tours."] = "Slowed enemies take more damage from other towers.",
	["Ralentit de 50 % au lieu de 40 %."] = "Slows by 50% instead of 40%.",
	["Zone d'impact plus large (+{1})."] = "Wider impact area (+{1}).",
	["Zone de foudre plus large (+{1})."] = "Wider lightning area (+{1}).",
	["Le carreau transperce jusqu'à 3 ennemis alignés."] = "The bolt pierces up to 3 enemies in a line.",
	["Le rayon chauffe 50 % plus vite."] = "The beam heats up 50% faster.",
	["Le rayon monte 20 % plus haut."] = "The beam ramps up 20% higher.",
	["Un ennemi de plus par éclair (5)."] = "One more enemy per bolt (5).",
	["Étourdit plus longtemps (+{1} s)."] = "Stuns longer (+{1} s).",

	----------------------------------------------------------------------
	-- Refus et messages du serveur (Shared/Levels.luau : checkPlacement ; Hub/LevelGame.luau ; Hub/LevelsService.luau),
	-- affichés en petit message
	----------------------------------------------------------------------
	["Position invalide"] = "Invalid position",
	["Hors du terrain"] = "Off the field",
	["Trop près du chemin"] = "Too close to the path",
	["Trop près du château"] = "Too close to the castle",
	["Trop près d'une autre tour"] = "Too close to another tower",
	["Le niveau est terminé"] = "The level is over",
	["Tour inconnue"] = "Unknown tower",
	["{1} n'est pas encore à toi : achète cette tour dans la boutique"] = "{1} isn't yours yet: buy this tower in the shop",
	["Maximum {1} {2} par niveau"] = "Max {1} {2} per level",
	["Pas assez d'or"] = "Not enough gold",
	["Niveau maximum atteint"] = "Max level reached",
	["Tes données ne sont pas encore chargées"] = "Your data isn't loaded yet",
	["Ce niveau n'existe pas encore"] = "This level doesn't exist yet",
	["Réussis d'abord le niveau {1}"] = "Clear level {1} first",
	["Aucune zone de combat libre pour toi"] = "No battle zone is free for you",
	["Cette tour n'est pas en vente"] = "This tower isn't for sale",
	["{1} est déjà à toi"] = "{1} is already yours",
	["Il te manque {1} pièces de niveau"] = "You need {1} more level coins",
	["Achat réussi : {1} rejoint ta barre de tours"] = "Purchased: {1} joins your tower bar",
	["Emplacement inconnu"] = "Unknown slot",
	["Cette tour n'est pas encore à toi"] = "You don't own this tower yet",
	["Cette tour est déjà au maximum de son entraînement"] = "This tower is already fully trained",
	["Cet emplacement est au niveau maximum"] = "This slot is at max level",
	["Tous les emplacements du camp sont ouverts"] = "All camp slots are open",

	----------------------------------------------------------------------
	-- Hub/Camp.luau : socles d'entraînement de la parcelle (étiquettes et invites)
	----------------------------------------------------------------------
	["Emplacement d'entraînement {1}"] = "Training slot {1}",
	["Gérer"] = "Manage",
	["Choisir une tour"] = "Pick a tower",
	["Ouvrir"] = "Open",
	["ENTRAÎNEMENT MAX"] = "MAX TRAINING",
	["Libre : choisis une tour à entraîner"] = "Free: pick a tower to train",
	["Ouvrir : {1} pièces de niveau"] = "Open: {1} level coins",

	----------------------------------------------------------------------
	-- Hub/HubMap.luau : les deux bâtiments à l'entrée de la parcelle
	----------------------------------------------------------------------
	["BOUTIQUE DES TOURS"] = "TOWER SHOP",
	["PORTE DES NIVEAUX"] = "LEVEL GATE",

	----------------------------------------------------------------------
	-- Hub/PlotBoard.luau : grand tableau au fond de la parcelle
	----------------------------------------------------------------------
	["CAMP D'ENTRAÎNEMENT"] = "TRAINING CAMP",
	["Camp de {1}"] = "{1}'s camp",
	["NIVEAUX RÉUSSIS"] = "LEVELS CLEARED",
	["TOURS DÉBLOQUÉES"] = "TOWERS UNLOCKED",
	["PIÈCES DE NIVEAU"] = "LEVEL COINS",
	["ENTRAÎNEMENT EN COURS · {1} tours"] = "TRAINING IN PROGRESS · {1} towers",
	["ENTRAÎNEMENT EN COURS · {1} tour"] = "TRAINING IN PROGRESS · {1} tower",
	["AUCUNE TOUR À L'ENTRAÎNEMENT"] = "NO TOWER IN TRAINING",
	["Un camp prêt à accueillir son seigneur"] = "A camp awaiting its lord",
	["Les tours posées ici s'entraînent tout le temps, même quand leur seigneur est parti"] = "Towers placed here train all the time, even while their lord is away",
	["L'entraînement les fait évoluer : ★ ★★ ★★★"] = "Training makes them evolve: ★ ★★ ★★★",
	["Parcelle libre"] = "Unclaimed plot",
	["En attente d'un propriétaire"] = "Waiting for an owner",

	----------------------------------------------------------------------
	-- Hub/PlotIdentity.luau : plaque à l'entrée de chaque parcelle (nom et vignette du propriétaire)
	----------------------------------------------------------------------
	["FIEF {1}  /  DOMAINE"] = "KEEP {1}  /  DOMAIN", -- {1} = numéro de la parcelle (01 à 06)
	["Fief libre"] = "Unclaimed keep",
	["Un domaine prêt à accueillir son seigneur"] = "A domain awaiting its lord",
	["PARCELLE DISPONIBLE"] = "PLOT AVAILABLE",
	["CAMP DES TOURS"] = "TOWER CAMP",

	----------------------------------------------------------------------
	-- Niveau d'une tour, au-dessus d'elle (client/PlotRenderer.luau) ; avec ses étoiles d'évolution : « ★★ Niv. 3 »
	----------------------------------------------------------------------
	["Niv. {1}"] = "Lv. {1}",

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

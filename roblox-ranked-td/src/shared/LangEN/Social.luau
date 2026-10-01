-- Dictionnaire anglais : le TUTO, le CLASSÉ, les DÉFIS et le MATCH.
-- Textes de src/client/TutorialUI.luau (tuto des nouveaux joueurs : panneau, flèche, boutons), LobbyUI.luau (carte de
-- rang, « S'INSCRIRE AU CLASSÉ », recherche, fenêtre « MATCH TROUVÉ ! »), ChallengeUI.luau (fenêtre des défis),
-- MatchUI.luau (HUD du match classé, écran de fin), et des modules partagés Challenges.luau (textes des défis,
-- progression, récompenses, règles) et Ranks.luau (noms des rangs, « Placement x/5 »).
-- Une ligne : ["texte français exact"] = "English", ; un texte qui change : {1}, {2}... (mode d'emploi en haut de
-- Shared/Lang.luau). Noms du jeu : Glossary.luau.
-- Les « » du français deviennent “ ” en anglais. Un {n} qui est un nom du jeu (tour, rang...) est traduit tout seul.
-- Mots choisis (les mêmes que dans les autres dictionnaires) : « lancer » -> spin, « s'inscrire » -> join (« JOIN
-- RANKED », comme les messages du serveur), « or » (monnaie du match) -> gold, « classé » -> Ranked (le mode) ou ranked
-- (« ranked match », « ranked queue »).
-- « 15 s » (temps pour accepter un match) n'a pas de ligne : il se lit aussi en anglais.
return {
	----------------------------------------------------------------------
	-- Tuto des nouveaux joueurs (TutorialUI.luau)
	----------------------------------------------------------------------
	-- Titre du panneau : « TUTO 1/4 • POSE UNE TOUR » ({2} = titre de l'étape, traduit par sa ligne plus bas).
	["TUTO {1} • {2}"] = "TUTORIAL {1} • {2}",
	["✓ BRAVO !"] = "✓ WELL DONE!",
	-- Les deux étapes à pied, montrées seulement quand le classé est ouvert (Config.RANKED_OPEN = true) : la zone
	-- classée, puis le retour sur sa parcelle (« ARÈNE CLASSÉE » et « TA PARCELLE » sont aussi les mots de la flèche).
	["LA ZONE CLASSÉE"] = "THE RANKED ZONE",
	["Le cercle rouge au centre, c'est le classé : des matchs 1 contre 1 pour monter en rang. Suis le rayon doré !"] = "The red circle in the middle is Ranked mode: 1v1 matches to climb the ranks. Follow the golden beam!",
	["ARÈNE CLASSÉE"] = "RANKED ARENA",
	["TA PARCELLE"] = "YOUR PLOT",
	["Voici ta parcelle : des vagues d'ennemis y arrivent sans fin. Retournes-y en suivant le rayon doré."] = "This is your plot: endless waves of enemies come here. Follow the golden beam to get back there.",
	-- Étape « poser une tour » (« appuie » = toucher ou cliquer : press)
	["POSE UNE TOUR"] = "PLACE A TOWER",
	["Des ennemis attaquent ta parcelle ! Appuie sur un « + » doré, puis sur la carte de l'Archer."] = "Enemies are attacking your plot! Press a golden “+”, then the Archer card.",
	-- Étape « l'améliorer »
	["AMÉLIORE-LA"] = "UPGRADE IT",
	["Ta tour tire toute seule. Appuie dessus, puis sur « Améliorer » : elle tapera plus fort."] = "Your tower shoots on its own. Press it, then “Upgrade”: it will hit harder.",
	-- Étape « l'Autel des héros », par son bouton : à gauche sur ordinateur, l'icône de droite sur téléphone (sans
	-- côté sur un téléphone tenu en hauteur)
	["L'AUTEL DES HÉROS"] = "THE HEROES' ALTAR",
	["Appuie sur « Autel des héros », à gauche, puis lance x1 : il donne de nouvelles tours."] = "Press “Heroes' Altar” on the left, then spin x1: it gives you new towers.",
	["Appuie sur 🏰, à droite, puis lance x1 : il donne de nouvelles tours."] = "Press 🏰 on the right, then spin x1: it gives you new towers.",
	["Appuie sur 🏰, puis lance x1 : il donne de nouvelles tours."] = "Press 🏰, then spin x1: it gives you new towers.",
	-- Dernière étape : la Forge runique, par son bouton, puis le mot de la fin ({1} = prix du prochain lancer, ex. « 100K »)
	["LA FORGE RUNIQUE"] = "THE RUNE FORGE",
	["Dernière étape : appuie sur « Forge runique », à gauche. Ses runes rendent tes tours bien plus fortes."] = "Last step: press “Rune Forge” on the left. Its runes make your towers much stronger.",
	["Dernière étape : appuie sur 🔨, à droite. Ses runes rendent tes tours bien plus fortes."] = "Last step: press 🔨 on the right. Its runes make your towers much stronger.",
	["Dernière étape : appuie sur 🔨. Ses runes rendent tes tours bien plus fortes."] = "Last step: press 🔨. Its runes make your towers much stronger.",
	["Les runes coûtent cher au début ({1} pièces) : reviens à la forge plus tard. À toi de jouer !"] = "Runes are pricey at first ({1} coins): come back to the forge later. Your turn to play!",
	-- Une fenêtre ouverte cache ce qu'il faut toucher
	["Ferme d'abord cette fenêtre : appuie sur son X."] = "Close this window first: press its X.",
	-- Les mots de la grosse flèche (TutorialUI.CAPTIONS)
	["APPUIE ICI"] = "PRESS HERE",
	["CHOISIS L'ARCHER"] = "PICK THE ARCHER",
	["APPUIE SUR TA TOUR"] = "PRESS YOUR TOWER",
	["AMÉLIORE"] = "UPGRADE",
	["OUVRE L'AUTEL"] = "OPEN THE ALTAR",
	["LANCE x1"] = "SPIN x1",
	["OUVRE LA FORGE"] = "OPEN THE FORGE",
	["FERME"] = "CLOSE",
	-- Boutons et messages de fin
	["Suivant"] = "Next",
	["Terminer"] = "Finish",
	["Passer"] = "Skip",
	-- (téléphone : « Passer » touché une 1re fois ; un 2e appui passe le tuto)
	["Confirmer ?"] = "Confirm?",
	["Tuto terminé ! À toi de jouer"] = "Tutorial complete! Your turn to play",
	["Tuto passé : bonne partie !"] = "Tutorial skipped: have fun!",

	----------------------------------------------------------------------
	-- Carte de rang et classé de la map principale (LobbyUI.luau)
	----------------------------------------------------------------------
	["Chargement..."] = "Loading...",
	["MMR caché pendant le placement"] = "MMR hidden during placement",
	-- « 1016 MMR  (record : 1050) » (deux espaces avant la parenthèse, comme dans le jeu)
	["{1} MMR  (record : {2})"] = "{1} MMR  (best: {2})",
	-- « 1234 MMR » seul (morceau après un « • », ex. « Or • 1234 MMR »)
	["{1} MMR"] = "{1} MMR",
	-- Victoires, défaites, égalités : « 3 V  •  1 D  •  0 N »
	["{1} V  •  {2} D  •  {3} N"] = "{1} W  •  {2} L  •  {3} D",
	["Saison {1} • ROYAUMES EN GUERRE"] = "Season {1} • KINGDOMS AT WAR",
	-- Bouton d'inscription (seulement dans le cercle) et conseils (« s'inscrire » -> join, comme les messages du serveur)
	["⚔ S'INSCRIRE AU CLASSÉ"] = "⚔ JOIN RANKED",
	["Inscription…"] = "Joining…",
	["Ensuite, va jouer : on te propose le match dès qu'un adversaire est trouvé"] = "Then go play: we'll offer you the match as soon as an opponent is found",
	["Entre dans le sceau rouge pour t'inscrire au classé"] = "Step into the red seal to join Ranked",
	-- Statut de la recherche (en bas à droite) ; {1} = temps d'attente « 1:23 »
	["⚔ Recherche d'un adversaire…  {1}"] = "⚔ Finding an opponent…  {1}",
	["Inscription au classé…"] = "Joining Ranked…",
	["⚔ Match trouvé ! Accepte-le vite"] = "⚔ Match found! Accept it quickly",
	["En attente de l'adversaire…"] = "Waiting for your opponent…",
	["Match accepté ! Préparation du match…"] = "Match accepted! Setting up the match…",
	["Téléportation vers le match…"] = "Teleporting to the match…",
	["ANNULER"] = "CANCEL",
	-- Classé fermé (Config.RANKED_OPEN = false, Shared/RankedGate.luau) : panneau dans le cercle, carte de rang ; les deux
	-- premiers servent aussi au serveur (tableau du classement, plaques, refus d'une inscription ou d'un « Récupérer »)
	["BIENTÔT DISPONIBLE"] = "COMING SOON",
	["Les matchs classés 1v1 arrivent bientôt !"] = "Ranked 1v1 matches are coming soon!",
	["CLASSÉ 1v1"] = "RANKED 1v1",
	-- Fenêtre « MATCH TROUVÉ ! » ({1} = nom de l'adversaire)
	["⚔ MATCH TROUVÉ !"] = "⚔ MATCH FOUND!",
	["Adversaire : {1}"] = "Opponent: {1}",
	["ACCEPTER"] = "ACCEPT",
	["REFUSER"] = "DECLINE",
	["Réponse envoyée…"] = "Answer sent…",
	["Temps écoulé…"] = "Time's up…",
	["Les deux joueurs ont accepté ! Préparation du match…"] = "Both players accepted! Setting up the match…",

	----------------------------------------------------------------------
	-- Rangs (Ranks.luau) : carte de rang, fenêtre « MATCH TROUVÉ ! », HUD et fin du match
	----------------------------------------------------------------------
	["Bronze"] = "Bronze",
	["Argent"] = "Silver",
	["Or"] = "Gold",
	["Platine"] = "Platinum",
	["Diamant"] = "Diamond",
	["Maître"] = "Master",
	["Légende"] = "Legend",
	-- Matchs de placement : « Placement 2/5 »
	["Placement {1}/{2}"] = "Placement {1}/{2}",

	----------------------------------------------------------------------
	-- Fenêtre des défis classés (ChallengeUI.luau)
	----------------------------------------------------------------------
	["⚔ DÉFIS"] = "⚔ CHALLENGES",
	["Défis classés"] = "Ranked Challenges",
	["X"] = "X", -- (bouton pour fermer)
	["Aujourd'hui"] = "Today",
	["Cette semaine"] = "This week",
	["Récupérer"] = "Claim",
	["✓ Récupérée"] = "✓ Claimed",
	["En cours"] = "In progress",
	["Récompenses pour le mode solo. Une récompense pas récupérée avant les nouveaux défis (00:00 UTC, le lundi pour la semaine) est perdue."] = "Rewards are for solo mode. A reward not claimed before the new challenges (00:00 UTC, Monday for weekly ones) is lost.",
	-- Temps avant les nouveaux défis : « 3 j 4 h », « 5 h 07 », « 12 min », « 40 s »
	["Nouveaux défis dans {1} j {2} h"] = "New challenges in {1}d {2}h",
	["Nouveaux défis dans {1} h {2}"] = "New challenges in {1}h {2}m",
	["Nouveaux défis dans {1} min"] = "New challenges in {1} min",
	["Nouveaux défis dans {1} s"] = "New challenges in {1}s",
	["Nouveaux défis en chemin..."] = "New challenges on the way...",

	----------------------------------------------------------------------
	-- Défis (Challenges.luau) : textes des défis, progression, récompenses, règles, raisons, messages
	----------------------------------------------------------------------
	-- Défis du jour et de la semaine ({1}, {2} = nombres)
	["Joue {1} matchs classés"] = "Play {1} ranked matches",
	["Gagne {1} match classé"] = "Win {1} ranked match",
	["Gagne {1} matchs classés"] = "Win {1} ranked matches",
	["Tiens {1} minutes dans un match classé"] = "Survive {1} minutes in a ranked match",
	["Pose {1} tours en match classé"] = "Place {1} towers in ranked matches",
	["Améliore tes tours {1} fois en match classé"] = "Upgrade towers {1} times in ranked matches",
	["Gagne un match avec {1} types de tours différents"] = "Win a match with {1} different tower types",
	["Tiens {1} minutes au total en match classé"] = "Survive {1} minutes total in ranked matches",
	["Gagne {1} matchs avec {2} types de tours différents"] = "Win {1} matches with {2} different tower types",
	-- Progression des défis en minutes : « 12/45 min » (les autres : « 1/2 », sans mot)
	["{1}/{2} min"] = "{1}/{2} min",
	-- Ligne des règles ({1} = durée minimum, ex. « 3 min » ; {2} = nombre de matchs)
	["Seuls les matchs classés d'au moins {1} comptent ; le même adversaire compte {2} fois par jour au plus"] = "Only ranked matches of at least {1} count; the same opponent counts at most {2} times a day",
	-- Récompense d'une ligne : « 💰 1.2M  +10 lancers d'autel » (morceaux séparés par deux espaces)
	["💰 {1}  +{2} lancer d'autel"] = "💰 {1}  +{2} altar spin",
	["💰 {1}  +{2} lancers d'autel"] = "💰 {1}  +{2} altar spins",
	["💰 {1}  +{2} lancer de forge"] = "💰 {1}  +{2} forge spin",
	["💰 {1}  +{2} lancers de forge"] = "💰 {1}  +{2} forge spins",
	["💰 {1}  +{2} lancer d'autel  +{3} lancer de forge"] = "💰 {1}  +{2} altar spin  +{3} forge spin",
	["💰 {1}  +{2} lancer d'autel  +{3} lancers de forge"] = "💰 {1}  +{2} altar spin  +{3} forge spins",
	["💰 {1}  +{2} lancers d'autel  +{3} lancer de forge"] = "💰 {1}  +{2} altar spins  +{3} forge spin",
	["💰 {1}  +{2} lancers d'autel  +{3} lancers de forge"] = "💰 {1}  +{2} altar spins  +{3} forge spins",
	-- Message après « Récupérer » : « +1.2M pièces • +10 lancers d'autel • +1 lancer de forge » (chaque morceau)
	["+{1} pièces"] = "+{1} coins",
	["+{1} lancer d'autel"] = "+{1} altar spin",
	["+{1} lancers d'autel"] = "+{1} altar spins",
	["+{1} lancer de forge"] = "+{1} forge spin",
	["+{1} lancers de forge"] = "+{1} forge spins",
	-- Refus du bouton « Récupérer » (message du serveur, mêmes lignes dans Server.luau) ; {1} = progression, ex. « 1/2 »
	["Défi inconnu"] = "Unknown challenge",
	["Ces défis sont terminés : voici les nouveaux défis"] = "These challenges are over: here are the new ones",
	["Récompense déjà récupérée"] = "Reward already claimed",
	["Défi pas encore terminé ({1})"] = "Challenge not finished yet ({1})",
	-- Fin d'un match classé : ligne des défis (« Défis : +1 match joué • 1 défi terminé ! », chaque morceau)
	["Défis : {1}"] = "Challenges: {1}",
	["Défis : +1 match joué"] = "Challenges: +1 match played",
	["1 défi terminé !"] = "1 challenge complete!",
	["{1} défis terminés !"] = "{1} challenges complete!",
	-- Pourquoi un match ne compte pas (après « Défis : » ou « Défis classés : » ; {1} = « 3 min », nombre de matchs)
	["match non classé (contre un bot), il ne compte pas"] = "unranked match (vs a bot), it doesn't count",
	["match de moins de {1}, il ne compte pas"] = "match shorter than {1}, it doesn't count",
	["déjà {1} matchs comptés contre ce joueur aujourd'hui, celui-ci ne compte pas"] = "{1} matches already counted against this player today, this one doesn't count",
	["ce match est déjà compté"] = "this match was already counted",

	----------------------------------------------------------------------
	-- HUD du match classé et écran de fin (MatchUI.luau)
	----------------------------------------------------------------------
	-- Panneaux des joueurs : or, revenu (« 500 or », « +100 or à chaque vague »)
	["{1} or"] = "{1} gold",
	["+{1} or à chaque vague"] = "+{1} gold per wave",
	-- Vague et chronos
	["Vague {1}"] = "Wave {1}",
	["Préparation"] = "Get ready",
	["Prochaine vague : {1}s   •   Fin : {2}"] = "Next wave: {1}s   •   Time left: {2}",
	-- Boutique de tours : « [1] Archer\n100 or  •  3 niv. » ({2} = nom de la tour, traduit par sa ligne)
	["[{1}] {2}\n{3} or  •  {4} niv."] = "[{1}] {2}\n{3} gold  •  {4} lvls",
	-- Fiche de tour : boutons et conseils
	["Améliorer [E]  •  {1} or"] = "Upgrade [E]  •  {1} gold",
	["★ Niveau max ★"] = "★ Max level ★",
	["Vendre [X]  •  +{1} or"] = "Sell [X]  •  +{1} gold",
	["Clique sur ton terrain pour poser  •  Maj : en poser plusieurs  •  Q : annuler"] = "Click your side to place  •  Shift: place several  •  Q: cancel",
	["Clique pour choisir cette tour"] = "Click to pick this tower",
	-- Attente, compte à rebours, match annulé
	["En attente"] = "Waiting",
	["Connexion de ton adversaire..."] = "Your opponent is connecting...",
	["Match classé"] = "Ranked match",
	["Match non classé (test)"] = "Unranked match (test)",
	["MATCH ANNULÉ"] = "MATCH CANCELLED",
	["Retour au lobby..."] = "Returning to the lobby...",
	-- Résultat : titre, raison de la fin, MMR, rang
	["VICTOIRE"] = "VICTORY",
	["DÉFAITE"] = "DEFEAT",
	["ÉGALITÉ"] = "DRAW",
	["Base détruite"] = "Base destroyed",
	["Les deux bases sont tombées en même temps"] = "Both bases fell at the same time",
	["Temps écoulé : la base la plus solide l'emporte"] = "Time's up: the strongest base wins",
	["Abandon"] = "Forfeit",
	-- « Base détruite — contre Pseudo » ({1} = raison, {2} = nom de l'adversaire)
	["{1} — contre {2}"] = "{1} — vs {2}",
	-- « MMR : 1000 → 1016 (+16) »
	["MMR : {1} → {2} ({3})"] = "MMR: {1} → {2} ({3})",
	["Nouveau rang : {1} !"] = "New rank: {1}!",
	["Rang : {1}"] = "Rank: {1}",
	["Match non classé"] = "Unranked match",
	["Retour au lobby dans quelques secondes..."] = "Returning to the lobby in a few seconds...",
}

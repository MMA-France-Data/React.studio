-- Dictionnaire anglais : les MACHINES et les fenêtres de la colonne de gauche.
-- Textes de src/client/MachineUI.luau (Autel des héros, Forge runique : chances, prix, résultats), RebirthUI.luau
-- (bouton et fenêtre de la renaissance), ShopUI.luau (boutique, passes, bouton Vitesse x2, « Pendant ton absence »),
-- UI.luau (petits textes communs), SoundManager.luau (bouton « SON » et ses modes), Main.client.luau, et les messages
-- de src/server/Monetization.luau (achats Robux, passes).
-- Une ligne : ["texte français exact"] = "English", ; un texte qui change : {1}, {2}... (mode d'emploi en haut de
-- Shared/Lang.luau). Noms du jeu : Glossary.luau.
-- Mots choisis ici (les mêmes que dans les autres dictionnaires) : « lancer » -> spin, « doublon » -> duplicate,
-- « emplacement » (d'une tour) -> spot, « mode infini » -> endless mode, « hors ligne » -> offline.
-- En anglais, pas d'espace avant « % » (« +2% »).
return {
	----------------------------------------------------------------------
	-- Colonne de gauche et titres des deux machines (MachineUI.luau)
	----------------------------------------------------------------------
	["AUTEL DES HÉROS"] = "HEROES' ALTAR",
	["FORGE RUNIQUE"] = "RUNE FORGE",
	-- Bouton « X » qui ferme les fenêtres (même texte en anglais : la ligne évite juste qu'il soit noté comme manquant)
	["X"] = "X",

	----------------------------------------------------------------------
	-- Autel des héros (MachineUI.luau)
	----------------------------------------------------------------------
	-- Sous le titre : chances du palier de ton record
	["Chances de ton record (vague {1})  •  meilleures dès la vague {2}"] = "Odds for your record (wave {1})  •  better from wave {2}",
	["Chances de ton record (vague {1})  •  meilleur palier atteint"] = "Odds for your record (wave {1})  •  best tier reached",
	-- Lignes des chances : la rareté en gras, puis ses 2 tours (« ✓ » = tour déjà débloquée)
	["<b>Commune</b>  {1}, {2}"] = "<b>Common</b>  {1}, {2}",
	["<b>Rare</b>  {1}, {2}"] = "<b>Rare</b>  {1}, {2}",
	["<b>Épique</b>  {1}, {2}"] = "<b>Epic</b>  {1}, {2}",
	["<b>Légendaire</b>  {1}, {2}"] = "<b>Legendary</b>  {1}, {2}",
	["Archer du rempart ✓"] = "Rampart Archer ✓",
	["Totem de givre ✓"] = "Frost Totem ✓",
	["Catapulte ✓"] = "Catapult ✓",
	["Mage des tempêtes ✓"] = "Storm Mage ✓",
	["Baliste lourde ✓"] = "Heavy Ballista ✓",
	["Sorcier des arcanes ✓"] = "Arcane Sorcerer ✓",
	["Oracle de la foudre ✓"] = "Lightning Oracle ✓",
	["Trébuchet royal ✓"] = "Royal Trebuchet ✓",
	-- Hausse du prix à chaque achat (« 0,05 » devient « 0.05 » tout seul) et lancers déjà achetés
	["Prochain lancer : +{1} % à chaque achat  •  aucun lancer acheté"] = "Spin price: +{1}% per purchase  •  no spins bought",
	["Prochain lancer : +{1} % à chaque achat  •  déjà 1 lancer"] = "Spin price: +{1}% per purchase  •  1 spin bought",
	["Prochain lancer : +{1} % à chaque achat  •  déjà {2} lancers"] = "Spin price: +{1}% per purchase  •  {2} spins bought",
	["Doublon = +{1} % de dégâts permanents pour cette tour  •  ✓ = déjà débloquée"] = "Duplicate = +{1}% permanent damage for that tower  •  ✓ = already unlocked",
	-- Boutons des quantités (« x10 » puis « 💰 prix » sur 2 lignes) ; la quantité pas encore débloquée : « 🔒 vague 40 »
	["🔒 vague {1}"] = "🔒 wave {1}",
	["💰 MAX"] = "💰 MAX",
	-- Achat refusé (message en haut de l'écran)
	["Prix trop élevé (MAX) : impossible de lancer {1} d'un coup"] = "Price too high (MAX): can't spin {1} at once",
	["Il te faut {1} pièces pour {2}"] = "You need {1} coins for {2}",
	-- Résultat d'un lancer x1 : nouvelle tour, ou doublon
	["Nouvelle tour : {1} !"] = "New tower: {1}!",
	["NOUVELLE TOUR {1} ! {2}"] = "NEW {1} TOWER! {2}",
	-- (la rareté de cette phrase est en majuscules ; string.upper laisse le « é » de Légendaire en minuscule)
	["COMMUNE"] = "COMMON",
	["RARE"] = "RARE",
	["ÉPIQUE"] = "EPIC",
	["LéGENDAIRE"] = "LEGENDARY",
	["Doublon : +{1} % de dégâts pour tes {2}"] = "Duplicate: +{1}% damage for your {2}s",
	-- Résumé d'un gros lot (x10, x100...) ; « offerts » = lancers gratuits gagnés avec un défi classé
	["{1} • 1 NOUVELLE TOUR !"] = "{1} • 1 NEW TOWER!",
	["{1} offerts • 1 NOUVELLE TOUR !"] = "{1} free • 1 NEW TOWER!",
	["{1} • {2} NOUVELLES TOURS !"] = "{1} • {2} NEW TOWERS!",
	["{1} offerts • {2} NOUVELLES TOURS !"] = "{1} free • {2} NEW TOWERS!",
	["{1} • que des doublons"] = "{1} • only duplicates",
	["{1} offerts • que des doublons"] = "{1} free • only duplicates",
	["{1} doublons au total • chacun = +{2} % de dégâts pour sa tour"] = "{1} duplicates in total • each = +{2}% damage for its tower",
	["1 doublons au total • chacun = +{1} % de dégâts pour sa tour"] = "1 duplicate in total • each = +{1}% damage for its tower", -- (1 seul : singulier)
	-- Une case par tour obtenue (1 doublon : « doublons » en français, singulier en anglais)
	["NOUVELLE TOUR !"] = "NEW TOWER!",
	["NOUVELLE TOUR ! + 1 doublons"] = "NEW TOWER! + 1 duplicate",
	["NOUVELLE TOUR ! + {1} doublons"] = "NEW TOWER! + {1} duplicates",
	["1 doublons • +{1} % de dégâts"] = "1 duplicate • +{1}% damage",
	["{1} doublons • +{2} % de dégâts"] = "{1} duplicates • +{2}% damage",

	----------------------------------------------------------------------
	-- Forge runique (MachineUI.luau)
	----------------------------------------------------------------------
	["Ne tombent que les runes utiles à une tour posée • 2 runes par tour : dégâts + vitesse"] = "Only runes useful to a placed tower can drop • 2 runes per tower: damage + speed",
	-- Noms des runes (IdleConfig.BONUSES) : lignes des chances, rouleau, rune obtenue
	["x2 dégâts"] = "x2 damage",
	["x2 vitesse d'attaque"] = "x2 attack speed",
	["x3 dégâts"] = "x3 damage",
	["x5 dégâts"] = "x5 damage",
	["x10 dégâts"] = "x10 damage",
	["x20 dégâts"] = "x20 damage",
	["x50 dégâts"] = "x50 damage",
	["x100 dégâts"] = "x100 damage",
	-- Lignes des chances : rune de vitesse (son effet sur le Sorcier), rune qui ne peut plus tomber (barrée)
	["<b>{1}</b>  (rayon du Sorcier : chauffe {2}x plus vite)"] = "<b>{1}</b>  (Sorcerer's beam ramps up {2}x faster)",
	["<s>{1}</s>  toutes tes tours l'ont déjà (ou mieux)"] = "<s>{1}</s>  all your towers already have it (or better)",
	-- Prix des lancers en pièces (x5, puis x2 dès 1T) et lancers déjà achetés
	["Chaque lancer en pièces : x{1} (x{2} dès {3})  •  aucun lancer en pièces"] = "Price x{1} per coin spin (x{2} from {3})  •  no coin spins bought",
	["Chaque lancer en pièces : x{1} (x{2} dès {3})  •  déjà 1 lancer en pièces"] = "Price x{1} per coin spin (x{2} from {3})  •  1 coin spin bought",
	["Chaque lancer en pièces : x{1} (x{2} dès {3})  •  déjà {4} lancers en pièces"] = "Price x{1} per coin spin (x{2} from {3})  •  {4} coin spins bought",
	-- Bouton du bas
	["Lancer • 💰 {1}"] = "Spin • 💰 {1}",
	["Inventaire plein ({1} runes)"] = "Inventory full ({1} runes)",
	-- Forge bloquée : message du serveur (attribut ForgeBlocked = IdleConfig.FORGE_NO_TOWER ou FORGE_ALL_BEST)
	["Pose d'abord une tour"] = "Place a tower first",
	["Toutes tes tours ont les meilleures runes"] = "All your towers have the best runes",
	-- Bas de la fenêtre : runes de l'inventaire (0 et 1 : « rune » en français, 0 : « runes » en anglais)
	["Inventaire : 0 rune"] = "Inventory: 0 runes",
	["Inventaire : {1} rune"] = "Inventory: {1} rune",
	["Inventaire : {1} runes"] = "Inventory: {1} runes",
	-- Achat refusé (message en haut de l'écran)
	["Ton inventaire de runes est plein : pose-en sur tes tours"] = "Your rune inventory is full: place some on your towers",
	["Prix trop élevé (MAX) : la forge en pièces n'est plus possible"] = "Price too high (MAX): coin spins are no longer possible",
	["Il te faut {1} pièces"] = "You need {1} coins",
	-- Rune obtenue
	["Offerte par un défi classé : ajoutée à ton inventaire, clique sur une tour pour la poser."] = "Gift from a ranked challenge: added to your inventory. Click a tower to place it.",
	["Ajoutée à ton inventaire : clique sur une tour pour la poser."] = "Added to your inventory: click a tower to place it.",

	----------------------------------------------------------------------
	-- Renaissance (RebirthUI.luau) ; « Renaissance » seul : Glossary.luau
	----------------------------------------------------------------------
	-- Bouton de la colonne de gauche (2 lignes)
	["Renaissance +{1} %"] = "Rebirth +{1}%",
	["Renaissance : vague {1}"] = "Rebirth at wave {1}", -- (bouton grisé : la vague à réussir)
	["Bonus pièces : +{1} %"] = "Coin bonus: +{1}%",
	-- Fenêtre de confirmation
	["Recommence une run à la vague 1 et gagne un bonus de pièces permanent"] = "Start a new run at wave 1 and earn a permanent coin bonus",
	["Meilleure vague de la run"] = "Best wave this run",
	["Gain de la renaissance"] = "Rebirth gain",
	["Bonus de pièces total"] = "Total coin bonus",
	["vague {1}"] = "wave {1}",
	["vague {1} requise"] = "wave {1} required",
	["Vague {1} requise"] = "Wave {1} required",
	["+{1} % de pièces"] = "+{1}% coins",
	-- Bonus total avant -> après ({2} = couleur de la balise, gardée telle quelle)
	['+{1} %  →  <font color="{2}">+{3} %</font>'] = '+{1}%  →  <font color="{2}">+{3}%</font>',
	['Exemple : un ennemi qui vaut {1} pièces en donnera <font color="{2}"><b>{3}</b></font> au lieu de {4}.'] = 'Example: an enemy worth {1} coins will give <font color="{2}"><b>{3}</b></font> instead of {4}.',
	["Réussis la vague {1} pour renaître. Gain : +{2} % à la vague {3}, +{4} % à la 50, +{5} % à la 100, et plus au-delà."] = "Clear wave {1} to rebirth. Gain: +{2}% at wave {3}, +{4}% at wave 50, +{5}% at wave 100, and more beyond.",
	-- Astuce montrée une seule fois, au premier échec quand la renaissance est possible (RebirthUI)
	["💡 <b>Tu bloques sur une vague ?</b>\nUtilise la <b>Renaissance</b> sans perdre ta progression : tu gardes tes tours, tes améliorations et tes pièces, et tu gagnes +{1} % de pièces pour toujours."] = "💡 <b>Stuck on a wave?</b>\nUse <b>Rebirth</b> without losing your progress: you keep your towers, upgrades and coins, and gain +{1}% coins forever.",
	["Compris !"] = "Got it!",
	["Tu gardes tout le reste :"] = "You keep everything else:",
	["✓ Pièces"] = "✓ Coins",
	["✓ Tours posées"] = "✓ Placed towers",
	["✓ Améliorations"] = "✓ Upgrades",
	["✓ Emplacements"] = "✓ Spots",
	["✓ Machines et bonus"] = "✓ Altar & Forge", -- (« machines » ne veut rien dire pour un joueur anglais : l'autel et la forge)
	["✓ Record"] = "✓ Record",
	["✓ Record : vague {1}"] = "✓ Record: wave {1}",
	["● Seule la vague repart à 1 (la vague en cours s'arrête)"] = "● Only the wave resets to 1 (the current wave stops)",
	["Renaître"] = "Rebirth",
	["Annuler"] = "Cancel",
	-- Grand titre à l'écran juste après une renaissance
	["RENAISSANCE !"] = "REBIRTH!",

	----------------------------------------------------------------------
	-- Boutique (ShopUI.luau) ; « Boutique » seul et noms des passes seuls : Glossary.luau
	----------------------------------------------------------------------
	["★ BOUTIQUE"] = "★ SHOP",
	["Passes du mode infini : aucun effet en ranked (mêmes tours et même or pour tous)"] = "Endless mode passes: no effect in Ranked (same towers and gold for everyone)",
	-- Cartes des 3 passes : titre, description, prix, bouton
	["→ Ramassage auto"] = "→ Auto collect",
	["★ Vitesse x2"] = "★ Speed x2",
	["💰 Pièces x2"] = "💰 Coins x2",
	["Les pièces tombées sur ta parcelle arrivent toutes seules dans ta bourse, même quand tu es loin."] = "Coins dropped on your plot go straight into your purse, even when you're far away.",
	["Ta parcelle joue 2 fois plus vite : ennemis, apparitions, tirs des tours et pauses entre les vagues. Tu peux la couper à tout moment."] = "Your plot runs twice as fast: enemies, spawns, tower shots and breaks between waves. You can turn it off anytime.",
	["Toutes les pièces gagnées sur ta parcelle sont doublées, même hors ligne."] = "All coins earned on your plot are doubled, even offline.",
	["Pass permanent • mode infini seulement"] = "Permanent pass • endless mode only",
	["{1} Robux"] = "{1} Robux",
	["Acheter • {1} Robux"] = "Buy • {1} Robux",
	["Acheter"] = "Buy",
	["✓ Possédé"] = "✓ Owned",
	["Bientôt disponible"] = "Coming soon",
	["{1} : bientôt disponible !"] = "{1}: coming soon!",
	["Achat impossible pour l'instant, réessaie plus tard"] = "Can't buy right now, try again later",
	-- Pass Vitesse x2 : interrupteur de la boutique, et petit bouton « x2 / Vitesse » à droite du compteur de pièces
	["Vitesse x2 : ACTIVÉE"] = "Speed x2: ON",
	["Vitesse x2 : coupée"] = "Speed x2: off",
	["Vitesse"] = "Speed",

	----------------------------------------------------------------------
	-- « Pendant ton absence » : gains hors ligne et pendant un match classé (ShopUI.luau)
	-- Les durées (« 45 s », « 12 min », « 3 h 05 ») restent telles quelles.
	----------------------------------------------------------------------
	["Pendant ton absence :"] = "While you were away:",
	["Pendant ton absence (pièces x2) :"] = "While you were away (coins x2):",
	["⚔ Match classé ({1}) : <b>+{2}</b> au rythme normal"] = "⚔ Ranked match ({1}): <b>+{2}</b> at the normal rate",
	["🌙 Hors ligne ({1}) : <b>+{2}</b> au ralenti"] = "🌙 Offline ({1}): <b>+{2}</b> at a slower rate",
	["Ta parcelle a continué de produire <b>au rythme normal</b> pendant ton match classé (<b>{1}</b>)."] = "Your plot kept producing <b>at the normal rate</b> during your ranked match (<b>{1}</b>).",
	-- {1} = « au ralenti » ou « au ralenti (20 % du rythme normal) » (lignes juste après)
	["Ta parcelle a continué de produire <b>{1}</b> pendant <b>{2}</b>."] = "Your plot kept producing <b>{1}</b> for <b>{2}</b>.",
	["au ralenti"] = "at a slower rate",
	["au ralenti ({1} % du rythme normal)"] = "at {1}% of the normal rate",
	-- Heure de la remise à zéro : « 2 h » ou « 2 h 30 » devient « 2:00 » ou « 2:30 » (« at 2 h » ferait penser à une
	-- durée). La ligne avec {2} seul sert si l'heure change de forme.
	["⚠ Limite du jour atteinte : au plus {1} runs complètes de gains hors ligne par jour. Remise à zéro à {2} h."] = "⚠ Daily limit reached: at most {1} full runs of offline earnings per day. Resets at {2}:00.",
	["⚠ Limite du jour atteinte : au plus {1} runs complètes de gains hors ligne par jour. Remise à zéro à {2} h {3}."] = "⚠ Daily limit reached: at most {1} full runs of offline earnings per day. Resets at {2}:{3}.",
	["⚠ Limite du jour atteinte : au plus {1} runs complètes de gains hors ligne par jour. Remise à zéro à {2}."] = "⚠ Daily limit reached: at most {1} full runs of offline earnings per day. Resets at {2}.",
	["Continuer"] = "Continue",
	-- Petit message en haut de l'écran (absence courte, ou rien gagné à cause de la limite du jour)
	["Pendant ton absence : +{1}"] = "While you were away: +{1}",
	["Pendant ton absence : +{1} (pièces x2)"] = "While you were away: +{1} (coins x2)",
	["Pendant ton absence : +0 (limite du jour atteinte, remise à zéro à {1} h)"] = "While you were away: +0 (daily limit reached, resets at {1}:00)",
	["Pendant ton absence : +0 (limite du jour atteinte, remise à zéro à {1} h {2})"] = "While you were away: +0 (daily limit reached, resets at {1}:{2})",
	["Pendant ton absence : +0 (limite du jour atteinte, remise à zéro à {1})"] = "While you were away: +0 (daily limit reached, resets at {1})",

	----------------------------------------------------------------------
	-- Bouton « SON » et ses 3 modes (SoundManager.luau, Sounds.MODE_LABELS)
	----------------------------------------------------------------------
	["SON"] = "SOUND",
	["tout"] = "all",
	["effets seuls"] = "effects only",
	["muet"] = "muted",
	["Son : {1}"] = "Sound: {1}",

	----------------------------------------------------------------------
	-- Message du serveur après l'achat d'un pass (src/server/Monetization.luau) ; {1} = nom du pass (Glossary.luau)
	----------------------------------------------------------------------
	["Merci ! Pass {1} activé"] = "Thanks! {1} pass activated",

	----------------------------------------------------------------------
	-- Petits textes communs (UI.luau) : vitesse d'une tour dans les fiches (« 5 atq/s », « continu » pour le rayon)
	----------------------------------------------------------------------
	["{1} atq/s"] = "{1} atk/s",
	["continu"] = "continuous",
}

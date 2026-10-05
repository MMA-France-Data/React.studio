-- Dictionnaire espagnol : les textes du jeu (tout sauf les noms, qui sont dans Glossary.luau).
-- Mêmes lignes (même texte français) que src/shared/LangEN/Game.luau : une ligne ajoutée là s'ajoute aussi ici. Le
-- jeu écrit toujours en français ; le client de chaque joueur hispanophone traduit en affichant (AutoTranslate).
-- Mode d'emploi en haut de Shared/Lang.luau. Les nombres gardent leur virgule (« 2,5 % »).
-- Vérifier : luau.exe tools/lang/check.luau et luau.exe tools/lang/samples.luau (depuis roblox-ranked-td).
return {
	----------------------------------------------------------------------
	-- Mots seuls gardés tels quels (ils s'affichent avec des nombres ou des symboles : « 10 / 40 XP », « 👑 BOSS »)
	----------------------------------------------------------------------
	["X"] = "X",
	["X ?"] = "X?",
	["XP"] = "XP",
	["XP/min"] = "XP/min",
	["MAX"] = "MÁX",
	["BOSS"] = "JEFE",
	["MINI-BOSS"] = "MINIJEFE",

	----------------------------------------------------------------------
	-- client/LevelsUI.luau : bouton de la map principale et fenêtre du camp
	----------------------------------------------------------------------
	["NIVEAUX"] = "NIVELES", -- « ⚔ NIVEAUX »
	["Niveaux"] = "Niveles",
	["Entraînement"] = "Entrenamiento",
	["Mes tours"] = "Mis torres",
	-- Onglet « Niveaux »
	["TERRITOIRE {1}"] = "TERRITORIO {1}",
	["réussis le niveau {1}"] = "supera el nivel {1}", -- « 🔒 réussis le niveau 10 »
	["NIVEAU {1}"] = "NIVEL {1}",
	["{1} monstres"] = "{1} monstruos",
	["Rejouer :"] = "Repetir:",
	["Victoire :"] = "Victoria:",
	["REJOUER"] = "REPETIR",
	["JOUER"] = "JUGAR", -- « ▶ JOUER »
	["Chaque niveau est un flot de monstres sans pause, de plus en plus forts : pose et améliore tes tours sans arrêt avec l'or qu'ils donnent, protège ton château ({1} vies). Gagner rapporte un œuf (une tour au hasard) et des pièces de niveau 💵 pour ton camp et tes couveuses."] = "Cada nivel es una oleada de monstruos sin pausa, cada vez más fuertes: coloca y mejora tus torres sin parar con el oro que sueltan, y protege tu castillo ({1} vidas). Ganar da un huevo (una torre al azar) y monedas de nivel 💵 para tu campamento y tus incubadoras.",
	["BIENTÔT"] = "PRONTO", -- « 🔒 BIENTÔT » (niveaux après Levels.OPEN_COUNT)
	["Bientôt"] = "Pronto", -- « TERRITOIRE 5 • ... • 🔒 Bientôt »
	["Victoires : {1}"] = "Victorias: {1}",
	["Défaites : {1}"] = "Derrotas: {1}",
	-- Rôles des tours (ROLES : « Mes tours » et la tour sortie d'un œuf)
	["Tireur rapide à longue portée. Ta tour de base."] = "Tirador rápido de largo alcance. Tu torre básica.",
	["Ralentit de {1} % tout ce qui passe près de lui."] = "Ralentiza un {1} % todo lo que pasa cerca.",
	["Ses rochers écrasent les groupes serrés."] = "Sus rocas aplastan los grupos apretados.",
	["Foudre sur un petit groupe, gros coup de frein."] = "Rayos sobre un grupo pequeño, y un gran frenazo.",
	["Gros carreau contre les monstres résistants."] = "Un gran virote contra los monstruos resistentes.",
	["Rayon qui chauffe : terrible contre les boss."] = "Un rayo que se calienta: terrible contra los jefes.",
	["Un éclair qui rebondit sur 4 monstres."] = "Un relámpago que rebota en 4 monstruos.",
	["Une pierre géante sur le plus gros groupe."] = "Una piedra gigante sobre el grupo más grande.",
	-- (tours de palier 2)
	["L'Archer en bien plus fort : ses flèches laissent du feu."] = "El Arquero, mucho más fuerte: sus flechas dejan fuego.",
	["Ralentit de {1} % et rend les monstres bien plus fragiles."] = "Ralentiza un {1} % y vuelve a los monstruos mucho más frágiles.",
	["Rochers de magma : grosse zone, et le sol brûle."] = "Rocas de magma: gran zona, y el suelo arde.",
	["Grosse foudre de zone, coup de frein immense."] = "Gran rayo de zona, un frenazo enorme.",
	["Carreau géant qui transperce {1} monstres et brûle le sol."] = "Virote gigante que atraviesa {1} monstruos y quema el suelo.",
	["Rayon du néant : il fait fondre les boss."] = "Rayo del vacío: derrite a los jefes.",
	["Un éclair qui rebondit sur {1} monstres."] = "Un relámpago que rebota en {1} monstruos.",
	["Une pierre céleste sur le plus gros groupe."] = "Una piedra celestial sobre el grupo más grande.",
	-- (tours spéciales)
	["Grosses flèches rapides : très fort contre un monstre à la fois."] = "Flechas grandes y rápidas: muy fuerte contra un monstruo a la vez.",
	["Ses carreaux transpercent {1} monstres alignés."] = "Sus virotes atraviesan {1} monstruos en fila.",
	["Ses ronces empoisonnent les monstres qui marchent dessus."] = "Sus espinas envenenan a los monstruos que las pisan.",
	["Blocs de glace : grosse zone, et ralentit de {1} %."] = "Bloques de hielo: gran zona, y ralentiza un {1} %.",
	-- Tours pas encore à lui, dans les listes « Entraînement » et « Mes tours » (« Rare • dans les œufs »)
	["Palier 2 de : {1}"] = "Rango 2 de: {1}", -- « Palier 2 de : Catapulte • dans les œufs » (et la tour sortie d'un œuf)
	["dans les œufs"] = "en los huevos",
	["boss du niveau {1}"] = "jefe del nivel {1}", -- « Spéciale • Œuf carmin • boss du niveau 10 » (tour spéciale)
	["ŒUFS"] = "HUEVOS",
	-- Onglet « Entraînement »
	["EMPLACEMENT {1}"] = "ESPACIO {1}",
	["niveau {1}"] = "nivel {1}",
	["Vide : choisis une tour à droite"] = "Vacío: elige una torre a la derecha",
	["+{1} XP par minute"] = "+{1} XP por minuto",
	["Améliorer {1}"] = "Mejorar {1}",
	["NIVEAU MAX"] = "NIVEL MÁX",
	["Une tour de plus à l'entraînement"] = "Una torre más entrenando",
	["Ouvre d'abord le précédent"] = "Abre primero el anterior",
	["Ouvrir {1}"] = "Abrir {1}",
	["Une tour dans un emplacement gagne de l'XP tout le temps, même quand tu es parti ({1} h au plus). Chaque niveau joué donne aussi de l'XP aux tours posées. Chaque niveau d'entraînement : +{2} % de dégâts, et une étoile aux niveaux {3}. Le bouton ⚡ achète avec tes pièces l'XP qui manque pour le niveau suivant."] = "Una torre en un espacio gana XP todo el tiempo, incluso cuando no estás (hasta {1} h). Cada nivel jugado también da XP a las torres colocadas. Cada nivel de entrenamiento: +{2} % de daño, y una estrella en los niveles {3}. El botón ⚡ compra con tus monedas la XP que falta para el siguiente nivel.",
	["NIVEAU"] = "NIVEL", -- « ⚡ +1 NIVEAU » (bouton ⚡ de l'onglet Entraînement)
	["Entraînement {1}/{2}"] = "Entrenamiento {1}/{2}",
	["Dégâts : +{1} %. Prochaine étoile à l'entraînement {2}."] = "Daño: +{1} %. Próxima estrella en el entrenamiento {2}.",
	["Dégâts : +{1} %. Toutes ses étoiles sont gagnées."] = "Daño: +{1} %. Ya tiene todas sus estrellas.",
	["✓ S'ENTRAÎNE (retirer)"] = "✓ ENTRENANDO (quitar)",
	["Empl. {1} → {2}"] = "Esp. {1} → {2}",
	["ENTRAÎNER"] = "ENTRENAR",
	-- Onglet « Mes tours »
	["Tes {1} premières tours vont dans ta barre rapide pour les niveaux, les autres attendent en réserve (▲ ▼ pour changer l'ordre)."] = "Tus {1} primeras torres van a tu barra rápida para los niveles, las demás esperan en reserva (▲ ▼ para cambiar el orden).",
	["Réserve"] = "Reserva", -- « Réserve • Catapulte • 45 💰 • entraînement 3 »
	["entraînement {1}"] = "entrenamiento {1}",
	-- Ligne de stats d'une tour (statsLine, UI.towerSpeed)
	["Dégâts {1}"] = "Daño {1}",
	["{1} atq/s"] = "{1} atq/s",
	["continu"] = "continuo",
	["Portée {1}"] = "Alcance {1}",

	----------------------------------------------------------------------
	-- client/LevelsUI.luau : écran d'un niveau
	----------------------------------------------------------------------
	["Monstres : {1} / {2}"] = "Monstruos: {1} / {2}",
	["ANNULER"] = "CANCELAR",
	-- Conseils au-dessus de la barre des tours
	["Ton Archer tire déjà ! Prends une tour dans la barre pour en poser une autre"] = "¡Tu Arquero ya dispara! Toma una torre de la barra para colocar otra",
	["Touche une tour pour l'améliorer avec ton or"] = "Toca una torre para mejorarla con tu oro",
	["Touche le terrain pour poser : {1}. Changer d'avis : « Annuler »"] = "Toca el suelo para colocar: {1}. ¿Cambiaste de idea? «Cancelar»",
	["Ne garde pas ton or : pose ou améliore une tour, les monstres deviennent de plus en plus forts !"] = "No guardes tu oro: coloca o mejora una torre, ¡los monstruos se vuelven cada vez más fuertes!",
	-- Menu d'une tour posée
	["niv. {1}"] = "niv. {1}",
	["Niveau suivant : dégâts {1}"] = "Siguiente nivel: daño {1}",
	["Vendre +{1}"] = "Vender +{1}",
	-- Écran de fin
	["VICTOIRE !"] = "¡VICTORIA!",
	["DÉFAITE"] = "DERROTA",
	["Niveau {1} réussi pour la première fois !"] = "¡Nivel {1} superado por primera vez!",
	["Niveau {1} réussi une fois de plus."] = "Nivel {1} superado una vez más.",
	["Vies restantes : {1}/{2}"] = "Vidas restantes: {1}/{2}",
	["Niveau {1} : {2} monstres éliminés sur {3}."] = "Nivel {1}: {2} de {3} monstruos eliminados.",
	["Il te restait {1} : dépense ton or au fur et à mesure, les monstres deviennent plus forts sans arrêt."] = "Te quedaban {1}: gasta tu oro sobre la marcha, los monstruos se vuelven más fuertes sin parar.",
	["Les monstres deviennent plus forts sans arrêt : pose et améliore tes tours du début à la fin, sans garder ton or."] = "Los monstruos se vuelven más fuertes sin parar: coloca y mejora tus torres de principio a fin, sin guardar tu oro.",
	["Les œufs et le camp d'entraînement aident aussi."] = "Los huevos y el campamento de entrenamiento también ayudan.",
	["Un gros monstre est passé : la Baliste lourde et le Sorcier des arcanes visent toujours le plus gros."] = "Pasó un monstruo grande: la Balista pesada y el Hechicero arcano siempre apuntan al más grande.",
	["Nouveau territoire ouvert : {1} !"] = "¡Nuevo territorio abierto: {1}!", -- « 🗺 Nouveau territoire... »
	["Tes tours posées gagnent +{1} XP d'entraînement."] = "Tus torres colocadas ganan +{1} XP de entrenamiento.",
	["ÉVOLUTION ! {1} : {2}"] = "¡EVOLUCIÓN! {1}: {2}", -- « ⭐ ÉVOLUTION ! Archer du rempart : ★★ »
	["Tour"] = "Torre",
	["Niveau {1} ▶"] = "Nivel {1} ▶",
	["Tous les niveaux sont réussis !"] = "¡Todos los niveles superados!",
	["Bientôt de nouveaux niveaux !"] = "¡Pronto habrá nuevos niveles!",
	["Réessayer"] = "Reintentar",
	["Rejouer"] = "Repetir",
	-- « Bloqué ? » : après 2 défaites de suite au même niveau (Levels.STUCK_LOSSES)
	["Bloqué ? Rejoue un niveau déjà réussi : chaque victoire donne un œuf et des pièces."] = "¿Atascado? Repite un nivel ya superado: cada victoria da un huevo y monedas.", -- « 🔁 ... »
	["Des œufs t'attendent : ouvre-les dans l'onglet Œufs pour avoir de nouvelles tours."] = "Hay huevos esperándote: ábrelos en la pestaña Huevos para tener torres nuevas.", -- « 🥚 ... »
	["Ce boss demande une tour de palier 2 (œufs rares et dorés) : rejouer un boss donne un œuf rare."] = "Este jefe pide una torre de rango 2 (huevos raros y dorados): repetir un jefe da un huevo raro.", -- « 👑 ... »
	["Mets tes tours au camp d'entraînement : elles deviennent plus fortes même quand tu n'es pas là."] = "Pon tus torres en el campamento de entrenamiento: se vuelven más fuertes incluso cuando no estás.", -- « ⛺ ... »
	["Rejouer le niveau {1}"] = "Repetir el nivel {1}", -- « ◀ Rejouer le niveau 9 » (bouton de l'écran de fin, bloqué)
	["Retour au camp"] = "Volver al campamento", -- « ⛺ Retour au camp »
	-- Petits messages
	["Appuie encore sur X pour abandonner ce niveau"] = "Toca X otra vez para abandonar este nivel",
	["Impossible de poser ici"] = "No se puede colocar aquí",
	["{1} : entraînement {2} (+{3} % de dégâts)"] = "{1}: entrenamiento {2} (+{3} % de daño)",

	----------------------------------------------------------------------
	-- client/TutorialUI.luau : les mots de la flèche du tuto
	----------------------------------------------------------------------
	["APPUIE ICI"] = "TOCA AQUÍ",
	["LES NIVEAUX"] = "LOS NIVELES",
	["JOUE ICI"] = "JUEGA AQUÍ",
	["PRENDS UN ARCHER"] = "TOMA UN ARQUERO",
	["PRENDS UNE CATAPULTE"] = "TOMA UNA CATAPULTA",
	["PRENDS CETTE TOUR"] = "TOMA ESTA TORRE",
	["POSE-LA OÙ TU VEUX"] = "COLÓCALA DONDE QUIERAS",
	["TOUCHE CETTE TOUR"] = "TOCA ESTA TORRE",
	["AMÉLIORE"] = "MEJORA",
	["CONTINUE"] = "SIGUE",
	["RÉESSAIE"] = "REINTÉNTALO",
	["TON ŒUF !"] = "¡TU HUEVO!",
	["LES ŒUFS"] = "LOS HUEVOS", -- (aussi : le bâtiment des œufs, à l'entrée de la parcelle)
	["OUVRE-LE !"] = "¡ÁBRELO!",
	["IL ÉCLOT BIENTÔT"] = "ECLOSIONA PRONTO",
	["Passer le tuto"] = "Saltar el tutorial",
	["Confirmer ?"] = "¿Confirmar?",
	["Tuto passé : bonne partie !"] = "Tutorial saltado: ¡que te diviertas!",

	----------------------------------------------------------------------
	-- Refus et messages du serveur (Shared/Levels.luau : checkPlacement ; Hub/LevelGame.luau ; Hub/LevelsService.luau),
	-- affichés en petit message
	----------------------------------------------------------------------
	["Position invalide"] = "Posición no válida",
	["Hors du terrain"] = "Fuera del terreno",
	["Trop près du chemin"] = "Demasiado cerca del camino",
	["Trop près du château"] = "Demasiado cerca del castillo",
	["Trop près d'une autre tour"] = "Demasiado cerca de otra torre",
	["Le niveau est terminé"] = "El nivel terminó",
	["Tour inconnue"] = "Torre desconocida",
	["{1} n'est pas dans ta barre de tours"] = "{1} no está en tu barra de torres",
	["Maximum {1} {2} par niveau"] = "Máximo {1} {2} por nivel",
	["Pas assez d'or"] = "No tienes suficiente oro",
	["Niveau maximum atteint"] = "Nivel máximo alcanzado",
	["Tes données ne sont pas encore chargées"] = "Tus datos aún no se han cargado",
	["Ce niveau n'existe pas encore"] = "Este nivel aún no existe",
	["Bientôt : les niveaux après le {1} arrivent avec les prochaines mises à jour"] = "Pronto: los niveles después del {1} llegarán con las próximas actualizaciones",
	["Réussis d'abord le niveau {1}"] = "Supera primero el nivel {1}",
	["Aucune zone de combat libre pour l'instant"] = "No hay ninguna zona de combate libre por ahora",
	["Il te manque {1} pièces de niveau"] = "Te faltan {1} monedas de nivel",
	["Emplacement inconnu"] = "Espacio desconocido",
	["Cette tour n'est pas encore à toi"] = "Esta torre todavía no es tuya",
	["Cette tour est déjà au maximum de son entraînement"] = "Esta torre ya tiene el entrenamiento al máximo",
	["Cet emplacement est au niveau maximum"] = "Este espacio ya está al nivel máximo",
	["Tous les emplacements du camp sont ouverts"] = "Todos los espacios del campamento están abiertos",

	----------------------------------------------------------------------
	-- Jouer en équipe : client/LevelsUI.luau (bouton et page de l'équipe, invitation, écran du niveau) et messages du
	-- serveur (Hub/LevelTeams.luau, Hub/LevelsService.luau, Hub/LevelGame.luau)
	----------------------------------------------------------------------
	["ÉQUIPE"] = "EQUIPO", -- « 👥 ÉQUIPE (3) », « 🔒 ÉQUIPE »
	["LE CHEF"] = "EL LÍDER", -- « 👥 LE CHEF »
	["Jusqu'à {1} joueurs défendent le même château, dans la même partie."] = "Hasta {1} jugadores defienden el mismo castillo, en la misma partida.",
	["Chacun pose ses tours avec son or, et chaque monstre tué donne son or à tout le monde."] = "Cada uno coloca sus torres con su oro, y cada monstruo eliminado da su oro a todos.",
	["Les monstres ont plus de vie, mais chacun gagne plus de pièces : +{1} % à deux, +{2} % à trois, +{3} % à quatre."] = "Los monstruos tienen más vida, pero todos ganan más monedas: +{1} % de a dos, +{2} % de a tres, +{3} % de a cuatro.",
	["C'est le chef de l'équipe qui lance les niveaux : ils doivent être ouverts pour tous."] = "El líder del equipo es quien empieza los niveles: deben estar abiertos para todos.",
	["TON ÉQUIPE ({1}/{2}) : tu es le chef"] = "TU EQUIPO ({1}/{2}): eres el líder",
	["L'ÉQUIPE DE {1} ({2}/{3})"] = "EL EQUIPO DE {1} ({2}/{3})",
	["TU JOUES SEUL : invite des joueurs ci-dessous"] = "JUEGAS SOLO: invita a jugadores abajo",
	["Réussis d'abord le niveau {1} pour jouer en équipe"] = "Supera primero el nivel {1} para jugar en equipo",
	["{1} (toi) : niveau {2} réussi"] = "{1} (tú): nivel {2} superado",
	["{1} : niveau {2} réussi"] = "{1}: nivel {2} superado",
	["{1} : dans ton équipe"] = "{1}: en tu equipo",
	["{1} : déjà dans une équipe"] = "{1}: ya está en un equipo",
	["{1} : pas encore fini le niveau {2}"] = "{1}: aún no superó el nivel {2}",
	["Quitter l'équipe"] = "Salir del equipo",
	["JOUEURS DE CE SERVEUR"] = "JUGADORES DE ESTE SERVIDOR",
	["Personne d'autre dans ce serveur pour l'instant. Invite des amis à te rejoindre sur Roblox !"] = "Nadie más en este servidor por ahora. ¡Invita a tus amigos a unirse en Roblox!",
	["Inviter"] = "Invitar",
	["{1} t'invite à jouer en équipe !"] = "¡{1} te invita a jugar en equipo!",
	["Accepter"] = "Aceptar", -- « ✓ Accepter »
	["Refuser"] = "Rechazar",
	["C'est {1}, le chef de ton équipe, qui lance les niveaux"] = "{1}, el líder de tu equipo, es quien empieza los niveles",
	["Tour de {1}"] = "Torre de {1}",
	["Bonus d'équipe ({1} joueurs) : +{2} % de pièces"] = "Bono de equipo ({1} jugadores): +{2} % de monedas", -- « 👥 Bonus d'équipe... »
	["{1} choisit la suite"] = "{1} elige qué sigue", -- « ⏳ Robin choisit la suite »
	["Invitation envoyée à {1}"] = "Invitación enviada a {1}",
	["{1} a refusé ton invitation"] = "{1} rechazó tu invitación",
	["{1} rejoint ton équipe !"] = "¡{1} se une a tu equipo!",
	["Tu joues maintenant dans l'équipe de {1}"] = "Ahora juegas en el equipo de {1}",
	["{1} a quitté l'équipe : tu joues seul"] = "{1} salió del equipo: juegas solo",
	["{1} a quitté l'équipe"] = "{1} salió del equipo",
	["{1} a quitté le niveau : ses tours restent et continuent de tirer"] = "{1} salió del nivel: sus torres se quedan y siguen disparando",
	["{1} lance le niveau {2} pour l'équipe"] = "{1} empieza el nivel {2} para el equipo",
	["C'est {1}, le chef de ton équipe, qui lance les niveaux (ou quitte l'équipe pour jouer seul)"] = "{1}, el líder de tu equipo, es quien empieza los niveles (o sal del equipo para jugar solo)",
	["Le niveau {1} n'est pas encore ouvert pour {2}"] = "El nivel {1} aún no está abierto para {2}",
	["{1} joue encore un niveau avec d'autres joueurs : attends la fin"] = "{1} sigue jugando un nivel con otros jugadores: espera a que termine",
	["Les données de {1} ne sont pas encore chargées"] = "Los datos de {1} aún no se han cargado",
	["Seul le chef de l'équipe peut inviter"] = "Solo el líder del equipo puede invitar",
	["Ton équipe est complète ({1} joueurs au plus)"] = "Tu equipo está completo ({1} jugadores como máximo)",
	["{1} est déjà dans une équipe"] = "{1} ya está en un equipo",
	["{1} doit d'abord réussir le niveau {2}"] = "{1} primero debe superar el nivel {2}",
	["Ce joueur n'est plus là"] = "Ese jugador ya no está",
	["Cette invitation n'est plus valable"] = "Esta invitación ya no es válida",
	["{1} n'est plus là"] = "{1} ya no está",
	["Tu es déjà dans une équipe : quitte-la d'abord"] = "Ya estás en un equipo: sal de él primero",
	["{1} n'est plus le chef de son équipe"] = "{1} ya no es el líder de su equipo",
	["L'équipe de {1} est complète"] = "El equipo de {1} está completo",
	["Ce n'est pas ta tour : seul celui qui l'a posée peut l'améliorer ou la vendre"] = "No es tu torre: solo quien la colocó puede mejorarla o venderla",

	----------------------------------------------------------------------
	-- Les amis : client/LevelsUI.luau (page de l'équipe, panneau « ami en ligne », écran de fin, invitation de
	-- Roblox) et messages du serveur (Hub/LevelsService.luau)
	----------------------------------------------------------------------
	["Un ami Roblox sur le même serveur : +{1} % de pièces en plus, seul ou en équipe."] = "Un amigo de Roblox en el mismo servidor: +{1} % de monedas extra, solo o en equipo.",
	["Un ami qui vient grâce à ton invitation : +{1} 💵 pour vous deux."] = "Un amigo que llega gracias a tu invitación: +{1} 💵 para los dos.",
	["Inviter des amis"] = "Invitar amigos", -- « 📨 Inviter des amis »
	["Amis Roblox sur ce serveur : {1} (+{2} % de pièces)"] = "Amigos de Roblox en este servidor: {1} (+{2} % de monedas)", -- « 🤝 Amis... »
	["Aucun ami Roblox sur ce serveur pour l'instant"] = "Ningún amigo de Roblox en este servidor por ahora",
	["{1} est en ligne ! Invite-le : +{2} 💵 pour vous deux s'il vient."] = "¡{1} está en línea! Invítalo: +{2} 💵 para los dos si viene.", -- « 🟢 Robin est en ligne ! ... »
	["Bonus d'ami sur le serveur : +{1} % de pièces"] = "Bono de amigo en el servidor: +{1} % de monedas", -- « 🤝 Bonus d'ami... »
	["Tu ne peux pas envoyer d'invitation depuis cet appareil"] = "No puedes enviar invitaciones desde este dispositivo",
	["Invite tes amis : {1} pièces de niveau pour vous deux quand ils arrivent !"] = "Invita a tus amigos: ¡{1} monedas de nivel para los dos cuando lleguen!",
	["Ton ami {1} est venu grâce à ton invitation : +{2} pièces de niveau !"] = "Tu amigo {1} vino gracias a tu invitación: ¡+{2} monedas de nivel!", -- « 🎁 ... »
	["Un ami est venu grâce à ton invitation : +{1} pièces de niveau !"] = "Un amigo vino gracias a tu invitación: ¡+{1} monedas de nivel!",
	["{1} amis sont venus grâce à tes invitations : +{2} pièces de niveau !"] = "{1} amigos vinieron gracias a tus invitaciones: ¡+{2} monedas de nivel!",
	["Tu es venu grâce à l'invitation de {1} : +{2} pièces de niveau !"] = "Viniste gracias a la invitación de {1}: ¡+{2} monedas de nivel!",
	["Tu es venu grâce à l'invitation d'un ami : +{1} pièces de niveau !"] = "Viniste gracias a la invitación de un amigo: ¡+{1} monedas de nivel!",

	----------------------------------------------------------------------
	-- Les œufs : client/LevelsUI.luau (onglet Œufs, tour sortie, écran de fin), Hub/Camp.luau (couveuses de la
	-- parcelle) et messages du serveur (Hub/LevelsService.luau)
	----------------------------------------------------------------------
	["Œufs"] = "Huevos",
	["Œuf commun"] = "Huevo común",
	["Œuf rare"] = "Huevo raro",
	["Œuf doré"] = "Huevo dorado",
	["Commune"] = "Común",
	["Rare"] = "Rara",
	["Épique"] = "Épica",
	["Légendaire"] = "Legendaria",
	["Spéciale"] = "Especial", -- (rareté des tours spéciales)
	["Œuf carmin"] = "Huevo carmesí",
	["Œuf de cuivre"] = "Huevo de cobre",
	["Œuf des ronces"] = "Huevo de espinas",
	["Œuf de givre"] = "Huevo de escarcha",
	["ŒUFS SPÉCIAUX"] = "HUEVOS ESPECIALES",
	["Boss du niveau {1}"] = "Jefe del nivel {1}", -- « 🔒 Boss du niveau 10 » (carte d'un œuf spécial pas encore gagné)
	["COUVER"] = "INCUBAR",
	["Couveuses pleines"] = "Incubadoras llenas",
	["Ton œuf spécial : son bouton COUVER, plus haut"] = "Tu huevo especial: su botón INCUBAR, más arriba",
	["Battre le boss d'un territoire donne aussi son œuf spécial (la première fois, puis 1 fois sur 10) : il donne toujours sa tour spéciale."] = "Vencer al jefe de un territorio también da su huevo especial (la primera vez, y luego 1 vez de cada 10): siempre da su torre especial.",
	["Œuf spécial gagné : {1} (tour : {2})"] = "Huevo especial ganado: {1} (torre: {2})", -- « 🌟 ... » (écran de fin)
	["TOUR SPÉCIALE !"] = "¡TORRE ESPECIAL!", -- « 🌟 TOUR SPÉCIALE ! » (panneau de la tour sortie d'un œuf)
	["TES ŒUFS ({1}/{2})"] = "TUS HUEVOS ({1}/{2})",
	["Éclot en {1}"] = "Eclosiona en {1}",
	["Chances :"] = "Probabilidades:",
	["Commune {1} %"] = "Común {1} %",
	["Rare {1} %"] = "Rara {1} %",
	["Épique {1} %"] = "Épica {1} %",
	["Légendaire {1} %"] = "Legendaria {1} %",
	["Palier 2 : {1} %"] = "Rango 2: {1} %",
	["COUVEUSES"] = "INCUBADORAS",
	["COUVEUSE {1}"] = "INCUBADORA {1}", -- « 🔒 COUVEUSE 2 »
	["COUVEUSE {1} : {2}"] = "INCUBADORA {1}: {2}",
	["COUVEUSE {1} (vide)"] = "INCUBADORA {1} (vacía)",
	["Couveuse {1}"] = "Incubadora {1}",
	["Prêt : ouvre-le !"] = "Listo: ¡ábrelo!",
	["Encore {1}"] = "Listo en {1}",
	["Pose un œuf :"] = "Coloca un huevo:",
	["Gagne des niveaux pour avoir des œufs"] = "Gana niveles para tener huevos",
	["Un œuf de plus en même temps"] = "Un huevo más al mismo tiempo",
	["OUVRIR !"] = "¡ABRIR!",
	["Finir : {1}"] = "Terminar: {1}",
	["Acheter : {1}"] = "Comprar: {1}",
	["Acheter : {1} pièces de niveau"] = "Comprar: {1} monedas de nivel",
	["Acheter"] = "Comprar",
	["Vide : pose un œuf"] = "Vacía: coloca un huevo",
	["{1} : prêt !"] = "{1}: ¡listo!",
	["Chaque victoire donne un œuf : commun, rare au mini-boss, doré au boss (en rejouant : commun, rare au boss)."] = "Cada victoria da un huevo: común, raro con un minijefe, dorado con un jefe (al repetir: común, raro con un jefe).",
	["Pose-le dans une couveuse : il éclot même quand tu n'es pas là, puis il donne une tour au hasard."] = "Ponlo en una incubadora: eclosiona incluso cuando no estás, y luego da una torre al azar.",
	["Une tour que tu as déjà donne de l'XP d'entraînement à cette tour."] = "Una torre que ya tienes da XP de entrenamiento a esa torre.",
	["Toutes les tours sortent des œufs. Les œufs rares et dorés donnent aussi des tours de palier 2, bien plus fortes."] = "Todas las torres salen de los huevos. Los huevos raros y dorados también dan torres de rango 2, mucho más fuertes.",
	["NOUVELLE TOUR !"] = "¡NUEVA TORRE!", -- « 🎉 NOUVELLE TOUR ! » (panneau de la tour sortie d'un œuf)
	["DOUBLON"] = "REPETIDA",
	["{1} : elle rejoint ta barre de tours"] = "{1}: se une a tu barra de torres",
	["{1} : +{2} XP d'entraînement pour cette tour"] = "{1}: +{2} XP de entrenamiento para esta torre",
	["Super !"] = "¡Genial!",
	["{1} gagné ! Pose-le dans une couveuse."] = "¡{1} ganado! Ponlo en una incubadora.",
	["{1} : il couve déjà dans ta couveuse !"] = "{1}: ¡ya está en tu incubadora!", -- « 🥚 Œuf commun : ... » (le premier œuf)
	["Réserve d'œufs pleine : {1} perdu"] = "Reserva de huevos llena: {1} perdido",
	["Cette couveuse est déjà occupée"] = "Esta incubadora ya está ocupada",
	["Tu n'as plus d'œuf de ce type : gagne des niveaux pour en avoir"] = "No te quedan huevos de este tipo: gana niveles para conseguir más",
	["Cet œuf n'est pas encore prêt"] = "Este huevo aún no está listo",
	["Tu as déjà toutes les couveuses"] = "Ya tienes todas las incubadoras",
	["Nouvelle couveuse : {1} œufs peuvent éclore en même temps"] = "Nueva incubadora: {1} huevos pueden eclosionar al mismo tiempo",

	----------------------------------------------------------------------
	-- Hub/Camp.luau : socles d'entraînement de la parcelle (étiquettes et invites)
	----------------------------------------------------------------------
	["Emplacement d'entraînement {1}"] = "Espacio de entrenamiento {1}",
	["Gérer"] = "Administrar",
	["Choisir une tour"] = "Elegir una torre",
	["Ouvrir"] = "Abrir",
	["ENTRAÎNEMENT MAX"] = "ENTRENAMIENTO MÁX",
	["Libre : choisis une tour à entraîner"] = "Libre: elige una torre para entrenar",
	["Ouvrir : {1} pièces de niveau"] = "Abrir: {1} monedas de nivel",

	----------------------------------------------------------------------
	-- Hub/HubMap.luau : les deux bâtiments à l'entrée de la parcelle
	----------------------------------------------------------------------
	["PORTE DES NIVEAUX"] = "PUERTA DE LOS NIVELES",

	----------------------------------------------------------------------
	-- Hub/PlotBoard.luau : grand tableau au fond de la parcelle
	----------------------------------------------------------------------
	["CAMP D'ENTRAÎNEMENT"] = "CAMPAMENTO DE ENTRENAMIENTO",
	["Camp de {1}"] = "Campamento de {1}",
	["NIVEAUX RÉUSSIS"] = "NIVELES SUPERADOS",
	["TOURS DÉBLOQUÉES"] = "TORRES DESBLOQUEADAS",
	["PIÈCES DE NIVEAU"] = "MONEDAS DE NIVEL",
	["ENTRAÎNEMENT EN COURS · {1} tours"] = "ENTRENAMIENTO EN CURSO · {1} torres",
	["ENTRAÎNEMENT EN COURS · {1} tour"] = "ENTRENAMIENTO EN CURSO · {1} torre",
	["AUCUNE TOUR À L'ENTRAÎNEMENT"] = "NINGUNA TORRE ENTRENANDO",
	["Un camp prêt à accueillir son seigneur"] = "Un campamento que espera a su señor",
	["Les tours posées ici s'entraînent tout le temps, même quand leur seigneur est parti"] = "Las torres colocadas aquí entrenan todo el tiempo, incluso cuando su señor no está",
	["L'entraînement les fait évoluer : ★ ★★ ★★★"] = "El entrenamiento las hace evolucionar: ★ ★★ ★★★",
	["Parcelle libre"] = "Parcela libre",
	["En attente d'un propriétaire"] = "Esperando a un dueño",

	----------------------------------------------------------------------
	-- Hub/LevelBoard.luau : les deux panneaux du classement des niveaux, sur la place centrale (« NIVEAU » : plus haut)
	----------------------------------------------------------------------
	["CLASSEMENT"] = "CLASIFICACIÓN",
	["MEILLEURS JOUEURS"] = "MEJORES JUGADORES",
	["SUR CE SERVEUR"] = "EN ESTE SERVIDOR",
	["JOUEUR"] = "JUGADOR",
	["VICTOIRES"] = "VICTORIAS",
	["Aucun joueur pour l'instant"] = "Ningún jugador por ahora",
	["Tous les serveurs · mis à jour chaque minute"] = "Todos los servidores · se actualiza cada minuto",
	["Les joueurs présents en ce moment"] = "Los jugadores presentes ahora mismo",

	----------------------------------------------------------------------
	-- Achats en Robux : la page « 🛒 BOUTIQUE », la couveuse royale, « Finir » en Robux (client/LevelsUI.luau,
	-- Hub/Camp.luau, Hub/Shop.luau, Hub/LevelsService.luau)
	----------------------------------------------------------------------
	["BOUTIQUE"] = "TIENDA", -- « 🛒 BOUTIQUE »
	["Couveuse royale"] = "Incubadora real",
	["Une 3e couveuse, dorée : tes œufs y éclosent 2 fois plus vite."] = "Una 3.ª incubadora, dorada: tus huevos eclosionan en ella 2 veces más rápido.",
	["XP x2"] = "XP x2",
	["Toute l'XP d'entraînement de tes tours est doublée : camp, niveaux joués, doublons des œufs."] = "Toda la XP de entrenamiento de tus torres se duplica: campamento, niveles jugados, torres repetidas de los huevos.",
	["Argent x2"] = "Dinero x2",
	["Les pièces de niveau gagnées en jouant les niveaux sont doublées."] = "Las monedas de nivel que ganas jugando los niveles se duplican.",
	["À TOI"] = "TUYO", -- « ✓ À TOI »
	["{1} R$"] = "{1} R$",
	["Un pass s'achète une fois pour toutes, avec des Robux. Tu peux aussi finir un œuf tout de suite avec des Robux (onglet Œufs)."] = "Un pase se compra una sola vez, con Robux. También puedes terminar un huevo al instante con Robux (pestaña Huevos).",
	["COUVEUSE ROYALE"] = "INCUBADORA REAL", -- « 👑 COUVEUSE ROYALE »
	["COUVEUSE ROYALE : {1}"] = "INCUBADORA REAL: {1}",
	["COUVEUSE ROYALE (vide)"] = "INCUBADORA REAL (vacía)",
	["Tes œufs y éclosent 2 fois plus vite"] = "Tus huevos eclosionan aquí 2 veces más rápido",
	["Acheter : {1} R$"] = "Comprar: {1} R$",
	["Finir : {1} R$"] = "Terminar: {1} R$",
	["2 fois plus rapide • {1} R$"] = "2 veces más rápido • {1} R$",
	["2 fois plus rapide • bientôt"] = "2 veces más rápido • pronto",
	["Voir"] = "Ver",
	["Couveuse royale débloquée : tes œufs y éclosent 2 fois plus vite !"] = "Incubadora real desbloqueada: ¡tus huevos eclosionan en ella 2 veces más rápido!", -- « 👑 ... »
	["XP x2 : toute l'XP d'entraînement de tes tours est doublée !"] = "XP x2: ¡toda la XP de entrenamiento de tus torres se duplica!", -- « ⭐ ... »
	["Argent x2 : les pièces des niveaux sont doublées !"] = "Dinero x2: ¡las monedas de los niveles se duplican!", -- « 💵 ... »
	["Merci !"] = "¡Gracias!",
	["Tu as déjà ce pass"] = "Ya tienes este pase",
	["Œuf fini : ouvre-le !"] = "Huevo terminado: ¡ábrelo!", -- « ⏩ ... »
	["Le temps acheté avance ton œuf qui a le plus à attendre"] = "El tiempo comprado adelanta tu huevo que más tiene que esperar", -- « ⏩ ... »
	["Aucun œuf à finir : +{1} pièces de niveau à la place"] = "Ningún huevo para terminar: +{1} monedas de nivel en su lugar",
	["Pass Argent x2 : pièces doublées"] = "Pase Dinero x2: monedas duplicadas", -- « 💵 ... » (écran de fin)
	["Pass XP x2 : XP doublée"] = "Pase XP x2: XP duplicada", -- « ⭐ ... » (écran de fin)

	----------------------------------------------------------------------
	-- Hub/PlotIdentity.luau : plaque à l'entrée de chaque parcelle (nom et vignette du propriétaire)
	----------------------------------------------------------------------
	["FIEF {1}  /  DOMAINE"] = "FEUDO {1}  /  DOMINIO", -- {1} = numéro de la parcelle (01 à 06)
	["Fief libre"] = "Feudo libre",
	["Un domaine prêt à accueillir son seigneur"] = "Un dominio que espera a su señor",
	["PARCELLE DISPONIBLE"] = "PARCELA DISPONIBLE",
	["CAMP DES TOURS"] = "CAMPAMENTO DE LAS TORRES",

	----------------------------------------------------------------------
	-- Niveau d'une tour, au-dessus d'elle (client/PlotRenderer.luau) ; avec ses étoiles d'évolution : « ★★ Niv. 3 »
	----------------------------------------------------------------------
	["Niv. {1}"] = "Niv. {1}",

	----------------------------------------------------------------------
	-- Bouton « SON » et ses 3 réglages (client/SoundManager.luau, Sounds.MODE_LABELS)
	----------------------------------------------------------------------
	["SON"] = "SONIDO",
	["tout"] = "todo",
	["effets seuls"] = "solo efectos",
	["muet"] = "silencio",
	["Son : {1}"] = "Sonido: {1}",

	----------------------------------------------------------------------
	-- PlayerData.luau : messages de player:Kick. Le client ne peut pas les traduire : le serveur appelle lui-même
	-- Lang.translate(texte, Lang.forPlayer(player)).
	----------------------------------------------------------------------
	["Impossible de charger tes données. Réessaie dans une minute."] = "No se pudieron cargar tus datos. Vuelve a intentarlo en un minuto.",
	["Ta session a été ouverte sur un autre serveur."] = "Tu sesión se abrió en otro servidor.",
}

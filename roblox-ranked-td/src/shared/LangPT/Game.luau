-- Dictionnaire portugais (du Brésil) : les textes du jeu (tout sauf les noms, qui sont dans Glossary.luau).
-- Mêmes lignes (même texte français) que src/shared/LangEN/Game.luau : une ligne ajoutée là s'ajoute aussi ici. Le
-- jeu écrit toujours en français ; le client de chaque joueur lusophone traduit en affichant (AutoTranslate).
-- Mode d'emploi en haut de Shared/Lang.luau. Les nombres gardent leur virgule, sans espace avant « % » (« 2,5% »).
-- « R$ » est le symbole du réal, la monnaie du Brésil : les prix en Robux s'écrivent en entier (« 99 Robux »).
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
	["BOSS"] = "CHEFE",
	["MINI-BOSS"] = "MINICHEFE",

	----------------------------------------------------------------------
	-- client/LevelsUI.luau : bouton de la map principale et fenêtre du camp
	----------------------------------------------------------------------
	["NIVEAUX"] = "NÍVEIS", -- « ⚔ NIVEAUX »
	["Niveaux"] = "Níveis",
	["Entraînement"] = "Treino",
	["Mes tours"] = "Minhas torres",
	-- Onglet « Niveaux »
	["TERRITOIRE {1}"] = "TERRITÓRIO {1}",
	["réussis le niveau {1}"] = "passe do nível {1}", -- « 🔒 réussis le niveau 10 »
	["NIVEAU {1}"] = "NÍVEL {1}",
	["{1} monstres"] = "{1} monstros",
	["Rejouer :"] = "Repetir:",
	["Victoire :"] = "Vitória:",
	["REJOUER"] = "REPETIR",
	["JOUER"] = "JOGAR", -- « ▶ JOUER »
	["Chaque niveau est un flot de monstres sans pause, de plus en plus forts : pose et améliore tes tours sans arrêt avec l'or qu'ils donnent, protège ton château ({1} vies). Gagner rapporte un œuf (une tour au hasard) et des pièces de niveau 💵 pour ton camp et tes couveuses."] = "Cada nível é uma onda de monstros sem pausa, cada vez mais fortes: coloque e melhore suas torres sem parar com o ouro que eles deixam, e proteja seu castelo ({1} vidas). Vencer dá um ovo (uma torre aleatória) e moedas de nível 💵 para seu acampamento e suas incubadoras.",
	["BIENTÔT"] = "EM BREVE", -- « 🔒 BIENTÔT » (niveaux après Levels.OPEN_COUNT)
	["Bientôt"] = "Em breve", -- « TERRITOIRE 5 • ... • 🔒 Bientôt »
	["Victoires : {1}"] = "Vitórias: {1}",
	["Défaites : {1}"] = "Derrotas: {1}",
	-- Rôles des tours (ROLES : « Mes tours » et la tour sortie d'un œuf)
	["Tireur rapide à longue portée. Ta tour de base."] = "Atirador rápido de longo alcance. Sua torre básica.",
	["Ralentit de {1} % tout ce qui passe près de lui."] = "Deixa {1}% mais lento tudo o que passa perto.",
	["Ses rochers écrasent les groupes serrés."] = "Suas pedras esmagam os grupos apertados.",
	["Foudre sur un petit groupe, gros coup de frein."] = "Raios num grupo pequeno, e uma grande freada.",
	["Gros carreau contre les monstres résistants."] = "Um grande virote contra os monstros resistentes.",
	["Rayon qui chauffe : terrible contre les boss."] = "Um raio que esquenta: terrível contra os chefes.",
	["Un éclair qui rebondit sur 4 monstres."] = "Um relâmpago que ricocheteia em 4 monstros.",
	["Une pierre géante sur le plus gros groupe."] = "Uma pedra gigante no maior grupo.",
	-- (tours de palier 2)
	["L'Archer en bien plus fort : ses flèches laissent du feu."] = "O Arqueiro, muito mais forte: suas flechas deixam fogo.",
	["Ralentit de {1} % et rend les monstres bien plus fragiles."] = "Deixa {1}% mais lento e torna os monstros bem mais frágeis.",
	["Rochers de magma : grosse zone, et le sol brûle."] = "Pedras de magma: área grande, e o chão queima.",
	["Grosse foudre de zone, coup de frein immense."] = "Grande raio em área, uma freada enorme.",
	["Carreau géant qui transperce {1} monstres et brûle le sol."] = "Virote gigante que atravessa {1} monstros e queima o chão.",
	["Rayon du néant : il fait fondre les boss."] = "Raio do vazio: derrete os chefes.",
	["Un éclair qui rebondit sur {1} monstres."] = "Um relâmpago que ricocheteia em {1} monstros.",
	["Une pierre céleste sur le plus gros groupe."] = "Uma pedra celestial no maior grupo.",
	-- (tours spéciales)
	["Grosses flèches rapides : très fort contre un monstre à la fois."] = "Flechas grandes e rápidas: muito forte contra um monstro por vez.",
	["Ses carreaux transpercent {1} monstres alignés."] = "Seus virotes atravessam {1} monstros em fila.",
	["Ses ronces empoisonnent les monstres qui marchent dessus."] = "Seus espinhos envenenam os monstros que pisam neles.",
	["Blocs de glace : grosse zone, et ralentit de {1} %."] = "Blocos de gelo: área grande, e deixa {1}% mais lento.",
	-- Tours pas encore à lui, dans les listes « Entraînement » et « Mes tours » (« Rare • dans les œufs »)
	["Palier 2 de : {1}"] = "Tier 2 de: {1}", -- « Palier 2 de : Catapulte • dans les œufs » (et la tour sortie d'un œuf)
	["dans les œufs"] = "nos ovos",
	["boss du niveau {1}"] = "chefe do nível {1}", -- « Spéciale • Œuf carmin • boss du niveau 10 » (tour spéciale)
	["ŒUFS"] = "OVOS",
	-- Onglet « Entraînement »
	["EMPLACEMENT {1}"] = "ESPAÇO {1}",
	["niveau {1}"] = "nível {1}",
	["Vide : choisis une tour à droite"] = "Vazio: escolha uma torre à direita",
	["+{1} XP par minute"] = "+{1} XP por minuto",
	["Améliorer {1}"] = "Melhorar {1}",
	["NIVEAU MAX"] = "NÍVEL MÁX",
	["Une tour de plus à l'entraînement"] = "Mais uma torre treinando",
	["Ouvre d'abord le précédent"] = "Abra o anterior primeiro",
	["Ouvrir {1}"] = "Abrir {1}",
	["Une tour dans un emplacement gagne de l'XP tout le temps, même quand tu es parti ({1} h au plus). Chaque niveau joué donne aussi de l'XP aux tours posées. Chaque niveau d'entraînement : +{2} % de dégâts, et une étoile aux niveaux {3}. Le bouton ⚡ achète avec tes pièces l'XP qui manque pour le niveau suivant."] = "Uma torre num espaço ganha XP o tempo todo, mesmo quando você não está (até {1} h). Cada nível jogado também dá XP às torres colocadas. Cada nível de treino: +{2}% de dano, e uma estrela nos níveis {3}. O botão ⚡ compra com suas moedas o XP que falta para o próximo nível.",
	["NIVEAU"] = "NÍVEL", -- « ⚡ +1 NIVEAU » (bouton ⚡ de l'onglet Entraînement)
	["Entraînement {1}/{2}"] = "Treino {1}/{2}",
	["Dégâts : +{1} %. Prochaine étoile à l'entraînement {2}."] = "Dano: +{1}%. Próxima estrela no treino {2}.",
	["Dégâts : +{1} %. Toutes ses étoiles sont gagnées."] = "Dano: +{1}%. Todas as estrelas conquistadas.",
	["✓ S'ENTRAÎNE (retirer)"] = "✓ TREINANDO (tirar)",
	["Empl. {1} → {2}"] = "Esp. {1} → {2}",
	["ENTRAÎNER"] = "TREINAR",
	-- Onglet « Mes tours »
	["Tes {1} premières tours vont dans ta barre rapide pour les niveaux, les autres attendent en réserve (▲ ▼ pour changer l'ordre)."] = "Suas {1} primeiras torres vão para a barra rápida nos níveis, as outras esperam na reserva (▲ ▼ para mudar a ordem).",
	["Réserve"] = "Reserva", -- « Réserve • Catapulte • 45 💰 • entraînement 3 »
	["entraînement {1}"] = "treino {1}",
	-- Ligne de stats d'une tour (statsLine, UI.towerSpeed)
	["Dégâts {1}"] = "Dano {1}",
	["{1} atq/s"] = "{1} atq/s",
	["continu"] = "contínuo",
	["Portée {1}"] = "Alcance {1}",

	----------------------------------------------------------------------
	-- client/LevelsUI.luau : écran d'un niveau
	----------------------------------------------------------------------
	["Monstres : {1} / {2}"] = "Monstros: {1} / {2}",
	["ANNULER"] = "CANCELAR",
	-- Conseils au-dessus de la barre des tours
	["Ton Archer tire déjà ! Prends une tour dans la barre pour en poser une autre"] = "Seu Arqueiro já está atirando! Pegue uma torre da barra para colocar outra",
	["Touche une tour pour l'améliorer avec ton or"] = "Toque numa torre para melhorá-la com seu ouro",
	["Touche le terrain pour poser : {1}. Changer d'avis : « Annuler »"] = "Toque no chão para colocar: {1}. Mudou de ideia? “Cancelar”",
	["Ne garde pas ton or : pose ou améliore une tour, les monstres deviennent de plus en plus forts !"] = "Não guarde seu ouro: coloque ou melhore uma torre, os monstros ficam cada vez mais fortes!",
	-- Menu d'une tour posée
	["niv. {1}"] = "nív. {1}",
	["Niveau suivant : dégâts {1}"] = "Próximo nível: dano {1}",
	["Vendre +{1}"] = "Vender +{1}",
	-- Écran de fin
	["VICTOIRE !"] = "VITÓRIA!",
	["DÉFAITE"] = "DERROTA",
	["Niveau {1} réussi pour la première fois !"] = "Nível {1} vencido pela primeira vez!",
	["Niveau {1} réussi une fois de plus."] = "Nível {1} vencido mais uma vez.",
	["Vies restantes : {1}/{2}"] = "Vidas restantes: {1}/{2}",
	["Niveau {1} : {2} monstres éliminés sur {3}."] = "Nível {1}: {2} de {3} monstros derrotados.",
	["Il te restait {1} : dépense ton or au fur et à mesure, les monstres deviennent plus forts sans arrêt."] = "Você ainda tinha {1}: gaste seu ouro aos poucos, os monstros ficam mais fortes sem parar.",
	["Les monstres deviennent plus forts sans arrêt : pose et améliore tes tours du début à la fin, sans garder ton or."] = "Os monstros ficam mais fortes sem parar: coloque e melhore suas torres do começo ao fim, sem guardar seu ouro.",
	["Les œufs et le camp d'entraînement aident aussi."] = "Os ovos e o acampamento de treino também ajudam.",
	["Un gros monstre est passé : la Baliste lourde et le Sorcier des arcanes visent toujours le plus gros."] = "Um monstro grande passou: a Balista pesada e o Feiticeiro arcano sempre miram no maior.",
	["Nouveau territoire ouvert : {1} !"] = "Novo território liberado: {1}!", -- « 🗺 Nouveau territoire... »
	["Tes tours posées gagnent +{1} XP d'entraînement."] = "Suas torres colocadas ganham +{1} XP de treino.",
	["ÉVOLUTION ! {1} : {2}"] = "EVOLUÇÃO! {1}: {2}", -- « ⭐ ÉVOLUTION ! Archer du rempart : ★★ »
	["Tour"] = "Torre",
	["Niveau {1} ▶"] = "Nível {1} ▶",
	["Tous les niveaux sont réussis !"] = "Todos os níveis vencidos!",
	["Bientôt de nouveaux niveaux !"] = "Novos níveis em breve!",
	["Réessayer"] = "Tentar de novo",
	["Rejouer"] = "Repetir",
	-- « Bloqué ? » : après 2 défaites de suite au même niveau (Levels.STUCK_LOSSES)
	["Bloqué ? Rejoue un niveau déjà réussi : chaque victoire donne un œuf et des pièces."] = "Travou? Repita um nível já vencido: cada vitória dá um ovo e moedas.", -- « 🔁 ... »
	["Des œufs t'attendent : ouvre-les dans l'onglet Œufs pour avoir de nouvelles tours."] = "Tem ovos esperando por você: abra-os na aba Ovos para ganhar torres novas.", -- « 🥚 ... »
	["Ce boss demande une tour de palier 2 (œufs rares et dorés) : rejouer un boss donne un œuf rare."] = "Este chefe pede uma torre tier 2 (ovos raros e dourados): repetir um chefe dá um ovo raro.", -- « 👑 ... »
	["Mets tes tours au camp d'entraînement : elles deviennent plus fortes même quand tu n'es pas là."] = "Coloque suas torres no acampamento de treino: elas ficam mais fortes mesmo quando você não está.", -- « ⛺ ... »
	["Rejouer le niveau {1}"] = "Repetir o nível {1}", -- « ◀ Rejouer le niveau 9 » (bouton de l'écran de fin, bloqué)
	["Retour au camp"] = "Voltar ao acampamento", -- « ⛺ Retour au camp »
	-- Petits messages
	["Appuie encore sur X pour abandonner ce niveau"] = "Toque no X de novo para desistir deste nível",
	["Impossible de poser ici"] = "Não dá para colocar aqui",
	["{1} : entraînement {2} (+{3} % de dégâts)"] = "{1}: treino {2} (+{3}% de dano)",

	----------------------------------------------------------------------
	-- client/TutorialUI.luau : les mots de la flèche du tuto
	----------------------------------------------------------------------
	["APPUIE ICI"] = "TOQUE AQUI",
	["LES NIVEAUX"] = "OS NÍVEIS",
	["JOUE ICI"] = "JOGUE AQUI",
	["PRENDS UN ARCHER"] = "PEGUE UM ARQUEIRO",
	["PRENDS UNE CATAPULTE"] = "PEGUE UMA CATAPULTA",
	["PRENDS CETTE TOUR"] = "PEGUE ESTA TORRE",
	["POSE-LA OÙ TU VEUX"] = "COLOQUE ONDE QUISER",
	["TOUCHE CETTE TOUR"] = "TOQUE NESTA TORRE",
	["AMÉLIORE"] = "MELHORE",
	["CONTINUE"] = "CONTINUE",
	["RÉESSAIE"] = "TENTE DE NOVO",
	["TON ŒUF !"] = "SEU OVO!",
	["LES ŒUFS"] = "OS OVOS", -- (aussi : le bâtiment des œufs, à l'entrée de la parcelle)
	["OUVRE-LE !"] = "ABRA!",
	["IL ÉCLOT BIENTÔT"] = "ECLODE EM BREVE",
	["Passer le tuto"] = "Pular o tutorial",
	["Confirmer ?"] = "Confirmar?",
	["Tuto passé : bonne partie !"] = "Tutorial pulado: divirta-se!",

	----------------------------------------------------------------------
	-- Refus et messages du serveur (Shared/Levels.luau : checkPlacement ; Hub/LevelGame.luau ; Hub/LevelsService.luau),
	-- affichés en petit message
	----------------------------------------------------------------------
	["Position invalide"] = "Posição inválida",
	["Hors du terrain"] = "Fora do terreno",
	["Trop près du chemin"] = "Perto demais do caminho",
	["Trop près du château"] = "Perto demais do castelo",
	["Trop près d'une autre tour"] = "Perto demais de outra torre",
	["Le niveau est terminé"] = "O nível acabou",
	["Tour inconnue"] = "Torre desconhecida",
	["{1} n'est pas dans ta barre de tours"] = "{1} não está na sua barra de torres",
	["Maximum {1} {2} par niveau"] = "Máximo {1} {2} por nível",
	["Pas assez d'or"] = "Ouro insuficiente",
	["Niveau maximum atteint"] = "Nível máximo alcançado",
	["Tes données ne sont pas encore chargées"] = "Seus dados ainda não carregaram",
	["Ce niveau n'existe pas encore"] = "Este nível ainda não existe",
	["Bientôt : les niveaux après le {1} arrivent avec les prochaines mises à jour"] = "Em breve: os níveis depois do {1} chegam nas próximas atualizações",
	["Réussis d'abord le niveau {1}"] = "Vença primeiro o nível {1}",
	["Aucune zone de combat libre pour l'instant"] = "Nenhuma zona de combate livre no momento",
	["Il te manque {1} pièces de niveau"] = "Faltam {1} moedas de nível",
	["Emplacement inconnu"] = "Espaço desconhecido",
	["Cette tour n'est pas encore à toi"] = "Esta torre ainda não é sua",
	["Cette tour est déjà au maximum de son entraînement"] = "Esta torre já está com o treino no máximo",
	["Cet emplacement est au niveau maximum"] = "Este espaço já está no nível máximo",
	["Tous les emplacements du camp sont ouverts"] = "Todos os espaços do acampamento estão abertos",

	----------------------------------------------------------------------
	-- Jouer en équipe : client/LevelsUI.luau (bouton et page de l'équipe, invitation, écran du niveau) et messages du
	-- serveur (Hub/LevelTeams.luau, Hub/LevelsService.luau, Hub/LevelGame.luau)
	----------------------------------------------------------------------
	["ÉQUIPE"] = "EQUIPE", -- « 👥 ÉQUIPE (3) », « 🔒 ÉQUIPE »
	["LE CHEF"] = "O LÍDER", -- « 👥 LE CHEF »
	["Jusqu'à {1} joueurs défendent le même château, dans la même partie."] = "Até {1} jogadores defendem o mesmo castelo, na mesma partida.",
	["Chacun pose ses tours avec son or, et chaque monstre tué donne son or à tout le monde."] = "Cada um coloca suas torres com seu próprio ouro, e cada monstro derrotado dá seu ouro para todos.",
	["Les monstres ont plus de vie, mais chacun gagne plus de pièces : +{1} % à deux, +{2} % à trois, +{3} % à quatre."] = "Os monstros têm mais vida, mas todos ganham mais moedas: +{1}% em dupla, +{2}% em trio, +{3}% em quatro.",
	["C'est le chef de l'équipe qui lance les niveaux : ils doivent être ouverts pour tous."] = "Quem começa os níveis é o líder da equipe: eles precisam estar liberados para todos.",
	["TON ÉQUIPE ({1}/{2}) : tu es le chef"] = "SUA EQUIPE ({1}/{2}): você é o líder",
	["L'ÉQUIPE DE {1} ({2}/{3})"] = "A EQUIPE DE {1} ({2}/{3})",
	["TU JOUES SEUL : invite des joueurs ci-dessous"] = "VOCÊ ESTÁ JOGANDO SOZINHO: convide jogadores abaixo",
	["Réussis d'abord le niveau {1} pour jouer en équipe"] = "Vença primeiro o nível {1} para jogar em equipe",
	["{1} (toi) : niveau {2} réussi"] = "{1} (você): nível {2} vencido",
	["{1} : niveau {2} réussi"] = "{1}: nível {2} vencido",
	["{1} : dans ton équipe"] = "{1}: na sua equipe",
	["{1} : déjà dans une équipe"] = "{1}: já está em uma equipe",
	["{1} : pas encore fini le niveau {2}"] = "{1}: ainda não venceu o nível {2}",
	["Quitter l'équipe"] = "Sair da equipe",
	["JOUEURS DE CE SERVEUR"] = "JOGADORES DESTE SERVIDOR",
	["Personne d'autre dans ce serveur pour l'instant. Invite des amis à te rejoindre sur Roblox !"] = "Ninguém mais neste servidor por enquanto. Convide amigos para jogar com você no Roblox!",
	["Inviter"] = "Convidar",
	["{1} t'invite à jouer en équipe !"] = "{1} convidou você para jogar em equipe!",
	["Accepter"] = "Aceitar", -- « ✓ Accepter »
	["Refuser"] = "Recusar",
	["C'est {1}, le chef de ton équipe, qui lance les niveaux"] = "Quem começa os níveis é {1}, o líder da sua equipe",
	["Tour de {1}"] = "Torre de {1}",
	["Bonus d'équipe ({1} joueurs) : +{2} % de pièces"] = "Bônus de equipe ({1} jogadores): +{2}% de moedas", -- « 👥 Bonus d'équipe... »
	["{1} choisit la suite"] = "{1} escolhe o que vem a seguir", -- « ⏳ Robin choisit la suite »
	["Invitation envoyée à {1}"] = "Convite enviado para {1}",
	["{1} a refusé ton invitation"] = "{1} recusou seu convite",
	["{1} a refusé tes invitations : réessaie dans une minute"] = "{1} recusou seus convites: tente de novo em um minuto",
	["{1} rejoint ton équipe !"] = "{1} entrou na sua equipe!",
	["Tu joues maintenant dans l'équipe de {1}"] = "Agora você joga na equipe de {1}",
	["{1} a quitté l'équipe : tu joues seul"] = "{1} saiu da equipe: você joga sozinho",
	["{1} a quitté l'équipe"] = "{1} saiu da equipe",
	["{1} a quitté le niveau : ses tours restent et continuent de tirer"] = "{1} saiu do nível: as torres dele ficam e continuam atirando",
	["{1} lance le niveau {2} pour l'équipe"] = "{1} começa o nível {2} para a equipe",
	["C'est {1}, le chef de ton équipe, qui lance les niveaux (ou quitte l'équipe pour jouer seul)"] = "Quem começa os níveis é {1}, o líder da sua equipe (ou saia da equipe para jogar sozinho)",
	["Le niveau {1} n'est pas encore ouvert pour {2}"] = "O nível {1} ainda não está liberado para {2}",
	["{1} joue encore un niveau avec d'autres joueurs : attends la fin"] = "{1} ainda está jogando um nível com outros jogadores: espere acabar",
	["Les données de {1} ne sont pas encore chargées"] = "Os dados de {1} ainda não carregaram",
	["Seul le chef de l'équipe peut inviter"] = "Só o líder da equipe pode convidar",
	["Ton équipe est complète ({1} joueurs au plus)"] = "Sua equipe está completa ({1} jogadores no máximo)",
	["{1} est déjà dans une équipe"] = "{1} já está em uma equipe",
	["{1} doit d'abord réussir le niveau {2}"] = "{1} precisa vencer o nível {2} primeiro",
	["Ce joueur n'est plus là"] = "Esse jogador não está mais aqui",
	["Cette invitation n'est plus valable"] = "Este convite não vale mais",
	["{1} n'est plus là"] = "{1} não está mais aqui",
	["Tu es déjà dans une équipe : quitte-la d'abord"] = "Você já está em uma equipe: saia dela primeiro",
	["{1} n'est plus le chef de son équipe"] = "{1} não é mais o líder da equipe",
	["L'équipe de {1} est complète"] = "A equipe de {1} está completa",
	["Ce n'est pas ta tour : seul celui qui l'a posée peut l'améliorer ou la vendre"] = "Essa torre não é sua: só quem colocou pode melhorar ou vender",

	----------------------------------------------------------------------
	-- Les amis : client/LevelsUI.luau (page de l'équipe, panneau « ami en ligne », écran de fin, invitation de
	-- Roblox) et messages du serveur (Hub/LevelsService.luau)
	----------------------------------------------------------------------
	["Un ami Roblox sur le même serveur : +{1} % de pièces en plus, seul ou en équipe."] = "Um amigo do Roblox no mesmo servidor: +{1}% de moedas a mais, sozinho ou em equipe.",
	["Un ami qui vient grâce à ton invitation : +{1} 💵 pour vous deux."] = "Um amigo que vem pelo seu convite: +{1} 💵 para vocês dois.",
	["Inviter des amis"] = "Convidar amigos", -- « 📨 Inviter des amis »
	["Amis Roblox sur ce serveur : {1} (+{2} % de pièces)"] = "Amigos do Roblox neste servidor: {1} (+{2}% de moedas)", -- « 🤝 Amis... »
	["Aucun ami Roblox sur ce serveur pour l'instant"] = "Nenhum amigo do Roblox neste servidor por enquanto",
	["{1} est en ligne ! Invite-le : +{2} 💵 pour vous deux s'il vient."] = "{1} está online! Convide: +{2} 💵 para vocês dois se ele vier.", -- « 🟢 Robin est en ligne ! ... »
	["Bonus d'ami sur le serveur : +{1} % de pièces"] = "Bônus de amigo no servidor: +{1}% de moedas", -- « 🤝 Bonus d'ami... »
	["Tu ne peux pas envoyer d'invitation depuis cet appareil"] = "Você não pode enviar convites deste aparelho",
	["Invite tes amis : {1} pièces de niveau pour vous deux quand ils arrivent !"] = "Convide seus amigos: {1} moedas de nível para vocês dois quando eles chegarem!",
	["Ton ami {1} est venu grâce à ton invitation : +{2} pièces de niveau !"] = "Seu amigo {1} veio pelo seu convite: +{2} moedas de nível!", -- « 🎁 ... »
	["Un ami est venu grâce à ton invitation : +{1} pièces de niveau !"] = "Um amigo veio pelo seu convite: +{1} moedas de nível!",
	["{1} amis sont venus grâce à tes invitations : +{2} pièces de niveau !"] = "{1} amigos vieram pelos seus convites: +{2} moedas de nível!",
	["Tu es venu grâce à l'invitation de {1} : +{2} pièces de niveau !"] = "Você veio pelo convite de {1}: +{2} moedas de nível!",
	["Tu es venu grâce à l'invitation d'un ami : +{1} pièces de niveau !"] = "Você veio pelo convite de um amigo: +{1} moedas de nível!",

	----------------------------------------------------------------------
	-- Les œufs : client/LevelsUI.luau (onglet Œufs, tour sortie, écran de fin), Hub/Camp.luau (couveuses de la
	-- parcelle) et messages du serveur (Hub/LevelsService.luau)
	----------------------------------------------------------------------
	["Œufs"] = "Ovos",
	["Œuf commun"] = "Ovo comum",
	["Œuf rare"] = "Ovo raro",
	["Œuf doré"] = "Ovo dourado",
	["Commune"] = "Comum",
	["Rare"] = "Rara",
	["Épique"] = "Épica",
	["Légendaire"] = "Lendária",
	["Spéciale"] = "Especial", -- (rareté des tours spéciales)
	["Œuf carmin"] = "Ovo carmesim",
	["Œuf de cuivre"] = "Ovo de cobre",
	["Œuf des ronces"] = "Ovo de espinhos",
	["Œuf de givre"] = "Ovo de gelo",
	["ŒUFS SPÉCIAUX"] = "OVOS ESPECIAIS",
	["Boss du niveau {1}"] = "Chefe do nível {1}", -- « 🔒 Boss du niveau 10 » (carte d'un œuf spécial pas encore gagné)
	["COUVER"] = "INCUBAR",
	["Couveuses pleines"] = "Incubadoras cheias",
	["Ton œuf spécial : son bouton COUVER, plus haut"] = "Seu ovo especial: o botão INCUBAR dele, mais acima",
	["Battre le boss d'un territoire donne aussi son œuf spécial (la première fois, puis 1 fois sur 10) : il donne toujours sa tour spéciale."] = "Vencer o chefe de um território também dá o ovo especial dele (na primeira vez, depois 1 vez em 10): ele sempre dá a torre especial.",
	["Œuf spécial gagné : {1} (tour : {2})"] = "Ovo especial ganho: {1} (torre: {2})", -- « 🌟 ... » (écran de fin)
	["TOUR SPÉCIALE !"] = "TORRE ESPECIAL!", -- « 🌟 TOUR SPÉCIALE ! » (panneau de la tour sortie d'un œuf)
	["TES ŒUFS ({1}/{2})"] = "SEUS OVOS ({1}/{2})",
	["Éclot en {1}"] = "Eclode em {1}",
	["Chances :"] = "Chances:",
	["Commune {1} %"] = "Comum {1}%",
	["Rare {1} %"] = "Rara {1}%",
	["Épique {1} %"] = "Épica {1}%",
	["Légendaire {1} %"] = "Lendária {1}%",
	["Palier 2 : {1} %"] = "Tier 2: {1}%",
	["COUVEUSES"] = "INCUBADORAS",
	["COUVEUSE {1}"] = "INCUBADORA {1}", -- « 🔒 COUVEUSE 2 »
	["COUVEUSE {1} : {2}"] = "INCUBADORA {1}: {2}",
	["COUVEUSE {1} (vide)"] = "INCUBADORA {1} (vazia)",
	["Couveuse {1}"] = "Incubadora {1}",
	["Prêt : ouvre-le !"] = "Pronto: abra!",
	["Encore {1}"] = "Pronto em {1}",
	["Pose un œuf :"] = "Coloque um ovo:",
	["Gagne des niveaux pour avoir des œufs"] = "Vença níveis para ganhar ovos",
	["Un œuf de plus en même temps"] = "Mais um ovo ao mesmo tempo",
	["OUVRIR !"] = "ABRIR!",
	["Finir : {1}"] = "Terminar: {1}",
	["Acheter : {1}"] = "Comprar: {1}",
	["Acheter : {1} pièces de niveau"] = "Comprar: {1} moedas de nível",
	["Acheter"] = "Comprar",
	["Vide : pose un œuf"] = "Vazia: coloque um ovo",
	["{1} : prêt !"] = "{1}: pronto!",
	["Chaque victoire donne un œuf : commun, rare au mini-boss, doré au boss (en rejouant : commun, rare au boss)."] = "Cada vitória dá um ovo: comum, raro num minichefe, dourado num chefe (ao repetir: comum, raro num chefe).",
	["Pose-le dans une couveuse : il éclot même quand tu n'es pas là, puis il donne une tour au hasard."] = "Coloque numa incubadora: ele eclode mesmo quando você não está, depois dá uma torre aleatória.",
	["Une tour que tu as déjà donne de l'XP d'entraînement à cette tour."] = "Uma torre que você já tem dá XP de treino para essa torre.",
	["Toutes les tours sortent des œufs. Les œufs rares et dorés donnent aussi des tours de palier 2, bien plus fortes."] = "Todas as torres saem dos ovos. Os ovos raros e dourados também dão torres tier 2, bem mais fortes.",
	["NOUVELLE TOUR !"] = "TORRE NOVA!", -- « 🎉 NOUVELLE TOUR ! » (panneau de la tour sortie d'un œuf)
	["DOUBLON"] = "REPETIDA",
	["{1} : elle rejoint ta barre de tours"] = "{1}: ela entra na sua barra de torres",
	["{1} : +{2} XP d'entraînement pour cette tour"] = "{1}: +{2} XP de treino para esta torre",
	["Super !"] = "Legal!",
	["{1} gagné ! Pose-le dans une couveuse."] = "{1} ganho! Coloque numa incubadora.",
	["{1} : il couve déjà dans ta couveuse !"] = "{1}: já está na sua incubadora!", -- « 🥚 Œuf commun : ... » (le premier œuf)
	["Réserve d'œufs pleine : {1} perdu"] = "Reserva de ovos cheia: {1} perdido",
	["Cette couveuse est déjà occupée"] = "Esta incubadora já está ocupada",
	["Tu n'as plus d'œuf de ce type : gagne des niveaux pour en avoir"] = "Você não tem mais ovos deste tipo: vença níveis para ganhar mais",
	["Cet œuf n'est pas encore prêt"] = "Este ovo ainda não está pronto",
	["Tu as déjà toutes les couveuses"] = "Você já tem todas as incubadoras",
	["Nouvelle couveuse : {1} œufs peuvent éclore en même temps"] = "Nova incubadora: {1} ovos podem eclodir ao mesmo tempo",

	----------------------------------------------------------------------
	-- Hub/Camp.luau : socles d'entraînement de la parcelle (étiquettes et invites)
	----------------------------------------------------------------------
	["Emplacement d'entraînement {1}"] = "Espaço de treino {1}",
	["Gérer"] = "Gerenciar",
	["Choisir une tour"] = "Escolher uma torre",
	["Ouvrir"] = "Abrir",
	["ENTRAÎNEMENT MAX"] = "TREINO MÁX",
	["Libre : choisis une tour à entraîner"] = "Livre: escolha uma torre para treinar",
	["Ouvrir : {1} pièces de niveau"] = "Abrir: {1} moedas de nível",

	----------------------------------------------------------------------
	-- Hub/HubMap.luau : les deux bâtiments à l'entrée de la parcelle
	----------------------------------------------------------------------
	["PORTE DES NIVEAUX"] = "PORTÃO DOS NÍVEIS",

	----------------------------------------------------------------------
	-- Hub/PlotBoard.luau : grand tableau au fond de la parcelle
	----------------------------------------------------------------------
	["CAMP D'ENTRAÎNEMENT"] = "ACAMPAMENTO DE TREINO",
	["Camp de {1}"] = "Acampamento de {1}",
	["NIVEAUX RÉUSSIS"] = "NÍVEIS VENCIDOS",
	["TOURS DÉBLOQUÉES"] = "TORRES DESBLOQUEADAS",
	["PIÈCES DE NIVEAU"] = "MOEDAS DE NÍVEL",
	["ENTRAÎNEMENT EN COURS · {1} tours"] = "TREINO EM ANDAMENTO · {1} torres",
	["ENTRAÎNEMENT EN COURS · {1} tour"] = "TREINO EM ANDAMENTO · {1} torre",
	["AUCUNE TOUR À L'ENTRAÎNEMENT"] = "NENHUMA TORRE TREINANDO",
	["Un camp prêt à accueillir son seigneur"] = "Um acampamento esperando seu senhor",
	["Les tours posées ici s'entraînent tout le temps, même quand leur seigneur est parti"] = "As torres colocadas aqui treinam o tempo todo, mesmo quando o senhor delas não está",
	["L'entraînement les fait évoluer : ★ ★★ ★★★"] = "O treino faz elas evoluírem: ★ ★★ ★★★",
	["Parcelle libre"] = "Lote livre",
	["En attente d'un propriétaire"] = "Esperando um dono",

	----------------------------------------------------------------------
	-- Hub/LevelBoard.luau : les deux panneaux du classement des niveaux, sur la place centrale (« NIVEAU » : plus haut)
	----------------------------------------------------------------------
	["CLASSEMENT"] = "RANKING",
	["MEILLEURS JOUEURS"] = "MELHORES JOGADORES",
	["SUR CE SERVEUR"] = "NESTE SERVIDOR",
	["JOUEUR"] = "JOGADOR",
	["VICTOIRES"] = "VITÓRIAS",
	["Aucun joueur pour l'instant"] = "Nenhum jogador por enquanto",
	["Tous les serveurs · mis à jour chaque minute"] = "Todos os servidores · atualizado a cada minuto",
	["Les joueurs présents en ce moment"] = "Os jogadores que estão aqui agora",

	----------------------------------------------------------------------
	-- Achats en Robux : la page « 🛒 BOUTIQUE », la couveuse royale, « Finir » en Robux (client/LevelsUI.luau,
	-- Hub/Camp.luau, Hub/Shop.luau, Hub/LevelsService.luau)
	----------------------------------------------------------------------
	["BOUTIQUE"] = "LOJA", -- « 🛒 BOUTIQUE »
	["Couveuse royale"] = "Incubadora real",
	["Une 3e couveuse, dorée : tes œufs y éclosent 2 fois plus vite."] = "Uma 3ª incubadora, dourada: seus ovos eclodem nela 2 vezes mais rápido.",
	["XP x2"] = "XP x2",
	["Toute l'XP d'entraînement de tes tours est doublée : camp, niveaux joués, doublons des œufs."] = "Todo o XP de treino das suas torres é dobrado: acampamento, níveis jogados, torres repetidas dos ovos.",
	["Argent x2"] = "Dinheiro x2",
	["Les pièces de niveau gagnées en jouant les niveaux sont doublées."] = "As moedas de nível que você ganha jogando os níveis são dobradas.",
	["À TOI"] = "SEU", -- « ✓ À TOI »
	["{1} R$"] = "{1} Robux",
	["Un pass s'achète une fois pour toutes, avec des Robux. Tu peux aussi finir un œuf tout de suite avec des Robux (onglet Œufs)."] = "Um passe é comprado uma vez só, com Robux. Você também pode terminar um ovo na hora com Robux (aba Ovos).",
	["COUVEUSE ROYALE"] = "INCUBADORA REAL", -- « 👑 COUVEUSE ROYALE »
	["COUVEUSE ROYALE : {1}"] = "INCUBADORA REAL: {1}",
	["COUVEUSE ROYALE (vide)"] = "INCUBADORA REAL (vazia)",
	["Tes œufs y éclosent 2 fois plus vite"] = "Seus ovos eclodem aqui 2 vezes mais rápido",
	["Acheter : {1} R$"] = "Comprar: {1} Robux",
	["Finir : {1} R$"] = "Terminar: {1} Robux",
	["2 fois plus rapide • {1} R$"] = "2 vezes mais rápido • {1} Robux",
	["2 fois plus rapide • bientôt"] = "2 vezes mais rápido • em breve",
	["Voir"] = "Ver",
	["Couveuse royale débloquée : tes œufs y éclosent 2 fois plus vite !"] = "Incubadora real desbloqueada: seus ovos eclodem nela 2 vezes mais rápido!", -- « 👑 ... »
	["XP x2 : toute l'XP d'entraînement de tes tours est doublée !"] = "XP x2: todo o XP de treino das suas torres é dobrado!", -- « ⭐ ... »
	["Argent x2 : les pièces des niveaux sont doublées !"] = "Dinheiro x2: as moedas dos níveis são dobradas!", -- « 💵 ... »
	["Merci !"] = "Obrigado!",
	["Tu as déjà ce pass"] = "Você já tem este passe",
	["Œuf fini : ouvre-le !"] = "Ovo pronto: abra!", -- « ⏩ ... »
	["Le temps acheté avance ton œuf qui a le plus à attendre"] = "O tempo comprado adianta o seu ovo que mais precisa esperar", -- « ⏩ ... »
	["Aucun œuf à finir : +{1} pièces de niveau à la place"] = "Nenhum ovo para terminar: +{1} moedas de nível no lugar",
	["Pass Argent x2 : pièces doublées"] = "Passe Dinheiro x2: moedas dobradas", -- « 💵 ... » (écran de fin)
	["Pass XP x2 : XP doublée"] = "Passe XP x2: XP dobrado", -- « ⭐ ... » (écran de fin)

	----------------------------------------------------------------------
	-- Hub/PlotIdentity.luau : plaque à l'entrée de chaque parcelle (nom et vignette du propriétaire)
	----------------------------------------------------------------------
	["FIEF {1}  /  DOMAINE"] = "FEUDO {1}  /  DOMÍNIO", -- {1} = numéro de la parcelle (01 à 06)
	["Fief libre"] = "Feudo livre",
	["Un domaine prêt à accueillir son seigneur"] = "Um domínio esperando seu senhor",
	["PARCELLE DISPONIBLE"] = "LOTE DISPONÍVEL",
	["CAMP DES TOURS"] = "ACAMPAMENTO DAS TORRES",

	----------------------------------------------------------------------
	-- Niveau d'une tour, au-dessus d'elle (client/PlotRenderer.luau) ; avec ses étoiles d'évolution : « ★★ Niv. 3 »
	----------------------------------------------------------------------
	["Niv. {1}"] = "Nív. {1}",

	----------------------------------------------------------------------
	-- Bouton « SON » et ses 3 réglages (client/SoundManager.luau, Sounds.MODE_LABELS)
	----------------------------------------------------------------------
	["SON"] = "SOM",
	["tout"] = "tudo",
	["effets seuls"] = "só efeitos",
	["muet"] = "mudo",
	["Son : {1}"] = "Som: {1}",

	----------------------------------------------------------------------
	-- PlayerData.luau : messages de player:Kick. Le client ne peut pas les traduire : le serveur appelle lui-même
	-- Lang.translate(texte, Lang.forPlayer(player)).
	----------------------------------------------------------------------
	["Impossible de charger tes données. Réessaie dans une minute."] = "Não foi possível carregar seus dados. Tente de novo em um minuto.",
	["Ta session a été ouverte sur un autre serveur."] = "Sua sessão foi aberta em outro servidor.",
	["Le jeu vient d'être mis à jour : rejoins une nouvelle partie pour avoir la dernière version."] = "O jogo acabou de ser atualizado: entre em um servidor novo para ter a versão mais recente.",
}

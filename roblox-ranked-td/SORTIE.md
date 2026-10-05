# Avant de rendre le jeu public

Liste des choses à faire avant d'ouvrir le jeu à tout le monde. On coche au fur et à mesure.

Le jeu sort comme une **nouvelle expérience Roblox** (décision du 02/10/2026) : plus rien n'est publié sur
« Tower 22 ». L'ancien jeu est gardé dans le dépôt, à l'étiquette git `ancien-jeu-complet`.

## Le jeu lui-même

- [x] 100 niveaux en 10 territoires (11 à 20 ajoutés le 02/10/2026, 21 à 100 le 03/10/2026 : une carte et une famille
      de monstres par territoire), camp d'entraînement, évolutions des tours, les œufs et les 20 tours (voir
      `NIVEAUX.md`). Depuis le 04/10/2026 : plus de boutique, les niveaux 1 à 40 ouverts (41 à 100 : « Bientôt »),
      une tour spéciale par territoire (son œuf spécial au boss du territoire).
- [x] Tout l'ancien jeu enlevé (classé, autel, forge, vagues infinies, renaissance, défis, passes, ancien tuto).
- [x] **Tuto** pour un nouveau joueur : une flèche dorée lui montre quoi toucher, du camp à la fin du niveau 1,
      puis son premier œuf à ouvrir (un œuf commun qui donne la Catapulte ; voir `NIVEAUX.md`, « Le tuto des
      nouveaux joueurs »). Celui qui la suit
      gagne le niveau 1.
- [x] **Version anglaise** : tous les écrans, le tuto, les messages et les panneaux sont traduits pour les joueurs
      non francophones (voir `README.md`, « Langues »). Vérifié par `run.ps1 -Test english` : aucun texte ne reste
      en français.
- [x] **Versions espagnole et portugaise** (nuit du 05/10/2026) : les joueurs dont la langue Roblox est l'espagnol
      ou le portugais voient tout le jeu dans leur langue (espagnol d'Amérique latine avec « tú », portugais du
      Brésil avec « você » ; en portugais, les prix s'écrivent « 99 Robux », car « R$ » y est le symbole du réal).
      Les autres (allemand, etc.) voient l'anglais. Vérifié par `run.ps1 -Test english` (les 3 langues).
- [ ] **Essai sur un vrai téléphone** : boutons, textes, pose d'une tour au doigt, zoom en pinçant, fluidité. (Les
      tests automatiques ne vérifient que la taille de l'écran, pas le toucher.)
- [ ] **Un nouveau joueur passe-t-il le niveau 1 ?** La difficulté est réglée avec des joueurs simulés et un seul
      vrai joueur (toi). Le tuto aide : un joueur simulé qui suit seulement la flèche gagne le niveau 1.
- [ ] **Joue les niveaux 11 à 40** : ils n'ont été essayés que par les joueurs simulés (trop durs ? trop faciles ?).
      Les boss 20, 30 et 40 demandent des tours de palier 2 (les œufs dorés des boss d'avant en donnent souvent).
- [ ] **Jouer en équipe, à deux pour de vrai** : dans Studio, le test « serveur et clients » avec 2 joueurs ;
      réussir le niveau 1 dans les deux, puis « 👥 ÉQUIPE » > « Inviter », accepter, lancer un niveau ensemble. À
      vérifier : chacun son couloir (son nom au-dessus de sa porte, des monstres dans les deux couloirs), chacun
      pose ses tours, l'or de chacun, l'écran de fin des deux, le niveau suivant ouvert pour les deux. (Le test
      automatique joue avec des joueurs d'essai, pas avec deux vrais clients.)
- [x] La Baliste et le Trébuchet renforcés (02/10/2026, voir `NIVEAUX.md`, « Ce que chaque tour apporte »).
- [ ] Ouvrir les niveaux 41 à 100 (tes mises à jour). **Le désert (41 à 50) est prêt** (nuit du 05/10/2026 : réglé
      pour les œufs, sa tour spéciale le Totem des sables et l'œuf des dunes) : ton « oui » et je mets
      `Levels.OPEN_COUNT = 50`. Les niveaux 51 à 100 : à régler de nouveau pour les œufs avant de les ouvrir. Plus de
      100 niveaux : il faudrait de nouvelles familles de monstres (les dix prévues sont utilisées).
- [ ] Les autres langues (allemand, russe, coréen...) : aujourd'hui ces joueurs voient le jeu en anglais. Une
      langue de plus = un dossier `src/shared/LangXX` comme `LangES` (voir le haut de `src/shared/Lang.luau`).
- [ ] Monstres : **les boss des niveaux 60 et 90** (la Légion des os, la Horde gobeline) n'ont pas encore de modèle
      3D : en attendant, ils sont faits de blocs, comme un monstre sans modèle (ces niveaux sont fermés pour
      l'instant). À faire faire par ChatGPT comme les autres (`assets/EnemyModels/Boss_5.rbxm` et `Boss_8.rbxm`).
      Le dragon (niveau 100) n'a pas d'animation de mort. Le colosse géant (niveaux 15, 25, 35) prend le modèle du
      chevalier colossal en plus grand ; un modèle à lui : `assets/EnemyModels/Colossus.rbxm`.
- [ ] **Les achats en Robux** (tes demandes du 04/10/2026 ; voir `NIVEAUX.md`, « Les achats en Robux ») : pass
      « Couveuse royale » 99, « XP x2 » 99, « Argent x2 » 199, « Finir l'œuf » 1 Robux les 5 min.
      - [x] Les 3 **pass** créés par toi le 05/10/2026 (« Incubateur royal » 2006325409, « XP x2 » 2006337360,
        « Argent x2 » 2006229395) : leurs numéros sont dans `src/shared/Monetization.luau`.
      - [ ] Leurs **images** (`assets/page` : `couveuse-royale.png`, `pass-xp-x2.png`, `pass-argent-x2.png`) : la
        page de chaque pass sur le Hub Création. Conseil : des noms en anglais (« Royal Incubator », « Money x2 »),
        la langue de la page étant l'anglais ; les noms français vont dans Localisation > Traduire > « Produits ».
      - [ ] Les 7 **produits pour développeurs** « Finish egg 1, 2, 3, 6, 12, 24, 48 » (Monétisation > Produits pour
        développeurs ; au prix de leur nombre ; image `finir-oeuf.png`), puis donne-moi leurs numéros : je les écris
        dans `Monetization.luau` et je refais la copie à publier. Tant qu'ils manquent, le bouton « Finir » en
        Robux n'apparaît pas (le reste marche).

## Publication (Studio et Hub Création)

- [ ] Le fichier à publier : la copie propre préparée par Claude, sur ton PC, dans le dossier du jeu :
      `A-PUBLIER\Jeu-100-niveaux-v13-anglais.rbxl` (refaite à chaque version, avec un nouveau nom : prends toujours
      la plus récente ; elle n'est pas dans git). Ferme les autres fenêtres de Studio avant de publier, pour ne pas
      te tromper de fichier. « -anglais » : la même que `Jeu-100-niveaux-v13` (commit e7ac7f0), mais Studio te la montre en
      anglais (`Config.STUDIO_LANGUAGE = "en"`, qui ne joue que dans Studio). Une fois publié, le jeu est le même :
      chaque joueur le voit dans sa langue Roblox (le français pour un compte en français, l'espagnol, le portugais,
      et l'anglais pour tous les autres).
- [ ] Publier comme une **nouvelle expérience** sur ton compte personnel (Fichier > Publier sur Roblox > « Créer une
      nouvelle expérience »), en privé. Les mises à jour ensuite : ouvrir la nouvelle copie propre,
      Publier sur Roblox > « Mettre à jour l'expérience existante… » > la nouvelle expérience (**pas** « Tower 22 »).
- [ ] Sur ton compte, pas sur une communauté : les animations des monstres sont publiées sur ton compte, elles ne se
      jouent que dans tes expériences.
- [ ] **À chaque mise à jour publiée**, surtout celle qui ouvrira de nouveaux niveaux (nouvelles tours, nouveaux
      œufs) : redémarre les serveurs (Hub Création > l'expérience > le menu « ⋯ » > « Redémarrer les serveurs » ;
      le nom exact peut changer). Sinon les anciens serveurs restent ouverts tant qu'ils ont des joueurs. Depuis le
      05/10/2026, le jeu protège quand même les sauvegardes : un joueur venu d'un serveur plus récent ne peut pas
      jouer sur un ancien (il est invité à rejoindre une nouvelle partie). Cette protection ne marche qu'à partir
      des serveurs qui l'ont : la première fois, redémarrer est nécessaire.
- [ ] Taille des serveurs : **6 joueurs** (une parcelle par joueur) : Hub Création > Lieux > le lieu > Accès.
- [ ] Appareils : **ordinateur, téléphone, tablette**. Décoche la console et la réalité virtuelle : le jeu n'a pas de
      commandes à la manette (Hub Création > l'expérience > Accès).
- [ ] Questionnaire sur le contenu : violence légère répétée -> « Léger » ; objets aléatoires payants : **oui** dès
      que les achats en Robux sont en ligne (« Finir l'œuf » et la couveuse royale font avoir plus vite une tour au
      hasard ; le jeu les cache là où Roblox les interdit) ; tout le reste : non.
- [ ] Langue de la page (Hub Création > l'expérience > Audience > Localisation > Langues) : la **langue source** doit
      être celle de la description que tu colles sur la page (**English** si tu colles la description anglaise).
      Tu peux ajouter « Français », « Espagnol » et « Portugais » dans les langues prises en charge et y coller le
      nom et la description dans ces langues (plus bas). Pour les textes **dans** le jeu, rien à régler : le jeu se
      traduit lui-même (français, anglais, espagnol, portugais) et empêche Roblox d'y toucher (voir `README.md`,
      « Langues »).
- [ ] Page du jeu : nom, description (français et anglais), icône, miniatures, vidéo (Roblox : 30 s au plus, textes
      et son en anglais, compte vérifié de 13 ans et plus pour l'envoyer). Une description prête à coller est plus
      bas (« Textes pour la page du jeu »), des images du nouveau jeu sont prêtes dans `assets/page` (voir son
      `LISEZ-MOI.txt`), et la VIDÉO de 16 s (ta demande du 04/10/2026 : « des rushs de 3/4 s ») dans `A-PUBLIER` :
      `video-16s.mp4` (le jeu seul) ou `video-16s-titres.mp4` (avec un titre en anglais sur chaque plan) : le colosse
      géant, un niveau du glacier, l'œuf carmin qui s'ouvre, le boss de glace, la victoire, enchaînés par des
      transitions, sur la musique du jeu « Courtly Dances » d'un seul morceau. Cette musique est sous licence
      Roblox : la vidéo est pour la page du jeu sur Roblox, pas pour YouTube ou TikTok. Refaite par
      `tools\studio-test\video.ps1` (OBS filme le vrai jeu, ffmpeg monte ; voir `tools/studio-test/README.md`).
- [ ] Public des moins de 16 ans (règles Roblox 2026) : tout nouveau jeu commence en 16+ ; pour Roblox Kids (5-8 ans)
      et Select (9-15 ans) : âge vérifié, double authentification, Roblox Premium 2 mois de suite (ou frais
      remboursables), puis 250 parties de joueurs « très engagés » en 60 jours (tableau « Audience Reach »). Ne pas
      payer l'examen accéléré.

## Textes pour la page du jeu (à coller, à changer comme tu veux)

Le nom du jeu est à toi de choisir. Description en anglais (c'est elle que la plupart des joueurs liront ; une
ligne par point, pour que le collage dans Roblox ne coupe pas les phrases) :

```text
Defend your castle in fast 2-3 minute levels!

- Place your towers anywhere and upgrade them non-stop: the monsters never stop getting stronger.
- 40 levels across 4 territories, with mini-bosses and bosses (more coming soon).
- 20 towers: win an egg with every victory, hatch it in your incubators and get a new tower, or its much stronger tier 2 version. Beat a territory's boss for its special egg and its special tower.
- Play together: teams of 2 to 4 players, everyone defends their own lane, and everyone earns bonus coins.
- Your own training camp: your towers train and earn stars, even while you're away.
- Plays on PC and phone. Free to play.
```

La même en français :

```text
Défends ton château dans des niveaux rapides de 2 à 3 minutes !

- Pose tes tours où tu veux et améliore-les sans arrêt : les monstres deviennent de plus en plus forts.
- 40 niveaux dans 4 territoires, avec des mini-boss et des boss (la suite arrive bientôt).
- 20 tours : un œuf à chaque victoire, à faire éclore dans tes couveuses, pour une nouvelle tour ou sa version de palier 2, bien plus forte. Bats le boss d'un territoire pour son œuf spécial et sa tour spéciale.
- Joue en équipe : de 2 à 4 joueurs, chacun défend son couloir, et tout le monde gagne plus de pièces.
- Ton camp d'entraînement : tes tours s'entraînent et gagnent des étoiles, même quand tu es parti.
- Sur ordinateur et sur téléphone. Gratuit.
```

En espagnol :

```text
¡Defiende tu castillo en niveles rápidos de 2 a 3 minutos!

- Coloca tus torres donde quieras y mejóralas sin parar: los monstruos se vuelven cada vez más fuertes.
- 40 niveles en 4 territorios, con minijefes y jefes (pronto habrá más).
- 20 torres: gana un huevo con cada victoria, ponlo en tus incubadoras y consigue una torre nueva, o su versión de rango 2, mucho más fuerte. Vence al jefe de un territorio para ganar su huevo especial y su torre especial.
- Juega en equipo: de 2 a 4 jugadores, cada uno defiende su camino, y todos ganan más monedas.
- Tu propio campamento de entrenamiento: tus torres entrenan y ganan estrellas, incluso cuando no estás.
- Para PC y teléfono. Gratis.
```

En portugais (du Brésil) :

```text
Defenda seu castelo em níveis rápidos de 2 a 3 minutos!

- Coloque suas torres onde quiser e melhore-as sem parar: os monstros ficam cada vez mais fortes.
- 40 níveis em 4 territórios, com minichefes e chefes (mais em breve).
- 20 torres: ganhe um ovo a cada vitória, coloque-o nas suas incubadoras e ganhe uma torre nova, ou a versão tier 2 dela, bem mais forte. Vença o chefe de um território para ganhar o ovo especial e a torre especial dele.
- Jogue em equipe: de 2 a 4 jogadores, cada um defende seu caminho, e todos ganham mais moedas.
- Seu próprio acampamento de treino: suas torres treinam e ganham estrelas, mesmo quando você não está.
- Para PC e celular. Grátis.
```

## Derniers essais dans le jeu publié (encore privé)

- [ ] Le tuto : à ta première visite, la flèche t'emmène au niveau 1 puis à ton premier œuf. Une fois l'œuf
      ouvert (ou le tuto passé avec « Passer le tuto »), elle ne revient plus, même à la visite suivante.
- [ ] La sauvegarde : gagner un niveau, quitter, revenir : le niveau, les pièces, les tours et les œufs sont là.
- [ ] Les œufs pendant l'absence : poser un œuf commun (15 min), quitter, revenir plus tard : il est prêt.
- [ ] Les tours spéciales : battre le boss du niveau 10, l'œuf carmin arrive en plus de l'œuf doré ; « COUVER »,
      1 h plus tard l'Arc carmin ; le poser dans un niveau (ses flèches rouges et dorées).
- [ ] L'entraînement pendant l'absence : mettre une tour dans le camp, revenir une heure plus tard.
- [ ] À deux joueurs : chacun sa parcelle, on voit le camp de l'autre en s'approchant, les invites de l'autre
      parcelle ne marchent pas, deux niveaux joués en même temps.
- [ ] **Les amis** (impossible à essayer dans Studio) : quand un ami Roblox se connecte, le panneau « Robin est en
      ligne ! » arrive en une minute au plus ; « 📨 Inviter » ouvre l'invitation de Roblox ; quand il vient grâce à
      l'invitation, 200 pièces de niveau pour chacun (une seule fois) ; avec un ami sur le serveur, l'écran de fin
      dit « Bonus d'ami sur le serveur : +10 % ».
- [ ] **Les panneaux de la place** (le classement de tous les serveurs ne marche que dans le jeu publié : dans Studio
      il est en mémoire) : ton nom tout de suite dans « SUR CE SERVEUR » ; après une victoire, dans « MEILLEURS
      JOUEURS » en une ou deux minutes.
- [ ] Les sons et les animations des monstres se chargent (dans une nouvelle expérience, une animation qui ne
      t'appartient pas ne se joue pas : le monstre glisse sans bouger les jambes).
- [ ] Rendre le jeu public.

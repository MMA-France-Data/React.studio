# Tower defense à niveaux (Roblox)

Un tower defense médiéval : une suite de **niveaux** de 2 à 3 minutes (100 niveaux en dix territoires, les 40
premiers ouverts), vus d'en
haut, où un flot continu de monstres devient de plus en plus fort. On pose ses tours où on veut et on les améliore
sans arrêt. Entre deux niveaux, on
retrouve sa parcelle, son **camp d'entraînement** : les tours s'y entraînent (même quand on est parti) et gagnent
des étoiles. Chaque victoire donne un **œuf** : toutes les tours en sortent (plus de boutique), à faire éclore dans
les couveuses de la parcelle.

- **Les règles, les chiffres et les décisions** : [NIVEAUX.md](NIVEAUX.md).
- **Ce qui reste à faire avant de rendre le jeu public** : [SORTIE.md](SORTIE.md).

Tout le code et tous les commentaires sont en français. Le dossier s'appelle encore `roblox-ranked-td` (le nom du
premier jeu) : c'est seulement un nom de dossier.

## L'ancien jeu

Jusqu'au 02/10/2026, ce dossier contenait un autre jeu (« Tower 22 » : classé 1 contre 1, parcelle à vagues
infinies, autel des héros, forge runique, renaissance, défis, passes Robux). Tout a été enlevé à la demande du
propriétaire. **Rien n'est perdu** : l'ancien jeu complet est gardé à l'étiquette git `ancien-jeu-complet`
(`git checkout ancien-jeu-complet` pour le revoir).

Ce jeu-ci est fait pour être publié comme une **nouvelle expérience Roblox**. Il enregistre dans son propre espace de
sauvegarde (`Niveaux_PlayerData_v1`) : il ne lit et n'écrase jamais les sauvegardes de « Tower 22 ».

## Installation

1. Installe [Rojo](https://rojo.space) (via [Rokit](https://github.com/rojo-rbx/rokit) : `rokit install` dans ce dossier)
   et le plugin Rojo dans Studio.
2. Dans ce dossier :
   ```bash
   rojo build -o Jeu.rbxl   # génère la place, à ouvrir dans Studio
   # ou, pour synchroniser en direct pendant que tu codes :
   rojo serve               # puis "Connect" dans le plugin Rojo
   ```
3. `Play` dans Studio pour essayer. Dans Studio, rien n'est sauvegardé pour de vrai (`Config.Data.MOCK_IN_STUDIO`) :
   chaque Play repart d'un nouveau joueur.
4. Publier : **Fichier > Publier sur Roblox**. La première fois : « Créer une nouvelle expérience ». Ensuite :
   « Mettre à jour l'expérience existante… ». Taille des serveurs : **6 joueurs** (une parcelle par joueur).

## Tester

**Sans Studio** :

```bash
powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1 -Tests
```

Les vérifications des règles, de la difficulté de chacun des 40 niveaux ouverts, de l'entraînement, du camp, du tuto,
du jeu en équipe et des œufs (une dizaine de minutes). Sans `-Tests` : le tableau de difficulté des 40 niveaux joués
par des joueurs
simulés ; `-Lazy`, `-Tune`, `-Curve`, `-Worth`, `-Equipe` pour régler la difficulté (voir
[tools/levels/README.md](tools/levels/README.md)).

```bash
powershell -ExecutionPolicy Bypass -File tools\studio-test\check.ps1
```

Syntaxe de tous les scripts et construction de la place.

**Dans Studio, tout seul** (4 à 6 minutes chacun, voir [tools/studio-test/README.md](tools/studio-test/README.md)) :

```bash
powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1
```

```bash
powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test monsters
```

```bash
powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test tutorial
```

```bash
powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test english
```

```bash
powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test team
```

```bash
powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test eggs
```

Le premier joue le jeu en entier (serveur, puis la vraie interface à la taille d'un ordinateur et d'un téléphone),
le deuxième vérifie les modèles 3D des monstres, le troisième joue le tuto d'un nouveau joueur en suivant la flèche,
le quatrième vérifie la version anglaise, le cinquième le jeu en équipe et les amis, le sixième les œufs, les
couveuses et les tours de palier 2.

**Images pour la page Roblox du jeu** (icône et miniatures, dans `assets/page`) : elles se refont toutes seules avec
`run.ps1 -Test page` puis `tools\studio-test\page.ps1` (voir `assets/page/LISEZ-MOI.txt`).
Captures dans `tools/studio-test/out/`. Le test s'ouvre dans sa propre fenêtre de Studio : un Studio déjà ouvert
n'est pas touché.

**Outils de Studio** (jamais dans le jeu publié), en haut à gauche pendant un Play :

- **« GALERIE (Studio) »** : t'emmène voir les 7 types de monstres dans les 10 styles (une rangée par territoire de
  10 niveaux), construits comme en jeu ; « ← RETOUR » te ramène. `Config.STUDIO_ENEMY_GALLERY = false` pour ne plus la
  construire (`src/client/EnemyGallery.luau`).
- **« SONS (Studio) »** : la liste de tous les sons, avec « Jouer ». `Config.STUDIO_SOUND_PANEL = false` pour cacher
  le bouton (`src/client/SoundPanel.luau`).
- **Le tuto** revient à chaque Play (dans Studio, tu es toujours un nouveau joueur) : « Passer le tuto » en bas à
  gauche, ou `Config.STUDIO_TUTORIAL = false` pour ne plus le voir dans Studio.
- **`ServerStorage.StudioDebug`** (barre de commande, vue Serveur) : lire les données d'un joueur, lui donner des
  pièces, finir un niveau… Liste en haut de `setupStudioDebug` (`src/server/Hub/init.luau`) et en bas de
  `src/server/Hub/LevelsService.luau`. Exemple :
  ```lua
  game.ServerStorage.StudioDebug:Invoke(game.Players:GetPlayers()[1], "Levels", "Set", "coins", 5000)
  ```

Pour utiliser les vraies sauvegardes depuis Studio : `Config.Data.MOCK_IN_STUDIO = false` et *Paramètres du jeu >
Sécurité > Activer l'accès de Studio aux services d'API*.

**Ce qui protège les sauvegardes et les achats** (relecture du 05/10/2026) :

- Un seul serveur à la fois écrit les données d'un joueur (verrou, `src/server/PlayerData.luau`). Un joueur qui
  revient sur le même serveur pendant la sauvegarde finale de sa visite d'avant attend qu'elle soit finie.
- Chaque sauvegarde garde la **version du jeu** qui l'a écrite (le numéro de publication du lieu). Après une mise à
  jour, les anciens serveurs restent ouverts tant qu'ils ont des joueurs : un ancien serveur ne charge jamais les
  données d'un joueur venu d'un serveur plus récent (il effacerait les nouvelles tours, les nouveaux œufs qu'il ne
  connaît pas) ; le joueur est invité à rejoindre une nouvelle partie.
- Achats en Robux (`src/server/Hub/Shop.luau`) : chaque reçu ne compte qu'une fois et n'est accepté qu'une fois la
  sauvegarde faite ; un reçu qui arrive pendant le chargement des données les attend ; « Finir l'œuf » ne finit
  que l'œuf pour lequel la fenêtre d'achat s'est ouverte ; si Roblox ne dit pas quels pass a un joueur, on
  redemande (et l'entraînement du camp attend la réponse, pour compter son XP x2).
- Demandes du client : un délai entre deux « lancer un niveau » (0,5 s) ou deux changements de tour au camp
  (0,25 s) ; plus d'invitation à un joueur qui en a refusé deux de suite, pendant une minute.

## Mettre tes propres modèles de monstres

Les monstres peuvent utiliser de vrais modèles 3D à la place des blocs. Un type sans modèle garde ses blocs : tu peux
en ajouter un à la fois. Les modèles en place sont dans `assets/EnemyModels/` (un fichier `.rbxm` par modèle).

1. **Trouve un modèle** dans Studio : Toolbox (Boîte à outils) > cherche « goblin » > clic pour l'insérer. Ou
   importe ton fichier 3D (Meshy, Tripo, Mixamo…) avec *Importer 3D*.
2. **Supprime tous ses scripts** (Script, LocalScript, ModuleScript : repère leur icône, pas leur nom, une porte
   dérobée a souvent un nom anodin). Un modèle de la Toolbox peut en cacher une. Le jeu les retire aussi et l'écrit
   dans la Sortie, mais trop tard pour un script piégé.
3. **Renomme-le** avec le type : `Normal` (Fantassin), `Fast` (Cavalier), `Tank` (Chevalier lourd), `Boss`
   (Seigneur de guerre), `Swarm` (Écuyer), `Giant` (Chevalier colossal). `Boss_9` = seulement les niveaux 91-100,
   `Swarm_0` = niveaux 1-10 (passe avant `Swarm`). Taille et position : réglées toutes seules.
4. **Essaie-le** : glisse-le dans ReplicatedStorage > `EnemyModels` (crée ce Folder s'il manque), puis Play.
   La galerie (bouton « GALERIE (Studio) ») écrit « modèle perso » ou « blocs » sous chaque monstre.
5. **Garde-le** : clic droit > *Enregistrer dans un fichier…* dans `assets/EnemyModels/`, même nom
   (`Swarm.rbxm`), puis `rojo build` et pousse le fichier sur GitHub.
6. **Marche animée** (facultatif) : un objet Animation nommé `Marche` (ou `Walk`, `Walking`) dans le modèle
   (personnage avec Humanoid ou AnimationController, ou modèle à os importé). L'animation doit être à toi (ou à ta
   communauté si c'est elle qui publie le jeu) ou à Roblox, sinon Roblox refuse de la jouer.
7. **Animation de mort** (facultatif) : pareil avec un objet Animation nommé `Mort` (ou `Dead`, `Death`) : jouée
   une fois quand le monstre est tué, le corps reste un instant puis s'efface. La galerie la montre toutes les 6 s.
   Plus simple : donne juste les **numéros** de tes animations publiées à Claude, qui les écrit dans
   `CustomModels.SETTINGS` (`src/shared/CustomModels.luau`), sans rien ajouter au modèle.

Le sens de marche est trouvé tout seul pour un personnage à os (ses orteils, ou la tête d'un cheval), et si son
animation le retourne d'un demi-tour (défaut de l'import de Studio sur les modèles d'un seul morceau, ex. le Roi
carmin et le fantassin), le jeu le mesure et le corrige tout seul. Sinon : attribut `FacingOffset` = 180 (ou 90 /
-90) sur le modèle ; trop petit ou trop grand : `HeightScale` (1.3, 0.8…). Détails dans
`assets/EnemyModels/README.txt` et `src/shared/CustomModels.luau`.

Import d'un `.glb` avec animations (ex. ceux de ChatGPT, dans `assets/enemies/`) : **Fichier > Importer** du fichier
qui contient le modèle ET l'animation (rig « Custom »), puis Éditeur d'animation > **⋯ > Charger** l'animation >
**Publier sur Roblox**. L'import d'un clip seul dans l'Éditeur d'animation (⋯ > Importer > depuis un fichier) ne
marche pas bien avec ces fichiers (seule la tête bouge, ou le modèle s'étire). L'os racine du squelette doit être sans
rotation (sinon le modèle bascule quand l'animation joue).

`tools/studio-helper/` : un petit plugin Studio (« Rangeur de monstres ») et un script pour récupérer les modèles
rangés dans un fichier de jeu enregistré.

**Important si tu publies une nouvelle expérience** : les animations des monstres sont publiées sur ton compte. Elles
se jouent dans toutes TES expériences ; si le jeu est publié par une communauté (groupe), il faut les republier pour
elle.

## Sons

Tous les sons du jeu sont réglés dans **un seul fichier** : `src/shared/Sounds.luau` (un son par ligne : numéro,
volume, hauteur, combien à la fois, écart minimum entre deux, distance à laquelle on l'entend). Ils ne sont joués
que chez le joueur (`src/client/SoundManager.luau`) : aucun coût pour le serveur.

- **Ce qu'on entend** : les tirs des 8 tours et leurs impacts (Catapulte, Baliste, Trébuchet), le bourdonnement du
  rayon du Sorcier, les morts des monstres (plus lourdes pour les chevaliers, les colosses et les boss), le cor de
  guerre quand un boss arrive dans ton niveau (des pas lourds pour un colosse), tour posée / améliorée / vendue,
  victoire / défaite, les clics et les refus (messages d'erreur), et des musiques médiévales calmes qui s'enchaînent.
- **Pas de brouhaha** : les sons des tours, impacts et morts sont en 3D (on n'entend que ce qui est près) ; 10 au
  plus en même temps (les plus proches d'abord ; la mort d'un boss passe toujours, réglage `priority`), et chaque
  son a son nombre maximum et son écart minimum (la vitesse x2 double les tirs, pas le bruit).
- **Bouton « SON »** : en haut à gauche, à droite du bouton « ⚔ NIVEAUX » et des pièces de niveau (téléphone : une
  petite icône dans la barre du haut de Roblox, à droite). « tout », « effets seuls » (sans musique) ou « muet » (même
  les bruits de pas). Le choix est sauvegardé avec tes données.
- **Changer un son** :
  1. Trouve un son **gratuit** : dans Studio, *Boîte à outils* (Toolbox) > onglet **Audio** (ou le Creator Store
     sur le site de Roblox, catégorie Audio). Écoute-le, vérifie qu'il est gratuit et public (les sons de
     Roblox, de « Pro Sound Effects » et d'« APM Music » marchent dans tous les jeux).
  2. Copie son **numéro** (clic droit > *Copier l'ID de l'asset*, ou le nombre dans l'adresse de sa page).
  3. Colle-le à la place de l'ancien `id` dans `src/shared/Sounds.luau` (garde le reste de la ligne), et change le
     commentaire au-dessus (titre et créateur du son).
  4. Joue dans Studio : bouton « SONS (Studio) » > « Jouer ». S'il affiche « ne se charge pas ! », le son est
     privé ou payant : prends-en un autre.
  Trop fort ou trop faible : change son `volume` (0 à 1). Joue trop souvent : augmente `minInterval`.

## Langues : français, anglais, espagnol, portugais

- Le jeu est écrit en français, et **tout est traduit en anglais, en espagnol et en portugais (du Brésil)** : un
  joueur dont la langue Roblox est le français voit le jeu en français, l'espagnol en espagnol, le portugais en
  portugais, et tous les autres en anglais (fenêtre du camp, niveaux, tuto, petits messages, panneaux et invites
  de la parcelle).
- **Comment ça marche** : le serveur met l'attribut `Lang` (« fr », « en », « es » ou « pt ») sur chaque joueur
  d'après sa langue
  Roblox (`Lang.startServer`). Chez un joueur non francophone, `src/client/AutoTranslate.luau` remplace chaque texte
  affiché par sa traduction dès qu'il apparaît ou change, et garde le texte français d'origine. Un joueur
  francophone ne paie presque rien. Le code du jeu ne relit donc jamais un `.Text` pour décider quelque chose, et
  n'écrit un texte que quand il change.
- **Traductions** : `src/shared/LangEN/` (anglais), `LangES/` (espagnol), `LangPT/` (portugais), avec dans chacun
  `Glossary` (les noms : tours, monstres, territoires, évolutions) et `Game` (tous les autres textes), une ligne par
  texte : `["texte français exact"] = "English",` (les mêmes lignes dans les trois). Une ligne qui manque en
  espagnol ou en portugais : ce joueur voit l'anglais à la place. Un texte qui change :
  `{1}`, `{2}`… Un texte entouré de symboles ou de nombres (« 🔒 Totem de givre », « Archer du rempart ★★ »,
  « +0,3 XP ») est traduit par son milieu : pas besoin d'une ligne pour chacun. Mode d'emploi en haut de
  `src/shared/Lang.luau`. Un texte sans traduction reste en français.
- **Quand tu ajoutes un texte au jeu** : ajoute sa traduction dans `LangEN/Game.luau`, `LangES/Game.luau` et
  `LangPT/Game.luau`, et une ligne dans `tools/lang/samples.luau` (le texte tel qu'il s'affiche, et l'anglais
  attendu).
- **Vérifier sans Studio** : `luau tools/lang/samples.luau` (387 textes du jeu et leur anglais attendu, aucun trou,
  ni en anglais, ni en espagnol, ni en portugais), `luau tools/lang/check.luau` (traductions chargées, doublons,
  lignes qui manquent en espagnol ou en portugais), `luau tools/lang/tests.luau` (le traducteur),
  `node tools/lang/autotranslate-test.cjs` (la traduction de l'écran, avec un faux Roblox).
- **Vérifier dans Studio** : `tools\studio-test\run.ps1 -Test english` passe le joueur en anglais, ouvre tous les
  écrans et liste chaque texte resté en français (il ne doit y en avoir aucun), puis refait le tour en espagnol et
  en portugais (aucun texte resté en français, aucun pris en anglais).
- **Voir le jeu dans une autre langue dans Studio** : `Config.STUDIO_LANGUAGE = "en"`, `"es"` ou `"pt"` (`"auto"` =
  comme le jeu publié, `"fr"`).
- **Jamais la traduction automatique de Roblox** : depuis juin 2026, Roblox traduit tout seul les textes des jeux
  pour les joueurs qui ont le réglage « Traductions automatiques », en supposant qu'ils sont écrits dans la « langue
  source » du jeu. Les nôtres sont en français pour les uns, traduits par nous pour les autres : il prendrait l'un
  pour l'autre. `AutoTranslate.luau` l'en empêche pour tous les joueurs (« LE BOUCLIER » : `AutoLocalize = false` sur
  chaque écran, chaque panneau du monde et chaque invite). La langue source réglée dans le Hub Création ne compte
  donc que pour la **page** du jeu (son nom, sa description), jamais pour le jeu lui-même.
- La colonne de la liste des joueurs de Roblox (`leaderstats`) a le même nom pour tout le monde : c'est donc un mot
  anglais, « Level » (le plus haut niveau réussi).

## Réglages

| Quoi | Où |
|---|---|
| Niveaux (et combien sont ouverts : `OPEN_COUNT`), territoires et cartes, monstres, or, prix, œufs, entraînement, évolutions | `src/shared/Levels.luau` |
| Décor de chaque territoire (couleurs du sol, rochers, arbres) | `THEMES`, en haut de `src/server/Hub/LevelArena.luau` |
| Les 21 tours (dégâts, portée, effets ; 8 de palier 1, 8 de palier 2, 5 tours spéciales) | `src/shared/IdleTowers.luau` |
| Vitesses, limites du combat, rythme des envois réseau | `src/shared/IdleConfig.luau` |
| Les 7 types de monstres (nom, vitesse, taille ; dont le colosse géant) | `src/shared/Enemies.luau` |
| Sons | `src/shared/Sounds.luau` |
| Outils de Studio, tuto et langue dans Studio, sauvegarde | `src/shared/Config.luau` |
| Caméra d'un niveau, tailles des fenêtres | en haut de `src/client/LevelsUI.luau` |
| Style de l'interface (couleurs, polices, contours) | `src/client/UI.luau` |

Après un changement de chiffre : `tools\levels\run.ps1 -Tests` (une minute et demie) dit si une règle ou la
difficulté d'un niveau est cassée.

## Structure

```
src/
  shared/   (ReplicatedStorage.Shared)    Config, Levels, Monetization, TeamMaps, IdleTowers, IdleConfig, Enemies, PlotLayout,
                                          RoadGeometry, Remotes, Sounds, NumberFormat, ProximityLabel, MedievalModels,
                                          CustomModels, Lang, LangEN/LangES/LangPT/{Glossary, Game}
  server/   (ServerScriptService.Server)  Main, PlayerData, MockDataStore, LevelLeaderboard,
                                          Hub/{init, HubMap, Plots, PlotBoard, PlotIdentity, PlotInterest, LevelBoard, Shop,
                                               Combat, LevelGame, LevelArena, LevelsService, LevelTeams, Funnel, Camp,
                                               CampGame, IdleTowerModel}
  client/   (StarterPlayerScripts.Client) Main, UI, LevelsUI, TutorialUI, PlotRenderer, PlotAccess, Effects,
                                          CombatVFX, SoundManager, AutoTranslate, EnemyGallery, SoundPanel
assets/
  EnemyModels/   les modèles 3D des monstres utilisés par le jeu (.rbxm, lus par Rojo)
  enemies/       leurs fichiers d'origine (.glb, .fbx), faits avec ChatGPT
  page/          icône et miniatures pour la page Roblox du jeu (pas dans le jeu lui-même)
tools/
  levels/        joueurs simulés et vérifications hors Studio
  team-maps/     les 30 cartes d'équipe : dessin, vérification, aperçus (Python : python tools/team-maps/generer.py)
  studio-test/   tests automatiques dans Studio
  lang/          vérifications de la traduction
  studio-helper/ plugin Studio pour ranger les modèles de monstres
```

Quelques noms viennent de l'ancien jeu et ont été gardés pour ne rien casser : `IdleTowers` et `IdleConfig` (les
tours et le combat), `PlotRenderer` (l'affichage du combat), l'attribut `Wave` d'une zone de combat (le numéro du
niveau, qui donne le style des monstres), `FiefBoard` (le tableau d'une parcelle).

## Limites connues

Voir la fin de [NIVEAUX.md](NIVEAUX.md).

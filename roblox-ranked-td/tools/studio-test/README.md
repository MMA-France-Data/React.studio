# Tests automatiques dans Roblox Studio

Ces scripts ouvrent le jeu dans Studio, lancent Play tout seuls, jouent un scénario de test, prennent des captures
d'écran et récupèrent la fenêtre Sortie. Ils ne servent qu'au développement : rien ici n'est dans la place construite
par `default.project.json`, donc rien n'est publié avec le jeu.

Il faut Windows, Roblox Studio, [Rojo](https://rojo.space) et [Node.js](https://nodejs.org).

## Lancer un test

Depuis le dossier `roblox-ranked-td` :

```bat
powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1
powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test monsters
powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test tutorial
powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test english
powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test team
```

**Ne touche pas au PC pendant un test** : la fenêtre de Studio du test bouge et change de taille toute seule ; un clic
dedans ferme une fenêtre du jeu ou pose une tour, et des vérifications échouent sans raison.

**Ton Studio déjà ouvert n'est pas touché** : le test s'ouvre dans une autre fenêtre de Studio, et seule cette
fenêtre est redimensionnée, photographiée, puis fermée à la fin (`-KeepOpen` pour la garder). `-CloseStudio` ferme
d'abord tous les Studio ouverts (travail non enregistré perdu).

**L'écran du PC reste allumé pendant un test** (`awake.ps1`) : quand Windows éteint l'écran (10 minutes sans souris
ni clavier), Studio n'affiche plus rien du tout (image du jeu de 1 x 1 pixel, captures blanches) et tous les tests de
l'écran ratent. Le script demande donc à Windows de garder l'écran allumé tant qu'il tourne. Aucun réglage
d'alimentation n'est changé : tout redevient normal à la fin du test.

### `run.ps1` : le jeu en entier (environ 6 minutes)

Scénarios `scenarios\LevelsServer.luau` puis `scenarios\LevelsClient.luau`. Captures `out\levels_<nom>.png`.

**Côté serveur** (par les mêmes demandes que le remote `LevelAction`, avec `ServerStorage.StudioDebug`) :

- le jeu ne contient plus que les niveaux et le camp : sauvegarde (niveaux + réglage du son), 5 remotes, une seule
  colonne « Level » dans la liste des joueurs, place centrale sans le cercle du classé, 6 parcelles avec leur
  bâtiment des œufs, leur porte des niveaux et 3 socles ;
- **le camp d'entraînement** (la parcelle du joueur) : l'Archer posé sur le 1er socle, étiquettes et invites,
  tableau du camp, cibles détruites, tour remplacée, **évolutions** ★★ puis ★★★ (anneau, fanions, halo), 2e
  emplacement (`levels_camp_evolue`) ;
- **qui reçoit quel camp** (`Hub/PlotInterest.luau`) : son propriétaire toujours, les autres seulement quand ils
  s'en approchent, avec de fausses positions puis avec le vrai joueur ;
- **six niveaux joués en même temps** : temps du serveur par image (voir `NIVEAUX.md`) ;
- demandes refusées, le niveau 1 **perdu** par celui qui pose 2 Archers puis attend (pose libre, refus, x2, défaite,
  petite récompense), puis gagné avec ses 5 Archers posés et améliorés (victoire, récompense, XP, **l'œuf de
  catapulte** dans la 1re couveuse, ouvert 11 s plus tard : la Catapulte), « Niveau suivant » dans la même zone,
  abandon, « Rejouer », plus de boutique, camp (emplacements, absence d'une heure puis d'une semaine), ordre de la
  barre rapide, entraînement publié dans un niveau ;
- **le 2e territoire** : le niveau 11 fermé tant que le niveau 10 n'est pas réussi, la carte du col construite
  (terre rousse, rochers), ses 12 emplacements, une capture en plein combat (`levels_territoire2`), les récompenses
  (280, 600 au mini-boss, 1 200 au boss), le retour à la carte de la vallée ;
- **les territoires 3 et 4** : les cartes de la forêt (un vrai bois) et du glacier (neige) construites, leurs 12
  emplacements, une capture de chacune en plein combat (`levels_territoire3`, `levels_territoire4`), le boss du
  niveau 40, le dernier ouvert (2 400 pièces, pas de niveau suivant), le niveau 41 refusé (« Bientôt »).

**Côté client** (avec la vraie interface : l'attribut `TestAction` des écrans « Levels » et « LevelHud » lance les
mêmes fonctions que les boutons, et un appui sur le terrain passe par le vrai chemin : point de l'écran, rayon de la
caméra, sol) :

- plus aucun écran de l'ancien jeu, la place vue d'en haut (`levels_place`), pièces de niveau et bouton « SON » à
  côté du bouton « ⚔ NIVEAUX », cibles de paille sur la parcelle, son des flèches, onglet Entraînement et évolutions
  (`levels_camp_parcelle`, `levels_camp_evolutions`) ;
- fenêtre du camp et ses 4 onglets (`levels_camp_niveaux`, `levels_camp_oeufs`, `levels_camp_entrainement`,
  `levels_camp_tours`), les 100 niveaux en 10 territoires dans une page qui défile, « 🔒 BIENTÔT » après le niveau 40
  (`levels_camp_dernier_territoire`) ;
- niveau 1 : vue d'en haut qui remplit l'écran, l'Archer seul dans la barre, Archer offert qui tue en moins de 10 s,
  son du combat, « +6 » doré de l'or gagné, **pose libre** (aucun « + », la tour se pose exactement là où on
  touche, même à côté d'un emplacement conseillé), **bouton « ANNULER » de la tour en main**
  (`levels_annuler`), menu de la tour, amélioration, pose libre, zoom et déplacement de la vue, trois inclinaisons
  de la caméra (`levels_vue_normale`, `levels_vue_70`, `levels_vue_90`), refus sur le chemin, conseil « ne garde pas
  ton or », x2 ;
- **défaite de celui qui pose 4 Archers puis attend** (`levels_defaite`), « Réessayer », **victoire en posant et en
  améliorant sans arrêt** (`levels_fin_de_niveau`, `levels_victoire` : le premier œuf annoncé), « Niveau
  suivant », abandon en deux appuis,
  retour au camp ;
- puis **à la taille d'un téléphone** (750 x 332 : le scénario écrit « PHONE:want=750x332;have=... » et `run.ps1`
  redimensionne la fenêtre de Studio jusqu'à ce que l'écran du jeu fasse cette taille) : boutons dans l'écran et
  sans recouvrement, icône du son dans la barre du haut, fenêtre du camp, niveau, « ANNULER », menu de la tour qui
  ne cache pas la tour, zoom (`levels_tel_*`).

### `run.ps1 -Test monsters` : les modèles 3D des monstres (environ 6 minutes)

Scénario `scenarios\MonstersClient.luau` (pas de scénario serveur). Captures `out\monsters_<nom>.png`.

- le module `CustomModels.luau`, avec un modèle de test « Swarm » posé pendant la partie : il remplace les blocs des
  écuyers, sans ses scripts ; paliers ; un modèle demandé à deux tailles ; animations lues dans le code ou dans le
  modèle ;
- **chaque vrai modèle** de `assets\EnemyModels` : nom valable, bonne hauteur, tourné dans le sens de la marche,
  animations publiées qui se chargent, et une photo de lui en train de marcher (`monsters_walk_<modèle>` : son
  visage doit regarder vers la pointe de la flèche rouge). Environ 3,5 s par modèle ;
- **la galerie Studio** construite avec ces modèles (`monsters_gallery_custom_model`, `monsters_gallery_boss_0`) ;
- **un vrai niveau** : ses monstres sont les vrais modèles (ou les blocs), à leur taille agrandie
  (`monsters_niveau`).

### `run.ps1 -Test tutorial` : le tuto d'un nouveau joueur (environ 4 minutes)

Scénarios `scenarios\TutorialServer.luau` et `scenarios\TutorialClient.luau`. Captures `out\tutorial_<nom>.png`.
La place de test contient le marqueur `__AutoTestNewPlayer` : le tuto y démarre comme pour un vrai nouveau joueur
(dans les autres tests, il ne démarre jamais). Le scénario lit ce que la flèche montre (attributs `Target`,
`TargetPoint` et `Caption` de l'écran « TutorialPointer ») et **fait seulement ce qu'elle dit** :

- à l'arrivée, la fenêtre des niveaux s'ouvre toute seule et la flèche montre « ▶ JOUER » du niveau 1
  (`tutorial_arrivee`) ; fenêtre fermée ou autre onglet : elle montre comment y revenir (`tutorial_bouton_niveaux`) ;
- niveau 1 : seulement deux gestes. « PRENDS UN ARCHER » sur la barre (`tutorial_prends`), puis, la tour en main,
  des mots seuls « POSE-LA OÙ TU VEUX », sans flèche ni « + » (`tutorial_pose_libre`) : le scénario pose loin des
  emplacements conseillés ; puis « TOUCHE CETTE TOUR » et « AMÉLIORE » (`tutorial_tour`, `tutorial_ameliore`) ;
  ensuite **plus aucune flèche pendant 10 s** malgré l'or qui monte (`tutorial_seul`) ; la flèche doit toujours être
  à côté de ce qu'elle montre, dans l'écran, sans recouvrir « Vendre » ; le niveau est ensuite gagné d'un coup ;
- victoire : le premier œuf (un œuf commun qui donne la Catapulte) couve déjà, « TON ŒUF ! » sur « Retour au camp » (`tutorial_victoire`) ; au camp :
  l'onglet Œufs (`tutorial_onglet_oeufs`), « TON ŒUF ! » sur « ⚔ NIVEAUX » si la fenêtre est fermée, la couveuse
  (`tutorial_couveuse`), « OUVRE-LE ! » au bout de 10 s (`tutorial_oeuf_pret`) ; la Catapulte sortie termine le tuto
  (`tutorial_fini`) ; les 6 étapes des statistiques des nouveaux joueurs ;
- « Passer le tuto » : un appui sur ordinateur, deux sur téléphone (`tutorial_tel_passer`) ;
- à la taille d'un téléphone : la flèche et ses mots restent dans l'écran (`tutorial_tel_*`).

### `run.ps1 -Test team` : jouer en équipe (environ 2 minutes)

Scénarios `scenarios\TeamServer.luau` et `scenarios\TeamClient.luau`. Captures `out\team_<nom>.png`. Un Play de
Studio n'a qu'un vrai joueur : ses coéquipiers sont des **joueurs d'essai** (des tables qui imitent un Player, sans
client : `LevelsService.debug` « TeamFake », « TeamAs »), qui passent par les mêmes demandes que le remote
`LevelAction`. Le jeu avec deux vrais clients reste à essayer à la main (le test « serveur et clients » de Studio
avec 2 joueurs, ou avec un ami).

- **serveur** : invitations (refus, acceptation, conditions : niveau 1 réussi, chef seulement, équipe complète),
  lancement par le chef d'un niveau ouvert pour tous, partie à deux sur la carte d'équipe (« Valley_2 » : le nom de
  chacun au-dessus de la porte de son couloir ; à quatre : « Valley_4 », quatre noms), or et entraînement de chacun publiés, monstres
  x1,85, tours de chacun : on ne peut ni améliorer ni vendre celle d'un autre, l'or des monstres à chacun),
  victoire (pièces avec le bonus de 10 %, niveau suivant ouvert pour les deux), départs (celui qui s'en va abandonne
  pour lui seul, ses tours restent ; le dernier range la partie ; le chef qui part), équipe de quatre (monstres x2,95,
  bonus de 40 %), départ du jeu d'un joueur d'essai, le chef qui quitte l'équipe ; les amis (un ami Roblox sur le
  serveur : +10 % de pièces ; un ami venu grâce à une invitation : 200 pièces chacun, une seule fois ; amis venus
  pendant l'absence du joueur : leurs récompenses à son retour) ;
- **client** : le bouton « 👥 ÉQUIPE » et sa page (`team_page_seul`, `team_page_equipe`), le panneau d'invitation
  (`team_invitation` : « Refuser », « Accepter »), les boutons des niveaux d'un coéquipier (« 👥 LE CHEF ») et du
  chef (« 🔒 ÉQUIPE », `team_niveaux_chef`), un niveau lancé par Robin sur la carte d'équipe (deux portes, « Robin »
  et le nom du joueur au-dessus, des monstres affichés dans les deux couloirs : `team_carte_equipe`), l'or du joueur et pas celui de Robin, l'or
  de Robin sous le bandeau, la tour de Robin sans « Améliorer » ni « Vendre » : `team_tour_de_robin`,
  `team_niveau_a_deux`), l'écran de fin (bonus, « ⏳ Robin choisit la suite » : `team_fin_coequipier`), la suite
  lancée par Robin, le joueur qui quitte, le chef dont l'écran de fin garde « Niveau suivant », « Quitter
  l'équipe » ; les amis (le panneau « ami en ligne » : `team_ami_en_ligne`, son « Inviter », le bouton « Inviter
  des amis », le bonus d'ami sur l'écran de fin) ; à la taille d'un téléphone (`team_tel_page`,
  `team_tel_invitation`).

### `run.ps1 -Test eggs` : les œufs et les couveuses (environ 2 minutes)

Scénarios `scenarios\EggsServer.luau` et `scenarios\EggsClient.luau`. Captures `out\eggs_<nom>.png`. L'heure du
serveur avance avec le debug « Clock » (un œuf de 4 h s'ouvre tout de suite), et le debug « EggForce » choisit la
tour du prochain œuf (le tirage au hasard n'est pas testable autrement).

- **serveur** : un œuf à chaque victoire (doré au boss, commun en rejouant, rien en perdant, perdu si la réserve est
  pleine), poser un œuf (couveuse vide et œuf en réserve seulement), pas d'ouverture avant son temps, la tour sortie
  (nouvelle : dans la barre, une tour de palier 2 à la place de sa tour de base ; doublon : XP d'entraînement ;
  attribut `Hatch` ; au hasard, un œuf commun : toujours une tour de palier 1), « Finir » avec des pièces, les
  couveuses achetées
  (pas de 4e), les couveuses de la parcelle (l'œuf de sa couleur, le temps qui reste, l'œuf prêt qui brille,
  l'invite vers l'onglet Œufs) ;
- **client** : l'onglet « Œufs » (cartes des œufs et leurs chances, couveuses : `eggs_onglet`), un œuf posé
  (`eggs_couve`), prêt puis ouvert : nouvelle tour de palier 2, sa tour de base et ce qu'elle fait
  (`eggs_nouvelle_tour`), et doublon (`eggs_doublon`), « Mes tours » avec la tour de palier 2 et celles qui
  attendent « dans les œufs » (`eggs_mes_tours_palier2`), la 2e couveuse achetée, la pastille « ! » de l'onglet,
  l'écran de fin qui dit l'œuf gagné (`eggs_fin_de_niveau`), à la taille d'un téléphone (`eggs_tel_onglet`).

### `run.ps1 -Test english` : la version anglaise (environ 3 minutes)

Scénarios `scenarios\EnglishServer.luau` et `scenarios\EnglishClient.luau`. Captures `out\english_<nom>.png`.
Le joueur passe en anglais en direct (son attribut `Lang`, comme le serveur le met pour un joueur non
francophone), puis tous les écrans sont ouverts l'un après l'autre : fenêtre du camp (4 onglets, nouveau joueur
puis joueur avancé), panneaux et invites de la parcelle, un niveau (conseils, barre des tours, menu d'une tour,
petits messages), les écrans de fin (défaite, victoire avec une évolution, dernier niveau), les mots de la flèche
du tuto. À chaque écran, chaque texte qui a encore l'air français (lettre accentuée ou mot français courant) est
noté, ainsi que les textes que le traducteur n'a pas trouvés. À la fin : la liste « non traduit : ... » (elle doit
être vide), puis le retour au français (chaque texte doit revenir).

### `run.ps1 -Test page` puis `page.ps1` : les images de la page Roblox du jeu

Ce n'est pas un test. Le scénario `scenarios\PageClient.luau` met en scène de vraies parties, en anglais (un combat
dans la vallée avec les 8 tours et un colosse, la même partie vue de près sans l'interface, le boss du col, l'écran
de victoire, le camp avec trois tours évoluées, l'onglet des œufs, les niveaux) et prend les captures
`out\page_<nom>.png`.
Puis :

```bat
powershell -ExecutionPolicy Bypass -File tools\studio-test\page.ps1
```

découpe l'image du jeu dans chaque capture (sans les menus de Studio : il la trouve grâce à la capture
`page_calibrage`, un écran rose plein cadre) et enregistre dans `assets\page` les miniatures (1920 x 1080) et
l'icône (512 x 512). À refaire quand le jeu change d'allure.

### Lire le résultat

À la fin, le script affiche chaque ligne `[PASS]` / `[FAIL]`, les erreurs de la Sortie, la liste des captures et le
compte « Réussis / Erreurs ». La Sortie complète est dans `out\studio-output.log`.

- « Temps dépassé » avec un journal vide : Studio n'a pas réussi à lancer le Play (fenêtre de connexion, mise à
  jour de Studio...). Ouvre Studio une fois à la main, puis relance.
- S'il manque les dernières lignes : le Play s'est arrêté trop tôt, relance avec un `-Seconds` plus grand (durée
  maximale du Play ; le script attend au plus `-Seconds` + 150 s).

Vérification rapide sans Studio (syntaxe de tous les scripts + construction de la place) :

```bat
powershell -ExecutionPolicy Bypass -File tools\studio-test\check.ps1
```

## Comment ça marche

| Fichier | Rôle |
|---|---|
| `run.ps1` | Construit la place de test, installe le plugin, ouvre Studio, redimensionne sa fenêtre quand le scénario le demande, prend les captures, affiche les résultats |
| `mkproj.cjs` | Crée `out\<levels\|monsters\|tutorial\|english\|page>.project.json` : `default.project.json` + le marqueur `__AutoPlayTest` + les scénarios |
| `awake.ps1` | Garde l'écran du PC allumé pendant un test (voir plus haut) |
| `AutoPlayTest.lua` | Plugin Studio, copié dans `%LOCALAPPDATA%\Roblox\Plugins` par `run.ps1` |
| `logserver.cjs` | Petit serveur sur `127.0.0.1:34999` (ce PC uniquement) qui écrit la Sortie dans `out\studio-output.log` |
| `shot.ps1` | Capture d'une fenêtre de Studio |
| `check.ps1` | Syntaxe de tous les scripts et construction de la place, sans Studio |
| `scenarios\LevelsServer.luau` | Le jeu côté serveur (pilote la partie avec `ServerStorage.StudioDebug`) |
| `scenarios\LevelsClient.luau` | Le jeu côté client (la vraie interface, à la taille d'un ordinateur puis d'un téléphone) |
| `scenarios\MonstersClient.luau` | Les modèles 3D des monstres et la galerie |
| `scenarios\TutorialServer.luau`, `scenarios\TutorialClient.luau` | Le tuto d'un nouveau joueur |
| `scenarios\EnglishServer.luau`, `scenarios\EnglishClient.luau` | La version anglaise |
| `scenarios\PageClient.luau`, `page.ps1` | Les images de la page Roblox du jeu (captures, puis recadrage dans `assets\page`) |

**Le plugin ne fait rien dans tes places** : sa première vérification est `if not marker then return end`. Il ne
s'active que si la place contient `ReplicatedStorage.__AutoPlayTest`, un objet que seul `mkproj.cjs` ajoute aux
places de test. Pour le désinstaller, supprime `%LOCALAPPDATA%\Roblox\Plugins\AutoPlayTest.lua`.

`ServerStorage.StudioDebug` (`src/server/Hub/init.luau`, commandes des niveaux en bas de
`src/server/Hub/LevelsService.luau`) n'est créé que dans Studio (`RunService:IsStudio()`) : il n'existe pas dans le
jeu publié.

Un test interrompu peut laisser tourner son serveur de journal (`logserver.cjs`) : le test suivant l'arrête tout seul
avant de lancer le sien (sinon la Sortie partirait dans le fichier de l'autre).

L'ancien jeu (classé, autel, forge, vagues infinies) avait ses propres scénarios et un mode « tournage » (vidéos de la
page Roblox avec OBS) : ils sont dans le dépôt à l'étiquette git `ancien-jeu-complet`.

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
  boutique, leur porte des niveaux et 3 socles ;
- **le camp d'entraînement** (la parcelle du joueur) : l'Archer posé sur le 1er socle, étiquettes et invites,
  tableau du camp, cibles détruites, tour remplacée, **évolutions** ★★ puis ★★★ (anneau, fanions, halo), 2e
  emplacement (`levels_camp_evolue`) ;
- **qui reçoit quel camp** (`Hub/PlotInterest.luau`) : son propriétaire toujours, les autres seulement quand ils
  s'en approchent, avec de fausses positions puis avec le vrai joueur ;
- **six niveaux joués en même temps** : temps du serveur par image (voir `NIVEAUX.md`) ;
- demandes refusées, le niveau 1 **perdu** par celui qui pose 2 Archers puis attend (pose libre, refus, x2, défaite,
  petite récompense), puis gagné avec toutes ses tours posées et améliorées (victoire, récompense, XP), « Niveau
  suivant » dans la même zone, abandon, « Rejouer », boutique à prix fixes, camp (emplacements, absence d'une heure
  puis d'une semaine), ordre de la barre rapide, flèches enflammées débloquées par l'entraînement ;
- **le 2e territoire** : le niveau 11 fermé tant que le niveau 10 n'est pas réussi, la carte du col construite
  (terre rousse, rochers), ses 12 emplacements, une capture en plein combat (`levels_territoire2`), les récompenses
  (280, 600 au mini-boss, 1 200 au boss), le retour à la carte de la vallée ;
- **les territoires 3 à 10** : les cartes de la forêt (un vrai bois), du glacier (neige), du désert (sable, cactus,
  aucun arbre), de la nécropole (pierres tombales), de la citadelle (pierre), du volcan (basalte, lave), des marais
  (boue, bois épais) et du repaire du dragon (lave, arbres calcinés) construites, leurs 12 emplacements, une capture
  de chacune en plein combat (`levels_territoire3` à `levels_territoire10`), le dragon du dernier niveau (6 000
  pièces, plus de niveau suivant).

**Côté client** (avec la vraie interface : l'attribut `TestAction` des écrans « Levels » et « LevelHud » lance les
mêmes fonctions que les boutons, et un appui sur le terrain passe par le vrai chemin : point de l'écran, rayon de la
caméra, sol) :

- plus aucun écran de l'ancien jeu, la place vue d'en haut (`levels_place`), pièces de niveau et bouton « SON » à
  côté du bouton « ⚔ NIVEAUX », cibles de paille sur la parcelle, son des flèches, onglet Entraînement et évolutions
  (`levels_camp_parcelle`, `levels_camp_evolutions`) ;
- fenêtre du camp et ses 4 onglets (`levels_camp_niveaux`, `levels_camp_boutique`, `levels_camp_entrainement`,
  `levels_camp_tours`), les 100 niveaux en 10 territoires dans une page qui défile (`levels_camp_dernier_territoire`) ;
- niveau 1 : vue d'en haut qui remplit l'écran, deux tours dans la barre, Archer offert qui tue en moins de 10 s,
  « + », son du combat, « +6 » doré de l'or gagné, pose près d'un « + », **bouton « ANNULER » de la tour en main**
  (`levels_annuler`), menu de la tour, amélioration, pose libre, zoom et déplacement de la vue, trois inclinaisons
  de la caméra (`levels_vue_normale`, `levels_vue_70`, `levels_vue_90`), refus sur le chemin, conseil « ne garde pas
  ton or », x2 ;
- **défaite de celui qui pose 4 Archers puis attend** (`levels_defaite`), « Réessayer », **victoire en posant et en
  améliorant sans arrêt** (`levels_fin_de_niveau`, `levels_victoire`), « Niveau suivant », abandon en deux appuis,
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
- niveau 1 : « POSE-LA ICI », « TOUCHE CETTE TOUR », « AMÉLIORE » (`tutorial_pose`, `tutorial_tour`,
  `tutorial_ameliore`), puis le scénario suit la flèche jusqu'à la fin : **le niveau doit être gagné** ; à chaque
  pas, la flèche doit être à côté de ce qu'elle montre, dans l'écran, sans recouvrir « Vendre » ;
- victoire : « CONTINUE » (`tutorial_victoire`) ; niveau 2 : plus de flèche ; dès que le joueur peut acheter une
  tour : « NOUVELLE TOUR ! » sur « Retour au camp », l'onglet Boutique, « ACHÈTE-LA » (`tutorial_fin_niveau_boutique`,
  `tutorial_boutique`) ; l'achat termine le tuto ; les 6 étapes des statistiques des nouveaux joueurs ;
- « Passer le tuto » : un appui sur ordinateur, deux sur téléphone (`tutorial_tel_passer`) ;
- à la taille d'un téléphone : la flèche et ses mots restent dans l'écran (`tutorial_tel_*`).

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
de victoire, le camp avec trois tours évoluées, la boutique, les niveaux) et prend les captures `out\page_<nom>.png`.
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

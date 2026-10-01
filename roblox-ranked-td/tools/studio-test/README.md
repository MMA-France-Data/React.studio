# Tests automatiques dans Roblox Studio

Ces scripts ouvrent le jeu dans Studio, lancent Play tout seuls, jouent un scénario de test, prennent
des captures d'écran et récupèrent la fenêtre Sortie. Ils ne servent qu'au développement : rien ici
n'est dans la place construite par `default.project.json`, donc rien n'est publié avec le jeu.

Il faut Windows, Roblox Studio, [Rojo](https://rojo.space) et [Node.js](https://nodejs.org).

## Lancer un test

Depuis le dossier `roblox-ranked-td`, Studio fermé :

```bat
powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1
powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Place match
powershell -ExecutionPolicy Bypass -File tools\studio-test\phone.ps1
```

**Ne touche pas à la fenêtre de Studio pendant un test** (ni clic, ni agrandissement) : un clic ferme une fenêtre du
jeu ou sélectionne un emplacement, et des vérifications échouent sans raison.

- `phone.ps1` : **le jeu à la taille d'un téléphone** (environ 4 minutes). Les autres tests ne font que des calculs
  avec de fausses tailles ; celui-ci réduit vraiment la fenêtre de Studio jusqu'à ce que l'écran du jeu fasse la
  taille voulue (706 x 300 = le téléphone du propriétaire, puis 750 x 332, 568 x 262 et 645 x 268).
  **D'abord l'arrivée d'un vrai nouveau joueur** : dans cette place de test seulement, le tuto démarre tout seul
  comme dans le jeu publié (objet `__AutoTestNewPlayer` ajouté par `mkproj.cjs`, lu par `TutorialUI.luau` ; dans les
  autres tests il ne démarre jamais seul), et le joueur reçoit la **parcelle 2** au lieu de la 1 (objet
  `__AutoTestPlot`, lu par `Hub/Plots.luau` dans Studio seulement), comme le 2e joueur arrivé sur un serveur. Le
  scénario vérifie qu'il est guidé vers SA parcelle : il y apparaît, la flèche du tuto et les « + » y sont, son Archer
  s'y pose (rien sur la parcelle 1), et les invites de l'autel et de la forge de la parcelle 1 sont éteintes pour lui.
  Tout le reste du test « téléphone » se fait donc sur la parcelle 2 (le test `hub` reste sur la 1).
  Le scénario suit ensuite la **grosse flèche du tuto** du début à la fin, à la taille du téléphone, avec une capture
  à chaque moment (`phone_a_newplayer*.png`) : le tuto commence tout de suite par « TUTO 1/4 • POSE UNE TOUR » (ni
  zone classée, ni écran d'accueil), son panneau est en bas de l'écran, la flèche montre un « + » (`newplayer`) ;
  l'autel ouvert trop tôt : le panneau se cache et la flèche montre son X (`newplayer_altar`) ; le « + » touché : la
  carte de l'Archer (`newplayer_cards`) ; l'Archer posé : « Améliorer » (`newplayer_upgrade`) ; la tour améliorée :
  le X du panneau des tours resté ouvert (`newplayer_close`), puis l'icône de l'autel, contre le bord droit
  (`newplayer_altar_icon`), puis x1 (`newplayer_spin`) ; le lancer : plus de flèche pendant que le rouleau tourne,
  puis le X de l'autel (`newplayer_result`), l'icône de la forge (`newplayer_forge_icon`) et le mot de la fin
  (`newplayer_end`). Côté serveur : le **défilé d'accueil** (`IdleConfig.NEW_PLAYER_PARADE` ; dans les places de test,
  il n'existe que dans celle-ci) : une dizaine d'ennemis déjà en marche sur tout le chemin à l'arrivée, aucune vague
  ratée avant la première tour, premier ennemi tué moins de 2 s après la pose (StudioDebug « Progress » : `kills`,
  `parade`), défilé fini et vraie vague 1 lancée ; puis le tuto est fini (« Done » à l'étape 4/4) et l'entonnoir des
  statistiques a ses 5 étapes dans l'ordre (`Hub/Funnel.luau`). Puis un 2e tuto pour « Passer » : un appui ne passe rien
  (« Confirmer ? »), deux appuis passent le tuto (attribut de test `TestSkipTap` de l'écran du tuto : un plugin ne
  peut pas toucher l'écran).
  Ensuite le serveur de test prépare la parcelle d'un joueur avancé et le scénario ouvre chaque
  fenêtre (écran de jeu : rien au milieu de la vue, icônes de l'autel et de la forge et bouton Renaissance contre le
  bord droit, Boutique en haut à gauche ; bouton « ▲ » qui les masque et les remet ;
  tuto ; cartes des tours page par page, fiche d'une tour, « Détails & effets », emplacement à acheter, autel,
  forge, boutique, défis, renaissance), vérifie que rien ne sort de l'écran ni ne se chevauche, et prend une
  capture (`out\phone_<taille>_<nom>.png`). Scénarios : `PhoneServer.luau` (attend la fin du tuto du nouveau joueur,
  puis parcelle de joueur avancé) et `PhoneClient.luau`. Les dispositions « téléphone » ne dépendent que de la taille de l'écran
  (`UI.touchLayout`), jamais de « écran tactile » : c'est ce qui permet de les voir dans Studio.

- `hub` (par défaut) : map principale. Le scénario achète des emplacements dans le désordre (prix,
  cadenas, refus), pose les 8 tours, les améliore, pose des bonus,
  puis vérifie la renaissance (vagues 10, 15, 50 et 100) et écrit `[PASS]` / `[FAIL]`.
  Forge runique : 2 runes par tour qui se cumulent (x10 puis x20 dégâts + x2 vitesse sur l'Archer, stats exactes,
  une rune de dégâts garde la rune de vitesse et inversement), runes tirables emplacement par emplacement (x20
  dégâts partout : seule x2 vitesse reste ; les deux partout : forge bloquée), anciennes sauvegardes (1 rune par
  tour -> emplacement de sa sorte). Le scénario client vérifie que le HUD de la parcelle n'a plus de panneau de
  vague (la vague est sur le tableau « CHRONIQUES DU FIEF ») mais garde le compteur de pièces.
  Contrôles : un seul à la fois par ennemi, et **fatigue** des contrôles courts : le Mage foudroie le même ennemi
  à chaque image pendant 4 s (jamais prolongé, ralenti au plus durée / (durée + immunité) du temps), une 2e pierre
  du Trébuchet blesse sans étourdir pendant l'immunité ; puis un rocher de la Catapulte **suit sa cible**, un
  cavalier arrêté net juste après le tir (`debugFreeze`) : les dégâts tombent sur lui.
  À la fin, les **défis classés** : progression comptée par le même code que le serveur de match, règle des
  3 minutes, même adversaire 2 fois par jour au plus, bot jamais compté, récompense exacte donnée une seule fois,
  lancers offerts de l'autel et de la forge sans hausse des prix, nouveau jour et nouvelle semaine (horloge des
  défis décalée), anciennes sauvegardes. Le scénario client ouvre la fenêtre des défis (capture
  `challenges_panel`) et vérifie qu'elle ne couvre ni le chat ni la liste des joueurs, si la vue du jeu fait au
  moins 1 000 px de large (plus étroite, comme sur un téléphone, la fenêtre est réduite, à droite de la colonne de
  gauche). **Forge sans achat en Robux** (lancer Robux retiré le 01/10/2026) : forge ouverte, pas de bouton Robux,
  aucun texte de la fenêtre ne parle de Robux, bouton des pièces sur toute la largeur. Les chances affichées par la
  forge font 100 % tout juste, et `MachineUI.formatChance` écrit celles de
  l'autel comme avant (« 80 % », « 23.5 % »). **Téléphones** (`UI.windowScale` / `UI.fitWindow`, `UI.leftColumnSlot`) : l'autel, la forge, la
  renaissance, les défis, la boutique, « Pendant ton absence » et « MATCH TROUVÉ ! » sont entiers sur l'écran du test,
  à leur taille d'ordinateur, puis, avec de fausses tailles de téléphone en paysage (844 x 390 et 667 x 375, moins la
  barre du haut), la fenêtre réduite et tous ses boutons restent dans l'écran ; la colonne de gauche aussi (et, avec
  `-Place match`, la fiche de tour du match : `MatchUI.cardScale`).
  Tout à la fin, le **classé** (inscription dans le cercle, match à ACCEPTER ; file en mémoire dans Studio, jamais
  de téléportation). Le scénario serveur donne la main au client (attribut `AutoTestRanked` de ReplicatedStorage =
  « Client ») : le client déplace son personnage hors du cercle / dans le cercle (le bouton « ⚔ S'INSCRIRE AU
  CLASSÉ » n'apparaît que dedans, sans couvrir la colonne de gauche, le chat ni le panneau des tours : capture
  `ranked_signup`), s'inscrit par le vrai remote, vérifie « Recherche d'un adversaire… » + ANNULER (capture `ranked_searching`,
  statut au-dessus du panneau des tours quand il est ouvert), repart, puis le serveur fait s'inscrire un
  adversaire factice : fenêtre « MATCH TROUVÉ ! » (nom, barre, ACCEPTER / REFUSER : capture `ranked_accept`), le
  client ACCEPTE, voit « En attente de l'adversaire… », l'adversaire accepte et tout se ferme. Ensuite, le serveur
  seul : inscription refusée hors du cercle, 2e inscription et anti-spam refusés, ANNULER, les deux acceptent (le
  match partirait avec les 2 joueurs), je refuse et temps écoulé (je sors, l'adversaire retourne dans la file avec
  son attente), l'adversaire refuse / part / ne répond pas (je retourne dans la file, chrono gardé), ANNULER
  pendant le match proposé, réservation ratée et créateur du match disparu (retour dans la file), l'adversaire
  qui quitte le jeu après avoir accepté (retour dans la file), priorité à ceux qui attendent depuis longtemps, et
  personne ne reste bloqué.
  Juste avant le tuto, la **limite de tours identiques** (`IdleTowers.MAX_COPIES` : 5 / 4 / 3 / 2 selon la
  rareté, fonction `testTowerLimit` du serveur) : la tour de trop refusée avec son message et sans rien dépenser,
  la vente qui libère une place, les remplacements, une vieille sauvegarde au-dessus de la limite gardée entière,
  les textes « x/limite » ; la parcelle est remise comme avant à la fin. Puis la **liste des joueurs** et le
  **classement solo** (fonction `testLeaderstatsAndSolo`) : seulement les colonnes « DPS » et « Money », DPS = le même
  texte que « DPS TOTAL » du tableau du fief et que la formule refaite avec les données (tour posée, 3 améliorations,
  vitesse x2 qui ne change PAS le DPS, vente), Money = les pièces ; puis le classement solo (DataStores en mémoire) : envoi du record et du DPS,
  un seul envoi par minute (horloge avancée par StudioDebug « Solo »), jamais plus bas, et 12 faux joueurs : les 2
  panneaux de la place montrent le bon top 10, recto verso (DPS énormes et « MAX » réaffichés comme les vrais nombres),
  puis faux joueurs retirés.
  **Classé ouvert, puis fermé** : pendant tous les tests d'avant, le classé est ouvert (le scénario serveur l'ouvre dès
  le début : StudioDebug « RankedOpen », true, attribut Studio seulement, `src/shared/RankedGate.luau`), même avec
  `Config.RANKED_OPEN = false`. Les autres places de test (match, tournage) gardent le réglage du jeu. Juste avant le tuto,
  le **classé fermé** (fonction `testRankedClosed` du serveur, StudioDebug « RankedOpen », false) : inscription refusée
  même dans le cercle, la boucle du leader ne travaille plus, tableau du classement (2 faces, sans lignes) et plaques
  « BIENTÔT DISPONIBLE », défi classé terminé mais « Récupérer » refusé ; puis plus aucun objet aléatoire payant (pas
  de produit Robux en vente, plus d'attribut `PaidRandomRestricted`). Il reste fermé jusqu'à la fin : au début de son test du tuto, le client vérifie
  la carte de rang (« CLASSÉ 1v1 », sans MMR), le bouton « ⚔ DÉFIS » caché, dans le cercle le panneau « BIENTÔT
  DISPONIBLE » à la place du bouton (capture `ranked_soon`), aucune fenêtre « MATCH TROUVÉ ! » même avec l'état
  « Pending » (chez lui seulement), puis envoie « Join » et « Accept » par le vrai remote : le serveur les refuse
  (`testRankedClosedRemote`, après le tuto). Le tuto se fait donc classé fermé, comme dans le jeu publié : 4 étapes,
  sans zone classée ni écran d'accueil (« TUTO 1/4 • POSE UNE TOUR »).
  Après le classé, le **tuto des nouveaux joueurs** (`TutorialUI.luau`, `Hub/Tutorial.luau`) : il ne s'affiche
  jamais tout seul pendant les tests. Le serveur vérifie le drapeau d'un nouveau joueur, les coûts (tour + amélioration
  + autel x1 = 33 sur les 50 pièces de départ), les anciennes sauvegardes (qui a déjà joué ne le voit pas) et
  l'entonnoir des statistiques (`Hub/Funnel.luau` : étape d'après les données, joueur suivi depuis son arrivée), rend
  la parcelle « nouveau joueur » (aucune tour, record 1, aucun lancer, 50 pièces) et donne la main au client
  (attribut `AutoTestTutorial` = « Client »). Le client vérifie d'abord les fonctions pures (place du panneau, côté
  de la flèche avec de faux boutons), puis relance le tuto 4 fois (« Replay », Studio seulement) :
  1. « Passer » tout de suite, par son bouton (attribut de test `TestSkipTap`) : le serveur note « passé à l'étape 1 »
     dans l'entonnoir ;
  2. tout le tuto, en suivant **la flèche** (écran `PlayerGui.TutorialPointer` : attributs `Target` = nom du bouton
     montré ou « World », `Caption` = ses mots, et la place de la flèche à côté de sa cible) : le « + » d'un
     emplacement (caméra vers lui : juste au-dessus ; caméra tournée ailleurs : au bord de l'écran ; capture
     `tutorial_step1`), la carte de l'Archer (`tutorial_card`), « Améliorer », la tour, le bouton de l'autel à
     gauche (`tutorial_altar`), x1, rien pendant que le rouleau tourne, le X de l'autel, le bouton de la forge, le
     mot de la fin. Actions vraies : tour posée et améliorée (remote `PlotAction`), lancer x1 (`MachineAction`),
     fenêtres ouvertes comme par leurs boutons. Au passage : le tuto se cache sous le panneau des tours ouvert
     par-dessus (comme sur un téléphone), et une mort (le rayon repart du nouveau personnage). Le serveur vérifie le
     drapeau `tutorialDone` (« Done » à l'étape 4/4) et les 3 achats payés avec les 50 pièces ;
  3. les étapes déjà faites passent toutes seules jusqu'à la forge ; autel ouvert par-dessus : ni « Passer » ni
     « Terminer », la flèche montre son X ; puis « Passer » ;
  4. classé ouvert chez le client seulement (attribut `StudioRankedOpen` changé chez lui) : les 6 étapes reviennent,
     la zone classée en premier (« TUTO 1/6 • LA ZONE CLASSÉE », flèche et rayon vers le cercle), puis « 2/6 • TA
     PARCELLE » avec le texte du retour, « ✓ BRAVO ! » sur sa parcelle, et « Passer ».
  **Sons** (côté client, en parallèle des autres tests) : le bouton « SON » ne couvre pas la carte de rang,
  chaque son de `src/shared/Sounds.luau` se charge (`[PASS]` / `[FAIL]` par son, avec sa durée), 200 tirs à la
  même image ne font pas jouer plus que `Sounds.MAX_COMBAT_SOUNDS` sons (la mort d'un boss, son « priority »,
  passe exprès au-delà : pas dans ce test), et 200 flèches un seul (à tout petit volume).
  **Parcelles des autres** (en parallèle des autres tests) : côté serveur, la règle « qui reçoit les ennemis et
  les tirs d'une parcelle » (`Hub/PlotInterest.luau`, vraie fonction avec de fausses positions) : le propriétaire
  loin la reçoit toujours, un voisin chez lui (même dans le coin le plus proche, devant son autel ou sa forge) non,
  il la reçoit en marchant dessus, hystérésis au bord (22 / 28 studs), « Clear » en partant ; puis le vrai joueur
  (StudioDebug « Interest », sa position compte ailleurs sans bouger son personnage) : il reçoit une parcelle libre
  en y allant et un « Clear » part quand il rentre. Tout à la fin (après le tuto), le **vrai personnage** : posé par
  le serveur sur une parcelle libre, il la reçoit ; renvoyé chez lui, un « Clear » part et il ne reçoit plus que la
  sienne. Côté client : seules les invites de SON autel et de SA forge
  sont allumées, celles des 5 autres parcelles éteintes, et les prix de leurs cadenas cachés (`PlotAccess.luau`).
  **Version anglaise** (tout à la fin, après le tuto : les autres vérifications lisent les textes français ; le test
  démarre toujours en français, quelle que soit la langue de Studio) : le joueur passe en anglais en direct (son
  attribut `Lang`), puis l'écran, la fiche d'une tour et les cartes (attribut Studio `TestSelectSpot` de PlotUI), un
  cadenas, l'autel, la forge, la boutique, les défis, la renaissance, « Pendant ton absence », le tuto (« Replay » puis
  « Passer ») et le classé (d'abord « BIENTÔT DISPONIBLE » dans le cercle, classé fermé, puis, classé ouvert chez le
  client seulement : « S'INSCRIRE », recherche, « MATCH TROUVÉ ! », attente ; attributs changés chez le client
  seulement, remis après) : captures `english_*`. Chaque texte qui a encore l'air français (lettre accentuée ou mot
  français courant, sans les noms des joueurs ni les nombres) est écrit `[CTEST] non traduit : …` : textes de l'écran,
  panneaux du monde et invites, et ceux que le traducteur n'a pas trouvés (BindableFunction Studio
  `AutoTranslateStudio`, `src/client/AutoTranslate.luau`). Puis `[PASS]` / `[FAIL]` « version anglaise : N textes
  encore en français » (FAIL tant qu'il en reste), et le retour au français en direct (chaque texte traduit revient).
- `match` : match ranked en solo (le bot joue l'autre terrain après 10 s). Le joueur de test ne pose
  aucune tour. Le scénario vérifie qu'il n'y a plus d'envois (ni remote `SendEnemies`, ni module
  `Sends`, ni panneau d'envoi dans le HUD), que l'or du joueur vaut 500 + 100 x vague, que les deux
  terrains reçoivent exactement les mêmes ennemis pendant 5 vagues, que le bot pose des tours
  et que les chiffres des défis classés de chaque terrain (tours posées, types, améliorations) sont justes
  (~2 min 10). Avec la durée par défaut (240 s ; `-Seconds 260 -Timeout 420` pour plus de marge), il vérifie aussi la fin : la base du joueur
  tombe vers la vague 8 (~3 min 15), le bot gagne, et ce match contre le bot ne compte pas pour les défis.
  À la fin du scénario client (~40 s), la version anglaise du HUD du match (capture `english_match`, mêmes lignes
  « non traduit » et `[PASS]` / `[FAIL]` que sur la map principale).
- Résultats dans `tools\studio-test\out\` : `studio-output.log` (la Sortie du serveur et du client)
  et les captures `.png`. À la fin, le script affiche le nombre d'erreurs.
- Si Studio est déjà ouvert, le script s'arrête pour ne pas te faire perdre ton travail
  (`-CloseStudio` pour le fermer quand même). Il referme le Studio qu'il a ouvert (`-KeepOpen` pour le garder).

Vérification rapide sans Studio (syntaxe de tous les scripts + construction de la place) :

```bat
powershell -ExecutionPolicy Bypass -File tools\studio-test\check.ps1
```

## Comment ça marche

| Fichier | Rôle |
|---|---|
| `run.ps1` | Construit la place de test, installe le plugin, ouvre Studio, prend les captures, affiche la Sortie |
| `mkproj.cjs` | Crée `out\<hub\|match>.project.json` : `default.project.json` + le marqueur `__AutoPlayTest` + les scénarios |
| `AutoPlayTest.lua` | Plugin Studio, copié dans `%LOCALAPPDATA%\Roblox\Plugins` par `run.ps1` |
| `logserver.cjs` | Petit serveur sur `127.0.0.1:34999` (ce PC uniquement) qui écrit la Sortie dans `out\studio-output.log` |
| `shot.ps1` | Capture de la fenêtre de Studio |
| `scenarios\HubServer.luau` | Scénario côté serveur de la map principale (pilote la partie avec `ServerStorage.StudioDebug`) |
| `scenarios\MatchServer.luau` | Scénario côté serveur du match (`-Place match`) : lit `ReplicatedStorage.MatchState` et compte les ennemis de chaque terrain |
| `scenarios\Client.luau` | Scénario côté client (caméra, fenêtres, HUD du match, captures `SHOT:nom`). À la fin, sur la map principale : un modèle « Swarm » posé dans `ReplicatedStorage.EnemyModels` pendant la partie remplace les blocs des écuyers (module, galerie, parcelles), sans ses scripts et avec ses pièces soudées restées ensemble après la mise à l'échelle, et les autres types gardent leurs blocs |

**Le plugin ne fait rien dans tes places** : sa première vérification est
`if not marker then return end`. Il ne s'active que si la place contient `ReplicatedStorage.__AutoPlayTest`,
un objet que seul `mkproj.cjs` ajoute aux places de test. Pour le désinstaller, supprime
`%LOCALAPPDATA%\Roblox\Plugins\AutoPlayTest.lua`.

`ServerStorage.StudioDebug` (dans `src/server/Hub/init.luau`, et une petite version pour le serveur de match
dans `src/server/Match/init.luau`) n'est créé que dans Studio (`RunService:IsStudio()`) : il n'existe pas dans le
jeu publié. Ses commandes « Ranked » (adversaires factices, temps écoulé...) sont dans `Matchmaking.debug`
(`src/server/Matchmaking.luau`).

Le test de la map principale dure maintenant ~6 min (Play de 420 s par défaut, 240 s pour `-Place match` ;
`-Seconds` pour changer, le délai max suit : `-Seconds` + 150 s) : les tests du classé attendent la fin des autres
tests du client (dont une photo par vrai modèle d'ennemi : ~3,5 s de plus pour chaque modèle ajouté dans
`assets/EnemyModels`), puis le classé fermé (~15 s) et ceux du tuto (~60 s : chaque étape reste affichée le temps de lire son texte) la fin
du classé, puis la version anglaise (~40 s, finie vers 6 min 10 s de Play). S'il manque les lignes du tuto ou de la
version anglaise à la fin de la Sortie, le Play s'est arrêté trop tôt : relance avec un `-Seconds` plus grand.

## Mode tournage (images et vidéos pour la page Roblox)

```bat
powershell -ExecutionPolicy Bypass -File tools\studio-test\tournage.ps1
```

Même machinerie que les tests, avec d'autres scénarios (`scenarios\TournageServer.luau` et
`scenarios\TournageClient.luau`, choisis par `mkproj.cjs tournage`) : les vraies mécaniques du jeu (22 tours, vraies
vagues, vrais effets), seule la caméra est pilotée et l'interface cachée (sauf l'image « interface »). OBS (déjà
installé sur ce PC) filme la vue 3D de Studio : `obs.cjs` le pilote par sa télécommande WebSocket (activée le
30/09/2026 avec l'accord du propriétaire ; mot de passe lu dans la configuration d'OBS, jamais recopié). Studio et
OBS doivent être fermés : OBS est lancé directement sur son profil « Tower 22 » (1920 x 1080, 60 images/s, sans
compte de stream) et sa collection de scènes « Tower 22 » (fenêtre de Studio + son de Studio, jamais le micro),
puis refermé ; le profil et les scènes habituels du propriétaire sont remis à la fin (`user.ini`). Ne jamais
changer de profil pendant qu'OBS tourne : passer du profil du propriétaire (chat Twitch) à « Tower 22 » l'a fait
planter.
- Le scénario client affiche d'abord un écran magenta (« CALIBRATE ») : OBS y repère la vue 3D dans la fenêtre de
  Studio et la recadre en 16:9 plein cadre.
- Marqueurs (envoyés tout de suite par le serveur à `logserver.cjs`, ~0,3 s jusqu'à OBS) : `REC:START` /
  `REC:STOP:nom` (vidéo `out\tournage\nom.mp4`, durée affichée), `REC:PAUSE` / `REC:RESUME` (coupes nettes),
  `IMG:nom` (image 1920 x 1080 `out\tournage\nom.png`), `CROP:left` / `CROP:center` (image prise à gauche de la vue
  3D, avec la colonne de boutons : la vue de Studio est plus large que 16:9).
- Règles de Roblox pour les vidéos : **30 s au plus**, moins de 375 Mo, textes et son **en anglais** (le tournage
  met le jeu en anglais), et un compte vérifié de 13 ans et plus pour les envoyer.
- Tournage actuel (demande du propriétaire : plans courts et compilation) : 7 plans de 3 à 3,5 s (parcelle, horde
  d'orcs vague 81, Titan du givre vague 40, dragon vague 100, carte vue du ciel) joués deux fois : une
  compilation d'un seul fichier (`compilation.mp4`, ~28 s, en pause entre les plans), puis un fichier par plan
  (`rush_1_parcelle.mp4`...) avec une image au milieu de chacun, et une image avec l'interface. Le classé y est
  fermé, comme dans le jeu publié. Les vidéos et images finies sont copiées à la main dans `Vidéos\Tower 22`.
- Studio doit rester au premier plan (caché, il ne dessine plus sa vue 3D) : ne pas toucher au PC pendant le
  tournage (~5 min) ; l'écran reste allumé.
- `-SansObs` : sans OBS, les images sont de simples captures de la fenêtre de Studio (pour régler les plans).
- Couper des morceaux d'une vidéo, avec le montage intégré à Windows (rien à installer) :
  `powershell -ExecutionPolicy Bypass -File tools\studio-test\couper.ps1 -Entree a.mp4 -Sortie b.mp4 -Garder "0-8,10-19,23-fin"`
  (morceaux gardés, en secondes ; image et son, 1080p 60 images/s).

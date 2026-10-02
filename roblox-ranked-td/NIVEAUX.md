# Les NIVEAUX — prototype de la nouvelle formule

Ce document explique le prototype construit le 02/10/2026 : **ce que c'est, comment l'essayer, ses règles, et ce qui
reste à décider**. Tout ce qui est écrit ici vient de nos discussions (« niveau 1, niveau 2, niveau 3… », gameplay
dynamique, pose libre, boutique à prix fixes, camp d'entraînement, plus aucun hasard).

## En deux mots

- Le jeu actuel (ta parcelle infinie, l'autel, la forge, le classement) **n'est pas touché**. Il tourne exactement
  comme avant, pour tous les joueurs.
- À côté, un nouveau mode : **10 niveaux**. Chaque niveau est une partie de 2 à 3 minutes, vue d'en haut : une longue
  vague de monstres, tu poses tes tours **où tu veux**, tu les améliores avec l'or des monstres, tu protèges ton
  château (10 vies). Mini-boss au niveau 5, boss au niveau 10.
- Gagner donne des **pièces de niveau** 🏅. Elles servent à acheter les autres tours dans une **boutique à prix fixes**
  (aucun tirage au sort) et à améliorer ton **camp d'entraînement**, où tes tours deviennent plus fortes, même quand
  tu n'es pas là.
- Pour l'instant, **toi seul le vois** (bouton « ⚔ NIVEAUX »). Les autres joueurs ne voient rien de nouveau.

## Comment l'essayer

1. Publie le jeu comme d'habitude (« Mettre à jour l'expérience existante… »), ou lance `Play` dans Studio.
2. En haut à gauche, à côté de ton bouton « 🎁 DONNER », clique **« ⚔ NIVEAUX »**.
3. Onglet « Niveaux » : clique **« ▶ JOUER »** sur le niveau 1.
4. Dans le niveau :
   - ton Archer est déjà posé et tire tout seul ;
   - **ordinateur** : clique une tour de la barre du bas (ou touches 1 à 8), un aperçu vert ou rouge suit ta souris
     avec sa portée, clique pour poser. Clique une tour posée pour ouvrir son petit menu (**Améliorer** / **Vendre**).
     Raccourcis : `E` améliorer, `X` vendre, `Q` annuler, `F` vitesse x2, `R` envoyer la suite, clic droit = annuler ;
   - **téléphone** : appuie sur la tour dans la barre, puis sur le terrain ; ou fais-la glisser depuis la barre.
     Appuie sur une tour posée pour son menu ;
   - les **« + »** montrent de bons emplacements, mais tu peux poser ailleurs sur l'herbe ;
   - **zoom** : la vue montre toute la carte. Pour voir de plus près : molette de la souris (puis clic droit
     maintenu ou flèches du clavier pour se déplacer) ; sur téléphone, pince avec deux doigts, puis glisse un doigt ;
   - en haut : le niveau, tes vies ❤, ton or 💰, les monstres qui restent, le bouton **x1 / x2**, et **X** pour
     quitter (deux appuis).
5. À la fin : **Niveau suivant**, **Rejouer**, ou **Retour au camp** (la fenêtre des niveaux se rouvre : boutique,
   entraînement).

Qui voit le mode ? C'est une ligne dans `src/shared/Config.luau` :

```lua
Config.LEVELS_ACCESS = "Owner"   -- "Owner" = toi seul (et toi dans Studio), "All" = tout le monde, "Off" = personne
```

## Les règles

### Un niveau

| | |
|---|---|
| Durée | 2 à 3 minutes (1 min 50 pour le niveau 1, 3 min pour le niveau 10) |
| Vies | 10. Un monstre qui atteint le château en coûte 1 (chevalier lourd : 2, mini-boss : 5, boss : 10) |
| Or de départ | fixe par niveau : 25 au niveau 1 (avec un Archer déjà posé), 45 au niveau 2… 90 au niveau 10 |
| Or gagné | chaque monstre tué donne son or tout de suite (2 pour un fantassin, 40 pour le mini-boss, 100 pour le boss) : un « +2 » doré s'envole au-dessus de lui |
| Ce qu'on garde d'un niveau à l'autre | **rien** : l'or et les tours posées repartent de zéro. On garde ses tours débloquées, ses pièces de niveau et son entraînement |
| Vague | les monstres arrivent en continu, par groupes de plus en plus serrés et de plus en plus résistants |
| « Envoyer la suite » ⏩ | pendant la petite pause entre deux groupes : le groupe suivant arrive tout de suite, contre 5 à 9 pièces d'or |
| Vitesse x2 | bouton x1 / x2, pour tout le monde (réglage `Levels.SPEED_FREE`) |
| Vue | caméra penchée : on voit les tours et les monstres de côté, et la carte remplit l'écran. **Choisie par toi le 02/10/2026** parmi trois (penchée, plus plongeante, pile au-dessus). Réglage : `CAMERA_PITCH_MIN` et `CAMERA_PITCH_MAX`, en haut de `src/client/LevelsUI.luau` |

Les 8 tours sont celles de la parcelle (mêmes dégâts, mêmes portées, mêmes effets), avec leurs prix en or à elles :

| Tour | Prix en or | Maximum par niveau |
|---|---|---|
| Archer du rempart | 20 | 5 |
| Totem de givre | 40 | 3 |
| Mage des tempêtes | 40 | 4 |
| Catapulte | 45 | 4 |
| Baliste lourde | 50 | 3 |
| Sorcier des arcanes | 90 | 3 |
| Trébuchet royal | 100 | 2 |
| Oracle de la foudre | 150 | 2 |

Améliorer une tour : +35 % de dégâts par niveau, jusqu'au niveau 10. Le prix monte à chaque fois (Archer : 15, 22,
32, 46…). Vendre rend 60 % de l'or dépensé.

### Les récompenses (pièces de niveau 🏅)

| Niveau | Première victoire | En le rejouant |
|---|---|---|
| 1 | 80 | 32 |
| 2 | 100 | 40 |
| 3 | 120 | 48 |
| 4 | 140 | 56 |
| 5 (mini-boss) | **300** | 120 |
| 6 | 180 | 72 |
| 7 | 200 | 80 |
| 8 | 220 | 88 |
| 9 | 240 | 96 |
| 10 (boss) | **600** | 240 |

Perdu ou abandonné : une petite part (la moitié de « en le rejouant », multipliée par la part de la vague éliminée).
Lancer un niveau et le quitter tout de suite ne donne donc rien.

### La boutique (prix fixes, aucun hasard)

| Tour | Prix en pièces de niveau |
|---|---|
| Archer du rempart | déjà à toi |
| Totem de givre | 150 |
| Catapulte | 350 |
| Mage des tempêtes | 700 |
| Baliste lourde | 1 200 |
| Sorcier des arcanes | 2 000 |
| Oracle de la foudre | 3 500 |
| Trébuchet royal | 6 000 |

### Le camp d'entraînement

- Chaque tour a de l'**XP d'entraînement**, qui donne un niveau d'entraînement de 0 à 6 (20, 60, 140, 300, 600 et
  1 200 XP).
- Chaque niveau d'entraînement : **+5 % de dégâts** dans les niveaux, et une amélioration aux niveaux 2, 4 et 6.
  Exemples : Archer niveau 2 = **flèches enflammées**, niveau 4 = +3 de portée, niveau 6 = +20 % de vitesse ;
  Totem niveau 2 = les monstres ralentis prennent plus de dégâts ; Baliste niveau 2 = carreau perçant.
- L'XP vient de deux endroits :
  - **les emplacements du camp** : la tour qu'on y met gagne 1 XP par minute, **même quand tu es parti** (12 h au
    plus d'un coup). Un emplacement s'améliore (120, 300, 700, 1 500 pièces : jusqu'à 4,5 XP par minute) et on en
    ouvre d'autres (400 puis 1 500 pièces, 3 au plus) ;
  - **jouer** : chaque type de tour posé dans un niveau gagne 8 XP si tu gagnes (moins si tu perds).
- Attendre n'est donc jamais la seule façon d'avancer.

### La difficulté, réglée avec un joueur simulé

`tools/levels` fait jouer les 10 niveaux par un joueur simulé, avec le vrai moteur du jeu, pour plusieurs profils :

| Niveau | Ce qu'il faut à peu près |
|---|---|
| 1 | sans rien faire, on gagne de justesse (6 vies sur 10) ; dès qu'on pose une 2e tour, on ne perd plus une vie |
| 2 à 4 | l'Archer seul suffit, à condition d'en poser plusieurs et de les améliorer |
| 5 (mini-boss) | l'Archer seul rate de peu : il faut le Totem, ou un Archer entraîné |
| 6 | la Catapulte, ou l'entraînement |
| 7 | trois tours et de l'entraînement (niveau 2) |
| 8 et 9 | plus de tours (Mage, Baliste), entraînement 2 à 3 |
| 10 (boss) | presque toutes les tours et un bon entraînement |

C'est un premier réglage : à ajuster quand tu y auras joué.

## Ce qui reste à décider (par toi)

1. **Le mode infini** : on le garde à côté, ou la parcelle devient seulement le camp d'entraînement ? Et que deviennent
   les progrès des joueurs actuels (vagues, tours, runes) ?
2. **Les passes Robux** : « Ramassage auto » n'a plus de sens dans les niveaux (l'or tombe tout seul). Le x2 est
   gratuit dans les niveaux pour l'instant (`Levels.SPEED_FREE`) : faut-il le réserver au pass ?
3. **L'autel et la forge** : tu as dit « on les supprime ». Dans le prototype ils n'existent pas dans les niveaux ;
   ils sont toujours sur la parcelle tant que le mode infini est là.
4. **Les améliorations d'entraînement** de chaque tour (3 par tour) : j'ai mis des idées simples, à revoir ensemble.
5. **La suite des niveaux** : 11 à 20 avec une autre famille de monstres et une autre carte (le code est prêt pour
   plusieurs cartes : `Levels.MAPS`).
6. **Ouvrir à tout le monde** : il faudra d'abord la traduction anglaise des nouveaux écrans, et un petit tuto.

## Technique (pour s'y retrouver)

- **Où ça se passe** : dans le même serveur que la map principale, sans téléportation ni écran de chargement.
  Six zones de combat (une par parcelle) sont réservées très loin de la place (`workspace.Arenas`). La carte d'un
  niveau n'est construite que pendant qu'un joueur y joue, puis effacée.
- **Le personnage** reste sur la place. Seule la caméra part regarder la zone de combat ; les commandes du
  personnage et les écrans de la parcelle sont coupés pendant le niveau, puis remis.
- **Le combat** est celui des parcelles : `LevelGame.luau` hérite de `PlotGame.luau` (visée, projectiles, zones,
  ralentissements…). Les monstres et les tirs voyagent dans les mêmes paquets, envoyés **au joueur du niveau
  seulement**. L'affichage est le même code que pour une parcelle (`PlotRenderer.luau`).
- **Le serveur décide de tout** (or, pose, récompenses, achats). Le client envoie des demandes (`LevelAction`).

| Fichier | Rôle |
|---|---|
| `src/shared/Levels.luau` | toutes les règles et tous les chiffres (niveaux, monstres, prix, boutique, entraînement) |
| `src/server/Hub/LevelGame.luau` | un niveau en cours (le combat) |
| `src/server/Hub/LevelArena.luau` | les zones de combat et leur carte |
| `src/server/Hub/LevelsService.luau` | accès, lancement, récompenses, boutique, camp, sauvegarde |
| `src/client/LevelsUI.luau` | le bouton, la fenêtre du camp, l'écran d'un niveau |
| `src/client/PlotRenderer.luau` | affiche aussi les zones de combat |
| `tools/levels/` | joueur simulé et vérifications hors Studio |
| `tools/studio-test/scenarios/Levels*.luau` | test automatique dans Studio |

Sauvegarde : `data.levels` dans les données du joueur (niveau le plus haut réussi, pièces de niveau, tours achetées,
XP, emplacements du camp). Une ancienne sauvegarde sans ce champ donne simplement un nouveau joueur des niveaux.

### Vérifier

```bash
powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1 -Tests
```

```bash
powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1
```

```bash
powershell -ExecutionPolicy Bypass -File tools\studio-test\phone.ps1 -Mode levels
```

- le premier : 150 vérifications des règles, sans Studio (quelques secondes) ;
- le deuxième : le tableau de difficulté des 10 niveaux par le joueur simulé ;
- le troisième : le test complet dans Studio (serveur, puis la vraie interface à la taille normale et à la taille
  d'un téléphone), avec des captures dans `tools/studio-test/out/levels_*.png`.

### Six combats dans le même serveur

C'était le point à valider par des mesures (un serveur = 6 joueurs, donc 6 niveaux possibles en même temps, en plus
des 6 parcelles). Mesuré dans Studio le 02/10/2026, six niveaux 10 (le plus chargé) joués en même temps pendant
90 secondes de jeu :

| Cas | Temps moyen par image | 99 % des images | Monstres en même temps |
|---|---|---|---|
| 12 tours par joueur (combat normal) | 0,08 ms | moins de 0,25 ms | jusqu'à 186 |
| 3 tours par joueur (carte pleine de monstres) | 0,11 ms | moins de 0,8 ms | jusqu'à 330 |

Une image du serveur dure 16,7 ms : les six combats ensemble en prennent **moins de 1 %**. Rester dans le même
serveur tient donc largement. Les monstres et les tirs d'un niveau ne sont envoyés qu'au joueur qui y joue.

La mesure se refait avec le test Studio (voir « Vérifier »), ou dans la barre de commande de Studio (vue Serveur) :

```lua
local m = game.ServerStorage.StudioDebug:Invoke(game.Players:GetPlayers()[1], "Levels", "Bench", 6, 90, 12)
print(m.averageMs, m.p99Ms, m.worstMs, m.enemiesPeak)
```

## Limites connues du prototype

- Une seule carte (« La vallée du Roi carmin ») pour les 10 niveaux.
- Les nouveaux écrans sont en français seulement.
- Pas encore de tuto dédié : au tout premier niveau, un conseil en bas de l'écran guide la pose puis l'amélioration.
- Les autres joueurs ne voient pas ton combat (ils restent sur la place).
- Pendant un niveau, ta parcelle continue de tourner toute seule sur la place.

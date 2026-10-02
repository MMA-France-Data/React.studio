# Les NIVEAUX — prototype de la nouvelle formule

Ce document explique le prototype construit le 02/10/2026 : **ce que c'est, comment l'essayer, ses règles, et ce qui
reste à décider**. Tout ce qui est écrit ici vient de nos discussions (« niveau 1, niveau 2, niveau 3… », gameplay
dynamique, pose libre, boutique à prix fixes, camp d'entraînement, plus aucun hasard).

**Deuxième version, après ton premier essai** (« beaucoup trop facile », « ils sortent par vagues, je veux que ce soit
en continu et de plus en plus dur, que je sois obligé d'être super actif », « commencer avec au moins deux tours »,
« pouvoir annuler quand je clique sur une tour », « si juste 2 Archers gèrent le niveau, je passe mon temps à
attendre ») :

- les monstres sortent en **flot continu**, sans aucune pause, de plus en plus serrés et de plus en plus résistants ;
- **attendre fait perdre** : il faut poser et améliorer sans arrêt, du début à la fin ;
- tu commences avec **deux tours** : l'Archer et la Catapulte ;
- la tour que tu as prise dans la barre devient un bouton rouge **« ANNULER »** ;
- le bouton « envoyer la suite » n'existe plus (il n'y a plus de pause à sauter).

**Réglage après ton deuxième essai** (« ça va, mais le ralentissement du givre est un peu cheaté, et les prix des
prochaines tours doivent être plus hauts, pas forcément les basiques mais les légendaires surtout ») :

- le **Totem de givre ralentit de 40 %** au lieu de 60 % dans les niveaux (sur ta parcelle, rien ne change). Mesuré
  avec le joueur simulé : avant, trois Totems permettaient de battre des monstres 50 à 70 % plus résistants ;
  maintenant 23 à 29 %. Il reste utile, ce n'est plus LA tour qui gagne le niveau. Les niveaux 3 à 10 ont été
  recalculés avec ce Totem plus faible, pour rester faisables ;
- **boutique** : le Totem (150) et le Mage (400) ne bougent pas. La Baliste passe de 900 à 1 200, le Sorcier de 1 600
  à 3 000, et les deux légendaires montent beaucoup : l'Oracle de 3 000 à 8 000, le Trébuchet de 5 000 à 15 000.

## En deux mots

- Le jeu actuel (ta parcelle infinie, l'autel, la forge, le classement) **n'est pas touché**. Il tourne exactement
  comme avant, pour tous les joueurs.
- À côté, un nouveau mode : **10 niveaux**. Chaque niveau est une partie de 2 à 3 minutes, vue d'en haut : un flot
  continu de monstres, de plus en plus forts. Tu poses tes tours **où tu veux** et tu les améliores **sans arrêt**
  avec l'or des monstres (si tu t'arrêtes, tu perds), tu protèges ton château (10 vies). Mini-boss au niveau 5, boss
  au niveau 10.
- Gagner donne des **pièces de niveau** 🏅. Elles servent à acheter les autres tours dans une **boutique à prix fixes**
  (aucun tirage au sort) et à améliorer ton **camp d'entraînement**, où tes tours deviennent plus fortes, même quand
  tu n'es pas là.
- Pour l'instant, **toi seul le vois** (bouton « ⚔ NIVEAUX »). Les autres joueurs ne voient rien de nouveau.

## Comment l'essayer

1. Publie le jeu comme d'habitude (« Mettre à jour l'expérience existante… »), ou lance `Play` dans Studio.
2. En haut à gauche, à côté de ton bouton « 🎁 DONNER », clique **« ⚔ NIVEAUX »**.
3. Onglet « Niveaux » : clique **« ▶ JOUER »** sur le niveau 1.
4. Dans le niveau :
   - tu as deux tours dans la barre du bas : l'**Archer** (une cible, rapide, 20 or) et la **Catapulte** (une zone,
     45 or). Au niveau 1, un Archer est déjà posé et tire tout seul ;
   - **ordinateur** : clique une tour de la barre du bas (ou touches 1 à 8), un aperçu vert ou rouge suit ta souris
     avec sa portée, clique pour poser. Clique une tour posée pour ouvrir son petit menu (**Améliorer** / **Vendre**).
     Raccourcis : `E` améliorer, `X` vendre, `F` vitesse x2 ;
   - **téléphone** : appuie sur la tour dans la barre, puis sur le terrain ; ou fais-la glisser depuis la barre.
     Appuie sur une tour posée pour son menu ;
   - **changer d'avis** : la tour que tu as prise devient rouge et dit **« ANNULER »**. Appuie dessus et rien n'est
     posé (ordinateur : aussi le clic droit, ou la touche `Q`) ;
   - **ne garde pas ton or** : les monstres deviennent plus forts sans arrêt. Si tu gardes de l'or sans rien acheter,
     un conseil te le rappelle en bas de l'écran ;
   - les **« + »** montrent de bons emplacements, mais tu peux poser ailleurs sur l'herbe ;
   - **zoom** : la vue montre toute la carte. Pour voir de plus près : molette de la souris (puis clic droit
     maintenu ou flèches du clavier pour se déplacer) ; sur téléphone, pince avec deux doigts, puis glisse un doigt ;
   - en haut : le niveau, tes vies ❤, ton or 💰, les monstres qui restent (la barre passe du vert au rouge : le
     niveau devient de plus en plus dur), le bouton **x1 / x2**, et **X** pour quitter (deux appuis).
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
| Durée | 2 à 3 minutes (1 min 55 pour le niveau 1, 3 min 15 pour le niveau 10) |
| Vies | 10. Un monstre qui atteint le château en coûte 1 (chevalier lourd : 2, mini-boss : 5, boss : 10) |
| Or de départ | fixe par niveau : 60 au niveau 1 (avec un Archer déjà posé), 65 au niveau 2… 110 au niveau 10 |
| Or gagné | chaque monstre tué donne son or tout de suite (6 pour un fantassin, 18 pour un chevalier lourd, 120 pour le mini-boss) : un « +6 » doré s'envole au-dessus de lui |
| Ce qu'on garde d'un niveau à l'autre | **rien** : l'or et les tours posées repartent de zéro. On garde ses tours débloquées, ses pièces de niveau et son entraînement |
| Le flot | les monstres sortent **un par un, sans aucune pause**, du début à la fin. Ils sortent de plus en plus serrés (3 fois plus par seconde à la fin) et sont de plus en plus résistants (16 fois plus de PV à la fin). Les types se mélangent : fantassins, cavaliers, meutes d'écuyers, chevaliers lourds |
| Rester actif | l'or des monstres permet un achat toutes les 3 secondes environ. Le niveau est réglé pour qu'il faille acheter ou améliorer quelque chose toutes les 5 secondes au niveau 1, toutes les 3,5 secondes à partir du niveau 6. Celui qui s'arrête est dépassé en une vingtaine de secondes |
| Vitesse x2 | bouton x1 / x2, pour tout le monde (réglage `Levels.SPEED_FREE`) |
| Vue | caméra penchée : on voit les tours et les monstres de côté, et la carte remplit l'écran. **Choisie par toi le 02/10/2026** parmi trois (penchée, plus plongeante, pile au-dessus). Réglage : `CAMERA_PITCH_MIN` et `CAMERA_PITCH_MAX`, en haut de `src/client/LevelsUI.luau` |

Les 8 tours sont celles de la parcelle (mêmes dégâts, mêmes portées, mêmes effets), avec leurs prix en or à elles.
Une seule différence : le Totem de givre ralentit de 40 % dans les niveaux (60 % sur la parcelle).

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

Perdu ou abandonné : une petite part (la moitié de « en le rejouant », multipliée par la part des monstres éliminés).
Lancer un niveau et le quitter tout de suite ne donne donc rien.

### La boutique (prix fixes, aucun hasard)

| Tour | Prix en pièces de niveau |
|---|---|
| Archer du rempart | déjà à toi |
| Catapulte | déjà à toi |
| Totem de givre | 150 |
| Mage des tempêtes | 400 |
| Baliste lourde (épique) | 1 200 |
| Sorcier des arcanes (épique) | 3 000 |
| Oracle de la foudre (légendaire) | 8 000 |
| Trébuchet royal (légendaire) | 15 000 |

Les pièces des premières victoires suffisent pour le Totem avant le niveau 3 (180 pièces après deux niveaux) et pour
le Mage avant le niveau 6 (740 après cinq niveaux).

**Est-ce qu'on a tout au niveau 10 ?** Non. Les 10 niveaux réussis une fois donnent 2 180 pièces en tout : de quoi
acheter le Totem, le Mage et la Baliste (1 750), pas plus. Le reste se gagne en rejouant (le niveau 10 rejoué rapporte
240 pièces) :

| Tour | Parties à rejouer au niveau 10 pour la payer | Avant ce réglage |
|---|---|---|
| Sorcier des arcanes | 13 | 7 |
| Oracle de la foudre | 34 | 13 |
| Trébuchet royal | 63 | 21 |

Les niveaux 11 à 20 rapporteront plus : les légendaires sont des buts à long terme, pas des tours du premier
territoire. Chaque prix est un seul chiffre dans `Levels.SHOP`.

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

### La difficulté, réglée avec des joueurs simulés

`tools/levels` fait jouer les 10 niveaux par des joueurs simulés, avec le vrai moteur du jeu. Chaque niveau est réglé
pour qu'**attendre fasse perdre** et que **rester actif fasse gagner** :

| Niveau | Très actif (dépense tout, tout de suite) | Au rythme demandé | Un achat toutes les 8 s | 2 Archers puis attendre | 4 Archers et 2 Catapultes, sans améliorer |
|---|---|---|---|---|---|
| 1 | gagne, 10 vies | un achat toutes les 5 s : gagne, 7 vies | perd à 76 % | perd à 15 % (48 s) | perd à 39 % |
| 2 | gagne, 10 vies | toutes les 4,5 s : gagne, 10 vies | perd à 80 % | perd à 11 % (46 s) | perd à 35 % |
| 3 | gagne, 10 vies | toutes les 4 s : gagne, 10 vies | perd à 83 % | perd à 11 % (48 s) | perd à 44 % |
| 4 | gagne, 10 vies | toutes les 4 s : gagne, 10 vies | perd à 85 % | perd à 11 % (48 s) | perd à 38 % |
| 5 (mini-boss) | gagne, 10 vies | toutes les 4 s : gagne, 6 vies | perd à 94 % | perd à 12 % (51 s) | perd à 38 % |
| 6 | gagne, 10 vies | toutes les 3,5 s : gagne, 10 vies | perd à 68 % | perd à 7 % (42 s) | perd à 27 % |
| 7 | gagne, 10 vies | toutes les 3,5 s : gagne, 10 vies | perd à 52 % | perd à 7 % (42 s) | perd à 26 % |
| 8 | gagne, 10 vies | toutes les 3,5 s : gagne, 10 vies | perd à 70 % | perd à 5 % (37 s) | perd à 18 % |
| 9 | gagne, 10 vies | toutes les 3,5 s : gagne, 10 vies | perd à 49 % | perd à 4 % (37 s) | perd à 15 % |
| 10 (boss) | gagne, 10 vies | toutes les 3,5 s : gagne, 10 vies | perd à 92 % | perd à 6 % (41 s) | perd à 21 % |

« Perd à 76 % » = le château tombe quand 76 % des monstres du niveau ont été éliminés.

Ce que les joueurs simulés ont en arrivant à chaque niveau : les deux tours de départ aux niveaux 1 et 2, le Totem à
partir du niveau 3, le Mage à partir du niveau 6, un peu d'entraînement (niveau 1 à partir du niveau 4, niveau 2 à
partir du niveau 8). Sans la boutique (Archer et Catapulte seulement), un joueur très actif gagne les niveaux 1 et 2,
passe ou rate de très peu les niveaux 3 à 5, et perd à partir du niveau 6. La Baliste et les tours suivantes ne
sont jamais nécessaires pour finir les 10 niveaux.

Un vrai joueur choisit moins bien que le joueur simulé : pour gagner, il doit aller un peu plus vite que le rythme
indiqué. **C'est un réglage à ajuster quand tu y auras joué** : si c'est trop dur ou encore trop facile, dis-le-moi,
un seul chiffre par niveau change tout (`health` dans `Levels.DEFINITIONS`).

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

- le premier : 273 vérifications des règles et de la difficulté de chaque niveau, sans Studio (20 secondes) ;
- le deuxième : le tableau de difficulté des 10 niveaux par les joueurs simulés ;
- le troisième : le test complet dans Studio (serveur, puis la vraie interface à la taille normale et à la taille
  d'un téléphone), avec des captures dans `tools/studio-test/out/levels_*.png`.

### Six combats dans le même serveur

C'était le point à valider par des mesures (un serveur = 6 joueurs, donc 6 niveaux possibles en même temps, en plus
des 6 parcelles). Mesuré dans Studio le 02/10/2026 avec le flot continu, six niveaux 10 (le plus chargé) joués en
même temps pendant 170 secondes de jeu (tout le flot, dont la fin, le moment le plus chargé) :

| Cas | Temps moyen par image | 99 % des images | Monstres en même temps |
|---|---|---|---|
| 12 tours par joueur (combat normal) | 0,13 ms | moins de 0,4 ms | jusqu'à 348 |
| 3 tours par joueur (carte pleine de monstres) | 0,10 ms | moins de 0,25 ms | jusqu'à 348 |

(348 = 58 monstres en vie par niveau : à la fin du flot il en sort 3,5 par seconde, et chacun met environ 16 secondes
à traverser la carte. La mesure donne des vies infinies et des tours de niveau 1, qui ne tuent presque plus rien à la
fin : c'est le pire cas possible. Dans une vraie partie, le château tombe bien avant.)

Une image du serveur dure 16,7 ms : les six combats ensemble en prennent **moins de 1 %**. Rester dans le même
serveur tient donc largement. Les monstres et les tirs d'un niveau ne sont envoyés qu'au joueur qui y joue.

La mesure se refait avec le test Studio (voir « Vérifier »), ou dans la barre de commande de Studio (vue Serveur) :

```lua
local m = game.ServerStorage.StudioDebug:Invoke(game.Players:GetPlayers()[1], "Levels", "Bench", 6, 170, 12)
print(m.averageMs, m.p99Ms, m.worstMs, m.enemiesPeak)
```

## Limites connues du prototype

- Une seule carte (« La vallée du Roi carmin ») pour les 10 niveaux.
- Les nouveaux écrans sont en français seulement.
- Pas encore de tuto dédié : au tout premier niveau, un conseil en bas de l'écran guide la pose puis l'amélioration.
- La difficulté est réglée avec des joueurs simulés, pas encore avec de vrais joueurs : le niveau 1 demande déjà
  d'acheter souvent. Avant d'ouvrir à tout le monde, il faudra voir si un nouveau joueur le passe.
- Les autres joueurs ne voient pas ton combat (ils restent sur la place).
- Pendant un niveau, ta parcelle continue de tourner toute seule sur la place.

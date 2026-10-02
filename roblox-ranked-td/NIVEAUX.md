# Les NIVEAUX — les règles du jeu

Ce document explique le jeu : **ce que c'est, comment y jouer, ses règles, et ce qui reste à décider**. Tout ce qui est
écrit ici vient de nos discussions (« niveau 1, niveau 2, niveau 3… », gameplay dynamique, pose libre, boutique à prix
fixes, camp d'entraînement, plus aucun hasard).

## En deux mots

- Le jeu est une suite de **niveaux** : **10 niveaux** pour l'instant. Chaque niveau est une partie de 2 à 3 minutes,
  vue d'en haut : un flot continu de monstres, de plus en plus forts. Tu poses tes tours **où tu veux** et tu les
  améliores **sans arrêt** avec l'or des monstres (si tu t'arrêtes, tu perds), tu protèges ton château (10 vies).
  Mini-boss au niveau 5, boss au niveau 10.
- Gagner donne des **pièces de niveau** 🏅. Elles servent à acheter les autres tours dans une **boutique à prix fixes**
  (aucun tirage au sort) et à améliorer ton **camp d'entraînement**.
- Ta parcelle est ton **camp d'entraînement** : les tours que tu y mets deviennent plus fortes, même quand tu n'es
  pas là, et elles **évoluent** (★, ★★, ★★★).
- **Tout le monde y a accès** : il n'y a plus de réglage « seulement pour toi ».
- Il n'y a **plus rien de l'ancien jeu** : ni classé, ni autel, ni forge, ni runes, ni vagues infinies sur la
  parcelle, ni renaissance, ni défis, ni passes Robux, ni ancien tuto (voir « Le grand ménage » plus bas).

## Comment y jouer

1. Lance `Play` dans Studio, ou publie le jeu (voir `README.md`).
2. Tu arrives sur ta parcelle, ton **camp** :
   - devant toi, les **socles d'entraînement** : ton Archer est sur le premier et tire sur les cibles. Au-dessus de
     lui : son nom, ses étoiles, son niveau d'entraînement, sa barre d'XP. Approche-toi d'un socle et utilise
     l'invite **« Gérer »** (touche `E`, ou le bouton sur téléphone) pour choisir la tour qui s'y entraîne ;
   - le socle sombre à côté est le 2e emplacement, à ouvrir avec 400 pièces de niveau ;
   - derrière toi, à l'entrée, les deux bâtiments sont la **BOUTIQUE DES TOURS** et la **PORTE DES NIVEAUX** ;
   - au fond, le grand tableau affiche ton camp (niveaux réussis, tours débloquées, pièces).
3. En haut à gauche, clique **« ⚔ NIVEAUX »** (tes pièces de niveau 🏅 sont affichées juste à côté, puis le bouton
   « SON »), puis **« ▶ JOUER »** sur le niveau 1.
4. Dans le niveau :
   - tu as deux tours dans la barre du bas : l'**Archer** (une cible, rapide, 20 or) et la **Catapulte** (une zone,
     45 or). Au niveau 1, un Archer est déjà posé et tire tout seul ;
   - **ordinateur** : clique une tour de la barre du bas (ou touches 1 à 8), un aperçu vert ou rouge suit ta souris
     avec sa portée, clique pour poser. Clique une tour posée pour ouvrir son petit menu (**Améliorer** / **Vendre**).
     Raccourcis : `E` améliorer, `X` vendre, `F` vitesse x2 ;
   - **téléphone** : appuie sur la tour dans la barre, puis sur le terrain ; ou fais-la glisser depuis la barre.
     Appuie sur une tour posée pour son menu (il s'ouvre dans un coin du bas, du côté opposé à la tour) ;
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
| Vitesse x2 | bouton x1 / x2, gratuit pour tout le monde |
| Taille des monstres | affichés plus gros que leur taille de base, pour être vus de haut (fantassin x1,8, boss x1,4). Réglage `Levels.ENEMY_SCALE` ; aucun effet sur le combat |
| Vue | caméra penchée : on voit les tours et les monstres de côté, et la carte remplit l'écran. **Choisie par toi le 02/10/2026** parmi trois (penchée, plus plongeante, pile au-dessus). Réglage : `CAMERA_PITCH_MIN` et `CAMERA_PITCH_MAX`, en haut de `src/client/LevelsUI.luau` |

Les 8 tours (dégâts, portées, effets : `src/shared/IdleTowers.luau`) et leurs prix en or :

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
240 pièces) : 13 parties pour le Sorcier des arcanes, 34 pour l'Oracle de la foudre, 63 pour le Trébuchet royal.

Les niveaux 11 à 20 rapporteront plus : les légendaires sont des buts à long terme, pas des tours du premier
territoire. Chaque prix est un seul chiffre dans `Levels.SHOP`.

### Ta parcelle : le camp d'entraînement

- **3 emplacements d'entraînement**, chacun avec son socle sur ta parcelle. Le premier est ouvert, les deux autres
  s'achètent (400 puis 1 500 pièces de niveau).
- La tour d'un emplacement est **posée pour de vrai** sur son socle et tire sur des **cibles d'entraînement**
  (mannequins de paille sur des chariots) qui roulent lentement sur le chemin. Elle se sert de ses évolutions : un
  Archer ★ met le feu aux cibles. Les cibles ne rapportent rien : ni pièces, ni XP.
- Une cible a autant de PV que les tours du camp en enlèvent en 2 secondes (à leurs dégâts de base) : une tour
  entraînée ou évoluée les casse donc plus vite, et ça se voit.
- Chaque tour a de l'**XP d'entraînement**, qui donne un niveau d'entraînement de 0 à 6 (20, 60, 140, 300, 600 et
  1 200 XP).
- Chaque niveau d'entraînement : **+5 % de dégâts** dans les niveaux, et une **évolution** aux niveaux 2, 4 et 6
  (voir plus bas).
- L'XP vient de deux endroits :
  - **les emplacements du camp** : la tour qu'on y met gagne 1 XP par minute, **même quand tu es parti** (12 h au
    plus d'un coup). Un emplacement s'améliore (120, 300, 700, 1 500 pièces : jusqu'à 4,5 XP par minute) et on en
    ouvre d'autres (400 puis 1 500 pièces, 3 au plus) ;
  - **jouer** : chaque type de tour posé dans un niveau gagne 8 XP si tu gagnes (moins si tu perds).
- Attendre n'est donc jamais la seule façon d'avancer.
- Quand une tour monte d'un niveau d'entraînement pendant que tu es là, un message te le dit ; quand elle
  **évolue**, elle est refaite sur son socle avec sa nouvelle apparence.
- Les autres joueurs voient ton camp (tes tours, tes cibles, ton tableau) quand ils s'approchent de ta parcelle.
  Les invites (« Gérer », boutique, porte des niveaux) ne marchent que sur TA parcelle.

### Les évolutions des tours

| Tour | ★ (entraînement 2) | ★★ (entraînement 4) | ★★★ (entraînement 6) |
|---|---|---|---|
| Archer du rempart | Flèches enflammées : chaque flèche laisse une petite zone de feu | Longue-vue : +3 de portée | Tir rapide : +20 % de vitesse d'attaque |
| Catapulte | Gros rochers : zone d'impact plus large (+1,5) | Bras long : +3 de portée | Rechargement rapide : +20 % de vitesse |
| Totem de givre | Givre mordant : les monstres ralentis prennent plus de dégâts | Grande aura : +2 de portée | Gel profond : ralentit de 50 % au lieu de 40 % |
| Mage des tempêtes | Éclair large : zone de foudre plus large (+1) | Long regard : +3 de portée | Tempête : +20 % de vitesse |
| Baliste lourde | Carreau perçant : transperce jusqu'à 3 monstres alignés | Tir tendu : +5 de portée | Treuil graissé : +20 % de vitesse |
| Sorcier des arcanes | Concentration : le rayon chauffe 50 % plus vite | Long rayon : +3 de portée | Surchauffe : le rayon monte 20 % plus haut |
| Oracle de la foudre | Éclair bondissant : un monstre de plus par éclair (5) | Vision lointaine : +3 de portée | Orage : +20 % de vitesse |
| Trébuchet royal | Pierre géante : zone d'impact plus large (+2) | Onde de choc : étourdit plus longtemps (+0,3 s) | Contrepoids : +20 % de vitesse |

À quoi on reconnaît une tour évoluée :

| Évolution | Sur la tour | Sur son étiquette |
|---|---|---|
| ★ | anneau de bronze autour du socle, 4 clous | ★ |
| ★★ | anneau d'argent, 4 hampes avec des fanions à sa couleur | ★★ |
| ★★★ | anneau d'or, hampes plus hautes, 4 joyaux lumineux, halo doré | ★★★ |

Les étoiles se voient au camp et dans les niveaux (« ★★ Niv. 3 » au pied de la tour).

Temps pour évoluer avec le seul emplacement du camp (sans compter l'XP gagnée en jouant, 8 XP par victoire) :

| Emplacement | ★ (60 XP) | ★★ (300 XP) | ★★★ (1 200 XP) |
|---|---|---|---|
| niveau 1 (1 XP par minute) | 1 h | 5 h | 20 h |
| niveau 5 (4,5 XP par minute) | 13 min | 1 h 07 | 4 h 27 |

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
indiqué. Tu as joué cette version et dit « ça va » (02/10/2026). Si c'est trop dur ou trop facile un jour, un seul
chiffre par niveau change tout (`health` dans `Levels.DEFINITIONS`).

### Ce que chaque tour de la boutique apporte

Mesuré avec le joueur simulé (`tools\levels\run.ps1 -Worth`) : « +20 % » veut dire qu'avec cette tour en plus,
il bat des monstres 20 % plus résistants qu'avec les seules tours attendues à ce niveau.

| Tour (prix à la boutique) | Niveau 6 | Niveau 8 | Niveau 10 |
|---|---|---|---|
| Baliste lourde (1 200) | +20 % | +23 % | +59 % |
| Sorcier des arcanes (3 000) | +20 % | +23 % | +59 % |
| Oracle de la foudre (8 000) | +47 % | +42 % | +29 % |
| Trébuchet royal (15 000) | +55 % | +34 % | +46 % |

La Baliste et le Trébuchet ont été **renforcés le 02/10/2026** (avec ton accord). Avant, ils n'apportaient presque
rien : la Baliste 0, 0 et +19 %, le Trébuchet +12 %, 0 et +12 %, alors que le Trébuchet est la tour la plus chère.

| Tour | Avant | Maintenant |
|---|---|---|
| Baliste lourde | 50 dégâts toutes les 4 s | **120** dégâts toutes les 4 s |
| Trébuchet royal | 35 dégâts dans sa zone toutes les 5 s, étourdit 0,5 s | **100** dégâts toutes les 5 s, étourdit **1 s** |

Ces deux tours ne servent pas à régler la difficulté des 10 niveaux (les joueurs simulés ne les ont pas quand ils
arrivent à un niveau) : rien d'autre n'a changé. Les chiffres sont dans `src/shared/IdleTowers.luau`.

## Comment on en est arrivé là (tes retours du 02/10/2026)

1. **Premier essai** (« beaucoup trop facile », « ils sortent par vagues, je veux que ce soit en continu et de plus
   en plus dur, que je sois obligé d'être super actif », « commencer avec au moins deux tours », « pouvoir annuler
   quand je clique sur une tour », « si juste 2 Archers gèrent le niveau, je passe mon temps à attendre ») : flot
   continu, attendre fait perdre, deux tours au départ, bouton « ANNULER », plus de bouton « envoyer la suite ».
2. **Deuxième essai** (« ça va, mais le ralentissement du givre est un peu cheaté, et les prix des prochaines tours
   doivent être plus hauts, pas forcément les basiques mais les légendaires surtout ») : le Totem de givre ralentit de
   40 % au lieu de 60 % (les niveaux 3 à 10 ont été recalculés) ; la Baliste passe de 900 à 1 200 pièces, le Sorcier
   de 1 600 à 3 000, l'Oracle de 3 000 à 8 000, le Trébuchet de 5 000 à 15 000.
3. **Ta parcelle et l'évolution des tours** (« tu peux gérer toute la parcelle et le système d'évolution de tour ») :
   la parcelle devient le camp d'entraînement, les tours évoluent (★, ★★, ★★★).
4. **Une interface « plus Roblox » et des monstres plus gros** : ChatGPT a refait le style des écrans (police ronde à
   contour noir, bandeau bleu, boutons verts et bleus, vraies tours dessinées en 3D sur les cartes) ; retouches
   ensuite (menu d'une tour plus petit sur téléphone, vignettes plus grandes, tours pas encore achetées en gris avec
   un bouton « BOUTIQUE ») ; monstres affichés plus gros dans les niveaux (`Levels.ENEMY_SCALE`).
5. **Le grand ménage** (« enlève tous les anciens trucs maintenant : ranked, forge, etc., tout ce qui est
   obsolète ») : voir juste en dessous.
6. **La Baliste et le Trébuchet renforcés** (« oui renforce la baliste et le trébuchet ») : voir « Ce que chaque
   tour de la boutique apporte », plus bas.

### Le grand ménage : ce qui a été enlevé

- le **classé** : file d'attente, cercle et tableaux sur la place, serveur de match, MMR, rangs, défis classés ;
- l'**autel des héros** et la **forge runique** (tirages, runes, doublons) ;
- le **jeu infini** de la parcelle : vagues, 22 emplacements, pièces à ramasser, gains d'absence, renaissance,
  classement solo ;
- les **passes Robux** (Ramassage auto, Vitesse x2, Pièces x2) et leur boutique, le panneau « 🎁 DONNER » ;
- l'ancien **tuto**, les scènes de tournage, les traductions anglaises de tous ces écrans ;
- les outils qui allaient avec (simulateur du jeu infini, chances de la forge, tests Studio de l'ancien jeu).

Ce qui a été gardé : les niveaux, le camp d'entraînement, les évolutions, la boutique des tours, les 8 tours et leur
combat, les monstres et leurs modèles 3D, les effets et les sons, la galerie et le panneau des sons de Studio, le
mécanisme de traduction (pour la future version anglaise).

**Rien n'est perdu** : l'ancien jeu complet est gardé dans le dépôt, à l'étiquette git `ancien-jeu-complet`.

**Sauvegardes** : le jeu enregistre maintenant dans un nouvel espace (`Niveaux_PlayerData_v1`), avec seulement les
niveaux du joueur et son réglage du son. Les sauvegardes de l'ancien jeu « Tower 22 » ne sont jamais lues ni
écrasées.

## Ce qui reste à décider (par toi)

1. **Les évolutions** de chaque tour (3 par tour) : ce sont mes propositions, à changer comme tu veux.
2. **La suite des niveaux** : 11 à 20 avec une autre famille de monstres et une autre carte (le code est prêt pour
   plusieurs cartes : `Levels.MAPS`, et les modèles des monstres des territoires suivants existent déjà).
3. **Des passes Robux pour ce jeu ?** Il n'y en a plus aucun. Si tu en veux, il faudra choisir lesquels (jamais un
   avantage qui casse la difficulté des niveaux).
4. **Avant de rendre le jeu public** : voir `SORTIE.md` (petit tuto, traduction anglaise des nouveaux écrans, essai
   sur un vrai téléphone, page du jeu).

## Technique (pour s'y retrouver)

- **Où ça se passe** : dans le même serveur que la map principale, sans téléportation ni écran de chargement.
  Six zones de combat (une par parcelle) sont réservées très loin de la place (`workspace.Arenas`). La carte d'un
  niveau n'est construite que pendant qu'un joueur y joue, puis effacée.
- **Le personnage** reste sur la place. Seule la caméra part regarder la zone de combat ; les commandes du
  personnage et les autres écrans sont coupés pendant le niveau, puis remis.
- **Le combat** : `Combat.luau` (visée, projectiles, zones, ralentissements…) est la base d'un niveau
  (`LevelGame.luau`) et d'un camp (`CampGame.luau`). Les monstres et les tirs d'un niveau voyagent dans des paquets
  compacts, envoyés **au joueur du niveau seulement** ; ceux d'un camp, à son propriétaire et aux joueurs proches.
  L'affichage est le même code pour les deux (`PlotRenderer.luau`).
- **Le serveur décide de tout** (or, pose, récompenses, achats). Le client envoie des demandes (`LevelAction`).

| Fichier | Rôle |
|---|---|
| `src/shared/Levels.luau` | toutes les règles et tous les chiffres (niveaux, monstres, prix, boutique, entraînement) |
| `src/shared/IdleTowers.luau`, `IdleConfig.luau`, `Enemies.luau` | les 8 tours, les réglages du combat, les 6 types de monstres |
| `src/server/Hub/Combat.luau` | le combat des tours contre les monstres, et ses paquets réseau |
| `src/server/Hub/LevelGame.luau` | un niveau en cours (or, vies, flot de monstres, pose des tours) |
| `src/server/Hub/LevelArena.luau` | les zones de combat et leur carte |
| `src/server/Hub/LevelsService.luau` | lancement, récompenses, boutique, camp, état publié au joueur |
| `src/server/Hub/Camp.luau`, `CampGame.luau` | la parcelle : socles, étiquettes, invites ; les tours du camp et leurs cibles |
| `src/server/Hub/HubMap.luau`, `Plots.luau`, `PlotBoard.luau`, `PlotIdentity.luau`, `PlotInterest.luau` | la map, l'attribution des parcelles, leurs panneaux, qui reçoit quel camp |
| `src/server/Hub/IdleTowerModel.luau` | modèles des tours, et leurs marques d'évolution (`addEvolution`) |
| `src/server/PlayerData.luau` | la sauvegarde |
| `src/client/LevelsUI.luau` | le bouton, la fenêtre du camp, l'écran d'un niveau |
| `src/client/PlotRenderer.luau`, `Effects.luau`, `CombatVFX.luau` | l'affichage des monstres, des cibles et des tirs |
| `src/client/SoundManager.luau`, `src/shared/Sounds.luau` | les sons |
| `tools/levels/` | joueur simulé et vérifications hors Studio |
| `tools/studio-test/` | tests automatiques dans Studio |

Sauvegarde : `data.levels` dans les données du joueur (niveau le plus haut réussi, pièces de niveau, tours achetées,
XP, emplacements du camp, ordre de la barre rapide), et `data.soundMode`.

### Vérifier

```bash
powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1 -Tests
```

```bash
powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1
```

```bash
powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1
```

- le premier : 291 vérifications des règles, de la difficulté de chaque niveau, des évolutions et du camp, sans
  Studio (20 secondes) ;
- le deuxième : le tableau de difficulté des 10 niveaux par les joueurs simulés ;
- le troisième : le test complet dans Studio (serveur, puis la vraie interface à la taille normale et à la taille
  d'un téléphone), avec des captures dans `tools/studio-test/out/levels_*.png`.

### Six combats dans le même serveur

C'était le point à valider par des mesures (un serveur = 6 joueurs, donc 6 niveaux possibles en même temps, en plus
des 6 camps). Mesuré dans Studio le 02/10/2026, six niveaux 10 (le plus chargé) joués en même temps pendant
170 secondes de jeu (tout le flot, dont la fin, le moment le plus chargé) :

| Cas | Temps moyen par image | 99 % des images | Monstres en même temps |
|---|---|---|---|
| 12 tours par joueur (combat normal) | 0,13 ms | moins de 0,4 ms | jusqu'à 348 |
| 3 tours par joueur (carte pleine de monstres) | 0,10 ms | moins de 0,25 ms | jusqu'à 348 |

(348 = 58 monstres en vie par niveau : à la fin du flot il en sort 3,5 par seconde, et chacun met environ 16 secondes
à traverser la carte. La mesure donne des vies infinies et des tours de niveau 1, qui ne tuent presque plus rien à la
fin : c'est le pire cas possible. Dans une vraie partie, le château tombe bien avant.)

Une image du serveur dure 16,7 ms : les six combats ensemble en prennent **moins de 1 %**. Rester dans le même
serveur tient donc largement.

La mesure se refait avec le test Studio (voir « Vérifier »), ou dans la barre de commande de Studio (vue Serveur) :

```lua
local m = game.ServerStorage.StudioDebug:Invoke(game.Players:GetPlayers()[1], "Levels", "Bench", 6, 170, 12)
print(m.averageMs, m.p99Ms, m.worstMs, m.enemiesPeak)
```

## Limites connues

- Une seule carte (« La vallée du Roi carmin ») pour les 10 niveaux.
- Les écrans des niveaux et du camp sont en français seulement (voir `README.md`, « Langues »).
- Pas encore de tuto : au tout premier niveau, un conseil en bas de l'écran guide la pose puis l'amélioration.
- La difficulté est réglée avec des joueurs simulés et un seul vrai joueur (toi) : avant de rendre le jeu public, il
  faudra voir si un nouveau joueur passe le niveau 1.
- Les autres joueurs ne voient pas ton combat (ils restent sur la place).
- Pendant un niveau, ton camp continue de s'entraîner sur ta parcelle.

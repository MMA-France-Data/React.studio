# Royaumes en guerre — Tower Defense 1v1 (Roblox)

Un tower defense médiéval fantastique avec une map principale à 6 fiefs (un par joueur) et un vrai système **ranked** 1v1 : MMR (Elo), rangs, matchs de placement,
saisons, classement global et matchmaking entre serveurs.

Tout est construit par code (forteresses, arènes, interfaces, tours et armées) : pas besoin de modèles dans Studio.
Les assauts opposent fantassins, écuyers, cavaliers rapides, chevaliers lourds et immenses seigneurs de guerre.

## La map principale

Chaque serveur accueille 6 joueurs (à régler dans *Game Settings > Places > Server Size*).
Chacun reçoit sa parcelle : un chemin, une base et 22 emplacements de tours (4 débloqués au départ, les 18 autres
s'achètent **dans n'importe quel ordre**). Le prix ne dépend que du nombre d'emplacements déjà possédés : 100 pièces
pour le 5e, puis ×2,6 à chaque fois, jusqu'à ~1,1 B pour le 22e (voir `PlotLayout.spotCost`).
Au centre, le **sceau de l'Arène royale** lance la recherche d'une partie ranked.
Les boutons « Mon fief » et « Arène royale » servent à se déplacer vite.

## Le mode infini (ta parcelle)

- Des vagues sans fin arrivent sur ta parcelle. **Impossible de perdre**, mais pas de PV de base : si **un seul**
  ennemi atteint ta base, la vague est ratée, tu redescends d'une vague et tu réessaies. Vague réussie → vague suivante.
- Les gains grandissent de ×1,25 par vague et les PV un peu plus vite (×1,46 vers la vague 10, ×1,30 à la 50,
  ×1,28 à la 100 ; réglages dans `IdleConfig.luau`) : les pièces passent de quelques unités à des trillions,
  puis des quadrillions, des quintillions… (réglé avec `tools/balance`, voir `tools/balance/RESULTS.md`).
- 5 types de vagues : **Escarmouche**, **Levée des écuyers** (masse de petits soldats → tours de zone),
  **Charge de cavalerie** (rapides → ralentissement), **Garde colossale** (un seul chevalier colossal, lent et
  blindé → gros dégâts), **Seigneur de guerre** toutes les 10 vagues (un seul boss et son escorte).
- Bonus de début : +50 % de pièces à la vague 1, qui fond jusqu'à 0 à la vague 40 (`IdleConfig.earlyRewardBonus`) ;
  50 pièces au départ.
- Les ennemis tués lâchent des **pièces à ramasser** (les pièces proches s'empilent). Le bonus de pièces
  s'additionne : ennemi à 3 pièces, +100 % → 6, +200 % → 9.
- 8 défenses (`IdleTowers.luau`) : Archer du rempart, Totem de givre, Catapulte, Mage des tempêtes,
  Baliste lourde, Sorcier des arcanes, Oracle de la foudre et Trébuchet royal. Clique sur un emplacement
  libre pour poser une défense. Clique sur une tour pour voir sa fiche (DPS, dégâts, vitesse en atq/s,
  portée) : « Remplacer… » puis une confirmation la remplace (50 % remboursés), vendre (2 clics) rend 50 %.
  Le serveur refuse toute pose sur une tour existante sans cette confirmation (`PlotGame:placeTower`).
- **Projectiles** (flèches de l'Archer, rochers de la Catapulte, carreaux de la Baliste, pierres du
  Trébuchet) : la tour vise l'endroit où **sera** l'ennemi quand le projectile arrivera (sa vitesse, son
  ralentissement et le chemin sont pris en compte), et les dégâts tombent **à l'impact**, pas au tir. Temps de
  vol : `projectileSpeed` (et `projectileMinFlight` pour les tirs en cloche) dans `IdleTowers.luau`. Une tour
  ne tire pas sur un ennemi que les projectiles déjà en vol vont tuer : elle en vise un autre. Une flèche dont
  la cible meurt en vol touche l'ennemi le plus proche du point d'impact (à 1,5 stud au plus), sinon elle est
  perdue. Les tirs instantanés restent instantanés : Totem, Mage des tempêtes, Oracle, rayon du Sorcier.
- **Archer du rempart** : portée 21 (15 avant) et **flèches enflammées** : chaque flèche laisse au sol une
  petite zone de feu (rayon 2,5) qui brûle tous les ennemis dedans, **40 % des dégâts de la flèche par
  seconde** pendant 2 s (un coup toutes les 0,5 s). Une flèche qui tombe dans une zone de la même tour la
  ravive ; 5 zones au plus par Archer et 30 par parcelle. Niveaux, doublons et runes de dégâts renforcent
  aussi le feu. (10 % et rayon 2,25 au premier essai : le feu ne changeait presque rien, voir
  `tools/balance/RESULTS.md`.)
- **Mage des tempêtes** : sa foudre frappe une **petite zone** (rayon 2,5, la Catapulte fait 7) : les ennemis
  collés à sa cible prennent aussi les dégâts (10 au niveau 1) et le ralentissement (-30 % pendant 0,8 s).
  Un vrai contrôle des groupes tassés, sans remplacer la Catapulte ni le Totem.
- **Sorcier des arcanes** : un **rayon continu**. Il s'accroche à l'ennemi le plus résistant à portée
  (14, 18 avant) et le garde tant qu'il vit et reste à portée, même si un ennemi plus fort arrive. Ses dégâts
  montent tant qu'il reste sur la même cible : dégâts par seconde = 7 x montée (au niveau 1), montée =
  1 + 2 par seconde, x25 au plus (après 12 s). Nouvelle cible = la montée repart de x1. À niveau égal, il bat
  la Baliste contre les ennemis lents (x1,7 contre un Seigneur de guerre, x2,1 contre un colosse, x1,35 contre
  un chevalier lourd, x3 avec un Totem de givre à côté) mais perd contre les rapides (x0,8 contre un cavalier) ;
  sur une vraie vague de boss (avec son escorte), il fait à peu près comme la Baliste : pas de victoire
  automatique. Plus fort dans un virage du chemin. La rune x2 vitesse d'attaque fait monter le rayon 2 fois
  plus vite (x25 en 6 s). Sa fiche affiche « Rayon 7 → 175 dégâts/s » au niveau 1 et « continu » à la place
  de la vitesse.
- **Oracle de la foudre** et **Trébuchet royal** (légendaires) : rares (voir l'autel), donc bien plus forts
  à niveau égal (Oracle : 50 dégâts par ennemi touché, Trébuchet : 70) ; les tours communes compensent avec
  leurs centaines de doublons.
- Clique sur **n'importe quel cadenas** pour débloquer cet emplacement. Tous les cadenas affichent le même prix
  (celui de ton prochain emplacement), qui monte après chaque achat. Les emplacements possédés sont sauvegardés
  dans `data.idle.ownedSpots` (`unlockedSpots` = leur nombre) ; les anciennes sauvegardes sont converties
  automatiquement (`PlayerData.luau`).
- **Améliorations** : clique sur une tour → « Améliorer » (ou touche E). Niveaux illimités, dégâts ×1,35 par
  niveau, prix ×1,35 par niveau (20 pièces pour le niveau 2, le même prix pour toutes les tours). Les PV des
  vagues montent un peu plus vite que les gains (×1,28 à ×1,46 contre ×1,25) :
  on bloque souvent, on farme un peu, une amélioration débloque les vagues suivantes.
- Chemin de ~360 studs (6 allers-retours) et ennemis 1,35× plus rapides qu'en ranked, sauf les cavaliers
  et les écuyers, freinés (13 studs/s), et les chevaliers lourds, colosses et Seigneurs de guerre, un peu
  moins lents (`IdleConfig.ENEMY_SPEED_FACTORS`).
- Le **Totem de givre** ralentit de 60 % tout ce qui passe dans son aura (et encore 2,5 s après) et blesse
  tous les ennemis proches à chaque seconde (6 dégâts). Les ralentissements ne s'additionnent pas : le plus
  fort gagne.

### Renaissance (bouton « Renaissance » dans la colonne de gauche)

- Possible dès que tu as réussi la **vague 15** dans ta run actuelle. Seule la vague repart à 1 : tu gardes
  tes pièces, tes tours, leurs améliorations, tes emplacements, les machines (tours débloquées, doublons,
  bonus, nombre de lancers déjà achetés à l'autel, donc ses prix) et ton record de tous les temps.
- En échange, un **bonus de pièces permanent** qui dépend de ta meilleure vague de la run :
  `gain = 1 + 6 × ((vague − 15) / 85) ^ 0,8` → +1 % à la vague 15, +4 % à la 50, +7 % à la 100, et ça continue
  de monter ensuite (+12,2 % à la 200). Arrondi à 0,1 % (`IdleConfig.rebirthGain`).
- Les gains s'additionnent au bonus de pièces (voir plus haut) : avec +12 %, un ennemi à 10 pièces en donne 11,2.
- Le serveur vérifie la vague (`PlotGame:rebirth`), sauvegarde tout de suite et publie `CoinBonus` et `Rebirths`
  sur le dossier de la parcelle ; la fenêtre de confirmation montre le gain et le bonus avant → après (`RebirthUI.luau`).
- Rien de tout ça ne compte en ranked : mêmes tours et même or pour tout le monde.

### L'Autel des héros et la Forge runique

- **Autel des héros** : les invocations se paient en pièces, par x1, x10, x100 (record 40), x1 000 (record 150),
  x10 000 (record 300, pour les joueurs avancés) ou x1 000 000 (record 1 000, un objectif presque mythique)
  (`IdleConfig.TOWER_SPIN_BULKS`).
- **Chaque lancer coûte un peu plus cher que le précédent** : +0,05 % à chaque lancer acheté, pour toujours
  (le compteur `data.idle.towerSpinsBought` ne repart jamais à zéro : ni à la renaissance, ni chaque jour).
  Prix du lancer n° n (n = 0 pour le tout premier) = prix de base × 1,0005^n. Les lots marchent pareil :
  x10 coûte les 10 prochains prix additionnés, exactement comme 10 x1 d'affilée
  (`prix de base × 1,0005^n × (1,0005^10 − 1) / 0,0005`, `IdleConfig.towerSpinCost`).
  Exemple avec un prix de base de 100 pièces : 1er lancer 100, 2e 100,05, puis un x10 ≈ 1 003 ;
  après 1 000 lancers achetés, un lancer coûte ~165 ; après 10 000, ~14 800.
  Un total trop grand pour être compté (plus de ~1,8e308) s'affiche « MAX » (bouton grisé) et le serveur
  refuse l'achat : avec les réglages actuels, c'est toujours le cas du x1 000 000 (~2,5e220 prix d'un lancer).
  Un lot vaut toujours le même nombre de fois le prix du prochain lancer : x100 = 102,5, x1 000 = 1 297,
  x10 000 = 294 456. Pour un joueur qui achète régulièrement (simulateur : ~550 lancers à 10 h, ~1 400 à
  25 h, ~2 300 à 50 h), un lancer coûte ~0,03 vague de gains : x100 ≈ 3 vagues (achat courant), x1 000 ≈
  40 vagues (~1 h de farm, gros achat), x10 000 ≈ 9 000 vagues (objectif à très long terme).
- Prix de base d'une invocation : 0,25 vague de gains à ton record, de moins en moins au-delà de la vague 10
  (divisé par (record / 10)^1,05 : 0,022 vague au record 100, `IdleConfig.towerSpinUnitCost`) ; il monte avec
  ton record. L'autel affiche le
  prix exact de chaque bouton et « Prochain lancer : +0,05 % à chaque achat • déjà X lancers » : le serveur
  publie le compteur dans l'attribut `TowerSpinsBought` du joueur, mais calcule toujours les prix avec ses
  propres données (`PlotGame:spinTower`). Les anciennes sauvegardes démarrent à 0 lancer (`PlayerData.luau`).
- Au départ seul l'Archer du rempart est débloqué. 8 tours en 4 raretés (Commune, Rare, Épique, Légendaire) ;
  les chances dépendent de ton **record** (`IdleConfig.TOWER_SPIN_TIERS`), exactement celles affichées par l'autel.
  Les **légendaires (dorées) sont rares** : aucune avant le record 60, puis 1 %, 2,5 % au record 100, 4 % au
  record 200 (la première arrive vers la vague 65-70, après ~7 h de jeu, dans le simulateur). Un doublon donne +2 % de
  dégâts permanents à cette tour. Les gros lots ne lancent pas un million de fois : le serveur tire directement
  combien de tours tombent de chaque rareté (`PlotGame:spinTower`). Un lancer gratuit en attente dans une
  ancienne sauvegarde est remboursé en pièces (`PlayerData.luau`).
- **Forge runique** : x2 dégâts, x2 vitesse d'attaque, x3, x5, x10, x20, x50, x100 dégâts (chances affichées
  dans la forge). 1 rune en pièces toutes les 30 minutes, forges en Robux à volonté. Le bonus va dans
  l'inventaire et se pose sur une tour (1 par tour ; en poser un nouveau remplace l'ancien, vendre la tour
  rend le bonus).
- **Robux** : crée un Developer Product dans le Creator Dashboard et mets son ID dans
  `Config.Products.BONUS_SPIN`. Chaque achat n'est livré qu'une fois (`Monetization.luau`).
- Côté technique, les ennemis n'existent que sous forme de données sur le serveur ; chaque client reçoit leurs
  positions 6 fois par seconde dans un paquet binaire et les affiche lui-même (`PlotGame.luau`, `PlotRenderer.luau`).
  Les tirs partent 10 fois par seconde dans un autre paquet, avec le temps de vol qui reste à chaque projectile :
  le client le fait arriver au moment où le serveur applique les dégâts. Le rayon du Sorcier est publié sur sa
  tour (attributs `BeamTarget` = id de l'ennemi visé, `BeamRamp` = montée) et dessiné à chaque image.

### Gains d'absence

- Ta parcelle continue de rapporter quand tu n'es pas là. En revenant, un message t'affiche
  « Pendant ton absence : +X » et les pièces sont ajoutées tout de suite (`Hub/init.luau`, réglages dans `IdleConfig.luau`).
- **Revenu normal** estimé = pièces de ta meilleure vague de la run × (1 + bonus de pièces / 100) / 100 s
  (dans le simulateur, un joueur actif gagne ~1 vague de gains de son record toutes les 100 s, murs compris).
- **Hors ligne** (pas dans le jeu) : **20 %** du revenu normal (`OFFLINE_RATE`), 24 h comptées au plus par absence.
- **Plafond : 3 runs complètes par jour** (`OFFLINE_DAILY_RUNS`). Une run = les pièces des vagues 1 à ta meilleure
  vague de la run (là où tu bloques), bonus compris. Les gains hors ligne reçus dans la journée s'additionnent ;
  le compteur repart à zéro chaque jour à **00:00 UTC** (2 h du matin en France l'été). En pratique, le plafond
  est atteint après ~2 h d'absence.
- **Match ranked** : le temps passé en match rapporte au **revenu normal**, sans compter dans le plafond (au plus
  20 min + 5 min de marge). L'heure du départ est notée par `Matchmaking.luau` avant la téléportation, l'heure de fin
  par la dernière sauvegarde du serveur de match (`PlayerData.luau` note `lastSeenAt` à chaque sauvegarde).
- Première connexion, heures abîmées ou dans le futur : rien. Rien de tout ça ne change le match ranked.

### Passes de jeu (Robux, mode solo uniquement)

- **Ramassage auto** : les pièces tombées sur ta parcelle sont ramassées toutes seules, où que tu sois.
- **Vitesse x2** : toute la partie de ta parcelle va deux fois plus vite (ennemis, apparitions, tirs, entractes).
  Allumée dès l'achat ; un bouton permet de l'éteindre et de la rallumer (choix sauvegardé).
- **Pièces x2** : toutes les pièces gagnées en solo sont doublées : ennemis tués sur ta parcelle (gain × (1 + bonus / 100) × 2)
  et gains d'absence (hors ligne et match ; le plafond du jour se compte en pièces x1). ID : `Config.GamePasses.COINS_X2`,
  test Studio `"CoinsX2"`, attributs `PassCoinsX2` (joueur) et `CoinMultiplier` (parcelle, 1 ou 2).
- Boutique : bouton « Boutique » dans la colonne de gauche. Rien ne change en ranked : mêmes tours, même or.
- **Créer les passes** : Creator Dashboard > ton expérience > **Monétisation > Passes** > « Créer un pass » (image,
  nom, description) > Enregistrer. Ouvre le pass > **Ventes** : mets-le en vente et choisis son prix en Robux.
  Copie son ID (le nombre dans l'adresse de sa page) dans `Config.GamePasses` (`src/shared/Config.luau`) :
  `AUTO_COLLECT` pour le ramassage auto, `SPEED_X2` pour la vitesse x2. Tant qu'un ID vaut 0, la boutique
  affiche « Bientôt disponible ».
- **Tester dans Studio** sans acheter (vue Serveur, barre de commande) :
  `game.ServerStorage.StudioDebug:Invoke(game.Players:GetPlayers()[1], "Pass", "SpeedX2", true)`
  (ou `"AutoCollect"` ; `false` pour le retirer). Cet outil n'existe pas dans le jeu publié.
- Côté serveur : possession vérifiée auprès de Roblox (`Monetization.luau`), publiée en attributs du joueur
  (`PassAutoCollect`, `PassSpeedX2`, `SpeedX2Enabled`) ; la vitesse de la parcelle est publiée dans l'attribut
  `SimSpeed` de son dossier (1 ou 2), que `PlotRenderer.luau` utilise pour garder l'affichage fluide.

## Le match ranked

- Chaque joueur défend **sa propre base** sur son terrain. Les deux reçoivent exactement les mêmes vagues.
- 4 tours (Archer, Arbalétrier, Catapulte, Mage de givre), chacune avec 3 niveaux : le modèle évolue
  (bandeau doré au niv. 2, bannière au niv. 3), un badge ●●○ au-dessus de chaque tour et une fiche qui compare les 3 niveaux.
- Or : 500 au départ, +100 à chaque vague (`Config.Match.BASE_INCOME`) et une prime par ennemi tué.
  Pas d'envois d'ennemis chez l'adversaire (retirés) : la pression ne vient que des vagues.
- Le premier dont la base tombe perd. Après 20 minutes, la base avec le plus de vie gagne.
- Quitter en plein match = défaite.

Contrôles : `1`-`4` choisir une tour • clic pour poser • clic sur une de tes tours pour la sélectionner •
`E` améliorer • `X` vendre • `Q` annuler • `Maj` enfoncée pour poser plusieurs tours d'affilée.

## Le système ranked

| Élément | Où | Détail |
|---|---|---|
| MMR / Elo | `src/shared/Elo.luau` | K = 32, K = 48 pendant les 5 matchs de placement |
| Rangs | `src/shared/Ranks.luau` | Bronze → Argent → Or → Platine → Diamant → Maître → Légende |
| Sauvegarde | `src/server/PlayerData.luau` | DataStore + **verrou de session** (un seul serveur écrit à la fois) |
| File d'attente | `src/server/Matchmaking.luau` | MemoryStore SortedMap triée par MMR, partagée par tous les serveurs |
| Match | `src/server/Match/` | Serveur réservé, attend les 2 joueurs, applique l'Elo, renvoie au lobby |
| Classement | `src/server/Leaderboard.luau` | OrderedDataStore par saison, affiché sur un panneau dans le lobby |
| Saisons | `Config.SEASON` | Nouvelle saison = soft reset du MMR (moitié de l'écart à 1000) + nouveau classement |

### Déroulement d'un match classé

```
 Lobby (serveur public)                MemoryStore                   Serveur de match (réservé)
 ─────────────────────                 ───────────                   ──────────────────────────
 Joueur clique "Ranked"  ──────────►  File (triée par MMR)
                                           │
 Serveur "leader" (1 seul, élu) ◄──────────┘
   apparie les MMR proches
   ReserveServer() ─────────────────►  Infos du match  ─────────────►  lit les infos, attend les 2 joueurs
   écrit les assignations ──────────►  Assignations
 Chaque lobby téléporte ses joueurs ─────────────────────────────────►  compte à rebours, partie
                                                                        Elo appliqué + sauvegarde
 Retour au lobby  ◄──────────────────────────────────────────────────  téléportation retour
```

- La fourchette de MMR acceptée commence à ±75 et s'élargit de 8 par seconde d'attente (max ±600).
- Une seule place Roblox sert aux deux : serveur public = map principale (« lobby »), serveur réservé = match
  (`src/server/Main.server.luau`).
- Toute la logique est côté serveur : le client ne fait que demander (poser, améliorer, vendre une tour)
  et le serveur vérifie l'or, la position, le propriétaire de la tour, etc.
- Si l'adversaire ne se connecte pas dans les 45 s, le match est annulé sans perte de MMR.

## Installation

1. Installe [Rojo](https://rojo.space) (via [Rokit](https://github.com/rojo-rbx/rokit) : `rokit install` dans ce dossier)
   et le plugin Rojo dans Studio.
2. Dans ce dossier :
   ```bash
   rojo build -o RankedTD.rbxl   # génère la place, à ouvrir dans Studio
   # ou, pour synchroniser en direct pendant que tu codes :
   rojo serve                     # puis "Connect" dans le plugin Rojo
   ```
3. Publie la place : **File > Publish to Roblox**.

Rien d'autre à configurer : les téléportations vers un serveur réservé de la même place sont autorisées par défaut.

## Tester

**Le gameplay dans Studio** : mets `Config.STUDIO_FORCE_MODE = "Match"` dans `src/shared/Config.luau`.
- `Test > Clients and Servers` avec 2 joueurs → vrai match (MMR appliqué sur des données en mémoire).
- `Play` en solo → après 10 s, l'autre terrain est joué par un bot simple (match non classé).

**Le matchmaking** ne peut pas marcher dans Studio (pas de `TeleportService`). Publie le jeu et
rejoins-le avec deux comptes (ou avec un ami) : cliquez tous les deux sur « Jouer en ranked ».

**Tests automatiques** : `tools/studio-test/` ouvre le jeu dans Studio, joue un scénario, prend des captures
et récupère la fenêtre Sortie (voir son README).

Dans Studio, les DataStores sont simulés en mémoire (`Config.Data.MOCK_IN_STUDIO`). Pour utiliser les
vrais depuis Studio, passe-le à `false` et active *Game Settings > Security > Enable Studio Access to API Services*.

## Réglages

Tout est dans `src/shared/Config.luau` (MMR de départ, K, fourchettes du matchmaking, or de départ,
durée des vagues...). Les stats des tours sont dans `Towers.luau`, les ennemis et la composition des
vagues dans `Enemies.luau`, le tracé du chemin dans `MapLayout.luau`.

## Structure

```
src/
  shared/   (ReplicatedStorage.Shared)   Config, IdleConfig, IdleTowers, NumberFormat, Elo, Ranks, Towers, Enemies, MapLayout, PlotLayout, Placement, Remotes
  server/   (ServerScriptService.Server) Main, PlayerData, Leaderboard, Matchmaking, Monetization, Hub/{init, HubMap, Plots, PlotGame, IdleTowerModel}, Match/{init, Game, MapBuilder}
  client/   (StarterPlayerScripts.Client) Main, LobbyUI, PlotUI, PlotRenderer, MachineUI, RebirthUI, ShopUI, MatchUI, TowerCard, TowerPlacement, Effects, UI
```

## Limites connues / pistes d'amélioration

- Les ennemis sont des parts déplacées par le serveur : très bien pour un 1v1, mais au-delà de
  quelques centaines d'ennemis, il vaudrait mieux ne répliquer que leur progression et les afficher côté client.
- Aucune pénalité si un joueur ne se connecte pas au match (il peut « esquiver » un adversaire).
- L'appariement est glouton (voisins de MMR) : suffisant pour une petite population de joueurs.
- Pas de protection contre deux comptes du même joueur qui s'affrontent (boost de MMR).

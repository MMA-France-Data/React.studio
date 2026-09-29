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
Au centre, le **sceau de l'Arène royale** : entre dedans et clique « ⚔ S'INSCRIRE AU CLASSÉ », puis retourne
jouer : le match te sera proposé dès qu'un adversaire est trouvé (voir « S'inscrire et accepter un match
classé »). On va à pied à sa parcelle et au sceau (plus de boutons de raccourci).

## Le mode infini (ta parcelle)

- Des vagues sans fin arrivent sur ta parcelle. **Impossible de perdre**, mais pas de PV de base : si **un seul**
  ennemi atteint ta base, la vague est ratée, tu redescends d'une vague et tu réessaies. Vague réussie → vague suivante.
- Les gains grandissent de ×1,25 par vague et les PV un peu plus vite (×1,47 vers la vague 10, ×1,31 à la 50,
  ×1,28 à la 100 ; réglages dans `IdleConfig.luau`) : les pièces passent de quelques unités à des trillions,
  puis des quadrillions, des quintillions… (réglé avec `tools/balance`, voir `tools/balance/RESULTS.md`).
- 5 types de vagues : **Escarmouche**, **Levée des écuyers** (masse de petits soldats → tours de zone),
  **Charge de cavalerie** (rapides → ralentissement), **Garde colossale** (un seul chevalier colossal, lent et
  blindé → gros dégâts), **Seigneur de guerre** toutes les 10 vagues (un seul boss et son escorte).
- Bonus de début : +50 % de pièces à la vague 1, qui fond jusqu'à 0 à la vague 40 (`IdleConfig.earlyRewardBonus`) ;
  50 pièces au départ.
- Les ennemis tués lâchent des **pièces à ramasser** (les pièces proches s'empilent). Le bonus de pièces
  s'additionne : ennemi à 3 pièces, +100 % → 6, +200 % → 9.
- **Une unité meurt → la suivante sort tout de suite** : chaque ennemi tué fait sortir le prochain ennemi de la
  vague **sans attendre** son heure normale, même s'il en reste d'autres en vie (`IdleConfig.SPAWN_NEXT_ON_KILL`).
  Plus tu tues vite, plus la vague sort vite : utile pour remonter vite après une renaissance. Les ennemis ne
  marchent pas plus vite (pas de rattrapage) et sortent toujours aussi à leur heure normale si personne ne meurt.
- **Vague écrasée** : quand plus **aucun** ennemi n'est en vie sur ta parcelle et qu'il en reste à faire sortir,
  le suivant sort **tout de suite** (l'attente est sautée). Avec la règle du dessus, elle ne sert presque plus.
  Les deux marchent aussi en Vitesse x2 (`IdleConfig.COMPRESS_EMPTY_SPAWNS`, `PlotGame:simulate`).
- 8 défenses (`IdleTowers.luau`) : Archer du rempart, Totem de givre, Catapulte, Mage des tempêtes,
  Baliste lourde, Sorcier des arcanes, Oracle de la foudre et Trébuchet royal. Clique sur un emplacement
  libre pour poser une défense. Clique sur une tour pour voir sa fiche (dégâts par coup, attaques par seconde,
  zone, contrôle, effets, « Idéale contre : … » écrit dans `idealAgainst`) : « Remplacer… » puis une
  confirmation la remplace (50 % remboursés), vendre (2 clics) rend 50 %.
  Le serveur refuse toute pose sur une tour existante sans cette confirmation (`PlotGame:placeTower`).
- **Projectiles** (flèches de l'Archer, rochers de la Catapulte, carreaux de la Baliste, pierres du
  Trébuchet) : la tour vise l'endroit où **sera** l'ennemi quand le projectile arrivera (sa vitesse, son
  ralentissement et le chemin sont pris en compte), et les dégâts tombent **à l'impact**, pas au tir. Temps de
  vol : `projectileSpeed` (et `projectileMinFlight` pour les tirs en cloche) dans `IdleTowers.luau`. Une tour
  ne tire pas sur un ennemi que les projectiles déjà en vol vont tuer : elle en vise un autre. Une flèche dont
  la cible meurt en vol touche l'ennemi le plus proche du point d'impact (à 1,5 stud au plus), sinon elle est
  perdue. Les tirs instantanés restent instantanés : Totem, Mage des tempêtes, Oracle, rayon du Sorcier.
- **Les projectiles suivent leur cible** (bug vu en jeu : la Catapulte visait avant de savoir le
  ralentissement que l'ennemi allait prendre pendant le vol, et tirait trop loin) : flèche de l'Archer, rocher
  de la Catapulte et carreau de la Baliste tombent là où leur cible est **vraiment** à l'impact (zone, zone de
  feu, ligne du carreau), si elle vit encore et reste à moins de (sa zone + 6) studs du point prévu
  (`IdleTowers.followDistance`, `PROJECTILE_FOLLOW_MARGIN`) ; sinon au point prévu. Le client fait voler le
  projectile vers l'ennemi affiché (en gardant la cloche). Le **Trébuchet royal** garde son point prévu : il
  vise une foule, pas un ennemi.
- **Contrôles : jamais de cumul** (règle du propriétaire). Un ennemi ne subit qu'**un seul** effet de contrôle
  à la fois : ralentissement du Totem de givre, ralentissement du Mage des tempêtes ou étourdissement du
  Trébuchet royal, et sa force ne se multiplie jamais (deux Totems = un seul -60 %). Un Totem peut prolonger
  le ralentissement d'un Totem ; une autre sorte de tour ne peut rien tant qu'il dure (premier arrivé, premier
  servi). Les dégâts, eux, tombent toujours. Totem et Mage ne se cumulent donc pas : à toi de choisir
  (`applyControl` dans `PlotGame.luau`).
- **Fatigue des contrôles courts** (retour de test à la vague 148 : plein de Mages avec la rune x2 vitesse
  gelaient toute la vague, et les Catapultes finissaient le travail) : un ralentissement du **Mage** ou un
  étourdissement du **Trébuchet** n'est **jamais prolongé** (il dure exactement 0,6 s ou 0,5 s), et quand il
  se termine, l'ennemi est **immunisé** contre les ralentissements du Mage pendant **0,8 s**
  (`IdleTowers.Defs.Tesla.slowImmunity`), contre les étourdissements pendant **1,5 s** (`stunImmunity`).
  Donc un ennemi n'est jamais ralenti par les Mages plus de 43 % du temps (0,6 s sur 1,4 s), ni étourdi plus
  de 25 % du temps, quel que soit le nombre de ces tours et leurs runes. L'immunité ne bloque que ce type de
  tour : le Totem de givre peut prendre le relais (lui n'a pas de fatigue : une aura est faite pour durer).
  La fiche de la tour le dit (« puis 0,8 s d'immunité »).
- **Archer du rempart** : portée 21 (15 avant) et **flèches enflammées** : chaque flèche laisse au sol une
  petite zone de feu (rayon 2,5) qui brûle tous les ennemis dedans, **40 % des dégâts de la flèche par
  seconde** pendant 2 s (un coup toutes les 0,5 s). Une flèche qui tombe dans une zone de la même tour la
  ravive ; 5 zones au plus par Archer et 30 par parcelle. Niveaux, doublons et runes de dégâts renforcent
  aussi le feu. (10 % et rayon 2,25 au premier essai : le feu ne changeait presque rien, voir
  `tools/balance/RESULTS.md`.)
- **Mage des tempêtes** : sa foudre frappe une **petite zone** (rayon 3, la Catapulte fait 7) : les ennemis
  collés à sa cible prennent aussi les dégâts (10 au niveau 1, inchangés) et un ralentissement **très fort mais
  court** (-90 % pendant 0,6 s, puis 0,8 s d'immunité : voir la fatigue plus haut ; le Totem : -60 %). Il ne
  s'applique pas à un ennemi déjà gelé par un Totem (et inversement), et ses dégâts ne profitent pas de la
  fragilité du Totem : pas de synergie Givre + Mage.
- **Baliste lourde** : vise toujours l'ennemi le plus résistant, mais son carreau est **perçant** : à l'impact,
  tous les ennemis à moins de 1,25 stud (`pierceWidth`) de la ligne tour → point d'impact prennent les dégâts
  (sa cible comprise). Elle remplace sa toute petite zone d'avant (rayon 2).
- **Trébuchet royal** : vise le point du chemin où sa **grande zone** (rayon 10) touchera **le plus d'ennemis**
  (positions prévues à l'arrivée de la pierre ; à égalité, le groupe le plus avancé), partout à portée (70), et
  **étourdit** la zone 0,5 s (un contrôle : pas sur un ennemi déjà ralenti par une autre tour ; puis 1,5 s
  d'immunité aux étourdissements : plusieurs Trébuchets ne peuvent pas les enchaîner). Très fort
  contre les foules, faible contre un boss seul, exprès (`PlotGame:pickCrowdTarget`).
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
  à niveau égal (Oracle : 50 dégâts par ennemi touché, Trébuchet : 35 à chaque ennemi de sa grande zone) ; les
  tours communes compensent avec leurs centaines de doublons.
- Clique sur **n'importe quel cadenas** pour débloquer cet emplacement. Tous les cadenas affichent le même prix
  (celui de ton prochain emplacement), qui monte après chaque achat. Les emplacements possédés sont sauvegardés
  dans `data.idle.ownedSpots` (`unlockedSpots` = leur nombre) ; les anciennes sauvegardes sont converties
  automatiquement (`PlayerData.luau`).
- **Améliorations** : clique sur une tour → « Améliorer » (ou touche E). Niveaux illimités, dégâts ×1,35 par
  niveau, prix ×1,35 par niveau (20 pièces pour le niveau 2, le même prix pour toutes les tours). Les PV des
  vagues montent un peu plus vite que les gains (×1,28 à ×1,47 contre ×1,25) :
  on bloque souvent, on farme un peu, une amélioration débloque les vagues suivantes.
- Chemin de ~360 studs (6 allers-retours) et ennemis 1,35× plus rapides qu'en ranked, sauf les cavaliers
  et les écuyers, freinés (13 studs/s), et les chevaliers lourds, colosses et Seigneurs de guerre, un peu
  moins lents (`IdleConfig.ENEMY_SPEED_FACTORS`).
- Le **Totem de givre** est une tour de **contrôle** : il ralentit de 60 % tout ce qui passe dans son aura
  (et encore 2,5 s après) et rend ces ennemis **fragiles** : ils prennent +X % de dégâts de toutes tes autres
  tours sauf le Mage des tempêtes, avec X = 10 % au niveau 1, +2 % par niveau (+100 % au niveau 46, +300 % au plus ;
  `fragilityBase`, `fragilityPerLevel`, `fragilityMax`). Deux Totems ne s'additionnent pas (le plus fort gagne),
  et la fragilité suit l'aura (2,5 s après la sortie). Ses propres dégâts restent faibles (2 au niveau 1, 6
  avant) et ne profitent pas de la fragilité, ni de la sienne ni de celle d'un autre Totem (`ignoresFragility`) :
  pas de partie « tout givre » (réglé avec `tools/balance`, voir `tools/balance/RESULTS.md`).
- **Styles des ennemis** : un style par tranche de 10 vagues (vagues 1-10, 11-20 … 91-100 : 10 styles, dont un
  dragon en boss aux vagues 81-90 et une horde gobeline aux vagues 91-100), puis les styles recommencent.
  Le client choisit le style avec l'attribut `Wave` de la parcelle quand l'ennemi apparaît
  (palier = (vague − 1) / 10 arrondi en dessous, `PlotRenderer.luau` ; modèles dans `MedievalModels.luau`).
  Le ranked garde ses modèles de toujours.
- **Sous les ennemis**, un disque montre le contrôle en cours : bleu glacé = ralenti par un Totem de givre,
  jaune = ralenti par un Mage des tempêtes, doré = étourdi par le Trébuchet royal, violet = seulement fragile.
  Un ennemi fragile a aussi un contour violet sur sa barre de vie. Le carreau de la Baliste laisse une traînée
  sur la ligne touchée, la pierre du Trébuchet une onde dorée de la taille de sa zone.
- **Vague, record et ennemis restants** : sur le tableau « CHRONIQUES DU FIEF » de ta parcelle (avec le DPS total :
  niveaux, doublons et runes compris ; `Hub/PlotBoard.luau`). Plus de panneau de vague en haut de l'écran : seul
  le compteur de pièces « 💰 » y reste (`PlotUI.luau`).
- Fiches des tours (cartes et fiche d'une tour posée) : dégâts par coup, attaques par seconde (« continu » pour
  le rayon), zone / cibles / ligne perçante / aura, contrôle, effets. La ligne « Idéale contre » est dans la
  fiche d'une tour posée, et sur les cartes en survolant une carte avec la souris (`PlotUI.luau`). La fiche
  d'une tour posée dit aussi ses runes (« Runes : x20 dégâts • x2 vitesse », déjà comptées dans ses chiffres).

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
  x10 000 = 294 456. Pour un joueur qui achète régulièrement (simulateur : ~340 lancers à 10 h, ~1 100 à
  25 h, ~2 750 à 50 h), un lancer coûte ~0,03-0,04 vague de gains : x100 ≈ 3-4,5 vagues (achat courant), x1 000 ≈
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
  record 200 (la première arrive vers la vague 65-75, après ~8 h de jeu, dans le simulateur). Un doublon donne +2 % de
  dégâts permanents à cette tour. Les gros lots ne lancent pas un million de fois : le serveur tire directement
  combien de tours tombent de chaque rareté (`PlotGame:spinTower`). Un lancer gratuit en attente dans une
  ancienne sauvegarde est remboursé en pièces (`PlayerData.luau`).
- **Forge runique** : x2 dégâts, x2 vitesse d'attaque, x3, x5, x10, x20, x50, x100 dégâts. La rune va dans
  l'inventaire et se pose sur une tour. **Chaque tour a 2 emplacements de rune qui se cumulent** : un pour une
  rune de **dégâts**, un pour la rune de **vitesse** (ex. Archer avec x20 dégâts et x2 vitesse : 20 fois plus
  de dégâts par flèche et 2 fois plus de flèches par seconde). Poser une rune ne remplace que la rune de la
  **même sorte** (l'ancienne est perdue, 2 clics pour confirmer) ; l'autre reste. Vendre ou remplacer la tour
  rend ses runes (tant que l'inventaire a de la place). La fiche d'une tour posée affiche
  « Runes : x20 dégâts • x2 vitesse ». Sauvegarde : `idle.towers[emplacement].runes = { Damage = id, Speed = id }` ;
  les anciennes sauvegardes (1 rune par tour, champ `bonus`) sont converties toutes seules, la rune va dans
  l'emplacement de sa sorte (`PlayerData.luau`). Le modèle de la tour publie ses runes dans l'attribut `Bonus`
  (« Damage20,Speed2 », `IdleConfig.runeList`), lu par la fiche et par le tableau du fief.
  - **Plus de délai** entre deux lancers en pièces (avant : 1 toutes les 30 minutes). Le prix monte à chaque
    lancer en pièces, pour toujours (compteur `data.idle.forgeSpinsBought`, jamais remis à zéro, même à la
    renaissance) : 100 K le tout premier, puis x5 à chaque lancer tant que le prix est sous 1 T, puis x2 :
    100 K, 500 K, 2,5 M … 976 B (11e), 4,88 T (12e), 9,76 T, 19,5 T… (`IdleConfig.forgeCoinPrice`).
  - Les lancers **Robux** restent à volonté : ils ne comptent pas et ne font pas monter le prix.
  - **Seulement des runes utiles** : une rune n'est tirée que si elle améliore au moins une tour **posée**
    dans **l'emplacement de sa sorte** (une rune de dégâts xM est exclue quand toutes les tours posées ont déjà
    une rune de dégâts xM ou mieux ; x2 vitesse est exclue quand toutes ont déjà x2 vitesse ; les runes de
    l'inventaire ne comptent pas). Les chances des runes restantes sont remises sur 100 %. Si plus rien
    n'améliore une tour (x100 dégâts ET x2 vitesse sur toutes), la forge est bloquée (« Toutes tes tours ont les
    meilleures runes », ou « Pose d'abord une tour ») : bouton pièces et bouton Robux. Si un achat Robux arrive
    quand même (ex. tour vendue pendant l'achat), la meilleure rune (x100 dégâts) est donnée : un achat n'est
    jamais perdu.
  - Le serveur publie l'état de la forge en attributs du joueur : `ForgeSpinsBought`, `ForgeCoinPrice` (-1 =
    « MAX »), `ForgeDrawable` (runes tirables) et `ForgeBlocked` (message, vide si la forge marche)
    (`PlotGame:publishForge`). Les anciennes sauvegardes démarrent à 0 lancer (`PlayerData.luau`).
- **Robux** : crée un Developer Product dans le Creator Dashboard et mets son ID dans
  `Config.Products.BONUS_SPIN`. Chaque achat n'est livré qu'une fois (`Monetization.luau`).
- Côté technique, les ennemis n'existent que sous forme de données sur le serveur ; chaque client reçoit leurs
  positions 6 fois par seconde dans un paquet binaire et les affiche lui-même (`PlotGame.luau`, `PlotRenderer.luau`).
  Les tirs partent 10 fois par seconde dans un autre paquet, avec le temps de vol qui reste à chaque projectile :
  le client le fait arriver au moment où le serveur applique les dégâts. Après les tirs, le paquet contient
  l'id (4 octets) de la cible que suit chaque projectile (0 = aucune) : le client le fait voler vers cet ennemi.
  Le rayon du Sorcier est publié sur sa
  tour (attributs `BeamTarget` = id de l'ennemi visé, `BeamRamp` = montée) et dessiné à chaque image.
  Après les positions, le paquet des ennemis contient 1 octet « contrôle » par ennemi : la tour dont le contrôle
  est en cours (Totem, Mage ou Trébuchet, 0 = aucune) et un drapeau « fragile » (détails en haut de `PlotGame.luau`).

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
| File d'attente | `src/server/Matchmaking.luau` | Inscription dans le cercle, MemoryStore SortedMap triée par MMR partagée par tous les serveurs, match à accepter (`MatchmakingBackend.luau` : en mémoire dans Studio) |
| Match | `src/server/Match/` | Serveur réservé, attend les 2 joueurs, applique l'Elo, renvoie au lobby |
| Classement | `src/server/Leaderboard.luau` | OrderedDataStore par saison, affiché sur un panneau dans le lobby |
| Saisons | `Config.SEASON` | Nouvelle saison = soft reset du MMR (moitié de l'écart à 1000) + nouveau classement |

### Déroulement d'un match classé

```
 Lobby (serveur public)                MemoryStore                   Serveur de match (réservé)
 ─────────────────────                 ───────────                   ──────────────────────────
 « S'INSCRIRE » dans le cercle ────►  File (triée par MMR)
   (le joueur repart jouer)                │
 Serveur "leader" (1 seul, élu) ◄──────────┘
   forme les paires ────────────────►  Proposition + invitations
 Chaque lobby : « MATCH TROUVÉ ! »
   ACCEPTER / REFUSER ──────────────►  Réponses (UpdateAsync)
 Le lobby du 2e qui accepte :
   ReserveServer() ─────────────────►  Infos du match  ─────────────►  lit les infos, attend les 2 joueurs
   proposition « Started » ─────────►  code d'accès
 Chaque lobby téléporte ses joueurs ─────────────────────────────────►  compte à rebours, partie
                                                                        Elo appliqué + sauvegarde
 Retour au lobby  ◄──────────────────────────────────────────────────  téléportation retour
```

### S'inscrire et accepter un match classé

- **S'inscrire** : entre dans le sceau rouge au centre de la map. Un gros bouton « ⚔ S'INSCRIRE AU CLASSÉ »
  apparaît, seulement tant que tu es dans le cercle (au-dessus de ton personnage : il ne cache ni le chat ni le
  panneau des tours). Le serveur vérifie que tu es vraiment dans le cercle (sa position à lui, attribut
  `InRankedCircle`), que tu n'es pas déjà inscrit, et au plus une inscription toutes les 2 s
  (`Config.Matchmaking.SIGNUP_COOLDOWN`). Message : « Tu es inscrit au classé ! Tu peux partir jouer : on te propose
  le match dès qu'un adversaire est trouvé. »
- **Tu restes inscrit en partant** : retourne sur ta parcelle et joue. En bas à droite, partout sur la map :
  « ⚔ Recherche d'un adversaire… 1:23 » et « ANNULER » (quand le panneau des tours est ouvert, ce statut passe
  juste au-dessus).
- **Match trouvé** : fenêtre « ⚔ MATCH TROUVÉ ! » au centre de l'écran : le nom de l'adversaire, son rang et son
  MMR (ou « Placement 2/5 », MMR caché, comme sur la carte de rang), une barre de **15 s**
  (`Config.Matchmaking.ACCEPT_SECONDS`), « ACCEPTER » et « REFUSER ». Après ACCEPTER : « En attente de
  l'adversaire… » (plus d'annulation possible : on attend l'autre).
- **Les deux acceptent** : le match est créé (serveur réservé) et chacun est téléporté, comme avant.
- **Refus** (REFUSER, ANNULER ou quitter le jeu) : « Tu as refusé le match », tu quittes la file. **Pas de réponse
  à temps** : « Match non accepté à temps : tu es retiré de la file ». L'autre joueur retourne tout seul dans la
  file avec son heure d'inscription (« Ton adversaire n'a pas accepté : retour dans la file ») : il garde son
  attente, donc sa grande fourchette de MMR et sa priorité. Pareil si l'un des deux quitte le jeu après avoir
  accepté, tant que le match n'est pas encore créé (l'autre ne part pas attendre seul sur le serveur de match).
- **Priorité** : le leader forme les paires en commençant par ceux qui attendent depuis le plus longtemps, chacun
  avec le joueur de MMR le plus proche dans la fourchette.
- **Jamais bloqué** : chaque étape a une limite de temps. Le serveur laisse 3 s de plus que la barre
  (`ACCEPT_GRACE` : le temps que la proposition arrive et un petit écart d'horloge entre serveurs), la création
  du match a 30 s (`START_TIMEOUT`, sinon les deux retournent dans la file, attente gardée), la téléportation 60 s
  (`TELEPORT_TIMEOUT`, sinon message et il faut se réinscrire), et tout expire tout seul dans MemoryStore. Si
  MemoryStore ne répond plus, chaque serveur libère ses joueurs tout seul (heure limite + `START_TIMEOUT`).
- **Entre serveurs** (détails et schéma des états en haut de `Matchmaking.luau`) : le leader écrit une
  **proposition** et une invitation pour chacun des deux joueurs ; chaque réponse est écrite avec `UpdateAsync`
  (une seule décision possible) ; le serveur du 2e qui accepte crée le match (serveur réservé, infos dans
  `RankedTD_Matches`, lues par `Match/init.luau` comme avant) ; puis chaque lobby téléporte SES joueurs, une seule
  fois. États du joueur (attribut `QueueState`, lu par `LobbyUI.luau`) : Idle, Joining, Searching, Pending (match
  proposé), Accepted, Found (les deux ont accepté), Teleporting.
- Rien ne change dans le match lui-même : mêmes règles, même Elo, mêmes défis classés.

- La fourchette de MMR acceptée commence à ±75 et s'élargit de 8 par seconde d'attente (max ±600).
- Une seule place Roblox sert aux deux : serveur public = map principale (« lobby »), serveur réservé = match
  (`src/server/Main.server.luau`).
- Toute la logique est côté serveur : le client ne fait que demander (poser, améliorer, vendre une tour)
  et le serveur vérifie l'or, la position, le propriétaire de la tour, etc.
- Si l'adversaire ne se connecte pas dans les 45 s, le match est annulé sans perte de MMR.

## Défis classés

- **3 défis par jour et 2 par semaine**, les mêmes pour tout le monde (tirés avec le numéro du jour ou de la
  semaine comme graine). Nouveaux défis du jour à **00:00 UTC** (2 h du matin en France l'été), de la semaine le
  **lundi à 00:00 UTC**. Ils se font en **match classé** et récompensent le **mode solo** : rien ne change dans un
  match (mêmes tours, même or pour tout le monde), le serveur de match ne fait que compter à la fin.
- **Un match compte** s'il a duré au moins **3 min** et si tu n'as pas déjà compté **2 matchs** aujourd'hui contre
  le même adversaire (`MIN_MATCH_SECONDS`, `MAX_MATCHES_PER_OPPONENT`). Un match contre le bot (tests Studio) ne
  compte jamais. Sinon, la fin du match dit pourquoi (« Défis : match de moins de 3 min, il ne compte pas »).
- **Défis du jour** (3 de sortes différentes parmi 7) : Joue 2 matchs classés • Gagne 1 match classé • Tiens
  6 minutes dans un match classé • Pose 15 tours • Améliore tes tours 10 fois • Gagne un match avec 3 types de
  tours différents • Tiens 15 minutes au total. **De la semaine** (2 parmi 6) : Joue 10 matchs • Gagne 5 matchs •
  Tiens 45 minutes au total • Pose 60 tours • Améliore tes tours 40 fois • Gagne 3 matchs avec 3 types de tours.
- **Récompenses** (bouton « ⚔ DÉFIS » dans la colonne de gauche, pastille = récompenses prêtes, puis
  « Récupérer ») : défi du jour = **8 vagues de gains à ton record** (~13 min de farm, bonus de pièces compris une
  fois, au moins 250 pièces), + **10 lancers de l'Autel des héros** pour « Gagne 1 match » et « Gagne avec 3 types ».
  Défi de la semaine = **25 vagues** (au moins 1 000 pièces) + **1 lancer de la Forge runique**. Les lancers
  offerts ne font pas monter les prix (compteurs `towerSpinsBought` et `forgeSpinsBought` inchangés) ; la forge
  marche comme un lancer Robux (seulement les runes utiles, emplacement par emplacement ; meilleure rune si les
  2 emplacements de toutes tes tours posées ont déjà la meilleure ; sans aucune tour posée, chances de base).
  Le pass Pièces x2 ne double pas ces pièces.
- Une récompense **pas récupérée avant les nouveaux défis est perdue** (la fenêtre le dit).
- Code : `src/shared/Challenges.luau` (règles, listes, récompenses, tous les réglages), `src/server/Match/init.luau`
  (compte le match à la fin, chiffres des terrains dans `Match/Game.luau`), `src/server/Hub/ChallengeRewards.luau`
  (état publié au client, bouton « Récupérer » revérifié par le serveur), `src/client/ChallengeUI.luau` (fenêtre).
  Sauvegarde : `data.challenges` (`PlayerData.luau`, anciennes sauvegardes complétées toutes seules).
- **Tester dans Studio** (vue Serveur, barre de commande) : `game.ServerStorage.StudioDebug:Invoke(game.Players:GetPlayers()[1],
  "ChallengeMatch", { seconds = 240, won = true, opponentId = 42, towersPlaced = 6 })` = un match classé terminé,
  compté comme sur le serveur de match ; `"Challenges"` = l'état ; `"ChallengeClock", 86400` = demain (`0` = heure
  réelle). Liste complète en haut de `setupStudioDebug` (`Hub/init.luau`).

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

**Le matchmaking dans Studio** : la file tourne en mémoire (`MatchmakingBackend.luau`, un seul serveur) et
personne n'est téléporté (quand les deux ont accepté, un message dit que la téléportation partirait). Entre dans
le cercle, clique « S'INSCRIRE », puis dans la barre de commande (vue Serveur) :
`game.ServerStorage.StudioDebug:Invoke(game.Players:GetPlayers()[1], "Ranked", "FakeOpponent")` : un adversaire
factice s'inscrit et la fenêtre « MATCH TROUVÉ ! » s'ouvre. `"OpponentAccept"`, `"OpponentRefuse"` ou `"Expire"`
le font accepter, refuser ou laisser passer le temps, `"State"` montre l'état (liste complète en haut de
`setupStudioDebug`, `Hub/init.luau`). Avec *Test > Clients et serveurs* et 2 joueurs, les deux peuvent s'inscrire
et accepter pour de vrai. **Le vrai test** (plusieurs serveurs, téléportation) : publie le jeu et rejoins-le avec
deux comptes (ou avec un ami) : inscrivez-vous tous les deux dans le cercle, puis acceptez le match.

**Tests automatiques** : `tools/studio-test/` ouvre le jeu dans Studio, joue un scénario, prend des captures
et récupère la fenêtre Sortie (voir son README).

**La galerie des ennemis** (Studio seulement, jamais dans le jeu publié) : en `Play` sur la map principale, le
bouton « GALERIE (Studio) » de la colonne de gauche t'emmène voir les 6 ennemis du mode solo dans les 10 styles
(une rangée par tranche de 10 vagues), construits exactement comme en jeu ; « ← RETOUR » te ramène. Elle est
derrière les montagnes, loin des parcelles. `Config.STUDIO_ENEMY_GALLERY = false` pour ne plus la construire
(`src/client/EnemyGallery.luau`, qui décrit aussi le crochet pour les tests automatiques).

Dans Studio, les DataStores sont simulés en mémoire (`Config.Data.MOCK_IN_STUDIO`). Pour utiliser les
vrais depuis Studio, passe-le à `false` et active *Game Settings > Security > Enable Studio Access to API Services*.

## Mettre tes propres modèles de monstres

Les ennemis du mode solo peuvent utiliser de vrais modèles 3D à la place des blocs (le ranked ne change pas).
Un type sans modèle garde ses blocs : tu peux en ajouter un à la fois.

1. **Trouve un modèle** dans Studio : Toolbox (Boîte à outils) > cherche « goblin » > clic pour l'insérer. Ou
   importe ton fichier 3D (Meshy, Tripo, Mixamo…) avec *Importer 3D*.
2. **Supprime tous ses scripts** (Script, LocalScript, ModuleScript : repère leur icône, pas leur nom, une porte
   dérobée a souvent un nom anodin). Un modèle de la Toolbox peut en cacher une. Le jeu les retire aussi et l'écrit
   dans la Sortie, mais trop tard pour un script piégé.
3. **Renomme-le** avec le type : `Normal` (Fantassin), `Fast` (Cavalier), `Tank` (Chevalier lourd), `Boss`
   (Seigneur de guerre), `Swarm` (Écuyer), `Giant` (Chevalier colossal). `Boss_9` = seulement les vagues 91-100,
   `Swarm_0` = vagues 1-10 (passe avant `Swarm`). Taille et position : réglées toutes seules.
4. **Essaie-le** : glisse-le dans ReplicatedStorage > `EnemyModels` (crée ce Folder s'il manque), puis Play.
   La galerie (bouton « GALERIE (Studio) ») écrit « modèle perso » ou « blocs » sous chaque ennemi.
5. **Garde-le** : clic droit > *Enregistrer dans un fichier…* dans `assets/EnemyModels/`, même nom
   (`Swarm.rbxm`), puis `rojo build` et pousse le fichier sur GitHub.
6. **Marche animée** (facultatif) : un objet Animation nommé `Marche` (ou `Walk`, `Walking`) dans le modèle
   (personnage avec Humanoid ou AnimationController, ou modèle à os importé). L'animation doit être à toi (ou à ta
   communauté si c'est elle qui publie le jeu) ou à Roblox, sinon Roblox refuse de la jouer.
7. **Animation de mort** (facultatif) : pareil avec un objet Animation nommé `Mort` (ou `Dead`, `Death`) : jouée
   une fois quand le monstre est tué, le corps reste un instant puis s'efface. La galerie la montre toutes les 6 s.
   Plus simple : donne juste les **numéros** de tes animations publiées à Claude, qui les écrit dans
   `CustomModels.SETTINGS` (`src/shared/CustomModels.luau`), sans rien ajouter au modèle.

Le **Roi carmin** de ChatGPT (`assets/enemies/crimson-king/RoiCarmin_Studio.glb`, boss des vagues 10, 110,
210…) est un fichier `.glb` : Rojo ne sait pas le lire, il faut l'importer une fois dans Studio (*Importer*,
type de rig « Custom »), enregistrer le modèle dans `assets/EnemyModels/Boss_0.rbxm`, puis publier ses deux
animations `Walking` et `Dead` depuis l'Animation Editor et donner leurs numéros à Claude.

Le sens de marche est trouvé tout seul pour un personnage à os (ses orteils, ou la tête d'un cheval), et si son
animation le retourne d'un demi-tour (défaut de l'import de Studio sur les modèles d'un seul morceau, ex. le Roi
carmin et le fantassin), le jeu le mesure et le corrige tout seul. Sinon : attribut `FacingOffset` = 180 (ou 90 /
-90) sur le modèle ; trop petit ou trop grand : `HeightScale` (1.3, 0.8…). Détails dans
`assets/EnemyModels/README.txt` et `src/shared/CustomModels.luau`.

Import d'un `.glb` avec animations (ex. ceux de ChatGPT) : **Fichier > Importer** du fichier qui contient le modèle
ET l'animation (rig « Custom »), puis Éditeur d'animation > **⋯ > Charger** l'animation > **Publier sur Roblox**.
L'import d'un clip seul dans l'Éditeur d'animation (⋯ > Importer > depuis un fichier) ne marche pas bien avec ces
fichiers (seule la tête bouge, ou le modèle s'étire). L'os racine du squelette doit être sans rotation (sinon le
modèle bascule quand l'animation joue).

## Réglages

Tout est dans `src/shared/Config.luau` (MMR de départ, K, fourchettes du matchmaking, or de départ,
durée des vagues...). Les stats des tours sont dans `Towers.luau`, les ennemis et la composition des
vagues dans `Enemies.luau`, le tracé du chemin dans `MapLayout.luau`.

## Structure

```
src/
  shared/   (ReplicatedStorage.Shared)   Config, IdleConfig, IdleTowers, NumberFormat, Elo, Ranks, Towers, Enemies, MapLayout, PlotLayout, Placement, Remotes, Challenges
  server/   (ServerScriptService.Server) Main, PlayerData, Leaderboard, Matchmaking, MatchmakingBackend, MockMemoryStore, Monetization, Hub/{init, HubMap, Plots, PlotGame, IdleTowerModel, ChallengeRewards}, Match/{init, Game, MapBuilder}
  client/   (StarterPlayerScripts.Client) Main, LobbyUI, PlotUI, PlotRenderer, MachineUI, RebirthUI, ShopUI, ChallengeUI, MatchUI, TowerCard, TowerPlacement, Effects, UI, EnemyGallery
```

## Limites connues / pistes d'amélioration

- Les ennemis sont des parts déplacées par le serveur : très bien pour un 1v1, mais au-delà de
  quelques centaines d'ennemis, il vaudrait mieux ne répliquer que leur progression et les afficher côté client.
- Aucune pénalité si un joueur ne se connecte pas au match (il peut « esquiver » un adversaire), ni s'il refuse un
  match proposé (à part sa sortie de la file).
- L'appariement est simple (les plus anciens d'abord, chacun avec le MMR le plus proche) : suffisant pour une petite
  population de joueurs.
- Pas de protection contre deux comptes du même joueur qui s'affrontent (boost de MMR).

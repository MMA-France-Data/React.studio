# Outil d'équilibrage du mode solo

Un simulateur « sans écran » du **mode infini** (ta parcelle : vagues sans fin, autel des héros,
améliorations, emplacements, forge runique, renaissance). Il fait tourner les **vrais modules du jeu**
(`src/shared`) hors de Studio, avec la commande `luau`, et joue des dizaines d'heures de jeu en quelques
minutes pour vérifier l'équilibrage. Le ranked n'est pas simulé.

Rien de ce dossier n'entre dans la place construite par `default.project.json` : il n'est jamais publié.

Les résultats du dernier réglage (objectifs, avant / après, ce qui a changé et pourquoi) sont dans
[`RESULTS.md`](RESULTS.md).

Il faut Windows et [Luau](https://github.com/luau-lang/luau/releases) (`luau.exe` dans le PATH ; tape
`luau --help` dans un terminal pour vérifier).

## Lancer

Depuis le dossier `roblox-ranked-td` :

```bat
powershell -ExecutionPolicy Bypass -File tools\balance\idle\run.ps1
```

5 scénarios x 3 parties x 100 h de jeu. Les 15 parties sont jouées **en même temps** (une par cœur du
processeur) : environ 15 min sur un PC à 12 cœurs logiques (plus d'1 h 30 une par une : la visée du
Trébuchet, les projectiles, le feu et le rayon du Sorcier demandent beaucoup de calcul). Pour un essai rapide
(environ 5 minutes : 3 parties x 40 h, scénario `base` seulement) :

```bat
powershell -ExecutionPolicy Bypass -File tools\balance\idle\run.ps1 -Rapide
```

Autres options (à ajouter après `run.ps1`) :

```bat
-Graines 5 -Heures 50                  plus ou moins de parties, plus ou moins longues
-Scenarios base,sans-sorcier           seulement certains scénarios
-Journal                               écrit aussi out\journal.txt : tout ce que fait le joueur simulé (1re partie)
-Pas 0.0166667                         pas de 1/60 s comme le jeu (plus lent ; résultats à 10 % près)
-Regler "IdleConfig.UPGRADE_COST_GROWTH=1.3;PlotLayout.SPOT_COST_GROWTH=2.5"   essai de réglages (voir plus bas)
-Verifier                              vérifie que le moteur joue comme le vrai PlotGame.luau (quelques secondes)
-Paralleles 4                          au plus 4 parties en même temps (1 = une après l'autre, comme avant)
```

En parallèle, chaque partie (scénario, graine) est jouée par son propre processus `luau`, qui écrit la partie
terminée dans `idle\gen\runs\` ; un dernier processus relit toutes les parties et écrit le rapport. Le rapport
est exactement le même qu'en jouant les parties une par une (`idle\Dump.luau`). Si tu arrêtes `run.ps1` en
cours de route (Ctrl+C), les parties déjà lancées continuent : ferme les processus `luau` (Gestionnaire des
tâches) avant de relancer.

## Vérifier le moteur (`-Verifier`)

```bat
powershell -ExecutionPolicy Bypass -File tools\balance\idle\run.ps1 -Verifier
```

Charge le **vrai** `src/server/Hub/PlotGame.luau` hors de Studio (avec des imitations de Roblox :
`idle/verif/extra.luau` et `idle/verif/stubs/`), puis fait jouer les mêmes vagues (vagues 8 à 60, 5 équipes :
toutes les tours avec des runes, que des Archers, Sorciers + Totem + Mage, zones et projectiles, et
« contrôles » : 2 Totems, 2 Mages, 2 Trébuchets, 2 Balistes, 2 Archers) au jeu et au moteur du simulateur
(`idle/verif/parity.luau`). Il affiche `OK` si toutes les vagues ont le même résultat (réussie ou ratée),
presque la même durée (2 s d'écart au plus) et les mêmes pièces. Pour une comparaison exacte, le pas de temps
vaut 1/32 s dans les deux (un nombre exact en binaire), la parcelle est au centre du monde et le moteur n'a pas
sa petite marge d'arrondi (`Engine.EPS = 0`). Dernier résultat : 135 vagues sur 135 identiques, 0,06 s d'écart
au plus (avec la règle « un seul contrôle à la fois », la fragilité, le carreau perçant, la visée du Trébuchet,
l'étourdissement, la sortie à chaque mort et la vague écrasée). **À relancer après chaque changement de combat dans `PlotGame.luau`** :
s'il affiche `DIFFÉRENCES`, fais le même changement dans `idle/Engine.luau`.

## Les résultats (`tools\balance\idle\out\`)

- `rapport.txt` : le rapport à lire (aussi affiché à l'écran), dans cet ordre :
  1. **Comparaison aux objectifs** : chaque objectif du mode solo, sa cible, la valeur mesurée et un
     verdict (`OK`, `TROP LENT`, `TROP LONGS`, `PAS ATTEINT`…), puis le nombre d'objectifs atteints.
  2. **Lecture des réglages** : des calculs directs sur les réglages (sans simulation) qui expliquent
     les résultats : croissance des PV et des pièces d'une vague à la suivante, de combien le temps de
     farm grandit, la valeur « neutre » de `UPGRADE_COST_GROWTH`, l'écart de prix entre deux emplacements,
     la puissance des tours à budget égal. Tout est lu dans les fonctions du jeu (`healthBudget`,
     `upgradeCost`…) : si tu changes une formule, cette partie suit.
  3. **Un bloc par scénario** : lancers achetés à l'autel (combien, quels lots, à partir de quel record, part
     des dépenses), **compteur de lancers et prix du prochain x1 / x100 / x10 000 à 1, 10, 25, 50 et 100 h**
     (en pièces et en vagues de gains), **première tour légendaire** (quand, à quelle vague), jalons (vagues 5,
     10, 15, 20, 25, 30, 40, 50…), murs, emplacements achetés (5e, 6e… : quand, à quel prix, lequel), tours
     obtenues à l'autel, part des dégâts de chaque tour.
  4. **Comparaison des scénarios** : temps pour atteindre chaque vague.
  5. **Grands nombres** : pour chaque scénario, record, pièces en poche, revenu par minute et total gagné
     à 1, 5, 10, 25, 50, 80, 90 et 100 h (valeur du milieu des graines), l'heure où le revenu atteint
     1 M, 1 B, 1 T, 1 Qa… par minute, puis les **limites des nombres** : la vague et le niveau
     d'amélioration où un montant deviendrait infini (au-delà de ~1,8e308 ; un DataStore ne sait pas
     le sauver), et la vague où NumberFormat passe en notation scientifique (après 10^96).
  6. **Banc d'essai des tours**, puis l'**anti-méta** (compositions extrêmes contre la défense mélangée du
     joueur simulé, même budget : tout Trébuchet, tout givre, Trébuchet + givre, tout Sorcier, tout Catapulte,
     givre + Mage… ; dernière vague réussie en jouant les vagues 1, 2, 3… avec une défense fixe, à 5, 10, 20,
     40 et 80 h), puis les **duels** : UNE tour contre UN seul ennemi (immortel) qui traverse tout le chemin,
     même niveau pour toutes, seule puis avec un Totem de givre voisin ; résultat en fois les dégâts de la
     Baliste lourde (c'est là qu'on voit le rayon du Sorcier battre la Baliste contre les ennemis lents et
     perdre contre les rapides) ; et la **foule** : une tour contre 30 écuyers, en fois la Catapulte (le Totem
     doit rester sous 1).
  7. **Renaissance en boucle**. Le scénario « renaissance » dit aussi combien de temps il faut pour remonter à
     80 % du record de la run après une renaissance (sortie à chaque mort et vague écrasée comprises).
- `timeline.csv` : une ligne par vague passée pour la première fois (scénario, graine, temps, pièces,
  revenu, emplacements, tours, doublons, lancers, bonus de pièces, murs, composition).
- `heures.csv` : une ligne par heure de jeu (record, pièces, revenu, total gagné, emplacements…), pour
  tracer des courbes.
  Les deux CSV utilisent `;` et la virgule décimale : ils s'ouvrent directement dans Excel en français.
- `journal.txt` (avec `-Journal`) : chaque vague réussie ou ratée, chaque achat, chaque lot de lancers de l'autel,
  chaque bonus posé, chaque renaissance, avec l'heure de jeu et les pièces en poche.

### Quelques définitions

- **Temps** : temps de jeu cumulé depuis le tout début, joueur connecté en continu.
- **Graine** : une suite de tirages de l'autel des héros et de la forge. Même graine = même partie.
  Les valeurs du rapport sont des moyennes sur les graines (« 3/5 » = seulement 3 graines sur 5).
- **Mur** : temps entre le premier échec d'une vague et sa réussite. Pendant un mur, le jeu fait farmer
  tout seul (vague N-1 réussie, vague N ratée, et ainsi de suite) et le joueur achète dès qu'il peut.
- **Vagues de gains** : un prix divisé par les pièces d'une vague entière à cette vague. 10 = il faut
  farmer environ 10 vagues pour se l'offrir.
- **Banc d'essai** : N tours du même type (N = nombre d'emplacements du joueur simulé à cette vague),
  chacune sur les emplacements qui couvrent le plus de chemin pour sa portée, avec le même budget par tour
  (celui du joueur simulé à cette vague). Épreuve : réussir une vague de chaque type, avec les vraies
  règles (un seul ennemi qui passe = vague ratée). Le simulateur cherche de combien il faudrait multiplier les dégâts
  pour y arriver. 100 = la meilleure tour contre ce type de vague ; 50 = il lui faudrait 2 fois plus de
  dégâts ; 0 = impossible (pas assez de tirs). Le tableau « Soutien » remplace 3 tours principales par
  3 exemplaires d'une autre tour : plus de 100 = cette tour aide mieux que des tours principales en plus
  (c'est là que les tours qui ralentissent se montrent).
- **Renaissance en boucle** : avec les tours du joueur simulé à 2 h, 5 h, 10 h…, temps pour rejouer les
  vagues 1 à N après une renaissance (le « cycle ») et ce que ça rapporte (bonus de pièces par heure),
  comparé à une heure de jeu normal au même moment.

## Essayer des réglages sans toucher à `src/` (`-Regler`)

`Module.CHAMP=valeur`, séparés par `;`. Modules : `IdleConfig`, `IdleTowers`, `PlotLayout`, `Enemies`,
et `Joueur` (les réglages du joueur simulé, en haut de `idle/Run.luau`). Exemples :

```text
IdleConfig.UPGRADE_COST_GROWTH=1.3
IdleConfig.REWARD_GROWTH=1.22                    (les grands nombres arrivent plus tard)
IdleConfig.HEALTH_WAVE_POWER=2                   (forme de la courbe des PV, voir IdleConfig.healthBudget)
IdleConfig.DUPLICATE_DAMAGE_BONUS=0.03
IdleConfig.TOWER_SPIN_TIERS.1.odds.Common=60     (un nombre = le n-ième élément d'une liste)
IdleTowers.Defs.Orbital.damage=300
PlotLayout.SPOT_COST_GROWTH=2.5
Joueur.SAVE_SECONDS=600
```

Le rapport rappelle l'essai tout en haut. Quand un essai te plaît, recopie la valeur dans le fichier de
`src/shared` et relance sans `-Regler`. Seuls les réglages lus pendant la partie sont pris en compte :
changer `PlotLayout.PATH` ne marche pas (la longueur du chemin est calculée au chargement du module).

## Ce qui est simulé

`run.ps1` copie les modules de `src/shared` dans `idle/gen/` en ajoutant des imitations de `Vector3`,
`Color3`, `CFrame` et `script` (`shim.luau`). Aucun chiffre n'est recopié à la main : si tu changes un
réglage dans `src/shared`, le simulateur l'utilise au prochain lancement.

`Engine.luau` refait pas à pas `PlotGame:simulate` (`src/server/Hub/PlotGame.luau`), dans le même ordre
(apparitions, déplacements, projectiles qui arrivent, tours, zones de feu, retrait des morts) :

- vagues de `IdleConfig.buildWave` (écarts entre ennemis, `MAX_ENEMIES`), chemin `PlotLayout.PATH`,
  vitesse des ennemis x `ENEMY_SPEED_MULTIPLIER` x facteur de leur type (`ENEMY_SPEED_FACTORS`) ;
  **sortie à chaque mort** (`SPAWN_NEXT_ON_KILL`) : chaque ennemi tué fait sortir le suivant de la file tout de
  suite, même si d'autres sont en vie ; **vague écrasée** (`COMPRESS_EMPTY_SPAWNS`) : plus aucun ennemi en vie
  -> le suivant sort tout de suite ;
- **contrôles : un seul à la fois** par ennemi (ralentissement du Totem de givre, du Mage des tempêtes,
  étourdissement du Trébuchet royal) : la même sorte de tour prolonge le sien, une autre est refusée tant qu'il
  dure ; **fragilité** du Totem (+X % de dégâts reçus, sauf Mage et Totems ; le plus fort Totem gagne) ;
- tirs des tours dans l'ordre des emplacements : simple (le plus avancé), `Strongest` (le plus de PV),
  `Crowd` (Trébuchet : le point où sa zone touche le plus d'ennemis), zone, aura, chaîne, carreau perçant
  (Baliste : toute la ligne tour -> impact) ; recharges ; stats de `IdleTowers.effectiveStats` (niveau,
  doublons, bonus de la forge) ;
- **projectiles** (Archer, Catapulte, Baliste, Trébuchet) : visée à l'endroit où sera l'ennemi (sa vitesse, la
  fin de son ralentissement, le chemin, 2 itérations), temps de vol `IdleTowers.flightTime` (distance en 3D
  depuis le haut de la tour), dégâts à l'impact ; une zone touche autour du point d'impact, une flèche touche sa
  cible (ou l'ennemi le plus proche à `PROJECTILE_CATCH_RADIUS` studs si elle est morte) ; dégâts « en attente »
  : une tour à projectile ne vise pas un ennemi que les projectiles déjà en vol vont tuer ;
- **flèches enflammées** : zones de feu au point d'impact (ravivées par la même tour, `fireMaxPatches` par
  tour, `FIRE_MAX_PER_PLOT` en tout), un coup toutes les `fireTick` s à tous les ennemis dedans ; les dégâts du
  feu comptent pour l'Archer qui l'a allumé ;
- **Mage des tempêtes** : foudre instantanée sur une petite zone, dégâts et ralentissement pour tous ;
- **rayon du Sorcier** : garde sa cible tant qu'elle vit et reste à portée, montée `IdleTowers.beamRamp` au
  milieu du pas, repart de x1 sur une nouvelle cible ;
- pas de PV de base : **un seul ennemi au bout du chemin = vague ratée** (arrêtée tout de suite), une vague
  plus bas ; réussie = vague suivante ; délais `FIRST_WAVE_DELAY`, `WAVE_CLEAR_DELAY`, `WAVE_FAIL_DELAY` ;
- pièces des ennemis tués x (1 + bonus de pièces), y compris ceux tués avant la fuite d'une vague ratée ;
- autel des héros : lancers payés en pièces par lots (`TOWER_SPIN_BULKS`, prix `towerSpinCost` avec le
  nombre de lancers déjà achetés : +0,05 % par lancer, jamais remis à zéro ; un prix « MAX » n'est pas achetable), chances du
  palier du **record** (`TOWER_SPIN_TIERS`), déblocage ou doublon, tirage des gros lots comme le serveur
  (nombre de tours par rareté puis par tour), forge runique (prix `forgeCoinPrice` : 100 K, x5 sous 1 T, puis
  x2, compteur jamais remis à zéro, plus de délai ; seulement les runes qui améliorent une tour posée,
  `forgeDrawableRunes` ; le bonus remplacé est perdu),
  emplacements (le n-ième acheté coûte `PlotLayout.spotCost(n)` ; achetés dans n'importe quel ordre si le
  jeu le permet, c'est-à-dire si `PlotLayout.startingSpots` existe, sinon dans l'ordre 5, 6, 7…), prix des
  tours et des améliorations, remplacement remboursé à 50 % (le bonus de l'ancienne tour revient dans
  l'inventaire), renaissance (`rebirthGain`, seule la vague repart à 1).

Différences voulues avec le jeu : pas de temps fixe de 0,05 s au lieu de ~1/60 s (les résultats changent
de moins de 10 % entre 0,1 s, 0,05 s et 1/60 s) ; une petite marge sur les recharges (dans le jeu, à 60 images
par seconde, une recharge de 0,2 s dure en fait 12 ou 13 images : les tours tirent jusqu'à ~5 % moins souvent) ;
la recharge des tours repart à 0 à chaque vague ; le joueur n'achète qu'entre les vagues ; les pièces sont
ramassées tout de suite.

Si tu changes `PlotGame.luau` (nouvelle règle de combat, nouveau type de tour…), fais le même changement
dans `Engine.luau` ou `Run.luau`, puis lance `run.ps1 -Verifier` : sinon le simulateur ne correspond plus au jeu.

## Le joueur simulé

Un joueur **actif** (réglages dans `Run.POLICY`, en haut de `idle/Run.luau`) :

- il est connecté en continu et ramasse toutes les pièces tout de suite ;
- entre deux vagues, il dépense ses pièces sur l'achat qui a le **meilleur rapport gain / prix** :
  améliorer une tour, poser une tour sur un emplacement vide, acheter un emplacement et y poser une tour
  (quand l'ordre est libre, il compare pour chaque tour les 3 emplacements libres qui couvrent le plus de
  chemin à sa portée), remplacer une de ses 3 tours les moins utiles (seulement une tour posée depuis
  au moins 2 h, une seule par entracte, et seulement si c'est nettement mieux : sans ces limites, au mur,
  il revendait en boucle des tours de haut niveau et perdait la moitié de leur prix à chaque fois), ou
  **acheter des lancers à l'autel** : un lot vaut les doublons attendus sur ses tours posées (+2 % de dégâts
  chacun) plus la chance de débloquer une tour qui ferait mieux que ses achats actuels ; le prix suit le vrai
  compteur de lancers (+0,05 % par lancer, jamais remis à zéro) ; à rapport presque égal (90 %, 75 % à partir
  de x1 000), il prend le plus gros lot qu'il peut payer (x10 plutôt que 10 fois x1), ou attend quelques
  minutes pour l'avoir (5 min de revenu pour x100, 30 min pour x1 000 et plus) ;
- le « gain » est mesuré contre les **prochaines vagues** (et, s'il est bloqué, contre la vague qui bloque,
  en visant les ennemis qui l'ont vraiment traversée) : le moteur rejoue ces vagues avec des ennemis
  immortels pour compter combien de coups chaque tour peut porter (portée, zone, chaîne, ralentissements),
  puis multiplie par les dégâts, plafonnés aux PV de l'ennemi (un gros tir sur un petit écuyer est gâché).
  Flèches enflammées : les coups de leurs zones de feu comptent en plus. Rayon du Sorcier : la montée x le temps
  passé sur chaque groupe, mais pas plus que ce qu'il peut infliger en tuant ses cibles l'une après l'autre
  (la montée repart de x1 à chaque nouvelle cible) ; il est jugé dans la vraie disposition, avec les
  ralentissements des autres tours (plus un ennemi reste longtemps, plus le rayon chauffe) (`Run.valueOf`).
  Une seule fuite fait rater la vague : chaque groupe d'ennemis compte d'autant plus que ses tours en
  viennent mal à bout (PV à infliger / puissance utile, au carré). Fragilité du Totem de givre : les coups sur
  un ennemi fragile sont comptés à part et valent x (1 + fragilité des Totems du joueur) ; améliorer un Totem
  est jugé avec la fragilité qu'il ajoute à TOUTES les autres tours ; une tour neuve est jugée avec les tours
  de contrôle déjà posées (ralentissements, étourdissements, fragilité) ;
- une tour neuve est jugée avec ses améliorations suivantes (au niveau où elle devient la plus rentable) ;
- si le meilleur achat est trop cher mais payable en moins de 5 min de farm (30 min pour un lot x1 000 ou
  x1 000 000 de l'autel), il économise ; sinon il prend le meilleur achat abordable (s'il vaut au moins 25 %
  du meilleur) ;
- il ne vend jamais une tour sans la remplacer.

Option `-Regler "Joueur.SOLVER=true"` : au mur (bloqué depuis 2 min, puis toutes les 30 min), le joueur
essaie aussi avec le vrai moteur de remplacer une tour par une tour qui ralentit (Mage des tempêtes, Totem
de givre) et garde le meilleur essai s'il rapproche nettement de la réussite ; ces tours de soutien restent
ensuite en place, sans amélioration. Les murs de Seigneur de guerre raccourcissent, mais avec moins
d'Archers le farm est plus lent : avec les réglages actuels, la progression totale est un peu moins bonne,
d'où l'option désactivée par défaut.

Scénarios (`-Scenarios`) :

| Scénario | Joueur |
|---|---|
| `base` | le joueur ci-dessus, sans forge ni renaissance (la référence des objectifs) |
| `forge` | + la forge runique en pièces (plus de délai) : dès que le prix du prochain lancer vaut moins de 30 min de revenu, il le met de côté puis lance ; seulement des runes utiles ; la rune va sur la tour où elle rapporte le plus. Le rapport donne les lancers achetés à 2, 6, 10, 25, 50 et 100 h |
| `renaissance` | forge + renaissance dès qu'il est bloqué depuis 15 min à son record (vague 15 ou plus) |
| `renaissance-seule` | base + la même renaissance, sans forge (pour voir l'effet de la renaissance seule) |
| `sans-sorcier` | base, mais il ne pose jamais de Sorcier des arcanes : le rapport compare les murs des Seigneurs de guerre et des Gardes colossales avec et sans lui |

Pas de Robux dans aucun scénario.

## Fichiers

| Fichier (`idle/`) | Rôle |
|---|---|
| `run.ps1` | Copie les modules, lance la simulation, écrit les fichiers de `out\` |
| `shim.luau` | Imitations de `Vector3`, `Color3`, `CFrame`, `script` pour charger les modules hors de Roblox |
| `Modules.luau` | Charge les vrais modules copiés dans `gen\shared` |
| `Engine.luau` | Le combat, pas à pas (copie fidèle de `PlotGame:simulate` : projectiles, feu, rayon compris) |
| `verif/` | Vérification du moteur (`run.ps1 -Verifier`) : `parity.luau` fait jouer les mêmes vagues au vrai `PlotGame.luau` et au moteur ; `extra.luau` et `stubs/` imitent Roblox |
| `Run.luau` | Une partie : le joueur simulé, les machines, la renaissance, les statistiques, le journal |
| `Report.luau` | Mise en forme du rapport et des CSV |
| `Dump.luau` | Calcul en parallèle : écrit une partie terminée en texte Luau, relu pour le rapport |
| `main.luau` | Lance les scénarios, le banc d'essai, la renaissance en boucle et la comparaison aux objectifs |
| `Rng.luau` | Tirages aléatoires reproductibles (même graine = même partie) |

`gen\` (copies des modules, parties du calcul en parallèle) est recréé à chaque lancement et les fichiers de
`out\` sont remplacés (`journal.txt` seulement avec `-Journal`). `gen\` et `journal.txt` ne vont pas dans git
(`idle/.gitignore`).

## Limites

- Le joueur simulé est bon mais pas parfait : un vrai joueur peut faire mieux (acheter pendant une vague,
  mieux combiner ses tours) ou moins bien (ne pas ramasser toutes les pièces, oublier l'autel,
  se déconnecter). Les temps du rapport sont ceux d'un joueur actif connecté en continu. Changer ses
  réglages (`Joueur.…`) change les temps d'environ 10 à 20 %, pas les grandes conclusions.
- Le banc d'essai compare N tours du même type, ou N - 3 tours principales + 3 autres ; il ne teste pas
  toutes les combinaisons possibles.
- La forge en Robux n'est pas simulée.

# Outil d'équilibrage du mode solo

Un simulateur « sans écran » du **mode infini** (ta parcelle : vagues sans fin, machine à tours,
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

Environ 35 minutes : 4 scénarios x 3 parties x 100 h de jeu. Pour un essai rapide (environ 2 à 3 minutes :
3 parties x 40 h, scénario `base` seulement) :

```bat
powershell -ExecutionPolicy Bypass -File tools\balance\idle\run.ps1 -Rapide
```

Autres options (à ajouter après `run.ps1`) :

```bat
-Graines 5 -Heures 50                  plus ou moins de parties, plus ou moins longues
-Scenarios base,forge                  seulement certains scénarios
-Journal                               écrit aussi out\journal.txt : tout ce que fait le joueur simulé (1re partie)
-Pas 0.0166667                         pas de 1/60 s comme le jeu (plus lent ; résultats à 10 % près)
-Regler "IdleConfig.UPGRADE_COST_GROWTH=1.3;PlotLayout.SPOT_COST_GROWTH=2.5"   essai de réglages (voir plus bas)
```

## Les résultats (`tools\balance\idle\out\`)

- `rapport.txt` : le rapport à lire (aussi affiché à l'écran), dans cet ordre :
  1. **Comparaison aux objectifs** : chaque objectif du mode solo, sa cible, la valeur mesurée et un
     verdict (`OK`, `TROP LENT`, `TROP LONGS`, `PAS ATTEINT`…), puis le nombre d'objectifs atteints.
  2. **Lecture des réglages** : des calculs directs sur les réglages (sans simulation) qui expliquent
     les résultats : croissance des PV et des pièces d'une vague à la suivante, de combien le temps de
     farm grandit, la valeur « neutre » de `UPGRADE_COST_GROWTH`, l'écart de prix entre deux emplacements,
     la puissance des tours à budget égal. Tout est lu dans les fonctions du jeu (`healthBudget`,
     `upgradeCost`…) : si tu changes une formule, cette partie suit.
  3. **Un bloc par scénario** : jalons (vagues 5, 10, 15, 20, 25, 30, 40, 50…), murs, emplacements
     achetés (5e, 6e… : quand, à quel prix, lequel), tours obtenues à la machine, part des dégâts de
     chaque tour.
  4. **Comparaison des scénarios** : temps pour atteindre chaque vague.
  5. **Grands nombres** : pour chaque scénario, record, pièces en poche, revenu par minute et total gagné
     à 1, 5, 10, 25, 50, 80, 90 et 100 h (valeur du milieu des graines), l'heure où le revenu atteint
     1 M, 1 B, 1 T, 1 Qa… par minute, puis les **limites des nombres** : la vague et le niveau
     d'amélioration où un montant deviendrait infini (au-delà de ~1,8e308 ; un DataStore ne sait pas
     le sauver), et la vague où NumberFormat passe en notation scientifique (après 10^96).
  6. **Banc d'essai des tours**.
  7. **Renaissance en boucle**.
- `timeline.csv` : une ligne par vague passée pour la première fois (scénario, graine, temps, pièces,
  revenu, emplacements, tours, doublons, lancers, bonus de pièces, murs, composition).
- `heures.csv` : une ligne par heure de jeu (record, pièces, revenu, total gagné, emplacements…), pour
  tracer des courbes.
  Les deux CSV utilisent `;` et la virgule décimale : ils s'ouvrent directement dans Excel en français.
- `journal.txt` (avec `-Journal`) : chaque vague réussie ou ratée, chaque achat, chaque lancer de machine,
  chaque bonus posé, chaque renaissance, avec l'heure de jeu et les pièces en poche.

### Quelques définitions

- **Temps** : temps de jeu cumulé depuis le tout début, joueur connecté en continu.
- **Graine** : une suite de tirages de la machine à tours et de la forge. Même graine = même partie.
  Les valeurs du rapport sont des moyennes sur les graines (« 3/5 » = seulement 3 graines sur 5).
- **Mur** : temps entre le premier échec d'une vague et sa réussite. Pendant un mur, le jeu fait farmer
  tout seul (vague N-1 réussie, vague N ratée, et ainsi de suite) et le joueur achète dès qu'il peut.
- **Vagues de gains** : un prix divisé par les pièces d'une vague entière à cette vague. 10 = il faut
  farmer environ 10 vagues pour se l'offrir.
- **Banc d'essai** : N tours du même type (N = nombre d'emplacements du joueur simulé à cette vague),
  chacune sur les emplacements qui couvrent le plus de chemin pour sa portée, avec le même budget par tour
  (celui du joueur simulé à cette vague). Épreuve : réussir une vague de chaque type, avec les vraies
  règles (la base a `BASE_HEALTH` PV). Le simulateur cherche de combien il faudrait multiplier les dégâts
  pour y arriver. 100 = la meilleure tour contre ce type de vague ; 50 = il lui faudrait 2 fois plus de
  dégâts ; 0 = impossible (pas assez de tirs). Le tableau « Soutien » remplace 3 tours principales par
  3 exemplaires d'une autre tour : plus de 100 = cette tour aide mieux que des tours principales en plus
  (c'est là que les tours qui ralentissent se montrent).
- **Renaissance en boucle** : avec les tours du joueur simulé à 2 h, 5 h, 10 h…, temps pour rejouer les
  vagues 1 à N après une renaissance (le « cycle ») et ce que ça rapporte (bonus de pièces par heure,
  lancers de la machine par heure), comparé à une heure de jeu normal au même moment.

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

`Engine.luau` refait pas à pas `PlotGame:step` (`src/server/Hub/PlotGame.luau`) :

- vagues de `IdleConfig.buildWave` (écarts entre ennemis, `MAX_ENEMIES`), chemin `PlotLayout.PATH`,
  vitesse des ennemis x `ENEMY_SPEED_MULTIPLIER`, ralentissements (Totem de givre, Mage des tempêtes) ;
- tirs des tours dans l'ordre des emplacements : simple (le plus avancé), `Strongest` (le plus de PV),
  zone, aura, chaîne ; recharges ; stats de `IdleTowers.effectiveStats` (niveau, doublons, bonus de la forge) ;
- base de `BASE_HEALTH` PV : vague ratée = une vague plus bas, réussie = vague suivante ; délais
  `FIRST_WAVE_DELAY`, `WAVE_CLEAR_DELAY`, `WAVE_FAIL_DELAY` ;
- pièces des ennemis tués x (1 + bonus de pièces), y compris pendant une vague ratée ;
- machine à tours (1 lancer par vague réussie, sans cumul, paliers et chances de `TOWER_SPIN_TIERS`,
  déblocage ou doublon), forge runique (`bonusSpinCost`, 1 lancer / 30 min, le bonus remplacé est perdu),
  emplacements (le n-ième acheté coûte `PlotLayout.spotCost(n)` ; achetés dans n'importe quel ordre si le
  jeu le permet, c'est-à-dire si `PlotLayout.startingSpots` existe, sinon dans l'ordre 5, 6, 7…), prix des
  tours et des améliorations, remplacement remboursé à 50 % (le bonus de l'ancienne tour revient dans
  l'inventaire), renaissance (`rebirthGain`, seule la vague repart à 1).

Différences voulues avec le jeu : pas de temps fixe de 0,05 s au lieu de ~1/60 s (les résultats changent
de moins de 10 % entre 0,1 s, 0,05 s et 1/60 s) ; la recharge des tours repart à 0 à chaque vague ; le
joueur n'achète qu'entre les vagues ; les pièces sont ramassées tout de suite.

Si tu changes `PlotGame.luau` (nouvelle règle de combat, nouveau type de tour…), fais le même changement
dans `Engine.luau` ou `Run.luau`, sinon le simulateur ne correspond plus au jeu.

## Le joueur simulé

Un joueur **actif** (réglages dans `Run.POLICY`, en haut de `idle/Run.luau`) :

- il est connecté en continu et ramasse toutes les pièces tout de suite ;
- il lance la machine à tours après chaque vague réussie (donc un lancer par vague réussie) ;
- entre deux vagues, il dépense ses pièces sur l'achat qui a le **meilleur rapport gain / prix** :
  améliorer une tour, poser une tour sur un emplacement vide, acheter un emplacement et y poser une tour
  (quand l'ordre est libre, il compare pour chaque tour les 3 emplacements libres qui couvrent le plus de
  chemin à sa portée), ou remplacer une de ses 3 tours les moins utiles (seulement une tour posée depuis
  au moins 2 h, une seule par entracte, et seulement si c'est nettement mieux : sans ces limites, au mur,
  il revendait en boucle des tours de haut niveau et perdait la moitié de leur prix à chaque fois) ;
- le « gain » est mesuré contre les **prochaines vagues qui peuvent être ratées**, selon leur type (et, s'il
  est bloqué, contre la vague qui bloque, en visant les ennemis qui ont vraiment atteint sa base) : le
  moteur rejoue ces vagues avec des ennemis immortels pour compter combien de coups chaque tour peut
  porter (portée, zone, chaîne, ralentissements), puis multiplie par les dégâts, plafonnés aux PV de
  l'ennemi (un gros tir sur un petit écuyer est gâché) ;
- une tour neuve est jugée avec ses améliorations suivantes (au niveau où elle devient la plus rentable) ;
- si le meilleur achat est trop cher mais payable en moins de 5 min de farm, il économise ; sinon il
  prend le meilleur achat abordable (s'il vaut au moins 25 % du meilleur) ;
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
| `forge` | + la forge runique en pièces dès qu'elle est prête (1 lancer / 30 min) : il met le prix de côté si ça vaut moins de 30 min de revenu ; le bonus va sur la tour où il rapporte le plus |
| `renaissance` | forge + renaissance dès qu'il est bloqué depuis 15 min à son record (vague 15 ou plus) |
| `renaissance-seule` | base + la même renaissance, sans forge (pour voir l'effet de la renaissance seule) |

Pas de Robux dans aucun scénario.

## Fichiers

| Fichier (`idle/`) | Rôle |
|---|---|
| `run.ps1` | Copie les modules, lance la simulation, écrit les fichiers de `out\` |
| `shim.luau` | Imitations de `Vector3`, `Color3`, `CFrame`, `script` pour charger les modules hors de Roblox |
| `Modules.luau` | Charge les vrais modules copiés dans `gen\shared` |
| `Engine.luau` | Le combat, pas à pas (copie fidèle de `PlotGame:step`) |
| `Run.luau` | Une partie : le joueur simulé, les machines, la renaissance, les statistiques, le journal |
| `Report.luau` | Mise en forme du rapport et des CSV |
| `main.luau` | Lance les scénarios, le banc d'essai, la renaissance en boucle et la comparaison aux objectifs |
| `Rng.luau` | Tirages aléatoires reproductibles (même graine = même partie) |

`gen\` (copies des modules) est recréé à chaque lancement et les fichiers de `out\` sont remplacés
(`journal.txt` seulement avec `-Journal`). `gen\` et `journal.txt` ne vont pas dans git (`idle/.gitignore`).

## Limites

- Le joueur simulé est bon mais pas parfait : un vrai joueur peut faire mieux (acheter pendant une vague,
  mieux combiner ses tours) ou moins bien (ne pas ramasser toutes les pièces, oublier la machine,
  se déconnecter). Les temps du rapport sont ceux d'un joueur actif connecté en continu. Changer ses
  réglages (`Joueur.…`) change les temps d'environ 10 à 20 %, pas les grandes conclusions.
- Le banc d'essai compare N tours du même type, ou N - 3 tours principales + 3 autres ; il ne teste pas
  toutes les combinaisons possibles.
- La forge en Robux n'est pas simulée.

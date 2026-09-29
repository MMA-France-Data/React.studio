# Équilibrage du mode solo : résultats

Le simulateur (`tools/balance/idle`, voir [`README.md`](README.md)) joue le mode infini avec les **vrais
modules du jeu**. Référence : le scénario **« base »** = un joueur actif (il ramasse tout, achète au meilleur
rapport gain / prix, lancers de l'autel compris), **sans forge runique ni renaissance**. Les chiffres « après »
viennent de `idle/out/rapport.txt` (5 scénarios x 3 parties x 100 h, calculées en même temps : 14 min).

## Les nouvelles règles de cette mise à jour (décisions du propriétaire)

Codées dans `PlotGame.luau`, et jouées **à l'identique** par le simulateur (`run.ps1 -Verifier` : 135 vagues sur
135 identiques, 0,06 s d'écart au plus) :

1. **Un seul contrôle à la fois** par ennemi (Totem de givre, Mage des tempêtes, étourdissement du Trébuchet) :
   jamais de cumul, la même sorte de tour prolonge le sien, une autre attend qu'il finisse.
2. **Totem de givre** = tour de contrôle : -60 % de vitesse et **fragilité** (+10 % de dégâts reçus, +2 % par
   niveau, +300 % au plus) pour toutes les autres tours sauf le Mage.
3. **Mage des tempêtes** : dégâts inchangés, ralentissement **-85 % très court** autour de sa cible.
4. **Baliste lourde** : carreau **perçant** (toute la ligne tour → impact).
5. **Trébuchet royal** : vise le **plus gros groupe**, grande zone, **étourdit** 0,5 s.
6. **Une unité meurt → la suivante sort** tout de suite, et « vague écrasée » quand plus personne n'est en vie.
7. **Forge runique** : 100 K le 1er lancer, x5 tant que le prix est sous 1 T, puis x2 ; plus de délai ;
   seulement des runes qui améliorent une tour posée.

**« Avant »** ci-dessous = ces règles avec les premiers réglages du code (3 parties x 30 h) ; **« après »** =
après ce réglage.

## Réglages changés et pourquoi

| Réglage | Avant | Après | Pourquoi |
|---|---|---|---|
| Trébuchet : dégâts / zone | 70 / rayon 9 | **35 / rayon 10** | à 70, avec sa portée qui couvre tout le chemin, il était aussi le meilleur contre un boss seul (2 fois la Baliste en duel) et faisait 98-100 % des dégâts après la vague 50 (10 Trébuchets posés). Maintenant : 1,05 fois la Baliste contre un boss seul, **7,75 fois la Catapulte contre une foule** |
| Totem de givre : dégâts | 3 | **2** | à 3, un Totem faisait 1,2 fois les dégâts de la Catapulte contre une foule (même niveau) ; 0,8 fois maintenant |
| Mage : durée du -85 % | 0,5 s | **0,4 s** | à 0,5 s, « tout Mage » (les Mages se relaient) allait aussi loin que le mélange ; à 0,3 s, plus personne ne posait de Mage |
| Baliste : demi-largeur du carreau | 1,5 | **1,25** | la Baliste faisait jusqu'à 90 % des dégâts des vagues 26-50 ; pas moins de 1,25 (le test Studio met un ennemi à 1 stud du trait) |
| Garde colossale : part des PV | 0,5 | **0,33** | un colosse seul devenait un mur de 40 min à 1 h (le Trébuchet ne l'écrase plus) |
| Seigneur de guerre : part max | 0,5 | **0,33** | même raison |
| PV : `HEALTH_WAVE_POWER` | 2,4 | **2,55** | sans ça, la vague 100 arrivait vers 11 h (cible 15-30 h) |

Inchangés : fragilité (+10 %, +2 %/niveau, +300 % au plus), Mage -85 % et 10 dégâts, étourdissement 0,5 s,
prix de la forge (décision du propriétaire), autel, emplacements, renaissance. Nouveaux réglages nommés
dans `IdleConfig` : `MIXED_TANK_SHARE`, `GIANT_SHARE`, `BOSS_SHARE_MIN`, `BOSS_SHARE_MAX`.

## Objectifs : avant / après (scénario « base »)

| Objectif | Cible | Avant | Après |
|---|---|---|---|
| Vagues 1 à 10 | 4-7 min, sans mur | 6 min | **6 min** |
| Premier vrai mur | vague 12-16 | vague 17-18 | **vague 16 (2 min)** |
| Vague 25 | 30-45 min | 28 min (trop tôt) | **33 min** |
| Vague 50 | 3-6 h | 3 h 05 | **4 h 22** |
| Vague 100 | 15-30 h | 11 h 04 (trop tôt) | **16 h 33** |
| Murs 11-30 | 1-5 min | 80 % sous 4 min | 80 % sous 4 min |
| Murs 31-70 | 80 % sous 20 min | 80 % sous 14-18 min, max 42 min | 80 % sous **22 min**, max 1 h 24 (un peu longs) |
| Murs 71-100 | 80 % sous 20 min | 80 % sous 25-51 min, max 1 h 06 | 80 % sous **33 min**, max 2 h 26 (**trop longs**) |
| Part des dégâts du Trébuchet (51-100) | utile, pas tout | 98-100 % | **21-52 %** selon le type de vague |
| Totem contre une foule | moins que la Catapulte | 1,2 fois | **0,8 fois** |
| 1re légendaire | vagues 60-90 | vague 67-69, ~5 h 50 | **vague 65-74, ~7 h 50** |
| Autel payant (+0,05 % par lancer) | acheté tout le jeu | 3-4 achats / 10 vagues | **2,5 à 17 achats / 10 vagues**, 5-10 % des pièces ; ~340 lancers à 10 h, 2 750 à 50 h |
| Grands nombres | trillions tôt, énormes ensuite | - | 1 T / min vers 23 h, 1 Qi vers 46 h, 118 Oc / min à 100 h, tout reste fini |

**19 objectifs atteints sur 26** dans le rapport. Le propriétaire trouvait bien « vague 64 en 6 h avec 2 lancers de
forge et quelques renaissances » : dans le simulateur, la vague 64 arrive vers 5 h 30 avec la forge, 6 h 15 avec
forge + renaissance, 7 h sans rien.

## Les tours (scénario « base », 100 h)

- Part des dégâts utiles, vagues 51-100 : Baliste 32-56 %, Trébuchet 21-52 %, Oracle 3-24 %, Catapulte 1-9 %,
  Mage 1-8 % ; après la vague 100 : Baliste 51-79 %, Catapulte 8-30 %, Mage 3-11 %.
- **Totem de givre** : 3 à 5 posés, le meilleur continue d'être amélioré (niveau 68 et +144 % de fragilité à la
  vague 100, niveau 106 et +220 % à la 150). En soutien au banc d'essai, l'équipe est jusqu'à 1,5 fois plus forte
  à la vague 75 et 1,7 fois à la 150.
- **Mage** : le meilleur au banc d'essai contre les Escarmouches, Levées et Charges à la vague 50 ; le joueur en
  pose 2 à 8. Totem et Mage ne se cumulent pas : « Givre + Mage » est moins bon que le mélange partout.
- **Duels** (une tour contre un ennemi seul, même niveau, 1 = la Baliste) : Sorcier x1,71 contre le Seigneur de
  guerre, x2,08 contre le colosse, x0,80 contre un cavalier ; Trébuchet x1,05 ; Oracle x1,40.
- **Foule** (30 écuyers, 1 = la Catapulte) : Trébuchet 7,75, Oracle 3,73, Mage 1,16, Baliste 0,88, Totem 0,80.

## Anti-méta (défense fixe, même budget ; dernière vague réussie en jouant 1, 2, 3...)

| Moment | Mélange du joueur | Tout Trébuchet | Tout givre | Trébuchet + givre | Tout Sorcier | Tout Catapulte | Givre + Mage | Tout Mage | Tout Archer | Tout Baliste |
|---|---|---|---|---|---|---|---|---|---|---|
| 5 h | 53 | 53 | 44 | **55** | 46 | 48 | 49 | 54 | 47 | 47 |
| 10 h | **78** | 77 | 64 | 77 | 68 | 69 | 71 | 74 | 68 | 68 |
| 20 h | **109** | 105 | 94 | 107 | 96 | 97 | 99 | 104 | 97 | 97 |
| 40 h | 157 | 157 | 144 | 157 | 146 | 147 | 149 | 154 | 146 | 147 |
| 80 h | 253 | 253 | 239 | 253 | 240 | 242 | 244 | 249 | 242 | 242 |

Avant : « Trébuchet + givre » battait le mélange à 5 h (67 contre 64) et l'égalait ensuite. Maintenant, le
mélange est devant ou à égalité partout sauf à 5 h (Trébuchet + givre +2 vagues, tout Mage +1), mais **« tout
Trébuchet » et « Trébuchet + givre » font jeu égal** à 40 et 80 h : le joueur simulé pose lui-même 9 Trébuchets
à la fin, donc son mélange y ressemble. Tout givre, tout Sorcier, tout Catapulte et Givre + Mage sont 4 à 15
vagues derrière : empiler les tours de contrôle ne paie pas.

## Sortie à chaque mort et vague écrasée (après une renaissance)

- Remonter à **80 % du record de la run** (scénarios « renaissance » et « renaissance-seule ») : 15 min (record
  15-39), 14-20 min (40-79), 13-25 min (80-149), 39-47 min (150 et plus). Avant ces règles : ~30 min et plus
  vers la vague 60.
- Comparé à `-Regler "IdleConfig.SPAWN_NEXT_ON_KILL=false"` (réglages finaux, 3 parties x 20 h, scénarios
  « renaissance » et « renaissance-seule ») : avec / sans la règle, 15 min / 15 min (record 15-39), 14-20 min /
  13-20 min (40-79), **11-26 min / 17-28 min** (80-149). La règle ne fait gagner du temps qu'aux records hauts
  (2 à 6 min). Le temps restant vient surtout de la **marche** des ennemis jusqu'aux tours (~25-30 s par vague) :
  la règle ne fait sortir plus vite qu'après la première mort. Sur 20 h, elle ne fait pas aller plus loin
  (record à 20 h : 141 et 118 avec, 146 et 123 sans ; seulement 3 parties, qui divergent vite).
- Les murs près du record ne sont pas devenus absurdes (même comparaison, scénario « renaissance » : 80 % des murs
  31-70 sous 38 min avec et sans la règle, 71-100 sous 42 min contre 43 min).

## Forge (100 K, x5 sous 1 T, puis x2 ; scénario « forge »)

- Lancers achetés (médiane) : **9 à 10 h, 29 à 25 h, 64 à 50 h, 152 à 100 h** (meilleure rune posée à la fin :
  x100). Le joueur simulé lance dès que le prix vaut moins de 30 min de revenu.
- Effet : vague 100 en **10 h 14** (16 h 33 sans), record à 100 h **557** (290 sans). Forge + renaissance : 530.

## Ce qui reste (honnêtement)

1. **Murs des vagues 71-100 trop longs** (80 % sous 33 min, cible 20) : surtout les Escarmouches juste après une
   Garde colossale (46, 56, 96 : on y farme une vague qui rapporte peu) et les Gardes 85-95. Essayé : colosse qui
   rapporte 0,8 à 1 fois une Escarmouche → murs 31-70 plus courts (80 % sous 14-22 min), pas ceux de 71-100, et
   vague 100 plus tôt. Les deux cibles (vague 100 après 15 h, murs courts) tirent en sens contraire.
2. **Sorcier des arcanes presque jamais posé** par le joueur simulé (4 % des dégâts au mieux) : il bat bien la
   Baliste en duel contre les lents, mais la Baliste perçante et les légendaires lui passent devant. Un vrai
   joueur peut s'en servir contre les boss ; à revoir si les essais le confirment.
3. **Archer** : jamais dans les 3 meilleures au banc d'essai après la vague 25 (6-7 % des dégâts).
4. **Anti-méta** : égalité avec « tout Trébuchet » tard dans le jeu (voir plus haut).
5. **x1 000 et x10 000 de l'autel jamais achetés** par le joueur simulé (il dépense tout à chaque entracte).
6. 3 parties par scénario : les chiffres bougent d'environ 1 à 2 h (vague 100) et de quelques minutes (murs)
   entre deux parties.

## Contre-vérification (2e passage)

- `run.ps1 -Verifier` : 135 vagues sur 135 identiques, 0,06 s d'écart au plus.
- Simulation complète relancée avec le code actuel : les 15 parties et le rapport sont les mêmes au chiffre près
  (seuls changent le temps de calcul et le titre de l'objectif 32, corrigé : la forge n'a plus de délai de
  30 min). Calcul en parallèle ou partie par partie : même rapport (essai 2 parties x 4 h).
- Corrigé dans `run.ps1` : en parallèle, relire une partie qui venait de finir pouvait échouer (« fichier en
  cours d'utilisation par un autre processus ») et arrêter tout le calcul, les parties déjà lancées continuant
  seules. Il relit maintenant le fichier en le partageant avec les autres et réessaie (10 s au plus).

## Relancer

Depuis le dossier `roblox-ranked-td` :

```bat
powershell -ExecutionPolicy Bypass -File tools\balance\idle\run.ps1            (complet : ~15 min en parallèle, 5 scénarios x 3 parties x 100 h)
powershell -ExecutionPolicy Bypass -File tools\balance\idle\run.ps1 -Rapide    (~5 min : 3 parties x 40 h, scénario base)
powershell -ExecutionPolicy Bypass -File tools\balance\idle\run.ps1 -Rapide -Regler "IdleTowers.Defs.Orbital.damage=40"
powershell -ExecutionPolicy Bypass -File tools\balance\idle\run.ps1 -Verifier  (le moteur joue-t-il comme PlotGame.luau ?)
```

Le rapport commence par la comparaison aux objectifs (`idle\out\rapport.txt`).

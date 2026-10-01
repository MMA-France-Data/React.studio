# Équilibrage du mode solo : résultats

Le simulateur (`tools/balance/idle`, voir [`README.md`](README.md)) joue le mode infini avec les **vrais
modules du jeu**. Référence : le scénario **« base »** = un joueur actif (il ramasse tout, achète au meilleur
rapport gain / prix, lancers de l'autel compris), **sans forge runique ni renaissance**. Les chiffres « après »
viennent de `idle/out/rapport.txt` (5 scénarios x 3 parties x 100 h, calculées en même temps : 14 min).

## Les nouvelles règles de cette mise à jour (décisions du propriétaire)

Codées dans `PlotGame.luau`, et jouées **à l'identique** par le simulateur (`run.ps1 -Verifier` : 135 vagues sur
135 identiques, 0,06 s d'écart au plus) :

1. **Un seul contrôle à la fois** par ennemi (Totem de givre, Mage des tempêtes, étourdissement du Trébuchet) :
   jamais de cumul, la même sorte de tour prolonge le sien, une autre attend qu'il finisse (depuis la
   « fatigue » plus bas, seul le Totem prolonge le sien).
2. **Totem de givre** = tour de contrôle : -60 % de vitesse et **fragilité** (+10 % de dégâts reçus, +2 % par
   niveau, +300 % au plus) pour toutes les autres tours sauf le Mage.
3. **Mage des tempêtes** : dégâts inchangés, ralentissement **-85 % très court** autour de sa cible (aujourd'hui
   -90 % pendant 0,6 s puis 0,8 s d'immunité : voir « Le Mage après la fatigue » plus bas).
4. **Baliste lourde** : carreau **perçant** (la ligne tour → impact ; 3 ennemis au plus depuis le 30/09, voir
   « Baliste : transperce 3 max » plus bas).
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
| Oracle : dégâts (30/09) | 50 | **60** | depuis la limite de 2 légendaires, il ne servait presque plus quand il sortait après le Trébuchet (« renforce un peu, mais pas trop » : voir « L'Oracle un peu plus fort » plus bas) |

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

(Simulation complète, quand une tour n'avait qu'UNE rune : voir juste après pour les 2 runes.)

- Lancers achetés (médiane) : **9 à 10 h, 29 à 25 h, 64 à 50 h, 152 à 100 h** (meilleure rune posée à la fin :
  x100). Le joueur simulé lance dès que le prix vaut moins de 30 min de revenu.
- Effet : vague 100 en **10 h 14** (16 h 33 sans), record à 100 h **557** (290 sans). Forge + renaissance : 530.

## Forge à 2 runes par tour (dégâts + vitesse, cumulées) : essai rapide

Nouvelle règle (demande du propriétaire) : chaque tour a un emplacement de rune de dégâts et un de vitesse, qui
se cumulent ; la forge ne tire que les runes utiles, emplacement par emplacement. `run.ps1 -Verifier` : 135 vagues
sur 135 identiques (l'Archer et une Baliste de la vérification ont les deux runes). Essai `run.ps1 -Rapide
-Scenarios forge` (3 parties x 40 h, les mêmes graines que la simulation complète : « avant » = ses 40 premières
heures, lues dans `out/heures.csv` et son rapport). Aucun réglage changé.

| Scénario « forge » | Avant (1 rune) | Après (2 runes) |
|---|---|---|
| Lancers de forge (médiane) à 6 h / 10 h / 25 h | 5 / 9 / 29 | 7 / 13 / 42 (73 à 40 h) |
| Vague 50 / 100 / 150 / 200 | 3 h 45 / 10 h 14 / 20 h 11 / 31 h 42 | 3 h 29 / **8 h 12** / 15 h 24 / 23 h 41 |
| Record à 10 h / 25 h / 40 h (moyenne) | 96 / 172 / 237 | 116 / 210 / **309** (291 - 328) |

- À 40 h : x2 vitesse sur toutes les tours posées, meilleure rune de dégâts x23 en moyenne.
- Pourquoi : x2 vitesse se cumule maintenant avec la rune de dégâts, soit x2 de DPS sur presque toutes les tours ;
  la courbe des PV transforme x2 de dégâts en un record ~1,3 fois plus loin (2^(1/2,55) ≈ 1,31).
- Le scénario « base » (sans forge) ne change pas : les objectifs du rapport ne bougent pas.
- Si la forge devient trop forte : rune de vitesse x1,5 au lieu de x2 (record ~+17 % au lieu de ~+30 %), ou x2
  vitesse plus rare (chance 30 -> 10). À décider par le propriétaire.
- Corrigé dans le simulateur : le joueur simulé pose aussi x2 vitesse sur le Sorcier (son estimation ne voit pas le
  rayon chauffer plus vite) ; sans ça, la rune restait « utile » pour la forge et 3 à 12 runes x2 vitesse
  dormaient dans son inventaire à 40 h (effet sur le record : 307 -> 309).

## Seigneur de guerre plus costaud, escorte plus fragile (demande du propriétaire, 29/09/2026)

Après ses parties (défense tournée vers les groupes) : « il faut plus de vie au boss et moins aux unités qui
l'accompagnent », il tuait le boss plus facilement que ses 6 fantassins groupés, qui avaient à eux tous plus de
vie que lui (0,4 contre 0,33 du budget de la vague). Nouveau : `BOSS_SHARE_MAX` 0,33 -> **0,5**,
`BOSS_ESCORT_SHARE` (nouveau) **0,2** (0,4 avant) ; premier boss (vague 10) toujours à `BOSS_SHARE_MIN` 0,3.

Essai rapide (`run.ps1 -Rapide` : 3 parties x 40 h, scénario « base », sans forge ni renaissance) :

- vague 50 : 4 h 21 (inchangée) ; vague 100 : **18 h 36** (16 h 33 avant) ; record à 40 h : vague 156 ;
- les murs des boss deviennent les plus durs, comme voulu : médiane **41 min** aux vagues 11-100 (et 1 h 52 au
  plus, vague 90), contre 8 à 15 min pour les autres ; le propriétaire trouve ces longs murs normaux (il en
  profite pour ses renaissances), et avec la forge, les renaissances et les passes ils sont bien plus courts.

## Fatigue des contrôles et projectiles qui suivent leur cible (retour du propriétaire, vague 148)

Retour : « mes Mages qui ralentissent, avec vitesse x2, j'en mets un max : full freeze, et mes Catapultes les
dégomment ; c'est un peu de la triche » (et « sinon le Mage était un peu obsolète »), plus un bug : « la Catapulte
tire avant de savoir le ralentissement que va prendre l'unité, donc elle tire trop loin ».

- **Fatigue** (`applyControl`) : un ralentissement du Mage ou un étourdissement du Trébuchet n'est plus jamais
  prolongé ; à sa fin, l'ennemi est immunisé contre ce type de tour 1 s (Mage, `slowImmunity`) ou 1,5 s
  (Trébuchet, `stunImmunity`). Au plus 29 % du temps ralenti par les Mages (43 % après le réglage du Mage juste
  en dessous), 25 % étourdi, quel que soit le nombre de tours et leurs runes. Le Totem de givre ne change pas.
- **Suivi de la cible** (`impactCenter`) : Archer, Catapulte et Baliste font tomber leur effet sur la position
  réelle de leur cible (si elle vit et reste à moins de sa zone + 6 studs du point prévu), le Trébuchet garde son
  point prévu.
- `run.ps1 -Verifier` : **162 vagues sur 162** identiques (nouvelle équipe « Mages x2 + Catapultes »), 0,06 s
  d'écart au plus, et 2 essais « dégâts comptés » sur 2 identiques. Sans le suivi dans le moteur, ces essais
  voient la différence (dégâts des Catapultes 357 au lieu de 408, 476 au lieu de 646) ; sans la fatigue, 22
  vagues sur 162 changent de résultat (jusqu'à 123 s d'écart).

Essai rapide (`run.ps1 -Rapide` : 3 parties x 40 h, scénario « base », mêmes graines que l'essai du boss juste
au-dessus ; aucun réglage changé) :

| Scénario « base » | Avant | Après |
|---|---|---|
| Vague 50 / 100 | 4 h 21 / 18 h 36 | 4 h 22 / **19 h 33** |
| Record à 40 h | vague 156 (147 - 163) | **vague 142** (135 - 146) |
| Murs 71-100 (80 % sous…) | 48 min | **26 min** (max 3 h 02, boss de la vague 90) |
| Part des dégâts du Mage (26-50 / après 50) | 9 % / 18 % | **0 % / 0 %** (posé mais plus amélioré) |
| Part des dégâts de l'Archer (26-50 / après 50) | 6 % / 9 % | 13 % / 27 % |
| Anti-méta à 40 h : mélange / « tout Mage » | 151 / 149 | 137 / 131 |

- Le verrou « plein de Mages » a disparu, mais le joueur simulé n'améliore plus du tout le Mage : au banc d'essai,
  une équipe de Mages reste pourtant la meilleure tour non légendaire contre les Escarmouches, Levées et Charges
  (vagues 50 à 100). Le propriétaire a confirmé (« j'étais obligé de faire ça, sinon le Mage était un peu
  obsolète ») : réglé juste en dessous, sans toucher à ses dégâts.

## Le Mage après la fatigue : réglage (retour du propriétaire : « sinon le Mage était un peu obsolète »)

But : que le Mage vaille la peine d'être posé sans redevenir un verrou. Ses dégâts (10) ne bougent pas ; on lui
rend de la valeur à **chaque éclair**. Nouveau dans l'anti-méta : la colonne **« Mages x2 + Catapultes »** (la
composition du propriétaire : moitié Mages AVEC la rune x2 vitesse, moitié Catapultes ; seule composition avec
des runes, donc avantagée face au mélange sans runes).

8 essais `run.ps1 -Rapide -Regler ...` (3 parties x 40 h, scénario « base », 4 essais en même temps dans des
copies du dossier). Foule = Mage contre 30 écuyers, 1 = la Catapulte ; banc = équipe de Mages seuls contre une
Levée à la vague 100 (avec doublons) ; anti-méta à 40 h = mélange / tout Mage / Mages x2 + Catapultes :

| Mage : ralenti, durée, immunité, zone | Vague 50 / 100 | Record 40 h | Foule | Banc | Anti-méta 40 h |
|---|---|---|---|---|---|
| **avant** : -85 %, 0,4 s, 1 s, 2,5 | 4 h 22 / 19 h 33 | 142 | 0,83 | 73 | 137 / 131 / 134 |
| -90 %, 0,6 s, 0,9 s, 2,5 | 4 h 52 / 20 h 21 | 146 | 1,02 | 95 | 139 / 133 / 134 |
| -90 %, 0,6 s, 0,9 s, 3,5 | 5 h 01 / 19 h 03 | 146 | 1,68 | 168 | 137 / 129 / 134 |
| -90 %, 0,5 s, 1 s, 3,5 | 4 h 15 / 17 h 55 | 145 | 1,33 | 137 | 133 / 129 / 129 |
| -90 %, 0,6 s, 0,8 s, 2,5 | 4 h 55 / 19 h 57 | 144 | 1,02 | 114 | 138 / 133 / 134 |
| **gardé** : -90 %, 0,6 s, 0,8 s, 3 | 4 h 42 / 18 h 51 | 146 | 1,50 | 128 | 138 / 133 / 134 |
| -90 %, 0,5 s, 0,9 s, 3 | 5 h 07 / 18 h 59 | 146 | 1,15 | 120 | 133 / 127 / 129 |
| -90 %, 0,5 s, 0,9 s, 3,5 | 4 h 30 / 22 h 00 | 134 | 1,33 | 118 | 128 / 123 / 124 |

Gardé : **-90 % pendant 0,6 s, puis 0,8 s d'immunité, zone 3** (`IdleTowers.Defs.Tesla`). Pourquoi :

- un éclair fait perdre **0,54 s de marche** à chaque ennemi touché (0,34 avant) ; un Mage seul ralentit sa cible
  0,6 s sur 1,6 s (0,4 s sur 1,6 s avant) ;
- jamais de verrou : **43 % du temps ralenti au plus** (0,6 s sur 1,4 s), quel que soit le nombre de Mages et leurs
  runes (100 % avant la fatigue). En moyenne, un ennemi ainsi ralenti avance encore à ~60 % de sa vitesse ; le
  Totem de givre, lui, garde -60 % tout le temps dans son aura ;
- durée + immunité = 1,4 s, exprès pas un multiple de 0,8 s (le temps entre deux éclairs) : pas d'éclair « à la
  limite » de la fin de l'immunité. Avec 0,6 s + 0,9 s ou 0,7 s + 0,8 s, le test Studio de la fatigue (4 s
  d'éclairs sur le même ennemi) tomberait pile sur sa marge ;
- zone 3 plutôt que 3,5 : à 3,5, le Mage faisait 1,7 fois la Catapulte contre une foule et lui volait son rôle.
  À 3 : 1,5 fois, mais seul (dans une vraie défense, la fragilité du Totem renforce la Catapulte, pas le Mage :
  la Catapulte garde 40 à 96 % des dégâts dans le scénario « forge »).

Simulation finale (`run.ps1 -Rapide -Scenarios base,forge,renaissance` : 3 parties x 40 h ; « avant » = mêmes
graines avec les anciens chiffres du Mage) :

| | Avant | Après |
|---|---|---|
| Base : vague 50 / 100 | 4 h 22 / 19 h 33 | 4 h 42 / 18 h 51 |
| Base : record à 40 h | 142 (135 - 146) | **146** (145 - 149) |
| Base : Mages posés (niveau) v50 / v70 / v100 | 2,7 (1) / 2,7 (13) / 1,3 (7) | 1,3 (1) / 2,7 (15) / 1,7 (22) |
| Base : murs 71-100 (80 % sous…) | 26 min | 43 min (voir plus bas) |
| Anti-méta 5 h / 10 h / 20 h / 40 h : mélange | 51 / 78 / 99 / 137 | 52 / 75 / 99 / 138 |
| … tout Mage | 47 / 67 / 93 / 131 | 48 / 68 / 94 / 133 |
| … Mages x2 + Catapultes | 49 / 69 / 94 / 134 | 49 / 69 / 97 / 134 |
| … Givre + Mage / tout givre (40 h) | 129 / 129 | 133 / 129 |
| Banc (vagues 50 / 75 / 100), Mages seuls, Levée (avec doublons) | 34 / 63 / 73 | 57 / 100 / 128 |
| Soutien : 3 Mages à la place de 3 tours (v50-v100) / 3 Totems | 82-102 / 141-238 | 84-111 / 135-233 |
| Duels (1 = la Baliste) / foule (1 = la Catapulte) | 0,36-0,40 / 0,83 | 0,44-0,50 / 1,50 |
| Forge : vague 50 / 100, record 40 h | 3 h 30 / 8 h 12, 287 | 3 h 37 / 9 h 28, 282 |
| Forge : Mages posés à la vague 100 / 200 | 5,7 / 6,7 (niveau 1) | 5 / 5 (niveau 1) |
| Renaissance (forge + renaissance) : record 40 h | pas mesuré | 268 (229 - 308) |

- Le mélange du joueur reste devant « tout Mage » (4 à 7 vagues) et devant « Mages x2 + Catapultes » (2 à 6
  vagues), même avec ses runes. Seul « Trébuchet + givre » fait jeu égal ou +1 (déjà le cas avant, pas le Mage).
- Totem ou Mage, un vrai choix : le joueur simulé pose les deux (4 à 7 Totems, 1 à 3 Mages dès la vague 50). Le Totem reste le
  meilleur soutien (sa fragilité renforce toutes les autres tours) ; le Mage est la meilleure tour non légendaire
  contre les Escarmouches, Levées et Charges au banc d'essai, et il ne se cumule toujours pas avec le Totem.
- Avec la forge, le joueur simulé fait déjà comme le propriétaire : 5 à 7 Mages niveau 1 (pour leur
  ralentissement) et des Catapultes avec les runes (40 à 96 % des dégâts). Le record à 40 h ne bouge pas (287 ->
  282) : la fatigue garde ce combo sous contrôle.
- Honnêtement : la part des **dégâts** du Mage reste sous 1 % (il est posé pour son ralentissement, ses dégâts
  ne profitent pas de la fragilité) : l'objectif 23 du rapport (>= 10 % des dégâts) reste « NON ». Les murs
  71-100 plus longs (43 min au lieu de 26) viennent de la **1re légendaire** : Trébuchet vers la vague 64
  (faible contre les boss, exprès) au lieu de l'Oracle vers la 63 dans l'essai « avant ». Les essais où l'Oracle
  est sorti en premier donnent 29-33 min. Avec 3 parties, les deux cas arrivent au hasard des lancers.

## Baliste plus maligne : entre ennemis « pareils », la meilleure ligne (demande du propriétaire, 30/09/2026)

Demande : « viser le plus gros monstre ok, mais si plusieurs monstres sont pareils, essayer de faire la meilleure
zone ».

- **Règle** (`PlotGame:pickPierceTarget`, la même dans `Engine.luau`) : la Baliste part du plus résistant à portée
  (pas condamné par les projectiles en vol, comme avant). Les ennemis à portée, pas condamnés, qui ont au moins
  **85 %** de ses PV (`IdleTowers.BALLISTA_TIE_RATIO`) sont « pareils » : elle vise celui dont le carreau (tour ->
  point visé, visée anticipée) transpercera le plus d'ennemis non condamnés, positions prévues à l'arrivée du
  carreau. À nombre égal : le plus résistant, puis le premier de la liste (la règle d'avant). 12 ennemis comparés
  au plus (`BALLISTA_MAX_CANDIDATES`). Un ennemi bien plus résistant que les autres reste toujours sa cible.
- **`run.ps1 -Verifier`** : 162 vagues sur 162 identiques, **0,00 s** d'écart (0,06 s avant : le moteur reçoit
  maintenant ses tours dans l'ordre où le jeu les fait tirer), 2 essais « dégâts comptés » sur 2 (Baliste 800 et
  950 au lieu de 450 et 550 : ennemis de mêmes PV, la règle joue à chaque tir) et, nouveau, les **carreaux de la
  Baliste comparés tir par tir** : 106 vagues sur 106 identiques (1 429 carreaux, dont 14 où la règle a changé la
  cible). Essai : départager les égalités autrement dans le moteur seul donne 26 vagues différentes ici, alors que
  les 162 résultats et les 2 essais de dégâts restaient identiques.
- **Relecture** : d'autres changements faits dans le moteur seul passaient encore la vérification (viser ou compter
  un ennemi condamné, comparer 13 « pareils » au lieu de 12, seuil à 0,9 au lieu de 0,85). Ajouté : 2 vagues faites
  à la main pour la Baliste, carreaux comparés tir par tir (« Balistes et condamnés » : 60 fantassins de 50 PV et
  3 Balistes x2 vitesse ; « seuil des pareils » : 50 fantassins de 120 PV, 2 Balistes, une Catapulte et un
  Archer). Elles voient maintenant ces 4 changements ; 2 sur 2 identiques (22 et 16 carreaux).

Essai rapide (`run.ps1 -Rapide` : 3 parties x 40 h, scénario « base », mêmes graines que la simulation finale du
Mage juste au-dessus) ; aucun réglage changé :

| Scénario « base » | Avant | Après |
|---|---|---|
| Vague 50 / 100 | 4 h 42 / 18 h 51 | 4 h 43 / 18 h 50 |
| Record à 40 h | 146 (145 - 149) | 149 (145 - 155) |
| Part des dégâts de la Baliste 26-50 / 51-100 / 101+ (selon le type de vague) | 19-67 % / 10-28 % / 15-40 % | **43-84 %** / **32-60 %** / **42-80 %** |
| Balistes posées vague 50 / 100 | 3,7 / 2,3 | 3 / 4,7 (10 à la vague 150, 1 partie sur 3) |
| Foule (30 écuyers, 1 = la Catapulte) : Baliste | 0,87 | 1,31 |
| Murs 31-70 / 71-100 (80 % sous…) | 23 min / 43 min | 25 min / 31 min |
| Anti-méta à 40 h : mélange / tout Baliste | 138 / 131 | 139 / 133 |

- La progression ne bouge presque pas (record +3 à 40 h, dans l'écart entre les parties ; vague 100 à la même
  heure) et tous les objectifs gardent leur verdict : la Baliste n'est pas devenue trop forte au total.
- Mais elle prend beaucoup plus de place dans les dégâts, surtout aux dépens de la Catapulte (101+ : 64-69 % ->
  48-53 %), du Trébuchet (51-100 : 34-82 % -> 25-53 %), du Sorcier (51-100 : 23 % -> 4 % au mieux) et de l'Oracle
  (51-100 : 6-14 % -> 2-5 %) : jusqu'à 84 % des dégâts des vagues 26-50 en moyenne des 3 parties, presque le niveau
  qui avait fait réduire son carreau (90 % avec 1,5 stud), et jusqu'à **92 % d'une tranche de vagues dans une des
  3 parties** (objectif 15 du rapport ; 84 % avant). Le joueur simulé ne pose presque plus de Sorcier ni d'Oracle
  après la vague 100 : leur meilleure part des dégâts (dans une partie) tombe à 13 % et 14 % (55 % et 41 % avant),
  tout près des 10 % de l'objectif 15 (« utile quelque part »). Contre une foule de 30 écuyers, elle fait
  maintenant **plus que la Catapulte** (1,31 fois), la tour faite pour ça.
  Si le propriétaire trouve qu'elle écrase les autres tours : `BALLISTA_TIE_RATIO` à 0,95 (moins de « pareils »)
  ou `pierceWidth` à 1,1. Pas touché ici.
- Relecture : « avant » rejoué avec `-Regler "IdleTowers.BALLISTA_TIE_RATIO=2"` (l'ancienne règle, mêmes graines) :
  mêmes chiffres que la colonne « avant » (record 146, 145 - 149).

## Baliste : transperce 3 max (décision du propriétaire, 30/09/2026)

Avec sa visée maligne, la Baliste faisait jusqu'à 84 % (92 % dans une partie) des dégâts et écrasait les autres
tours. Décision : « transperce 3 max peut-être ». **Règle** (`PlotGame:hitLine`, la même dans `Engine.luau`) : le
carreau touche au plus `IdleTowers.BALLISTA_PIERCE_MAX` = **3** ennemis : sa cible, plus les 2 premiers ennemis
que le carreau rencontre sur sa ligne (les plus proches de la tour ; à égalité, le premier de la liste des
ennemis ; une cible morte pendant le vol laisse sa place). Sa visée (`countPierced`) compte aussi 3 au plus par
ligne : 3 alignés ou plus, c'est pareil (à égalité, le plus résistant). Rien d'autre n'a changé (dégâts 50,
largeur 1,25, seuil des « pareils » 85 %).

`run.ps1 -Verifier` : 162 vagues sur 162 identiques, **0,00 s** d'écart, 106 vagues sur 106 avec les mêmes carreaux
(1 429), 2 essais « dégâts comptés » sur 2 (Baliste 500 et 700 au lieu de 800 et 950 : le plafond joue), et 4 vagues
faites à la main sur 4 : la nouvelle « lignes pleines » (36 carreaux) voit les égalités mal départagées ; « groupes
serrés » (22 carreaux, ajoutée à la relecture) voit une cible morte en vol qui garderait sa place et des condamnés
sautés à l'impact. Sans elle, ces 2 erreurs passaient : dans toute la vérification, seuls 13 carreaux (sur ~1 500
dans le jeu) arrivaient sur une ligne pleine, et aucun avec une cible morte en vol.

Essai rapide (`run.ps1 -Rapide` : 3 parties x 40 h, scénario « base », mêmes graines que les deux essais du dessus ;
part des dégâts utiles, « de - à » selon le type de vague, moyenne des 3 parties) :

| Scénario « base » | Visée simple | Visée maligne | **3 au plus** |
|---|---|---|---|
| Vague 50 / 100 | 4 h 42 / 18 h 51 | 4 h 43 / 18 h 50 | 5 h 02 / **18 h 26** |
| Record à 40 h | 146 (145 - 149) | 149 (145 - 155) | **149** (139 - 159) |
| Baliste 26-50 / 51-100 / 101+ | 19-67 % / 10-28 % / 15-40 % | 43-84 % / 32-60 % / 42-80 % | **18-55 % / 9-25 % / 4-19 %** |
| Catapulte 26-50 / 101+ (Escarmouche, Levée, Charge) | ? / 64-69 % | 22-51 % / 48-53 % | **66-76 % / 66-67 %** |
| Catapulte 51-100 (tous types) | ? | 2-13 % | 0-4 % |
| Trébuchet 51-100 / 101+ | 34-82 % / ? | 25-53 % / 1-5 % | 24-56 % / **6-20 %** |
| Sorcier 26-50 / 51-100 / 101+ | ? / 23 % au mieux / ? | 0 % / 0-4 % / 0 % | **1-24 %** / 0-5 % / **2-36 %** |
| Oracle 51-100 / 101+ | 6-14 % / ? | 2-5 % / 0 % | **28-32 %** / 0 % |
| Meilleure part d'une tranche (objectif 15) : Baliste / Sorcier / Oracle | 84 % / 55 % / 41 % | 92 % / 13 % / 14 % | 65 % / 62 % / 97 % |
| Balistes posées vague 50 / 100 / 150 (150 : 1 partie sur 3) | 3,7 / 2,3 / ? | 3 / 4,7 / 10 | 3 / 2,7 / 1 |
| Foule (30 écuyers, 1 = la Catapulte) : Baliste | 0,87 | 1,31 | 1,20 |
| Murs 31-70 / 71-100 (80 % sous…) | 23 min / 43 min | 25 min / 31 min | 21 min / 34 min |
| Anti-méta à 40 h : mélange / tout Baliste | 138 / 131 | 139 / 133 | 143 / 137 |

(« ? » : pas noté à l'époque.)

- **Ni dominante, ni inutile** : la Baliste reste la 1re tour contre les Gardes colossales et les boss des vagues
  26-50 (55 % et 39 %), garde 9-25 % des dégâts aux vagues 51-100 (objectif 20 « utile au milieu de partie » :
  OK) et 4-19 % après 100. La Catapulte reprend les foules (66-76 % des Escarmouches, Levées et Charges avant la
  vague 51 et après la 100), le Sorcier revient contre les colosses et les boss (jusqu'à 36 %), le Trébuchet et
  l'Oracle servent. Les verdicts des objectifs du rapport sont les mêmes qu'avec la visée maligne, et la
  progression ne bouge presque pas (record 149 à 40 h ; vague 50 19 min plus tard, vague 100 24 min plus tôt).
- Honnêtement : 3 parties seulement, et la part de l'Oracle (28-32 % aux vagues 51-100) dépend surtout de la
  légendaire qui sort en premier à l'autel (hasard des lancers). Contre une foule seule, à niveau égal, la Baliste
  fait encore un peu plus que la Catapulte (1,20) grâce à sa portée (30 contre 14), mais dans les vraies parties,
  sur les Levées, la Catapulte fait 76 % des dégâts contre 18 % pour la Baliste (vagues 26-50), 67 % contre 4 %
  (après 100).
- Aucun réglage à changer. Si le propriétaire la trouve trop faible après la vague 100 : `BALLISTA_PIERCE_MAX` à 4.
- Relecture : l'essai rapide relancé avec le code actuel redonne exactement le même rapport. 16 erreurs faites
  exprès dans le moteur seul (sans plafond, plafond 2 ou 4, sans tri, le plus loin ou le plus avancé d'abord,
  égalités à l'envers, cible pas toujours touchée ou en plus des 3, cible morte qui garde sa place, condamnés
  sautés, visée sans plafond…) : 15 vues par `-Verifier`. La seule qui passe range la ligne par distance à la tour
  au lieu de l'avancée le long du trait (presque toujours le même ordre). Le test Studio « 5 ennemis alignés » suit
  maintenant le réglage (avec `BALLISTA_PIERCE_MAX` à 4, il attend T et les 3 plus proches) ; joué hors de Studio
  avec le vrai `PlotGame.luau`, il passe avec 1, 2, 3 et 4.

## Limite de tours identiques (décision du propriétaire, 30/09/2026)

Décision : « un nombre de tours max, pas total mais de doublons ». **Règle** (`IdleTowers.MAX_COPIES`,
`PlotGame:placeTower`) : sur sa parcelle, 5 exemplaires au plus d'une même tour commune, 4 d'une rare, 3 d'une
épique, 2 d'une légendaire (28 places pour 22 emplacements). Le joueur simulé la respecte (`Run:packageOptions`,
`Run:wallSolver`, vérifiée dans `Run:execute`). Le banc d'essai et l'anti-méta comparent encore des équipes « tout X » :
le rapport les marque maintenant « ! » (impossibles en jeu). Le combat ne change pas : `run.ps1 -Verifier` = 162
vagues sur 162 identiques, 0,00 s d'écart, 106 sur 106 avec les mêmes carreaux, 2 essais de dégâts sur 2, 4 vagues
faites à la main sur 4.

Essai rapide (`run.ps1 -Rapide` : 3 parties x 40 h, scénario « base », mêmes graines que « Baliste : transperce 3
max » juste au-dessus) ; aucun réglage changé :

| Scénario « base » | Transperce 3 max (avant) | **Limite de tours** |
|---|---|---|
| Vague 50 / 100 | 5 h 02 / 18 h 26 | **4 h 17 / 16 h 00** |
| Record à 40 h | 149 (139 - 159) | **163** (159 - 165) |
| Murs 31-70 / 71-100 (80 % sous…) | 21 min / 34 min | 14 min / 33 min |
| 1re légendaire | 9 h 42, vague 70 | 6 h 48, vague 63 |
| Lancers de l'autel en 40 h | 2 010 | 2 370 |
| Anti-méta à 40 h : mélange / tout Baliste | 143 / 137 | 157 / 150 ! |
| Objectifs atteints | 18 sur 26 | 18 sur 26 : gagné « murs 31-70 » (OK) ; perdu « 22 emplacements peu à peu » (TROP TARD : le 22e à la vague 105 au lieu de 98, la progression va plus vite) ; « les 8 tours utiles » reste NON (l'Oracle rejoint le Mage) |

Tours du joueur simulé (graine 1) :

| Moment | Avant | Limite de tours |
|---|---|---|
| 5 h | 1 Archer, 6 Totem, 2 Catapulte, 1 Mage, 3 Baliste, 1 Sorcier | 1 Archer, 5 Totem, 3 Catapulte, 2 Mage, 2 Baliste, 1 Sorcier |
| 10 h | 1 Archer, **9 Totem, 8 Oracle** | 2 Archer, 5 Totem, 4 Catapulte, 1 Mage, 3 Baliste, 3 Sorcier, 2 Trébuchet |
| 20 h | **8 Totem**, 2 Baliste, **6 Oracle, 6 Trébuchet** | 2 Archer, 5 Totem, 4 Catapulte, 1 Mage, 3 Baliste, 3 Sorcier, 1 Oracle, 2 Trébuchet |
| 40 h | 1 Archer, 4 Totem, 4 Catapulte, 2 Baliste, 1 Sorcier, **10 Trébuchet** | 2 Archer, 5 Totem, 4 Catapulte, 2 Mage, 3 Baliste, 3 Sorcier, 1 Oracle, 2 Trébuchet |

Part des dégâts utiles (moyenne des 3 parties, « de - à » selon le type de vague ; vagues 26-50 / 51-100 / 101+) :

| Tour | Avant | Limite de tours |
|---|---|---|
| Archer | 1-5 % / 3-20 % / 6-16 % | 2-7 % / 4-16 % / 4-14 % |
| Catapulte | 30-76 % / 0-4 % / 26-67 % | 27-74 % / **13-43 %** / 23-79 % |
| Baliste | 18-55 % / 9-25 % / 4-19 % | 22-66 % / 5-17 % / 6-27 % |
| Sorcier | 1-24 % / 0-5 % / 2-36 % | 0-14 % / **2-39 %** / 3-32 % |
| Oracle | 0 % / 28-32 % / 0 % | 0 % / **0-1 %** / 0 % |
| Trébuchet | 0 % / 24-56 % / 6-20 % | 0 % / 17-53 % / 3-7 % |
| Totem, Mage (contrôle) | 2 % au plus | 1 % au plus |

- Le joueur simulé empilait des Totems (jusqu'à 9) et des légendaires (8 Oracles, 10 Trébuchets) : achat par achat,
  c'était le meilleur choix, mais pas au total. Obligé de mélanger (Catapultes, Balistes, Sorciers), il va **plus
  vite** : vague 100 2 h 26 plus tôt, record +14 à 40 h. Il achète aussi plus de lancers à l'autel (plus rien à
  poser), d'où une 1re légendaire plus tôt.
- **Cible manquée** : vague 100 vers 18-20 h, mesurée à **16 h 00**. Aucun réglage changé ici. **Proposition (une
  seule)** : `IdleConfig.HEALTH_WAVE_POWER` de 2,55 à **2,62** (PV +17 % à la vague 50, +22 % à la 100). Essayé avec
  `-Regler "IdleConfig.HEALTH_WAVE_POWER=2.62"` (mêmes graines) : vague 50 à 4 h 58, **vague 100 à 18 h 10**, record
  154 (145 - 168) à 40 h, murs 31-70 / 71-100 : 80 % sous 20 min / 31 min ; 17 objectifs sur 26 (le 20, « Baliste et
  Trébuchet utiles au milieu de partie », passe à NON). À décider avec le propriétaire.
- Honnêtement : l'**Oracle** ne sert presque plus (0-1 % des dégâts) : avec 2 exemplaires au plus, le joueur simulé
  préfère 2 Trébuchets et ne pose qu'un Oracle, tard (vague ~87). Le Mage reste une tour de contrôle (0 % des dégâts,
  2 à 3 posés). 3 parties seulement.
- Relecture : l'essai rapide relancé redonne exactement ces chiffres ; relancé sans limite (`-Regler` avec
  `IdleTowers.MAX_COPIES` à 99 partout), il redonne exactement la colonne « avant » (seule la limite a changé le
  joueur simulé) ; la proposition à 2,62 aussi. Erreur faite exprès dans le joueur simulé (une tour de plus que la
  limite proposée) : `Run:execute` arrête la partie dès le 6e Totem. Le test Studio, rejoué hors de Studio avec le
  vrai `PlotGame.luau` : 15 sur 15, et il voit une limite décalée de 1 ou une vieille sauvegarde rognée au chargement.

## L'Oracle un peu plus fort (décision du propriétaire, 30/09/2026)

Constat de l'essai du dessus : l'Oracle ne faisait plus que 0-1 % des dégâts. Décision : « renforce un peu alors, mais
pas trop », sans ralentir le jeu (vague 100 vers 16 h : bien). **Changé : ses dégâts, 50 -> 60 par ennemi touché**
(`IdleTowers.Defs.Chain.damage`, +20 %). Rien d'autre (portée 20, 4 cibles, 1,2 s, `HEALTH_WAVE_POWER` inchangés).

**Pourquoi il ne servait plus** (banc d'essai, duels, parties du simulateur) :

- **Pas une tour faible** : à niveau égal et sans doublons, c'était déjà la meilleure tour du banc d'essai contre les
  Escarmouches, les Charges et les boss (vagues 25 à 150) et contre les Gardes (vagues 50 à 150), 1,4 à 1,5 fois la
  Baliste en duel, 4,1 fois la Catapulte contre une foule.
- **Surtout le hasard de l'autel** : une légendaire tirée est un Oracle ou un Trébuchet (50/50). Dans les 3 parties de
  l'essai rapide, le Trébuchet sort en premier (vagues 61-65) et prend les emplacements achetés à ce moment ; l'Oracle
  arrive vers la vague 87 (79 à 95), quand presque tous les emplacements sont pris. Il est posé aux vagues 114, 98 et
  96 : il ne joue presque pas les vagues 51-100. Le joueur simulé le monte tout de suite vers le niveau 60-70 et
  continue ensuite (niveau ~95 à la vague 150), mais il reste 10 à 15 niveaux sous les Catapultes et les Balistes, qui
  ont aussi 20 fois plus de doublons (graine 1 à 40 h : 18 pour l'Oracle, 407 pour la Catapulte) : 0-1 % des dégâts
  après la vague 100.
- **Avec 3 parties de plus** (`-Graines 6` : dans les graines 4 à 6, l'Oracle sort plus tôt et il est posé aux
  vagues 70, 75 et 87, avant le Trébuchet dans la graine 4), il servait déjà : 8-13 % des dégâts des vagues 51-100 en
  moyenne des 6 parties (8-13 % aussi sur 12 parties), jusqu'à 43 % d'une tranche dans une partie. Le « 0-1 % » venait
  donc surtout de l'ordre de sortie dans les 3 parties de référence. Dans celles-ci, la limite de 2 ne le gênait pas
  (1 ou 2 posés) ; quand il sort tôt, le joueur simulé en pose souvent 2, le maximum (avant la limite : jusqu'à 8).
- **Le joueur simulé y est pour quelque chose, sans bug.** Il est prudent exprès (il ne remplace qu'une de ses 3 tours
  les moins utiles, posée depuis 2 h, et compte le prix de tous les niveaux d'une tour neuve) et prend toujours l'achat
  au meilleur rapport gain / prix. Dans les parties 1 et 3, il achète bien un nouvel emplacement après le déblocage de
  l'Oracle, mais il y pose un Mage de niveau 1 (il ralentit tout de suite pour presque rien, alors qu'un Oracle doit
  être monté d'une soixantaine de niveaux pour servir) : l'Oracle attend l'emplacement suivant, environ 7 h et 4 h
  après son déblocage (partie 2 : il remplace l'Archer 3 vagues après). Un vrai joueur poserait sûrement sa légendaire
  sur le nouvel emplacement. C'est la règle voulue du joueur simulé (la changer déplacerait tous les résultats de
  référence) : pas changée.

Essais (`run.ps1 -Rapide -Graines 6 -Regler "IdleTowers.Defs.Chain.damage=..."` : 6 parties x 40 h ; part des dégâts
utiles, « de - à » selon le type de vague, moyenne des parties ; « 1 partie » = meilleure part d'une tranche dans une
seule partie, objectif 15 du rapport) :

| Dégâts de l'Oracle (6 parties) | Oracle 51-100 / 101+ | 1 partie | Trébuchet 51-100 / 101+ | Vague 100 | Record 40 h |
|---|---|---|---|---|---|
| 50 (avant) | 8-13 % / 1-2 % | 43 % | 20-45 % / 2-8 % | 16 h 35 | 160 (155 - 165) |
| 55 | 13-20 % / 3-5 % | 70 % | 21-47 % / 4-9 % | 16 h 21 | 162 (155 - 173) |
| **60 (gardé)** | **13-20 % / 1-2 %** | 48 % | 19-46 % / 3-6 % | 16 h 09 | 164 (155 - 179) |
| 70 | 25-42 % / 3-6 % | 68 % | 15-45 % / 2-7 % | 16 h 29 | 161 (155 - 170) |
| 75 | 27-46 % / 7-12 % | 75 % | 14-44 % / 3-7 % | 16 h 12 | 159 (145 - 167) |

Aussi essayés sur les 3 parties de référence seulement (Oracle 51-100 / 101+, record à 40 h) : portée 24 : 1-8 % /
1 %, 163 ; 5 cibles : 0-8 % / 2-4 %, 160 ; dégâts 65 : 3-8 % / 0-2 %, 164 ; dégâts 80 : 12-21 % / 2-5 %, 159 (jusqu'à
41 % dans une partie). Les 5 cibles changeraient aussi le texte « 4 cibles » des fiches : pas gardé.

Relecture sur **12 parties** (`-Graines 12`, plus sûr : les parties 1 à 6 sont les mêmes qu'au-dessus) :

| Dégâts de l'Oracle (12 parties) | Oracle 51-100 / 101+ | 1 partie | Trébuchet 51-100 / 101+ | Vague 100 | Record 40 h | Objectifs |
|---|---|---|---|---|---|---|
| 50 (avant) | 8-13 % / 1-2 % | 45 % | 17-42 % / 3-9 % | 16 h 24 | 162 (149 - 175) | 18 sur 26 |
| 55 | 11-16 % / 2-4 % | 70 % | 17-38 % / 3-8 % | 16 h 18 | 164 (155 - 175) | 18 sur 26 |
| **60 (gardé)** | **11-16 % / 2-4 %** | 62 % | 15-37 % / 3-10 % | 15 h 59 | 163 (149 - 179) | 18 sur 26 |
| 65 | 22-31 % / 3-5 % | 81 % | 13-37 % / 4-10 % | 15 h 59 | 163 (155 - 170) | 18 sur 26 |
| 70 | 27-41 % / 4-7 % | 68 % | 13-39 % / 2-7 % | 16 h 23 | 161 (149 - 171) | 17 sur 26 |

(Le Trébuchet, lui, va jusqu'à 74-77 % d'une tranche dans une partie, avec tous ces réglages.)

Gardé : **60**. Il donne une vraie place à l'Oracle (11-16 % des dégâts des vagues 51-100 sur 12 parties, 13-20 % sur
6 ; le Trébuchet garde 15-37 %) sans en faire la tour obligatoire, et la vitesse ne bouge pas. 55 donne la même part en
moyenne : 60 est gardé pour que le renfort « un peu » se voie en jeu (+20 %, « 60 dégâts/coup » sur la fiche).
**Ne pas monter plus haut** : dès 65, le joueur simulé en pose plus souvent 2 et les monte plus haut, et l'Oracle prend
22-31 % des dégâts des vagues 51-100 (jusqu'à 81 % dans une partie) ; 27-41 % à 70.

Essai rapide officiel (`run.ps1 -Rapide` : 3 parties x 40 h, mêmes graines que « Limite de tours identiques ») :

| Scénario « base » | Avant (dégâts 50) | **Après (dégâts 60)** |
|---|---|---|
| Vague 50 / 100 | 4 h 17 / 16 h 00 | 4 h 17 / **16 h 11** |
| Record à 40 h | 163 (159 - 165) | **162** (155 - 165) |
| Oracle 51-100 / 101+ | 0-1 % / 0 % | 0-4 % / 0-1 % |
| Trébuchet 51-100 / 101+ | 17-53 % / 3-7 % | 22-57 % / 2-7 % |
| Oracle : posé à la vague (graines 1, 2, 3) ; posés à 40 h | 114, 98, 96 ; 1, 2, 1 | 111, 98, 96 ; 1, 2, 1 |
| Meilleure part d'une tranche dans 1 partie : Oracle | 4 % | 11 % |
| Murs 31-70 / 71-100 (80 % sous…) | 14 min / 33 min | 16 min / 33 min |
| Duels (1 = la Baliste) / foule (1 = la Catapulte) : Oracle | 1,40-1,55 / 4,14 | 1,68-1,85 / 4,97 |
| Anti-méta, mélange à 5 / 10 / 20 / 40 h | 53 / 78 / 106 / 157 | 53 / 75 / 107 / 157 |
| Objectifs atteints | 18 sur 26 | 17 sur 26 (voir plus bas) |

Tours du joueur simulé (graine 1) : **10 h** : 2 Archer, 5 Totem, 4 Catapulte, 1 Mage, 3 Baliste, 3 Sorcier,
2 Trébuchet (avant et après) ; **20 h** : 2 Archer, 5 Totem, 4 Catapulte, 1 Mage (après : 2), 3 Baliste, 3 Sorcier,
1 Oracle, 2 Trébuchet ; **40 h** : 2 Archer,
5 Totem, 4 Catapulte, 2 Mage, 3 Baliste, 3 Sorcier, 1 Oracle, 2 Trébuchet (avant et après).

- Dans les 3 parties de référence, l'Oracle sort toujours après le Trébuchet, quand presque tout est pris : +20 % de
  dégâts n'y change presque rien (0-4 %). Il faudrait ~80 pour qu'il y serve vraiment (12-21 %), mais dès 65-75, sur
  6 ou 12 parties, il prend 22 à 46 % des dégâts des vagues 51-100 : trop.
- **Après la vague 100, les deux légendaires restent petites** (Oracle 1-2 %, Trébuchet 2-8 % sur 6 parties ; 2-4 % et
  3-10 % sur 12) : les tours communes et rares y ont des centaines de doublons (+2 % chacun), les légendaires presque
  pas. Pour 10 % après la vague 100, il faudrait ~75, qui ferait de l'Oracle la tour obligatoire des vagues 51-100.
  Pas fait.
- Objectifs : le 15 (« les 8 tours utiles ») ne manque plus que le Mage (tour de contrôle) ; le 16 passe à « PEU VARIÉ » :
  au banc d'essai (équipes de N tours identiques, SANS doublons, impossibles en jeu), l'Oracle est maintenant le
  meilleur contre tous les types de vague à partir de la vague 25 (avant : tous sauf les Levées et une Garde) ; dans
  les vraies parties, il n'écrase rien (sur 12 parties, le 16 reste OK de justesse : 3 tours différentes). Le 14 : dans
  une partie (record 155), le 22e emplacement n'est pas acheté en 40 h (hasard de la partie : 21,7 en moyenne, 22e à la
  vague 105 dans les deux autres).
- `run.ps1 -Verifier` : 162 vagues sur 162 identiques, 0,00 s d'écart, 106 sur 106 avec les mêmes carreaux, 2 essais
  de dégâts sur 2, 4 vagues faites à la main sur 4 (le combat n'a pas changé, seul le chiffre de l'Oracle). Aucun
  test Studio ne vérifie ses dégâts ; la fiche lit les vrais chiffres (60 par coup), le texte « rebondit entre quatre
  ennemis » reste juste.
- Relecture : l'essai rapide relancé redonne exactement ce rapport, et le tableau de 6 parties est retrouvé (lignes 50
  et 60) ; `-Verifier` et `check.ps1` : OK. Tableau de 12 parties ajouté plus haut. Simulation complète (5 scénarios x
  3 parties x 100 h) avec 60 puis 50 : l'Oracle ne dépasse 6 % des dégâts (moyenne des 3 parties) dans aucun scénario ;
  « base » : vague 100 à 16 h 11 (16 h 00 avec 50), record à 100 h 256 (261) ; « forge » : identique. Dans
  « renaissance », une partie finit à 765 au lieu de 1 729 à 100 h : ce scénario « explose » vers 70-80 h (record de
  ~450 à plus de 1 000) à un moment qui change beaucoup d'une partie à l'autre. Sur 12 parties de 60 h, rien ne bouge
  en moyenne (record 258 à 40 h et 392 à 60 h, contre 258 et 393 avec 50 ; 9 parties identiques).

## Forge sans x50 ni x100, « tout sur l'Archer », prix des améliorations x1,45 (décisions du propriétaire, 01/10/2026)

**Forge** : x2 dégâts 37 %, x2 vitesse 31 %, x3 20 %, x5 10,9 %, x10 1 %, x20 0,1 % ; x50 et x100 retirées (celles
déjà obtenues gardent leur effet, `IdleConfig.RETIRED_BONUSES`). Le simulateur tire dans `IdleConfig.BONUSES` : rien
à changer de son côté.

**« Tout sur l'Archer »** (question du propriétaire : sa copine a eu x20 au 1er lancer de forge ; « elle ne sera plus
jamais bloquée si elle met tout sur l'Archer ? »). Nouveaux scénarios `archer-*` : l'Archer de l'emplacement 1 et un
Totem de givre à côté (emplacement 5, la meilleure paire au vrai moteur), toutes les pièces dans l'Archer, runes
forcées (x20 au 1er lancer de forge, 100 K ; x2 vitesse au 2e, 500 K). Et `base-archer-x20-x2` : le joueur normal avec
les mêmes runes forcées sur son meilleur Archer. Avec les anciens prix (x1,35), 3 parties x 40 h :

| Scénario | Record 1 / 4 / 12 / 40 h | Vague 100 |
|---|---|---|
| base (joueur normal) | 27 / 49 / 86 / 162 | 16 h 11 |
| archer-sans-rune | 29 / 45 / 64 / 95 | jamais |
| archer-x20 | 28 / 104 / 158 / 229 | 3 h 38 |
| archer-x20-x2 | 28 / 121 / 186 / 272 | 2 h 50 |
| archer-x20-x2-givre (Totem amélioré) | 28 / 147 / 248 / 372 | 2 h 21 |
| archer-x20-x2-2givres (Totems 5 et 2, collés à l'Archer) | 29 / 158 / 266 / 399 | 2 h 15 |
| archer-x20-x2-4givres (5, 2 + 12 et 3 en face) | 28 / 144 / 258 / 393 | 2 h 42 |
| base-archer-x20-x2 | 27 / 121 / 255 / 514 | 3 h 18 |

- Il bloque sur les vagues à beaucoup d'ennemis (Escarmouches, surtout après une Garde colossale ; Charges ; Levées) :
  l'Archer ne tire que sur un ennemi à la fois. La Garde colossale et le Seigneur de guerre jamais (gelés par le Totem).
  À chaque mur il ne manque que x1,1 à x1,5 de dégâts (1 ou 2 niveaux).
- 2 Totems collés valent mieux qu'un (l'ennemi reste ~22 s sous les flèches au lieu de 18) ; 4 n'apportent rien de plus.
  Le Totem monte à son maximum (niveau 146, +300 %) dès 12 h : ça coûte moins qu'un seul niveau d'Archer.
- Renaissance (après 15 min bloqué) : moins bien pour lui (228 contre 272 à 40 h) : chaque remontée prend ~2 h.

**Le problème** (« le plus rentable c'est d'investir sur peu de tours ») : `UPGRADE_COST_GROWTH` = `UPGRADE_DAMAGE` =
1,35, donc une pièce rapporte autant de dégâts à n'importe quel niveau, et la tour au plus gros multiplicateur (rune,
doublons, fragilité) reste TOUJOURS le meilleur achat. `base-archer-x20-x2` à 40 h : Archer niveau 387, ses 17 autres
tours niveau 12, 100 % des pièces des tours dans l'Archer.

**Décision** (« il faudrait que monter chaque tour soit rentable, exemple augmenter le prix des upgrades ») : prix x1,45
par niveau (dégâts toujours x1,35 : chaque niveau de plus sur la même tour rapporte ~7 % de moins par pièce), compensé
par des PV qui montent moins vite : **`UPGRADE_COST_GROWTH` 1,35 -> 1,45 et `HEALTH_GROWTH` 1,25 -> 1,207** (pièces
inchangées : les grands nombres viennent toujours des vagues). Limite de sécurité : `HEALTH_GROWTH` doit rester
au-dessus de `REWARD_GROWTH`^(ln 1,35 / ln prix), 1,1975 ici ; en dessous, un joueur fort ne bloque plus jamais (vu
avec x1,55 et des PV x1,16 : 1 104 à 40 h). Essais (3 parties x 40 h, `-Regler`) :

| Prix par niveau (compensation) | base 1 / 4 / 12 / 40 h | Vague 100 | forge 40 h | renaissance 40 h | base-archer-x20-x2 40 h (écart de niveau) | archer-x20-x2 40 h | archer-sans-rune 40 h |
|---|---|---|---|---|---|---|---|
| x1,35 (avant) | 27 / 49 / 86 / 162 | 16 h 11 | 251 | 229 | 514 (375) | 272 | 95 |
| **x1,45 (PV x1,207)** | 29 / 50 / 89 / 156 | 15 h 50 | 221 | 231 | 359 (38) | 177 | 70 |
| x1,55 (PV x1,16 + `HEALTH_WAVE_POWER` 3) | 29 / 50 / 89 / 177 | 14 h 59 | 279 | 302 | 1 104 (19), s'emballe | 188 | 56 |
| x1,65 (PV x1,143 + puissance 3) | 30 / 53 / 93 / 160 | 14 h 41 | 258 | 239 | 415 (12) | 146 | 48 |
| x1,8 (PV x1,1227 + puissance 3) | 31 / 56 / 92 / 150 | 15 h 24 | 237 | 263 | 342 (9) | 127 | 42 |

Gardé : **x1,45**, le plus simple (2 chiffres) et sûr ; à partir de x1,55 il faut aussi `HEALTH_WAVE_POWER` et on est
pile à la limite de sécurité (avec des PV plus prudents, base tombe sous 150 à 40 h). Vérifié avec le vrai code
(`run.ps1 -Graines 3 -Heures 40`) : mêmes chiffres que l'essai. `base-archer-x20-x2` répartit enfin : Archer à rune
niveau 70 / 134 / 222 à 4 / 12 / 40 h, ses autres tours 28 / 97 / 184. `archer-x20-x2-2givres` : 229 à 40 h (399
avant). 1 T de pièces par minute vers 23 h (23 h 20 avant). Sur 100 h (essai) : base 219-225 (256 avant), le joueur à
rune 430-450 ; rien ne s'emballe. Objectifs : 15 OK au lieu de 17, le début étant un peu plus facile (premier mur à la
vague 18 au lieu de 16, vague 25 en 28 min au lieu de 33-35) ; gardé ainsi (le propriétaire voulait un début
généreux). `HEALTH_BUDGET` 24 remettait le début, mais ralentissait la suite (vague 100 en 18 h 30, 146 à 40 h).

Sauvegardes existantes (le jeu est public) : les PV baissent d'un coup, une défense qui tenait la vague 100 tient
~116 ; ensuite leurs améliorations coûtent plus cher (prochain niveau d'une tour niveau 100 : 190 Qa au lieu de
160 T). Scènes de tournage et bouton « SCÈNES (Studio) » : tours baissées de 74 à 62 (dragon), 28 à 23 (Titan du
givre), 59 à 50 (horde) pour garder le même temps sous le feu.

## Ce qui reste (honnêtement)

1. **Murs des vagues 71-100 trop longs** (80 % sous 33 min, cible 20) : surtout les Escarmouches juste après une
   Garde colossale (46, 56, 96 : on y farme une vague qui rapporte peu) et les Gardes 85-95. Essayé : colosse qui
   rapporte 0,8 à 1 fois une Escarmouche → murs 31-70 plus courts (80 % sous 14-22 min), pas ceux de 71-100, et
   vague 100 plus tôt. Les deux cibles (vague 100 après 15 h, murs courts) tirent en sens contraire.
2. **Sorcier des arcanes presque jamais posé** par le joueur simulé (4 % des dégâts au mieux) : il bat bien la
   Baliste en duel contre les lents, mais la Baliste perçante et les légendaires lui passent devant. Un vrai
   joueur peut s'en servir contre les boss ; à revoir si les essais le confirment. (Depuis le carreau à 3 ennemis
   au plus : de nouveau posé, jusqu'à 36 % des dégâts contre les colosses et les boss, voir plus haut.)
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

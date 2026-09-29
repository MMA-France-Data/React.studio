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

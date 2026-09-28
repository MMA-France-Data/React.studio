# Équilibrage du mode solo : résultats

Le simulateur (`tools/balance/idle`, voir [`README.md`](README.md)) a joué le mode infini avec les **vrais
modules du jeu**. Référence : le scénario **« base »** = un joueur actif (il ramasse tout, lance la machine à
tours à chaque vague, achète au meilleur rapport), **sans forge runique ni renaissance**, 3 parties de 100 h.
Les chiffres « après » viennent de `idle/out/rapport.txt`.

> **Relecture (correction du simulateur).** Loin dans le jeu (après ~40 h, vers la vague 130), le joueur simulé
> jugeait mal les petits achats : ses tours faisaient 1e20 de dégâts et plus, et le gain d'une tour neuve ou
> de bas niveau (1e-16 de ce total) était arrondi à zéro. Il n'améliorait plus jamais ses nouvelles tours et
> finissait avec 21 tours au niveau 1 et une seule tour de haut niveau. C'est corrigé (`idle/Run.luau`,
> `logGain`) : jusqu'à la vague 100 (~22 h), rien ne change ; après, les chiffres ci-dessous sont ceux du
> simulateur corrigé (record 217 à 100 h au lieu de 206, murs après la vague 100 moins extrêmes, renaissance et
> forge beaucoup plus fortes qu'annoncé avant). Le mur « vagues 31-100 » est aussi coupé en deux (31-70 et
> 71-100) : sur la tranche entière, la bonne médiane cachait les murs d'une heure et plus des vagues 71-100.

## Objectifs : avant / après

| Objectif | Cible | Avant | Après |
|---|---|---|---|
| Vagues 1 à 10 | 5-8 min, sans mur | 13 min, dont 7 min bloqué (boss de la vague 10) | **7 min, aucun mur** |
| Premier vrai mur | vers la vague 12-16 | vague 10 | **vague 13** (3 min) |
| Vague 15 (renaissance possible) | 20-30 min | 16 min | **23 min** |
| Vague 25 | ~1 h | 50 min | **1 h 07** |
| Vague 50 | 4-8 h | 6 h 35 | **4 h 35** |
| Vague 100 | 20-40 h | jamais en 50 h (record 93) | **21 h 56** |
| Murs du début (vagues 11-30) | 1-5 min | médiane 18 min | **médiane 3 min** (80 % font moins de 10 min) |
| Murs vagues 31-70 | 10-20 min au plus | médiane 1 h 37 (31-100), jusqu'à 15 h | **médiane 11 min** (80 % font moins de 18 min) |
| Murs vagues 71-100 | 10-20 min au plus | (voir ci-dessus) | **TROP LONGS** : médiane 16 min, mais 80 % font moins de 52 min seulement ; 14 % dépassent 1 h (boss 80, 90, 100 ; Garde 85, 95 ; Charge 91 : 1 h à 1 h 30 en moyenne, jusqu'à 2 h 26) |
| Murs après la vague 100 | (idle : ils s'allongent) | - | médiane 28 min (80 % font moins de 1 h 05, jusqu'à 4 h 21) |
| Murs variés | pas que des boss, boss les plus durs | 100 % des murs = boss | Escarmouche 49 %, Levée 13 %, Charge 16 %, Garde 11 %, boss 12 % (**boss les plus longs** : médiane 32 min) |
| Pas de zone morte | jamais 1 h sans achat | 33 min au plus | 17 min au plus |
| 22 emplacements | le dernier vers la vague 80-100 | 13,8 en 50 h, le 22e hors de portée | **un toutes les 4-5 vagues, le 22e vers la vague 98** |
| 8 tours utiles | chacune ≥ 10 % des dégâts quelque part | Archer 100 %, 5 tours à 0 % | **toutes entre 51 et 86 %** selon le moment |
| Chaque type de vague a sa tour | tours différentes | 3 | **6 tours différentes** |
| Aucune tour dominée pour toujours | aucune | Catapulte, Sorcier, Oracle | **aucune** |
| Légendaires fortes, pas écrasantes | x1 à x3 | x0,56 à x1,96 | x0,81 à x1,54 |
| Grands nombres | ≥ 1 T de pièces / min vers 80-90 h | ~15 M / min à 50 h | **1 T / min vers 29 h ; 8,2 Qi / min à 80 h ; 130 Qi / min à 90 h** |
| Nombres finis | jusqu'à la vague 1500 et au niveau 1000 | non vérifié | **oui** (voir plus bas) |

**16 objectifs atteints sur 18.** Deux ratés :
- « UN PEU LONGS » au début : la médiane des murs est bonne (3 min) mais 20 % des murs dépassent 8 min
  (surtout la Levée d'écuyers 21 et la Garde colossale 25).
- « TROP LONGS » vers les vagues 71-100 : 40 % des murs dépassent 20 min et 14 % dépassent 1 h. Attention, les
  deux cibles se contredisent un peu : avec un mur sur presque chaque vague, atteindre la vague 100 en 20-40 h
  demande ~20-40 min par vague entre les vagues 50 et 100 ; des murs de 20 min au plus demanderaient des murs
  très réguliers (aujourd'hui, les boss et les Gardes colossales de ces vagues bloquent 3 à 5 fois plus que
  les autres).

### Les pièces au fil des heures (scénario « base », valeur du milieu des 3 parties)

| Temps | Record | Pièces en poche | Revenu par minute | Total gagné |
|---|---|---|---|---|
| 1 h | vague 24 | 2,2 K | 970 | 25 K |
| 10 h | vague 73 | 65 M | 40 M | 3,3 B |
| 25 h | vague 107 | 7 B | 100 B | 9,8 T |
| 50 h | vague 149 | 32 T | 836 T | 237 Qa |
| 80 h | vague 190 | 442 Qa | 8,2 Qi | 1,8 Sx |
| 90 h | vague 204 | 1,36 Sx | 130 Qi | 39 Sx |
| 100 h | vague 216 | 1,4 Sx | 3,69 Sx | 879 Sx |

Revenu par minute : 1 M vers 6 h, 1 B vers 16 h, **1 T vers 29 h**, 1 Qa vers 51 h, 1 Qi vers 73 h, 1 Sx vers 93 h.
Les trillions arrivent donc avant 80-90 h (le minimum demandé) et ensuite tout continue d'exploser.
Pour qu'ils arrivent plus tard, baisser `IdleConfig.REWARD_GROWTH` (par exemple 1,22) et relancer.

**Limites des nombres** : sans garde-fou, les PV deviendraient infinis vers la vague 3 100 ; à partir de
`IdleConfig.MAX_SCALING_WAVE` (3 000), PV et pièces arrêtent de grandir, donc tout reste fini. Vague 1500 :
ennemi de 8,8e151 PV, 1,5e146 pièces par vague. Améliorations : niveau 1000 = 3,2e131 pièces ; un prix ne
deviendrait infini qu'au niveau ~2 300, jamais nécessaire. `NumberFormat.short` a des suffixes jusqu'à
10^93 (Tg) puis passe en notation scientifique (« 1.23e96 ») : les PV y passent vers la vague 930.

## Ce qui a changé et pourquoi

1. **Les vagues grandissent beaucoup plus** (`IdleConfig`) : pièces **x1,25 par vague** (avant x1,18), PV
   x1,25 par vague multipliés par `((vague + 5) / 6)^2,3` (avant x1,22). Au total les PV montent toujours un
   peu plus vite que les pièces : x1,45 d'une vague à l'autre vers la vague 10, x1,30 à la 50, x1,28 à la 100.
   `HEALTH_BUDGET` 150 -> 18. Pourquoi : les grands nombres viennent des vagues elles-mêmes, et cette
   forme donne des murs courts au début qui s'allongent doucement, au lieu d'exploser (avant, le temps de
   farm était multiplié par 1,11 à chaque vague).
2. **Même prix d'amélioration pour toutes les tours** (`IdleTowers.upgradeCost`) : 20 pièces pour le
   niveau 2, puis **x1,35 par niveau** (avant : prix de pose x 2 x 1,5 par niveau). Pourquoi : avant, à dépense
   égale, l'Archer (10 pièces) finissait 5 fois plus fort que le Trébuchet (400 pièces), d'où 100 % des dégâts
   pour l'Archer. Et avec un prix qui monte comme les dégâts (x1,35), une pièce rapporte autant de dégâts à
   n'importe quel niveau d'une tour : une tour neuve vaut autant la peine d'être améliorée qu'une vieille tour
   (avec un prix plus lent que les dégâts, tout mettre sur une seule tour était toujours mieux).
3. **Stats des tours** (`IdleTowers`) : Totem 2 -> 4,2 ; Catapulte 12 -> 17 ; Mage 8 -> 14 ; Baliste 45 ->
   40 (recharge 3 -> 4 s, zone 4 -> 2) ; Sorcier 6 -> 9 (recharge 0,1 -> 0,25 s, vise le plus résistant) ;
   Oracle 30 -> 15 par ennemi touché ; Trébuchet 220 -> 40 (zone 10 -> 5). Pourquoi : à prix égal, chaque type
   de vague a maintenant sa meilleure tour (Oracle contre Escarmouches et Charges, Sorcier contre la Garde
   colossale, Trébuchet et Mage contre les boss, Totem et Catapulte contre les hordes au début) et la portée
   (30 pour la Baliste, 70 pour le Trébuchet) est compensée par moins de dégâts.
4. **`BASE_HEALTH` 20 -> 10** : chaque type de vague peut être raté (avant, seuls les boss et les hordes
   pouvaient bloquer).
5. **Types de vagues** : parts du budget ajustées (Levée 1 -> 0,68 avec 15 à 45 écuyers ; Charge 1 -> 0,6 ;
   Garde 1,2 -> 1,5 ; Escarmouche 1 -> 1,07 ; boss 1,5 -> de 0,4 à la vague 10 jusqu'à 0,8 dès la vague 20).
   Les 10 premières vagues sont des Escarmouches (sauf la 5 et le boss de la 10), et la vague juste avant chaque
   boss aussi : c'est celle qu'on farme quand le boss bloque, et elle rapporte bien.
6. **Doublons +5 % -> +2 %** et machine à tours un peu plus généreuse aux paliers hauts (vague 50+ : 12 % de
   Légendaires, vague 100+ : 20 %). Pourquoi : les tours communes recevaient des centaines de doublons et
   écrasaient les autres ; les grands nombres doivent venir des vagues, pas des doublons.
7. **Emplacements** (`PlotLayout`) : 500 x3,8 (qui accélère) -> **100 x2,6** par emplacement : le 5e vers la
   vague 14, le 22e (~1,1 B) vers la vague 98. Avant, chaque emplacement coûtait 4 à 7 fois le précédent.
8. **`MAX_SCALING_WAVE` = 3 000** : garde-fou contre les nombres infinis (voir plus haut).

Le prix de la forge en pièces (`bonusSpinCost`, 15 vagues de gains à ton record) suit automatiquement la
nouvelle croissance des pièces.

## Renaissance et forge (pour information)

- **Renaissance** (formule inchangée, règle acceptée par le propriétaire) : **très forte** avec ces réglages.
  En renaissant dès qu'il bloque 15 min à son record, le joueur simulé fait ~53 renaissances en 100 h, bonus
  de pièces +615 %, record **487 contre 217** sans ; vague 100 en 17 h au lieu de 22 h, vague 200 en 39 h au
  lieu de 86 h ; 3,6 fois plus de lancers de machine. Un cycle (revenir au record) dure 53 min en moyenne.
  Rejouer 1 à 25 prend 3 min et rapporte jusqu'à +40 % de bonus par heure et ~500 lancers de machine par heure
  (contre ~30 en jeu normal).
- **Forge runique en pièces** (1 lancer / 30 min) : **très forte** aussi : record 471 à 100 h contre 217 sans,
  vague 100 en 10 h 38 au lieu de 22 h. Forge + renaissance : vagues 750 à 1 200 à 100 h (915 en moyenne ; les
  PV passent en notation scientifique vers la vague 930).
- Explication commune : loin dans le jeu, les PV montent à peine plus vite que les pièces (x1,264 contre x1,25
  à la vague 200) et le prix des améliorations monte comme les dégâts. Pour une vague de plus, le temps de
  farm n'est multiplié que par ~1,01 : un revenu x7 (renaissances) ou des dégâts x20 à x100 (forge) font gagner
  des centaines de vagues. Un joueur actif qui utilise la forge en pièces arrive donc à la vague 100 vers
  10-17 h, sous la cible de 20-40 h (qui n'est tenue que sans forge ni renaissance).
- Pistes (non appliquées, choix de design à faire) : des PV qui montent nettement plus vite que les pièces
  loin dans le jeu (par exemple `HEALTH_WAVE_POWER` plus grand, ou `HEALTH_GROWTH` 1,26), ce qui allonge
  aussi les murs sans forge ; ou une forge moins fréquente. Essais faits AVANT la correction du simulateur
  (donc seulement indicatifs) : un lancer toutes les 2 h donnait encore la vague 432 ; `HEALTH_GROWTH` 1,26
  ramenait la forge à la vague 247, mais sans forge la vague 100 arrivait alors à 40 h avec des murs d'environ
  1 h après la vague 100.

## Limites

- Le joueur simulé n'achète qu'entre les vagues, ramasse tout tout de suite, ne se déconnecte jamais et
  n'utilise pas de Robux : les temps sont ceux d'un joueur actif connecté en continu.
- Il ne revend une tour que si elle est posée depuis 2 h (une seule par entracte) : sans cette limite, il
  revendait en boucle des tours de haut niveau au mur.
- 3 parties par scénario : les chiffres varient de ~10 % d'une partie à l'autre (plus pour la forge).

## Relancer

Depuis le dossier `roblox-ranked-td` :

```bat
powershell -ExecutionPolicy Bypass -File tools\balance\idle\run.ps1            (complet : ~35 min, 4 scénarios x 3 parties x 100 h)
powershell -ExecutionPolicy Bypass -File tools\balance\idle\run.ps1 -Rapide    (~2-3 min : 3 parties x 40 h, scénario base)
powershell -ExecutionPolicy Bypass -File tools\balance\idle\run.ps1 -Rapide -Regler "IdleConfig.REWARD_GROWTH=1.22"
```

Le rapport commence par la comparaison aux objectifs (`idle\out\rapport.txt`).

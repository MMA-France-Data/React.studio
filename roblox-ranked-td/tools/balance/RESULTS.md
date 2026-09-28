# Équilibrage du mode solo : résultats

Le simulateur (`tools/balance/idle`, voir [`README.md`](README.md)) a joué le mode infini avec les **vrais
modules du jeu**. Référence : le scénario **« base »** = un joueur actif (il ramasse tout, achète au meilleur
rapport gain / prix, lancers de l'autel compris), **sans forge runique ni renaissance**, 3 parties de 100 h.
Les chiffres « après » viennent de `idle/out/rapport.txt`.

## Les nouvelles règles de cette mise à jour

Retours du propriétaire après ses essais, déjà codés dans le jeu (`PlotGame.luau`) et maintenant suivis par
le simulateur :

- **Une seule fuite = vague ratée** : plus de PV de base, un seul ennemi au bout du chemin et on redescend
  d'une vague (la vague s'arrête tout de suite ; les pièces des ennemis déjà tués restent).
- **Autel des héros payant** : plus de lancer gratuit par vague ; x1, x10, x100, x1 000, x1 000 000 payés en
  pièces, aux chances du **record**.
- **Un seul colosse** par Garde colossale, **un seul Seigneur de guerre** (et 6 fantassins) par vague de boss.
- **Totem de givre renforcé**, ennemis plus lents, cavaliers freinés, 50 pièces au départ et +50 % de
  pièces au début (qui fond jusqu'à la vague 40).

Le simulateur a été mis à jour pour ces règles (moteur, joueur simulé qui achète des lots à l'autel quand
ça vaut le coup, nouveaux objectifs). **« Avant »** ci-dessous = ces nouvelles règles avec les réglages tels
qu'ils étaient livrés ; **« après »** = après ce réglage.

## Objectifs : avant / après (scénario « base », moyenne de 3 parties)

| Objectif | Cible | Avant | Après |
|---|---|---|---|
| Vagues 1 à 10 | 4-7 min, sans mur | 8 min | **7 min**, aucun mur |
| Premier vrai mur | vague 12-16, court (1-3 min) | vague 15, **19 min** | **vague 14-15, 2 min** |
| Vague 25 | 30-45 min | 1 h 32 | **42 min** |
| Vague 50 | 3-6 h | 4 h 59 | **4 h 32** |
| Vague 100 | 15-30 h | 11 h 52 (trop tôt) | **16 h 37** |
| Murs vagues 11-30 | 1-5 min | médiane 15 min, 20 % au-delà de 40 min | **médiane 2 min** (80 % sous 5 min) |
| Murs vagues 31-70 | ~10-20 min au plus | médiane 15 min, 20 % au-delà de 1 h 06 | **médiane 7 min**, 80 % sous 21 min (UN PEU LONGS) |
| Murs vagues 71-100 | ~10-20 min au plus | médiane 16 min, 20 % au-delà de 57 min | **médiane 12 min**, 80 % sous 27 min (UN PEU LONGS) |
| Murs après la vague 100 | plus longs, c'est de l'idle | médiane 4 min (le jeu s'emballe) | médiane 17 min (80 % sous 32 min) |
| Murs variés, boss les plus durs | plusieurs types | Garde colossale 50 % (53 min), boss 50 % | **5 types** : Escarmouche 58 %, Charge 13 %, Garde 12 %, boss 13 % (le plus long : 19 min), Levée 5 % |
| Charge et Levée pas absurdes (une fuite = ratée) | pas plus longues que les autres | jamais bloquantes | médianes 4 et 5 min (Escarmouche + Garde : 8 min) |
| Totem de givre | ralentit vraiment, vrais dégâts, vaut sa place | meilleure tour contre presque tout (100 % des dégâts par endroits) | **-60 % de vitesse**, 6 dégâts/s en zone ; 87 % des dégâts au début ; meilleur contre Levées et Charges tout le jeu ; en soutien, l'équipe est 1,1 à 2,1 fois plus forte (le plus contre Levées et Charges) |
| Autel des héros | acheté régulièrement, pas le seul achat | 30 % des pièces au début, puis des doublons à l'infini | acheté tout le jeu (5 à 220 achats / 10 vagues), 3 à 14 % des pièces ; x100, x1 000 et x1 M jamais achetés (voir plus bas) |
| Les 8 tours utiles | chacune >= 10 % des dégâts quelque part | **non** (Oracle 0 %, Trébuchet 6 %) | **oui** (de 21 % à 99 %) |
| Chaque type de vague a sa tour | tours différentes | 4 | **5** (Totem, Oracle, Archer, Trébuchet, Sorcier) |
| Aucune tour dominée pour toujours | aucune | aucune | aucune |
| Légendaires fortes, pas écrasantes | x1 à x3 | x0,26 à x1,16 | x0,47 à x1,35 |
| Grands nombres | ≥ 1 T de pièces / min vers 80-90 h | oui (1 T vers 15 h, 1e105 / min à 100 h) | oui : 1 B / min vers 14 h, **1 T vers 22 h**, 1 Qi vers 39 h, 1 Dc vers 88 h |
| Record à 100 h | (long à la fin) | vague 1 066 | vague 376 |

**16 objectifs atteints sur 20** (10 avant). Pour comparer, la mise à jour précédente (anciennes règles, lancer
gratuit à chaque vague) donnait vague 25 en 1 h 07, vague 50 en 4 h 35 et vague 100 en 22 h.

### Ce qui reste (honnêtement)

1. **Murs des vagues 31-100 un peu longs** : la médiane est bonne (7 et 12 min), mais 1 mur sur 5 dépasse
   21 min (31-70) et 27 min (71-100). Les deux cibles tirent en sens contraire : avec des murs plus courts
   (80 % sous 20 min), la vague 100 arrive vers 13-14 h, avant la cible de 15-30 h. Les murs les plus longs :
   la Garde colossale et le Seigneur de guerre des vagues 70-100 (17-38 min), et les Escarmouches des vagues
   46, 56, 66, 76 (24-57 min) : au mur d'une vague x6, on farme la Garde colossale x5, qui rapporte moins.
   Essayé ensuite (3 parties x 30 h) : une Garde colossale qui rapporte autant qu'une Escarmouche donne 80 % des
   murs sous 18 min (31-70) et 22 min (71-100), mais la vague 100 arrive en 13 h 52 ; toutes les vagues qui
   rapportent pareil, 17 et 21 min, vague 100 en 12 h 45 (14 h 42 avec `HEALTH_WAVE_POWER` 2,45, mais 80 % sous
   24 min pour 71-100). Aucun ne fait mieux sur tous les objectifs : réglages gardés.
2. **x100, x1 000 et x1 000 000 jamais achetés** par le joueur simulé du scénario « base » : il dépense tout à
   chaque entracte et n'a jamais 7 à 20 vagues de gains en poche d'un coup. Un joueur qui revient après une pause,
   si. Dans les autres scénarios, le x100 sert un peu (en moyenne 3 achats avec la forge, 61 avec forge +
   renaissance, 78 avec la renaissance seule, à partir des records 140-430) et le x1 000 une seule fois (1 partie
   sur 3, record 922). Le x1 000 000 n'est jamais acheté : il est exprès très loin (voir « La règle qui explique tout »).
3. **22e emplacement vers la vague 104** (cible des réglages précédents : 80-100 ; 167 avant). Le prix n'est
   pas le frein : le 22e coûte 0,03 vague de gains à la vague 100. Prix des emplacements inchangés.
4. **Vague 10 vers 7 min** : juste dans la cible (4-7 min). Le temps vient surtout de la marche des ennemis
   jusqu'aux 4 premiers emplacements (près de la base), et on les a ralentis.
5. Les chiffres bougent d'environ 1 h (vague 100) et de quelques minutes (murs) entre deux réglages presque
   identiques : 3 parties, et chaque partie fait des choix un peu différents.

## Ce qui a changé et pourquoi

1. **Garde colossale : part 1,5 → 0,5** (`IdleConfig.WAVE_TYPES`). Un seul colosse avec tout le budget : seules
   les tours qui le visent comptent, et une Garde ratée ne rapporte rien. Avant, c'était LE mur (médiane 53 min,
   jusqu'à 1 h 43). Plus bas que 0,5, les vagues x6 devenaient des murs de 30 min et plus (on y farme la Garde).
2. **Seigneur de guerre : 0,4 → 0,8 devient 0,3 → 0,5** (+ les 6 fantassins). Il reste le mur le plus long.
3. **Levée des écuyers 0,68 → 0,75, Charge de cavalerie 0,6 → 0,7** : avec le Totem renforcé et des ennemis
   plus lents, elles ne bloquaient plus jamais. Elles bloquent maintenant un peu (médianes 4-5 min), sans
   devenir absurdes malgré la règle « une fuite = ratée ».
4. **Vitesses** (`ENEMY_SPEED_FACTORS`) : chevaliers lourds x1,1, colosse et Seigneur de guerre x1,15 (7,4 /
   4,7 / 5,4 studs/s, contre 8 / 4,8 / 5,6 avant la mise à jour : ils restent un peu plus lents qu'avant).
   Cavaliers et écuyers inchangés (13 studs/s). Pourquoi : vague 10 en 8 min et Gardes ratées interminables.
5. **Totem de givre** (`IdleTowers`) : 8 dégâts → **6**, portée 12 → **11**, ralentissement 65 % → **60 %**
   (avant la mise à jour : 4,2 dégâts, 25 %). À 8 / 12 / 65 %, il était la meilleure tour contre presque tout
   jusqu'à la vague 100 et l'Oracle et le Trébuchet ne servaient à rien. Maintenant : chaque passage dans
   son aura fait ~2 fois plus de dégâts qu'avant la mise à jour, il ralentit 2,4 fois plus, il est le meilleur
   contre les Levées et les Charges tout le jeu et l'équipe est 1,1 à 2,1 fois plus forte avec lui en soutien (le plus contre Levées et Charges).
6. **Oracle 15 → 18, Sorcier 9 → 10, Baliste 40 → 50** : l'Oracle est redevenu le meilleur contre les
   Escarmouches ; la Baliste était moins bonne que le Sorcier contre tout.
7. **Autel des héros** :
   - prix d'un lancer : 0,25 vague de gains à ton record jusqu'à la vague 10, puis divisé par (record / 10)^0,9
     (`TOWER_SPIN_COST_WAVES` 0,3 → 0,25, `TOWER_SPIN_DISCOUNT_POWER` 2 → 0,9). Avant, les lancers devenaient
     si peu chers que les doublons (x2 300 de dégâts sur une tour) écrasaient tout : vague 1 066 en 100 h, murs
     de plus en plus courts ;
   - lots : x100 dès le record 40, x1 000 dès 150, x1 000 000 dès 1 000, toujours au prix normal (champ
     `price` = nombre de lancers x1 que coûte le lot) ;
   - chances : 10 % d'Épiques dès la vague 10 (8 % avant), 5 % de Légendaires dès la vague 25 (3 % avant).
     Déblocages : Totem tout de suite, Catapulte vers la vague 7, Mage vers 13, Oracle 33, Sorcier 41,
     Trébuchet 44, Baliste 46.

   | Record | 1 lancer | x10 | x100 | x1 000 | x1 000 000 |
   |---|---|---|---|---|---|
   | 1-10 | 0,25 vague de gains | 2,5 | - | - | - |
   | 40 | 0,07 | 0,7 | 7 | - | - |
   | 100 | 0,03 | 0,3 | 3 | - | - |
   | 150 | 0,02 | 0,2 | 2 | 22 | - |
   | 300 | 0,012 | 0,12 | 1,2 | 12 | - |
   | 1 000 | 0,004 | 0,04 | 0,4 | 4 | 4 000 |
8. **PV : `HEALTH_WAVE_POWER` 2,3 → 2,4** : un peu plus de PV partout (x1,2 à la vague 25, x1,3 à la 100) pour
   que la vague 100 arrive après 15 h malgré tout ce qui précède.

Inchangés : 50 pièces au départ, +50 % de pièces au début, croissance x1,25 des pièces et des PV,
améliorations, emplacements (`PlotLayout`), renaissance, forge.

## La règle qui explique tout (utile pour les prochains réglages)

Les PV et les pièces grandissent **au même rythme** (x1,25 par vague) : ce qui les sépare, c'est seulement le
facteur `((vague + 5) / 6)^2,4` des PV. Du coup, **multiplier tous ses dégâts par M fait avancer le record
d'un facteur ~M^(1/2,4)**, pas d'un nombre fixe de vagues. Doubler ses dégâts vers la vague 400 fait gagner
~130 vagues. D'où :

- **Le x1 000 000 ne peut pas être abordable sans danger** : un million de lancers, c'est 75 000 à 175 000
  doublons par tour, donc x1 500 à x3 500 de dégâts. Essayé au prix de 5 000 lancers le lot (dès le record
  300) : le joueur simulé est passé de la vague 377 à la vague 600-1 000 en 6 h. Il reste donc un objectif
  lointain (record 1 000, ~4 000 vagues de gains). Le seul moyen de le rendre achetable serait que les
  doublons rapportent de moins en moins (ex. +2 % pour les 100 premiers, puis moins) : c'est un choix de
  design, pas un réglage.
- Même le x1 000 à moitié prix (dès le record 80) faisait arriver la vague 100 ~1 h 20 plus tôt. D'où : pas de
  remise de gros.
- La forge et la renaissance sont très fortes loin dans le jeu (voir plus bas).

## Forge et renaissance (pour information, règles inchangées)

| Scénario | Record à 100 h (avant) | Record à 100 h (après) | Vague 100 (après) |
|---|---|---|---|
| base | 1 066 | 376 | 16 h 37 |
| renaissance seule (dès qu'il bloque 15 min) | 1 906 | 490 | 15 h 19 |
| forge en pièces (1 lancer / 30 min) | 1 806 | 595 | 12 h 26 |
| forge + renaissance | 3 000 (limite du simulateur) | 901 | 14 h 27 |

- **Renaissance** : ~40 renaissances en 100 h, bonus de pièces +460 à +510 %, record 490 contre 376.
- **Forge runique** : ~86 lancers, meilleur bonus posé x57 en moyenne : record 595 contre 376. Dans ce scénario, le
  joueur simulé met le prix de la forge de côté dès le début, ce qui ralentit ses 25 premières vagues
  (vague 25 en 50 min) : c'est sa façon de jouer, pas le jeu.
- Avant ce réglage, les doublons à bas prix s'ajoutaient à tout ça et le jeu s'emballait (vague 3 000,
  la limite, atteinte en 100 h avec forge + renaissance).

## Limites

- Le joueur simulé n'achète qu'entre les vagues, ramasse tout tout de suite, ne se déconnecte jamais et
  n'utilise pas de Robux : les temps sont ceux d'un joueur actif connecté en continu.
- Il dépense tout à chaque entracte (il n'économise que 5 min, 30 min pour un gros lot plus rentable) : il
  n'achète donc presque jamais les gros lots au prix normal (jamais dans le scénario « base »).
- 3 parties par scénario : les chiffres varient de ~10 % d'un réglage presque identique à l'autre.

## Relancer

Depuis le dossier `roblox-ranked-td` :

```bat
powershell -ExecutionPolicy Bypass -File tools\balance\idle\run.ps1            (complet : ~30 min, 4 scénarios x 3 parties x 100 h)
powershell -ExecutionPolicy Bypass -File tools\balance\idle\run.ps1 -Rapide    (~5 min : 3 parties x 40 h, scénario base)
powershell -ExecutionPolicy Bypass -File tools\balance\idle\run.ps1 -Rapide -Regler "IdleConfig.HEALTH_WAVE_POWER=2.35"
```

Le rapport commence par la comparaison aux objectifs (`idle\out\rapport.txt`).

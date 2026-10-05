# Les niveaux hors de Studio

Ces scripts font tourner le **vrai moteur du jeu** (`src/server/Hub/LevelGame.luau` et `CampGame.luau`, qui héritent
du vrai `Combat.luau`, avec les règles de `src/shared/Levels.luau`) sans ouvrir Studio, en quelques secondes. Ils
servent à régler la difficulté et à vérifier les règles. Le jeu est expliqué dans [NIVEAUX.md](../../NIVEAUX.md).

Il faut la commande `luau` ([Luau](https://github.com/luau-lang/luau/releases)). Depuis le dossier `roblox-ranked-td` :

```bat
powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1
powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1 -Tests
powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1 -Lazy
powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1 -Tune
powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1 -Barre -Niveaux "11,12"
powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1 -Curve
powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1 -Worth
powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1 -Equipe
powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1 -Regler "Levels.STREAM.RAMP_CURVE=1;Levels.DEFINITIONS.1.health=60"
```

- **sans option** : le tableau de difficulté. Chaque niveau est joué par des joueurs simulés : très actif, au rythme
  demandé par le niveau, lent (un achat toutes les 8 s), distrait (toutes les 15 s), sans œuf (l'Archer et la
  Catapulte seulement), tout débloqué (la meilleure barre, entraînée à fond : `Bot.FULL_BAR`).
  « G 7 » = gagné avec 7 vies, « P 62 % » = perdu après avoir éliminé 62 % des monstres. Environ 2 minutes.
- **`-Tests`** : 1 483 vérifications (100 niveaux dont 40 ouverts, 10 territoires, flot continu, cartes, pose libre, récompenses, prix, entraînement, données
  du joueur, le moteur : or, vies, victoire, défaite, vitesse x2, paquets réseau, **la difficulté de chaque
  niveau** : voir plus bas, les évolutions des tours, le camp d'entraînement de la parcelle : `CampGame.luau`, et
  **le tuto** : son étape dans les données, les deux premiers gestes du niveau 1 ; **le jeu en équipe** : les règles,
  une partie à deux (or et tours de chacun, l'or des monstres à chacun, celui qui s'en va), **les 30 cartes
  d'équipe** (mêmes règles que les cartes seules, couloirs qui restent ensemble après leur rencontre, écarts, dalles
  du chemin), le flot partagé entre les couloirs, chaque monstre sur son couloir, des équipes de 2, 3 et 4
  joueurs simulés qui doivent gagner les niveaux 10, 25 et 40, les gros monstres dans un couloir tiré au sort ;
  **les amis** : bonus d'ami sur le serveur, récompenses d'invitation une fois par ami ; **les œufs** : l'œuf de
  catapulte, œuf gagné, réserve, chances et part des tours de palier 2, tour sortie, données ; **les tours de palier
  2** : chacune et sa tour de base, prix, bien plus fortes même face à une tour de base entraînée au maximum,
  pouvoirs déjà là, **la barre** (une tour par rareté, « Choisir », la réserve, les sauvegardes d'avant), la
  Catapulte de magma posée dans un niveau, Totem de givre +
  Totem du blizzard qui ne s'additionnent pas ; **le colosse géant** ; **les tours spéciales** : une par territoire,
  un peu plus fortes que les tours de palier 2, posées dans un niveau, le poison des ronces (encore là hors des
  ronces, sans ralentir), la Catapulte de givre qui ralentit sans cumul avec le Totem du blizzard, les œufs spéciaux
  au boss du territoire, gardés même réserve pleine ; **« Bloqué ? »** : les défaites de suite au même niveau).
  Un quart d'heure.
- **`-Lazy`** : les 10 niveaux joués par un joueur qui pose quelques tours puis attend (rien de plus, 2 Archers,
  3 Archers, 2 Archers et une Catapulte, 4 Archers et 2 Catapultes). Ils doivent tous perdre.
- **`-Tune`** : cherche, pour chaque niveau, les PV des monstres les plus hauts avec lesquels le joueur de référence
  gagne encore (un niveau par processus, quelques minutes pour 10 niveaux), précis à 2 % près (les niveaux à gros
  monstres basculent d'un coup). `-Niveaux "1,3"` : seulement ces
  niveaux (pour régler un nouveau territoire : `-Niveaux "11,12,13,14,15,16,17,18,19,20"`). `-Rythme 3` : un autre
  rythme de référence. `-Vies 8` : il doit garder 8 vies.
- **`-Barre`** : la meilleure BARRE de chaque niveau demandé (`-Niveaux "11,12"` ; sans : les niveaux 11 à 50).
  Dans un niveau, le joueur ne pose qu'une tour par rareté : l'outil essaie toutes les barres que le joueur attendu
  peut former avec ses tours (`OWNED` dans `bar.luau`), garde les 2 plus fortes, et cherche pour elles les PV les
  plus hauts. Il affiche la barre gagnante et son entraînement (un cran de plus que ce que ses parties lui ont
  donné, deux à partir du niveau 31 : « dur partout ») : c'est la ligne à mettre dans `Bot.EXPECTED`. De 30 s à
  quelques minutes par niveau, 12 à la fois. Le joueur attendu est celui qui n'a PAS eu de chance aux œufs dorés
  (une tour rare de palier 2, pas d'épique de palier 2, pas de légendaire) : voir le début de `bar.luau`.
- **`-Curve`** : la pression d'un niveau au fil du temps (les PV qui sortent par seconde, comparés à ce que le joueur
  peut se payer). Elle doit monter du début à la fin.
- **`-Worth`** : ce que chaque tour APPORTE (de combien les monstres peuvent être plus résistants
  quand on la possède), aux niveaux 6, 8 et 10 : un processus par mesure, environ 6 minutes. `-Tours "Laser,Rocket"`
  et `-Niveaux "10"` pour n'en mesurer que quelques-unes. C'est ce qui a montré que le Sorcier des arcanes est utile
  (+20 à +59 %) et que la Baliste et le Trébuchet ne l'étaient presque pas : ils ont été renforcés le 02/10/2026
  (résultats dans `NIVEAUX.md`).
- **`-Equipe`** : jouer en équipe. Des équipes de 2, 3 et 4 joueurs simulés de référence jouent quelques niveaux
  (`-Niveaux "10,50"` pour en choisir) ; pour chacun, le plus haut multiplicateur de PV avec lequel l'équipe gagne
  encore avec 5 vies (`-Vies 8` : 8 vies), et, avec le réglage actuel (`Levels.TEAM_HEALTH`), ce que font une équipe
  très active et une équipe lente. À la fin, la médiane pour chaque taille d'équipe. Un processus par mesure, tous
  en même temps : quelques minutes.
- **`-Regler`** : essayer des réglages sans toucher à `src` (avec toutes les options ci-dessus). Deux tables se
  règlent : `Levels` et `IdleTowers` (`IdleTowers.Defs.Rocket.damage=120`). `*` = toutes les entrées d'une table :
  `Levels.DEFINITIONS.*.gold=80`.

## Ce que la difficulté doit respecter

Retour du propriétaire après son premier essai (02/10/2026) : « beaucoup trop facile », « je veux que ce soit en
continu et de plus en plus dur, que je sois obligé d'être super actif : poser des tours, améliorer », « si juste
2 Archers gèrent le niveau, je passe mon temps à attendre ». Puis, le 05/10/2026 : « les niveaux sont beaucoup trop
simples, ma copine est allée au niveau 30 sans être bloquée » : la **barre** (une tour par rareté) et « **dur
partout** » à partir du niveau 11. `tests.luau` vérifie donc, pour **chacun des 40 niveaux ouverts**
(`Levels.OPEN_COUNT`), avec la barre attendue à ce niveau (`Bot.EXPECTED`) :

| Joueur simulé | Niveaux 1 à 10 | Niveaux 11 et plus |
|---|---|---|
| Très actif (il dépense son or tout de suite) | gagner avec au moins 8 vies | gagner avec au moins 5 vies |
| Au rythme demandé (un achat toutes les 5 s au niveau 1, toutes les 3,5 s à partir du niveau 6) | gagner avec au moins 5 vies | pareil |
| Lent (un achat toutes les 8 s) | perdre | perdre s'il n'a pas entraîné ses tours en plus (`Bot.EXPECTED` moins `Bot.extraTraining` : un cran, deux à partir du niveau 31) |
| Distrait (un achat toutes les 15 s) | perdre encore plus tôt | perdre, même avec des tours entraînées |
| 2 Archers puis attendre | perdre avant 30 % du niveau, mais tenir au moins 35 s | pareil, tenir au moins 30 s |
| 4 Archers et 2 Catapultes sans rien améliorer | perdre avant 60 % du niveau | pareil |

Et, pour l'ensemble des niveaux 11 et plus (« dur partout ») : **celui qui arrive** à un niveau au rythme demandé,
avec la bonne barre mais sans avoir entraîné ses tours en plus, doit perdre au moins 4 niveaux sur 10 et n'en
gagner facilement (8 vies ou plus) qu'un sur 10 au plus. Les boss des niveaux 20, 30 et 40 ne passent pas avec les
tours de base à la place des tours de palier 2.

**La chance aux œufs.** La barre attendue est celle que presque tous les joueurs peuvent former (pas de tour épique
de palier 2, pas de légendaire). Avec une tour « de chance », la suite est plus facile : la Baliste du dragon vaut
+45 % de PV de monstres au 4e territoire (46 % des joueurs l'ont au niveau 31), une légendaire de palier 2 +20 à
+50 %. Réglé pour la Baliste du dragon, le niveau 31 était impossible sans elle. Mesures : `gen/barvar.luau`
(fichier de travail) ; détails dans `NIVEAUX.md`, « La difficulté ».

La barre et l'entraînement « attendus » à chaque niveau, et le rythme demandé, sont dans `Bot.EXPECTED`. Avec moins
de sortes de tours à poser (3 ou 4 au lieu de 8), il y a moins d'achats à faire : un joueur lent mais dont les tours
sont bien entraînées gagne certains niveaux. Ce qui bloque maintenant, c'est la barre et l'entraînement.

## Ajouter un territoire (10 niveaux)

C'est ce qui a été fait pour les niveaux 11 à 20 (02/10/2026, « ajoute des niveaux »), puis 21 à 100 (03/10/2026,
« continue les niveaux jusqu'à 40 », « fais encore 20 », « fais les 50 derniers ») :

1. `src/shared/Levels.luau` : la carte dans `MAPS` (chemin en tronçons droits, château, 12 emplacements conseillés),
   son nom dans `TERRITORIES`, 10 lignes dans `DEFINITIONS` avec des PV provisoires, puis `COUNT`.
2. `bar.luau` : les tours que le joueur attendu possède dans ce territoire (`OWNED`, `NATURAL`, `SPECIAL_BOSS`), puis
   `run.ps1 -Barre -Niveaux "..."` : la meilleure barre de chaque niveau, à recopier dans `Bot.EXPECTED` (`Bot.luau`).
3. `run.ps1 -Tune -Niveaux "..."` donne les PV ; on garde 5 % de marge en dessous (`health` dans `DEFINITIONS`).
4. `run.ps1 -Tests` vérifie tout (les mêmes règles que pour les autres niveaux), puis `run.ps1` montre le tableau.
5. `src/server/Hub/LevelArena.luau` : le décor du territoire (`THEMES`).

Un boss doit fermer le flot (`{ "Boss", 1 }`). Sorti pendant le flot, il se fait doubler par les monstres rapides,
les tours qui visent « le plus avancé » ne le touchent plus, et le joueur simulé très actif perd après avoir tout
éliminé sauf lui (essayé au niveau 20). Un boss trop résistant pour le joueur très actif, même en fin de flot :
baisser sa part de PV (`{ "Boss", 1, 0.85 }` au niveau 40) ; un boss plus faible que celui du territoire d'avant :
la monter (`{ "Boss", 1, 1.1 }` au niveau 30). Les niveaux à boss sont un peu plus courts : le boss doit encore
traverser la carte, et un niveau dure 200 s au plus. Avec quatre ou cinq colosses par niveau (41 à 60), régler avec
`-Tune -Vies 8` : sinon le réglage laisse passer un colosse (5 vies d'un coup), même au joueur très actif. Un chemin
court (252 studs) : faire sortir les premiers monstres moins serrés (écart de 1 s), sinon celui qui pose 2 Archers
puis attend tombe avant 35 s. Des colosses collés (0,02 d'écart) font perdre le joueur très actif : les espacer
(0,05). Un mini-boss fait d'un seul colosse énorme (2,5 fois les PV) : le réglage s'arrête à ce que le joueur peut
tuer en un seul monstre, le reste du flot devient trop facile et le joueur lent gagne ; préférer plusieurs colosses
un peu plus gros.

## Comment un niveau est réglé

1. La **forme** du flot est la même partout (`Levels.STREAM`) : les monstres sortent 3 fois plus serrés à la fin et
   ont 16 fois plus de PV. `-Curve` montre que la pression suit ce qu'un joueur peut se payer : un tiers de ses
   moyens au début, tous à la fin.
2. L'**or** des monstres (`Levels.ENEMY`) fixe le nombre d'achats : environ un toutes les 3 secondes pour celui qui
   dépense tout. C'est ce qui sépare le joueur actif du joueur lent (lui ne peut pas tout dépenser).
3. Les **PV** de chaque niveau (`health` dans `Levels.DEFINITIONS`) : `-Tune` donne la valeur la plus haute pour le
   joueur de référence ; on garde environ 5 % de marge en dessous, puis on vérifie avec le tableau et `-Tests`.
4. Changer la force d'une tour change ce que le joueur peut battre : il faut alors refaire `-Tune` pour les niveaux
   où cette tour est attendue. Exemple : le ralentissement du Totem de givre (`Levels.TOWER_TWEAKS`), passé de 60 %
   à 40 % après le retour du propriétaire (« un peu cheaté ») ; les PV des niveaux 3 à 10 ont baissé de 15 à 25 %.

| Fichier | Rôle |
|---|---|
| `run.ps1` | Copie les vrais modules dans `gen\` (avec les imitations de Roblox ajoutées en tête) et lance le script voulu |
| `env.luau`, `shim.luau`, `stubs\` | Imitations de Roblox (objets, services, Vector3, CFrame...) et des modules du serveur dont le combat n'a pas besoin |
| `Bot.luau` | Les joueurs simulés : à chaque décision, l'achat qui donne le plus de dégâts par pièce d'or (plusieurs façons de jouer, la meilleure partie est gardée) ; le joueur qui pose quelques tours puis attend ; les équipes (Bot.playTeam : plusieurs joueurs simulés dans la même partie) ; ce qui est attendu à chaque niveau |
| `settings.luau` | Lit les options (`regler=`, `rythme=`…) |
| `sim.luau` | Le tableau de difficulté |
| `lazy.luau` | Les niveaux joués sans presque rien faire |
| `tune.luau` | La recherche des PV de chaque niveau |
| `worth.luau` | Ce qu'une tour apporte |
| `curve.luau` | La pression d'un niveau au fil du temps |
| `team.luau` | Jouer en équipe : les PV des monstres selon le nombre de joueurs |
| `tests.luau` | Les vérifications des règles et de la difficulté |

Le joueur simulé n'est ni parfait ni mauvais : il sert à **comparer** des réglages, pas à dire exactement où un vrai
joueur bloquera. Un humain choisit moins bien que lui : pour gagner, il doit aller un peu plus vite que le rythme de
référence. Le dossier `gen\` est refait à chaque lancement (il n'est pas dans git).

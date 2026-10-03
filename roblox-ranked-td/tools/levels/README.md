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
powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1 -Curve
powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1 -Worth
powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1 -Coach
powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1 -Regler "Levels.STREAM.RAMP_CURVE=1;Levels.DEFINITIONS.1.health=60"
```

- **sans option** : le tableau de difficulté. Chaque niveau est joué par des joueurs simulés : très actif, au rythme
  demandé par le niveau, lent (un achat toutes les 8 s), distrait (toutes les 15 s), sans boutique, tout débloqué.
  « G 7 » = gagné avec 7 vies, « P 62 % » = perdu après avoir éliminé 62 % des monstres. Environ 2 minutes.
- **`-Tests`** : 815 vérifications (40 niveaux, 4 territoires, flot continu, cartes, pose libre, récompenses, prix, entraînement, données
  du joueur, le moteur : or, vies, victoire, défaite, vitesse x2, paquets réseau, **la difficulté de chaque
  niveau** : voir plus bas, les évolutions des tours, le camp d'entraînement de la parcelle : `CampGame.luau`, et
  **le tuto** : son étape dans les données, le guide du niveau 1, le joueur qui suit la flèche). Environ une minute
  et demie.
- **`-Lazy`** : les 10 niveaux joués par un joueur qui pose quelques tours puis attend (rien de plus, 2 Archers,
  3 Archers, 2 Archers et une Catapulte, 4 Archers et 2 Catapultes). Ils doivent tous perdre.
- **`-Tune`** : cherche, pour chaque niveau, les PV des monstres les plus hauts avec lesquels le joueur de référence
  gagne encore (un niveau par processus, environ 2 minutes pour 10 niveaux). `-Niveaux "1,3"` : seulement ces
  niveaux (pour régler un nouveau territoire : `-Niveaux "11,12,13,14,15,16,17,18,19,20"`). `-Rythme 3` : un autre
  rythme de référence. `-Vies 8` : il doit garder 8 vies.
- **`-Curve`** : la pression d'un niveau au fil du temps (les PV qui sortent par seconde, comparés à ce que le joueur
  peut se payer). Elle doit monter du début à la fin.
- **`-Worth`** : ce que chaque tour de la boutique APPORTE (de combien les monstres peuvent être plus résistants
  quand on la possède), aux niveaux 6, 8 et 10 : un processus par mesure, environ 6 minutes. `-Tours "Laser,Rocket"`
  et `-Niveaux "10"` pour n'en mesurer que quelques-unes. C'est ce qui a montré que le Sorcier des arcanes est utile
  (+20 à +59 %) et que la Baliste et le Trébuchet ne l'étaient presque pas : ils ont été renforcés le 02/10/2026
  (résultats dans `NIVEAUX.md`).
- **`-Coach`** : le TUTO joué par un joueur simulé qui ne fait que suivre la flèche du guide (`Levels.coachAdvice`),
  en mettant 1, 2, 3… 10 secondes à faire chaque achat montré. Il doit gagner le niveau 1 sans se presser.
  `-Niveaux "1,2"` pour d'autres niveaux.
- **`-Regler`** : essayer des réglages sans toucher à `src` (avec toutes les options ci-dessus). Deux tables se
  règlent : `Levels` et `IdleTowers` (`IdleTowers.Defs.Rocket.damage=120`). `*` = toutes les entrées d'une table :
  `Levels.DEFINITIONS.*.gold=80`.

## Ce que la difficulté doit respecter

Retour du propriétaire après son premier essai (02/10/2026) : « beaucoup trop facile », « je veux que ce soit en
continu et de plus en plus dur, que je sois obligé d'être super actif : poser des tours, améliorer », « si juste
2 Archers gèrent le niveau, je passe mon temps à attendre ». `tests.luau` vérifie donc, pour **chacun des 40 niveaux** :

| Joueur simulé | Doit |
|---|---|
| Très actif (il dépense son or tout de suite) | gagner avec au moins 8 vies |
| Au rythme demandé (un achat toutes les 5 s au niveau 1, toutes les 3,5 s à partir du niveau 6) | gagner avec au moins 5 vies |
| Lent (un achat toutes les 8 s) | perdre |
| Distrait (un achat toutes les 15 s) | perdre encore plus tôt |
| 2 Archers puis attendre | perdre avant 30 % du niveau, mais tenir au moins 35 s |
| 4 Archers et 2 Catapultes sans rien améliorer | perdre avant 60 % du niveau |

Les tours et l'entraînement « attendus » à chaque niveau, et le rythme demandé, sont dans `Bot.EXPECTED` (une tour
qui vient d'être achetée n'est pas encore entraînée : `trainings`).

## Ajouter un territoire (10 niveaux)

C'est ce qui a été fait pour les niveaux 11 à 20 (02/10/2026, « ajoute des niveaux »), puis 21 à 40 (03/10/2026,
« continue les niveaux jusqu'à 40 ») :

1. `src/shared/Levels.luau` : la carte dans `MAPS` (chemin en tronçons droits, château, 12 emplacements conseillés),
   son nom dans `TERRITORIES`, 10 lignes dans `DEFINITIONS` avec des PV provisoires, puis `COUNT`.
2. `Bot.luau` : 10 lignes dans `Bot.EXPECTED` (les tours que les pièces gagnées jusque-là permettent d'acheter).
3. `run.ps1 -Tune -Niveaux "..."` donne les PV ; on garde 5 % de marge en dessous.
4. `run.ps1 -Tests` vérifie tout (les mêmes règles que pour les autres niveaux), puis `run.ps1` montre le tableau.
5. `src/server/Hub/LevelArena.luau` : le décor du territoire (`THEMES`).

Un boss doit fermer le flot (`{ "Boss", 1 }`). Sorti pendant le flot, il se fait doubler par les monstres rapides,
les tours qui visent « le plus avancé » ne le touchent plus, et le joueur simulé très actif perd après avoir tout
éliminé sauf lui (essayé au niveau 20). Un boss trop résistant pour le joueur très actif, même en fin de flot :
baisser sa part de PV (`{ "Boss", 1, 0.85 }` au niveau 40) ; un boss plus faible que celui du territoire d'avant :
la monter (`{ "Boss", 1, 1.1 }` au niveau 30). Les niveaux à boss sont un peu plus courts : le boss doit encore
traverser la carte, et un niveau dure 200 s au plus.

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
| `Bot.luau` | Les joueurs simulés : à chaque décision, l'achat qui donne le plus de dégâts par pièce d'or (plusieurs façons de jouer, la meilleure partie est gardée) ; le joueur qui pose quelques tours puis attend ; celui qui suit le guide du tuto ; ce qui est attendu à chaque niveau |
| `settings.luau` | Lit les options (`regler=`, `rythme=`…) |
| `sim.luau` | Le tableau de difficulté |
| `lazy.luau` | Les niveaux joués sans presque rien faire |
| `tune.luau` | La recherche des PV de chaque niveau |
| `worth.luau` | Ce qu'une tour de la boutique apporte |
| `curve.luau` | La pression d'un niveau au fil du temps |
| `coach.luau` | Le tuto : le joueur qui suit la flèche du guide |
| `tests.luau` | Les vérifications des règles et de la difficulté |

Le joueur simulé n'est ni parfait ni mauvais : il sert à **comparer** des réglages, pas à dire exactement où un vrai
joueur bloquera. Un humain choisit moins bien que lui : pour gagner, il doit aller un peu plus vite que le rythme de
référence. Le dossier `gen\` est refait à chaque lancement (il n'est pas dans git).

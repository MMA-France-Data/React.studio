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
powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1 -Regler "Levels.STREAM.RAMP_CURVE=1;Levels.DEFINITIONS.1.health=60"
```

- **sans option** : le tableau de difficulté. Chaque niveau est joué par des joueurs simulés : très actif, au rythme
  demandé par le niveau, lent (un achat toutes les 8 s), distrait (toutes les 15 s), sans boutique, tout débloqué.
  « G 7 » = gagné avec 7 vies, « P 62 % » = perdu après avoir éliminé 62 % des monstres. Environ 45 secondes.
- **`-Tests`** : 291 vérifications (niveaux, flot continu, carte, pose libre, récompenses, prix, entraînement, données
  du joueur, le moteur : or, vies, victoire, défaite, vitesse x2, paquets réseau, **la difficulté de chaque
  niveau** : voir plus bas, les évolutions des tours et le camp d'entraînement de la parcelle : `CampGame.luau`).
  Environ 20 secondes.
- **`-Lazy`** : les 10 niveaux joués par un joueur qui pose quelques tours puis attend (rien de plus, 2 Archers,
  3 Archers, 2 Archers et une Catapulte, 4 Archers et 2 Catapultes). Ils doivent tous perdre.
- **`-Tune`** : cherche, pour chaque niveau, les PV des monstres les plus hauts avec lesquels le joueur de référence
  gagne encore (un niveau par processus, environ 1 minute). `-Niveaux "1,3"` : seulement ces niveaux. `-Rythme 3` :
  un autre rythme de référence. `-Vies 8` : il doit garder 8 vies.
- **`-Curve`** : la pression d'un niveau au fil du temps (les PV qui sortent par seconde, comparés à ce que le joueur
  peut se payer). Elle doit monter du début à la fin.
- **`-Worth`** : ce que chaque tour de la boutique APPORTE (de combien les monstres peuvent être plus résistants
  quand on la possède), aux niveaux 6, 8 et 10 : un processus par mesure, environ 6 minutes. `-Tours "Laser,Rocket"`
  et `-Niveaux "10"` pour n'en mesurer que quelques-unes. C'est ce qui a montré que le Sorcier des arcanes est utile
  (+20 à +59 %) et que la Baliste et le Trébuchet ne le sont presque pas.
- **`-Regler`** : essayer des réglages sans toucher à `src` (avec toutes les options ci-dessus). `*` = toutes les
  entrées d'une table : `Levels.DEFINITIONS.*.gold=80`.

## Ce que la difficulté doit respecter

Retour du propriétaire après son premier essai (02/10/2026) : « beaucoup trop facile », « je veux que ce soit en
continu et de plus en plus dur, que je sois obligé d'être super actif : poser des tours, améliorer », « si juste
2 Archers gèrent le niveau, je passe mon temps à attendre ». `tests.luau` vérifie donc, pour **chacun des 10 niveaux** :

| Joueur simulé | Doit |
|---|---|
| Très actif (il dépense son or tout de suite) | gagner avec au moins 8 vies |
| Au rythme demandé (un achat toutes les 5 s au niveau 1, toutes les 3,5 s à partir du niveau 6) | gagner avec au moins 5 vies |
| Lent (un achat toutes les 8 s) | perdre |
| Distrait (un achat toutes les 15 s) | perdre encore plus tôt |
| 2 Archers puis attendre | perdre avant 30 % du niveau, mais tenir au moins 35 s |
| 4 Archers et 2 Catapultes sans rien améliorer | perdre avant 60 % du niveau |

Les tours et l'entraînement « attendus » à chaque niveau, et le rythme demandé, sont dans `Bot.EXPECTED`.

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
| `Bot.luau` | Les joueurs simulés : à chaque décision, l'achat qui donne le plus de dégâts par pièce d'or (plusieurs façons de jouer, la meilleure partie est gardée) ; le joueur qui pose quelques tours puis attend ; ce qui est attendu à chaque niveau |
| `settings.luau` | Lit les options (`regler=`, `rythme=`…) |
| `sim.luau` | Le tableau de difficulté |
| `lazy.luau` | Les niveaux joués sans presque rien faire |
| `tune.luau` | La recherche des PV de chaque niveau |
| `worth.luau` | Ce qu'une tour de la boutique apporte |
| `curve.luau` | La pression d'un niveau au fil du temps |
| `tests.luau` | Les vérifications des règles et de la difficulté |

Le joueur simulé n'est ni parfait ni mauvais : il sert à **comparer** des réglages, pas à dire exactement où un vrai
joueur bloquera. Un humain choisit moins bien que lui : pour gagner, il doit aller un peu plus vite que le rythme de
référence. Le dossier `gen\` est refait à chaque lancement (il n'est pas dans git).

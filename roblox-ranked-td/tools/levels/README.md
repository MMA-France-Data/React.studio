# Les niveaux hors de Studio

Ces scripts font tourner le **vrai moteur des niveaux** (`src/server/Hub/LevelGame.luau`, qui hérite du vrai
`PlotGame.luau`, avec les règles de `src/shared/Levels.luau`) sans ouvrir Studio, en quelques secondes. Ils servent à
régler la difficulté et à vérifier les règles. Le prototype est expliqué dans [NIVEAUX.md](../../NIVEAUX.md).

Il faut la commande `luau` ([Luau](https://github.com/luau-lang/luau/releases)). Depuis le dossier `roblox-ranked-td` :

```bat
powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1
powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1 -Tests
powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1 -Lazy
powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1 -Regler "Levels.RAMP_END=1.4;Levels.DEFINITIONS.1.health=10"
```

- **sans option** : le tableau de difficulté. Chaque niveau est joué par un joueur simulé, pour 9 profils (l'Archer
  seul, avec le Totem, avec la Catapulte, entraîné ou non, toutes les tours…). « G 7 » = gagné avec 7 vies, « P 62 % »
  = perdu après avoir éliminé 62 % de la vague. Environ 25 secondes.
- **`-Tests`** : 150 vérifications des règles (niveaux, carte, pose libre, récompenses, prix, entraînement, données du
  joueur, et le moteur : or, vies, victoire, défaite, « envoyer la suite », vitesse x2, paquets réseau).
- **`-Lazy`** : les premiers niveaux joués par un joueur qui ne fait presque rien (rien du tout, une tour de plus,
  deux tours de plus). Sert à régler le tout début : au niveau 1, ne rien faire gagne de justesse, agir se voit.
- **`-Regler`** : essayer des réglages sans toucher à `src` (avec le tableau, ou avec `-Lazy`).

| Fichier | Rôle |
|---|---|
| `run.ps1` | Copie les vrais modules dans `gen\` (avec les imitations de Roblox ajoutées en tête) et lance le script voulu |
| `env.luau`, `stubs\` | Imitations de Roblox (objets, services) et des modules du serveur dont le combat n'a pas besoin |
| `Bot.luau` | Le joueur simulé : à chaque décision, l'achat qui donne le plus de dégâts par pièce d'or ; il essaie plusieurs façons de jouer et garde la meilleure partie |
| `sim.luau` | Le tableau de difficulté |
| `lazy.luau` | Les premiers niveaux sans presque rien faire |
| `tests.luau` | Les vérifications des règles |

Le joueur simulé n'est ni parfait ni mauvais : il sert à **comparer** des réglages, pas à dire exactement où un vrai
joueur bloquera. Le dossier `gen\` est refait à chaque lancement (il n'est pas dans git).

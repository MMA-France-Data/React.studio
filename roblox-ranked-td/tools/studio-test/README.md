# Tests automatiques dans Roblox Studio

Ces scripts ouvrent le jeu dans Studio, lancent Play tout seuls, jouent un scénario de test, prennent
des captures d'écran et récupèrent la fenêtre Sortie. Ils ne servent qu'au développement : rien ici
n'est dans la place construite par `default.project.json`, donc rien n'est publié avec le jeu.

Il faut Windows, Roblox Studio, [Rojo](https://rojo.space) et [Node.js](https://nodejs.org).

## Lancer un test

Depuis le dossier `roblox-ranked-td`, Studio fermé :

```bat
powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1
powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Place match
```

- `hub` (par défaut) : map principale. Le scénario achète des emplacements dans le désordre (prix,
  cadenas, refus), pose les 8 tours, les améliore, pose des bonus,
  puis vérifie la renaissance (vagues 10, 15, 50 et 100) et écrit `[PASS]` / `[FAIL]`.
- `match` : match ranked en solo (le bot joue l'autre terrain après 10 s).
- Résultats dans `tools\studio-test\out\` : `studio-output.log` (la Sortie du serveur et du client)
  et les captures `.png`. À la fin, le script affiche le nombre d'erreurs.
- Si Studio est déjà ouvert, le script s'arrête pour ne pas te faire perdre ton travail
  (`-CloseStudio` pour le fermer quand même). Il referme le Studio qu'il a ouvert (`-KeepOpen` pour le garder).

Vérification rapide sans Studio (syntaxe de tous les scripts + construction de la place) :

```bat
powershell -ExecutionPolicy Bypass -File tools\studio-test\check.ps1
```

## Comment ça marche

| Fichier | Rôle |
|---|---|
| `run.ps1` | Construit la place de test, installe le plugin, ouvre Studio, prend les captures, affiche la Sortie |
| `mkproj.cjs` | Crée `out\<hub\|match>.project.json` : `default.project.json` + le marqueur `__AutoPlayTest` + les scénarios |
| `AutoPlayTest.lua` | Plugin Studio, copié dans `%LOCALAPPDATA%\Roblox\Plugins` par `run.ps1` |
| `logserver.cjs` | Petit serveur sur `127.0.0.1:34999` (ce PC uniquement) qui écrit la Sortie dans `out\studio-output.log` |
| `shot.ps1` | Capture de la fenêtre de Studio |
| `scenarios\HubServer.luau` | Scénario côté serveur (pilote la partie avec `ServerStorage.StudioDebug`) |
| `scenarios\Client.luau` | Scénario côté client (caméra, fenêtres, captures `SHOT:nom`) |

**Le plugin ne fait rien dans tes places** : sa première vérification est
`if not marker then return end`. Il ne s'active que si la place contient `ReplicatedStorage.__AutoPlayTest`,
un objet que seul `mkproj.cjs` ajoute aux places de test. Pour le désinstaller, supprime
`%LOCALAPPDATA%\Roblox\Plugins\AutoPlayTest.lua`.

`ServerStorage.StudioDebug` (dans `src/server/Hub/init.luau`) n'est créé que dans Studio
(`RunService:IsStudio()`) : il n'existe pas dans le jeu publié.

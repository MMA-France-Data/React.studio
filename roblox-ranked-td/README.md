# Ranked Tower Defense 1v1 (Roblox)

Un tower defense 1v1 avec un vrai système **ranked** : MMR (Elo), rangs, matchs de placement,
saisons, classement global et matchmaking entre serveurs.

Tout est construit par code (carte, interface, tours, ennemis) : pas besoin de modèles dans Studio.

## Le jeu

- Chaque joueur défend **sa propre base** sur son terrain. Les deux reçoivent exactement les mêmes vagues.
- 4 tours (Mitrailleur, Sniper, Mortier, Givreur), chacune avec 3 niveaux.
- **Envois** : tu paies pour envoyer des ennemis en plus chez l'adversaire, et ça augmente ton revenu
  par vague. C'est le cœur du 1v1 : économiser ou attaquer ?
- Le premier dont la base tombe perd. Après 20 minutes, la base avec le plus de vie gagne.
- Quitter en plein match = défaite.

Contrôles : `1`-`4` choisir une tour • clic pour poser • clic sur une de tes tours pour la sélectionner •
`E` améliorer • `X` vendre • `Q` annuler • `Maj` enfoncée pour poser plusieurs tours d'affilée.

## Le système ranked

| Élément | Où | Détail |
|---|---|---|
| MMR / Elo | `src/shared/Elo.luau` | K = 32, K = 48 pendant les 5 matchs de placement |
| Rangs | `src/shared/Ranks.luau` | Bronze → Argent → Or → Platine → Diamant → Maître → Légende |
| Sauvegarde | `src/server/PlayerData.luau` | DataStore + **verrou de session** (un seul serveur écrit à la fois) |
| File d'attente | `src/server/Matchmaking.luau` | MemoryStore SortedMap triée par MMR, partagée par tous les serveurs |
| Match | `src/server/Match/` | Serveur réservé, attend les 2 joueurs, applique l'Elo, renvoie au lobby |
| Classement | `src/server/Leaderboard.luau` | OrderedDataStore par saison, affiché sur un panneau dans le lobby |
| Saisons | `Config.SEASON` | Nouvelle saison = soft reset du MMR (moitié de l'écart à 1000) + nouveau classement |

### Déroulement d'un match classé

```
 Lobby (serveur public)                MemoryStore                   Serveur de match (réservé)
 ─────────────────────                 ───────────                   ──────────────────────────
 Joueur clique "Ranked"  ──────────►  File (triée par MMR)
                                           │
 Serveur "leader" (1 seul, élu) ◄──────────┘
   apparie les MMR proches
   ReserveServer() ─────────────────►  Infos du match  ─────────────►  lit les infos, attend les 2 joueurs
   écrit les assignations ──────────►  Assignations
 Chaque lobby téléporte ses joueurs ─────────────────────────────────►  compte à rebours, partie
                                                                        Elo appliqué + sauvegarde
 Retour au lobby  ◄──────────────────────────────────────────────────  téléportation retour
```

- La fourchette de MMR acceptée commence à ±75 et s'élargit de 8 par seconde d'attente (max ±600).
- Une seule place Roblox sert aux deux : serveur public = lobby, serveur réservé = match
  (`src/server/Main.server.luau`).
- Toute la logique est côté serveur : le client ne fait que demander (poser une tour, envoyer...)
  et le serveur vérifie l'or, la position, le propriétaire de la tour, etc.
- Si l'adversaire ne se connecte pas dans les 45 s, le match est annulé sans perte de MMR.

## Installation

1. Installe [Rojo](https://rojo.space) (via [Rokit](https://github.com/rojo-rbx/rokit) : `rokit install` dans ce dossier)
   et le plugin Rojo dans Studio.
2. Dans ce dossier :
   ```bash
   rojo build -o RankedTD.rbxl   # génère la place, à ouvrir dans Studio
   # ou, pour synchroniser en direct pendant que tu codes :
   rojo serve                     # puis "Connect" dans le plugin Rojo
   ```
3. Publie la place : **File > Publish to Roblox**.

Rien d'autre à configurer : les téléportations vers un serveur réservé de la même place sont autorisées par défaut.

## Tester

**Le gameplay dans Studio** : mets `Config.STUDIO_FORCE_MODE = "Match"` dans `src/shared/Config.luau`.
- `Test > Clients and Servers` avec 2 joueurs → vrai match (MMR appliqué sur des données en mémoire).
- `Play` en solo → après 10 s, l'autre terrain est joué par un bot simple (match non classé).

**Le matchmaking** ne peut pas marcher dans Studio (pas de `TeleportService`). Publie le jeu et
rejoins-le avec deux comptes (ou avec un ami) : cliquez tous les deux sur « Jouer en ranked ».

Dans Studio, les DataStores sont simulés en mémoire (`Config.Data.MOCK_IN_STUDIO`). Pour utiliser les
vrais depuis Studio, passe-le à `false` et active *Game Settings > Security > Enable Studio Access to API Services*.

## Réglages

Tout est dans `src/shared/Config.luau` (MMR de départ, K, fourchettes du matchmaking, or de départ,
durée des vagues...). Les stats des tours sont dans `Towers.luau`, les ennemis et la composition des
vagues dans `Enemies.luau`, les envois dans `Sends.luau`, le tracé du chemin dans `MapLayout.luau`.

## Structure

```
src/
  shared/   (ReplicatedStorage.Shared)   Config, Elo, Ranks, Towers, Enemies, Sends, MapLayout, Placement, Remotes
  server/   (ServerScriptService.Server) Main, PlayerData, Leaderboard, Matchmaking, Lobby, Match/{init, Game, MapBuilder}
  client/   (StarterPlayerScripts.Client) Main, LobbyUI, MatchUI, TowerPlacement, Effects, UI
```

## Limites connues / pistes d'amélioration

- Les ennemis sont des parts déplacées par le serveur : très bien pour un 1v1, mais au-delà de
  quelques centaines d'ennemis, il vaudrait mieux ne répliquer que leur progression et les afficher côté client.
- Aucune pénalité si un joueur ne se connecte pas au match (il peut « esquiver » un adversaire).
- L'appariement est glouton (voisins de MMR) : suffisant pour une petite population de joueurs.
- Pas de protection contre deux comptes du même joueur qui s'affrontent (boost de MMR).

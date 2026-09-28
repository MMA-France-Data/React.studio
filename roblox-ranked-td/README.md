# Ranked Tower Defense 1v1 (Roblox)

Un tower defense avec une map principale à 6 parcelles (une par joueur) et un vrai système **ranked** 1v1 : MMR (Elo), rangs, matchs de placement,
saisons, classement global et matchmaking entre serveurs.

Tout est construit par code (carte, interface, tours, ennemis) : pas besoin de modèles dans Studio.

## La map principale

Chaque serveur accueille 6 joueurs (à régler dans *Game Settings > Places > Server Size*).
Chacun reçoit sa parcelle : un chemin, une base et 22 emplacements de tours (4 débloqués au départ, les autres de 500 pièces
jusqu'à ~1,1 Qa pour le dernier, voir `PlotLayout.spotCost`).
Au centre, un **cercle rouge** : entrer dedans lance la recherche d'une partie ranked.
Les boutons « Ma base » et « Cercle ranked » servent à se déplacer vite.

## Le mode infini (ta parcelle)

- Des vagues sans fin arrivent sur ta parcelle. **Impossible de perdre** : si ta base tombe, tu redescends
  d'une vague et tu réessaies. Vague réussie → vague suivante.
- Les PV grandissent de ×1,22 et les gains de ×1,18 par vague (réglages dans `IdleConfig.luau`) : les pièces
  passent de quelques unités à des trillions.
- 5 types de vagues : **Mixte**, **Horde** (masse de petits ennemis → tours de zone), **Rush** (rapides →
  ralentissement), **Géants** (lents et énormes → gros dégâts), **Boss** toutes les 10 vagues.
- Les ennemis tués lâchent des **pièces à ramasser** (les pièces proches s'empilent). Le bonus de pièces
  s'additionne : ennemi à 3 pièces, +100 % → 6, +200 % → 9.
- 8 tours (`IdleTowers.luau`) : Mitrailleur, Givre, Bombe, Électrique, Lance-roquettes, Laser, Foudre en chaîne,
  Frappe orbitale. Clique sur un emplacement pour poser une tour ; poser sur une tour existante la remplace (50 % remboursés), vendre rend 50 %.
- Clique sur le cadenas suivant pour débloquer un emplacement.
- **Améliorations** : clique sur une tour → « Améliorer » (ou touche E). Niveaux illimités, dégâts ×1,35 par
  niveau, prix ×1,5 par niveau. Les PV des vagues montent un peu plus vite que les gains (×1,22 contre ×1,18) :
  on bloque souvent, on farme un peu, une amélioration débloque les vagues suivantes.
- Chemin de ~360 studs (6 allers-retours) et ennemis 1,6× plus rapides qu'en ranked.

### Les deux machines à sous (devant chaque parcelle, ou boutons en haut à droite)

- **Machine à tours** : 1 lancer gratuit à chaque vague réussie, sans cumul (le lancer garde le meilleur
  palier). Au départ seul le Mitrailleur est débloqué. 8 tours en 4 raretés (Commune, Rare, Épique,
  Légendaire) ; plus la vague réussie est haute, meilleures sont les chances (`IdleConfig.TOWER_SPIN_TIERS`).
  Un doublon donne +5 % de dégâts permanents à cette tour.
- **Machine à bonus** : x2 dégâts, x2 vitesse d'attaque, x3, x5, x10, x20, x50, x100 dégâts (chances affichées
  dans la machine). 1 lancer en pièces toutes les 30 minutes, lancers en Robux à volonté. Le bonus va dans
  l'inventaire et se pose sur une tour (1 par tour ; en poser un nouveau remplace l'ancien, vendre la tour
  rend le bonus).
- **Robux** : crée un Developer Product dans le Creator Dashboard et mets son ID dans
  `Config.Products.BONUS_SPIN`. Chaque achat n'est livré qu'une fois (`Monetization.luau`).
- Côté technique, les ennemis n'existent que sous forme de données sur le serveur ; chaque client reçoit leurs
  positions 6 fois par seconde dans un paquet binaire et les affiche lui-même (`PlotGame.luau`, `PlotRenderer.luau`).

## Le match ranked

- Chaque joueur défend **sa propre base** sur son terrain. Les deux reçoivent exactement les mêmes vagues.
- 4 tours (Mitrailleur, Sniper, Mortier, Givreur), chacune avec 3 niveaux : le modèle évolue (anneau au niv. 2,
  couronne au niv. 3), un badge ●●○ au-dessus de chaque tour et une fiche qui compare les 3 niveaux.
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
- Une seule place Roblox sert aux deux : serveur public = map principale (« lobby »), serveur réservé = match
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
  shared/   (ReplicatedStorage.Shared)   Config, IdleConfig, IdleTowers, NumberFormat, Elo, Ranks, Towers, Enemies, Sends, MapLayout, PlotLayout, Placement, Remotes
  server/   (ServerScriptService.Server) Main, PlayerData, Leaderboard, Matchmaking, Monetization, Hub/{init, HubMap, Plots, PlotGame, IdleTowerModel}, Match/{init, Game, MapBuilder}
  client/   (StarterPlayerScripts.Client) Main, LobbyUI, PlotUI, PlotRenderer, MachineUI, MatchUI, TowerCard, TowerPlacement, Effects, UI
```

## Limites connues / pistes d'amélioration

- Les ennemis sont des parts déplacées par le serveur : très bien pour un 1v1, mais au-delà de
  quelques centaines d'ennemis, il vaudrait mieux ne répliquer que leur progression et les afficher côté client.
- Aucune pénalité si un joueur ne se connecte pas au match (il peut « esquiver » un adversaire).
- L'appariement est glouton (voisins de MMR) : suffisant pour une petite population de joueurs.
- Pas de protection contre deux comptes du même joueur qui s'affrontent (boost de MMR).

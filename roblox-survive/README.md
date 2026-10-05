# SURVIVE!

Jeu Roblox. Chaque joueur a son **espace** dans le lobby : ses machines de sport et son enclos.
Il améliore son personnage sur les machines, puis traverse des **salles à la suite** : dans chaque salle il faut
survivre 60 secondes à un événement, et la porte du bout s'ouvre sur la salle suivante. Chaque salle réussie donne
des pièces et un œuf, qui couve dans l'enclos ; le familier qui en sort **rapporte des pièces à chaque
seconde**, qui servent à améliorer les machines pour aller plus loin. Un mort réapparaît dans son espace.

Ce dossier est séparé du jeu de tours (`roblox-ranked-td`) : rien n'est partagé entre les deux.

## Ce qu'il y a dans le jeu

- **Lobby** : une allée qui mène à la porte des salles, et 6 espaces (un par joueur du serveur), chacun avec ses
  3 machines et son enclos. Le joueur apparaît dans le sien ; les machines des autres espaces ne lui servent pas.
- **Machines** : tapis de course (vitesse), trampoline (saut), musculation (force pour repousser le plafond).
  Tout le monde commence au niveau 0. Pour gagner un niveau, on va sur la machine (touche E) : le personnage
  s'entraîne 4 secondes (il court sur le tapis, pousse la barre couché sur le banc, rebondit sur le trampoline).
  Le niveau 1 est gratuit, puis 500, 1 500, 4 000, 10 000 et 25 000 pièces. Chaque niveau est un vrai palier :
  +15 % de vitesse, +15 % de saut, +50 % de force.
- **10 salles** : compte à rebours de 10 secondes quand on entre, puis 60 secondes d'événement. Le panneau de
  chaque salle dit les niveaux qu'il faut, et le bandeau le dit en rouge au joueur à qui il en manque.
  - Lave : un parcours qui grimpe en spirale ; la dernière plateforme (verte) est le seul endroit sûr à la fin.
    Les grandes marches (violettes) sont trop hautes sans le niveau de saut demandé.
  - Météorites : un cercle rouge prévient, puis ça explose. La GRANDE PLUIE (salles 2 et 8) : toute la salle
    explose sauf un rond vert, à l'autre bout à chaque fois ; sans le niveau de vitesse demandé, on n'y arrive
    pas à temps.
  - Explosions : le sol est en 16 dalles ; celles qui clignotent en rouge explosent.
  - Plafond (toujours avec la lave) : 30 secondes pour grimper, puis le plafond descend. En haut du parcours,
    on le repousse en appuyant très vite sur E (gros bouton sur téléphone) ; sans le niveau de force demandé,
    il écrase même en appuyant au plus vite.

| Salle | Événements | Il faut |
| --- | --- | --- |
| 1 | lave | rien |
| 2 | grande pluie de météorites | vitesse 1 |
| 3 | explosions | rien |
| 4 | lave + plafond | saut 1, force 1 |
| 5 | lave + météorites | saut 2 |
| 6 | mélodie | rien |
| 7 | lave + plafond | saut 3, force 2 |
| 8 | grande pluie + météorites | vitesse 3 |
| 9 | lave + météorites | saut 4 |
| 10 | lave + plafond + météorites | saut 5, force 4 |

  Les salles 1 à 4 ne demandent que les niveaux gratuits. Ensuite chaque palier coûte plus cher que ce que
  rapportent les salles déjà ouvertes (voir le tableau « LA PROGRESSION » dans `Config.luau`).
- **Pièces** : salle réussie = 100 × le numéro de la salle ; mort après 30 secondes = la moitié ; +1 000 pour
  la dernière salle.
- Mélodie (salle 6, casse-tête) : le mur joue une suite de notes en allumant des couleurs ; il faut la refaire en
    marchant sur les dalles de couleur, dans l'ordre. 3 manches (3, 4 puis 5 notes). Une fausse note blesse ;
    réussir ouvre la porte tout de suite ; ne pas finir à temps élimine tout le monde.
- **Œufs et familiers** : chaque salle réussie donne l'œuf de son animal. Il va tout seul dans le nid de l'enclos
  et y couve (30 secondes × le numéro de la salle, même hors du jeu). Pas de couveuse : autant d'œufs qu'on veut
  couvent en même temps. À la fin il éclot tout seul, et la rareté est tirée à ce moment-là (commun, rare,
  épique, légendaire ; plus de chances dans les salles du fond).
  - **La collection** : 5 animaux × 4 raretés = 20 familiers à trouver. Chaque familier trouvé est posé sur son
    socle dans l'enclos et rapporte des pièces à chaque seconde, tant que le joueur est dans le jeu. Un familier
    déjà trouvé donne des pièces d'un coup à la place (100, 300, 1 000 ou 5 000).
  - **Ce qu'ils rapportent** par seconde : 0,5 / 2 / 6 / 20 selon la rareté, multiplié par l'animal (dragon × 1,
    caillou × 1,5, lapin × 2, chouette × 2,5, golem × 3). Toute la collection : 285 pièces par seconde.
  - Les familiers ne donnent **aucun bonus dans les salles**. Le joueur peut en choisir un qui le suit (bouton
    « ANIMAUX », qui montre aussi la collection). Chaque rareté a son mélange de couleurs.
- **Raccourci** dans la salle de sport : mène devant la salle 6 quand la salle 5 est réussie.
- **Sauvegarde** des pièces, des niveaux et de la meilleure salle (dans le jeu publié ; dans Studio, tout reste
  en mémoire le temps du test).
- Textes en français ou en anglais selon la langue Roblox du joueur.

Pas encore fait : vrais sons (la mélodie utilise un petit son fourni avec Roblox, joué plus ou moins aigu), vélo
et machine spéciale, monstre, inondation, sol glissant, machines qui changent d'apparence, achats en Robux.
Les animaux utilisent des modèles gratuits du Creator Store, nettoyés et conservés dans `assets/pets`.
`src/shared/PetModels.luau` les prépare ; `Pets.luau` conserve les pouvoirs, les raretés et les modèles de secours.
Les textures restent hébergées sur Roblox. Voir `assets/pets/README.md` pour les sources et la vérification.

## Régler le jeu

Les familiers (ce qu'ils rapportent, chances des raretés, temps de couvaison) sont dans `src/shared/Pets.luau`.
Tous les autres chiffres sont dans `src/shared/Config.luau` : prix, gains par niveau, durée des manches, pièces, et la
liste des salles (`Config.ROOMS`) avec les réglages de chaque événement. Pour qu'une salle demande un autre niveau :
changer `jump` (lave), `level` (plafond, grande pluie) et la ligne `need` de la salle (le panneau). Les textes sont dans
`src/shared/Texts.luau`.

## Fichiers

- `src/server/World.luau` : construit tout le décor au démarrage (rien n'est posé à la main dans Studio).
- `src/server/GymModels.luau` : les machines, faites de blocs.
- `src/server/Gym.luau` : l'espace de chaque joueur, l'entraînement sur les machines, vitesse et saut, raccourci.
- `src/server/Rooms.luau` : le déroulement d'une salle (attente, compte à rebours, événement, porte ouverte).
- `src/server/Events/` : un fichier par événement.
- `src/server/Eggs.luau` : œufs, collection et revenu des familiers.
- `src/server/PlayerData.luau` : sauvegarde.
- `src/client/Main.client.luau` : l'écran du joueur ; `src/client/Animals.luau` : enclos, familiers.
- `assets/library` : modèles gratuits de la bibliothèque Roblox (voir son README).
- `assets/pets` : les 5 compagnons de la bibliothèque ; géométrie et matériaux seulement, sans scripts importés.

## Essayer et tester

Construire la place : `rojo build default.project.json -o Survive.rbxl`, puis l'ouvrir dans Studio et lancer Play.

Tests automatiques dans Studio (une fenêtre Studio s'ouvre toute seule ; ne pas toucher au PC pendant ce temps) :

- `powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1` : tout le jeu
  (233 vérifications, environ 8 minutes, captures dans `tools\studio-test\out`).
- `powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test jump -Seconds 560` : mesure la
  hauteur de marche qu'un personnage grimpe d'un saut (a servi à régler `Config.stepHeight`).

Le test déplace le joueur lui-même et accélère le temps : il vérifie les règles (pièces, portes, lave, plafond),
pas le plaisir de jeu. La difficulté des salles n'a pas encore été essayée par un vrai joueur.

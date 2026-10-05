# SURVIVE!

Jeu Roblox. Chaque joueur a son **espace** dans le lobby : ses machines de sport et son enclos.
Il améliore son personnage sur les machines, puis traverse des **salles à la suite** : dans chaque salle il faut
survivre 60 secondes à un événement, et la porte du bout s'ouvre sur la salle suivante. Chaque salle réussie donne
des pièces et un ticket, à échanger contre un œuf à poser dans son enclos ; le familier qui en sort **rapporte
des pièces à chaque seconde**, qui servent à améliorer les machines pour aller plus loin. Un mort réapparaît dans son espace.

Ce dossier est séparé du jeu de tours (`roblox-ranked-td`) : rien n'est partagé entre les deux.

## Ce qu'il y a dans le jeu

- **Lobby** : une allée qui mène à la porte des salles, et 6 espaces (un par joueur du serveur), chacun avec ses
  3 machines et son enclos. Le joueur apparaît dans le sien ; les machines des autres espaces ne lui servent pas.
- **Machines** : tapis de course (vitesse), trampoline (saut), musculation (force pour repousser le plafond).
  Tout le monde commence au niveau 0. Pour gagner un niveau, on va sur la machine (touche E) : le personnage
  s'entraîne 4 secondes (il court sur le tapis, pousse la barre couché sur le banc, rebondit sur le trampoline).
  Le niveau 1 est gratuit, puis 500, 1 500, 4 000, 10 000 et 25 000 pièces. Chaque niveau est un vrai palier :
  +15 % de vitesse, +15 % de saut, +50 % de force.
- **Marcher et courir** : le personnage marche à 70 % de sa vitesse. Il court à pleine vitesse tant qu'on tient
  la touche Maj, ou après un appui sur le bouton « COURIR » de l'écran (un 2e appui le remet à la marche).
- **10 salles** : compte à rebours de 10 secondes quand on entre, puis 60 secondes d'événement. Le panneau de
  chaque salle dit les niveaux qu'il faut, et le bandeau le dit en rouge au joueur à qui il en manque.
  - Bombe (salle 1) : un parcours qui grimpe en spirale, sans lave : si on tombe, on remonte. Tout en haut, une
    bombe avec un gros compte à rebours. Chaque joueur monte couper SON fil (E maintenu 3 secondes). À zéro, elle
    élimine ceux qui n'ont pas coupé le leur ; si tous l'ont coupé, la porte s'ouvre tout de suite.
  - Lave : un parcours qui grimpe en spirale ; la dernière plateforme (verte) est le seul endroit sûr à la fin.
    Les grandes marches (violettes) sont trop hautes sans le niveau de saut demandé.
  - Météorites : un cercle rouge prévient, puis ça explose. La GRANDE PLUIE (salle 2) : toute la salle
    explose sauf un rond vert, à l'autre bout à chaque fois ; sans le niveau de vitesse demandé, on n'y arrive
    pas à temps.
  - Explosions : le sol est en 16 dalles ; celles qui clignotent en rouge explosent.
  - Monstre (salle 8, salle de course) : un grand golem fonce sur le joueur le plus proche ; s'il le touche,
    c'est fini. Il va 9 % moins vite qu'un joueur du niveau de vitesse demandé qui court, et 5 % plus vite que le
    niveau d'en dessous : il faut courir tout le long, en grands cercles.
  - Plafond (toujours avec la lave) : 30 secondes pour grimper, puis le plafond descend. En haut du parcours,
    on le repousse en appuyant très vite sur E (gros bouton sur téléphone) ; sans le niveau de force demandé,
    il écrase même en appuyant au plus vite.

| Salle | Événements | Il faut |
| --- | --- | --- |
| 1 | la bombe | rien |
| 2 | grande pluie de météorites | vitesse 1 |
| 3 | explosions | rien |
| 4 | lave + plafond | saut 1, force 1 |
| 5 | lave + météorites | saut 2 |
| 6 | mélodie | rien |
| 7 | lave + plafond | saut 3, force 2 |
| 8 | le monstre (salle de course) | vitesse 3 |
| 9 | lave + météorites | saut 4 |
| 10 | lave + plafond + météorites | saut 5, force 4 |

  Les salles 1 à 4 ne demandent que les niveaux gratuits. Ensuite chaque palier coûte plus cher que ce que
  rapportent les salles déjà ouvertes (voir le tableau « LA PROGRESSION » dans `Config.luau`).
- **Pièces** : salle réussie = 100 × le numéro de la salle ; mort après 30 secondes = la moitié ; +1 000 pour
  la dernière salle.
- Mélodie (salle 6, casse-tête) : le mur joue une suite de notes en allumant des couleurs ; il faut la refaire en
    marchant sur les dalles de couleur, dans l'ordre. 3 manches (3, 4 puis 5 notes). Une fausse note blesse ;
    réussir ouvre la porte tout de suite ; ne pas finir à temps élimine tout le monde.
- **Tickets, œufs et familiers** :
  1. chaque salle réussie donne un **ticket** de cette salle ;
  2. à la **boutique des œufs** (le stand jaune de l'allée, près de la porte des salles), les tickets s'échangent
     contre des œufs de l'animal de la salle ; la rareté de l'œuf est tirée à ce moment-là (commun, peu commun,
     rare, légendaire ; plus de chances dans les salles du fond) ;
  3. le joueur **pose l'œuf lui-même** sur une place libre de son enclos (touche E). Il y couve : 30 s, 1 min 30,
     4 min ou 10 min selon la rareté, multiplié par 0,6 (salle 1) à 1,5 (salle 10) ; le temps continue hors du jeu ;
  4. à l'éclosion, le familier reçoit une **valeur cachée** tirée dans le palier de sa rareté : commun 1 à 100,
     peu commun 100 à 200, rare 200 à 400, légendaire 400 à 800. Il rapporte chaque seconde sa valeur / 100,
     multipliée par son animal (dragon × 1, caillou × 1,5, lapin × 2, chouette × 2,5, golem × 3), tant que le
     joueur est dans le jeu. Deux familiers de la même rareté ne rapportent donc pas pareil.
  - **Les places** : l'enclos commence avec 5 places. La 6e coûte 1 000 pièces, et chaque place suivante 6 fois
    la précédente (6 000, 36 000, 216 000...), jusqu'à 12.
  - **Doublons** : on peut avoir plusieurs fois le même familier. Pour libérer une place, on vend le familier
    (E maintenu) : il rend ce qu'il rapporte en 100 secondes.
  - Les familiers ne donnent **aucun bonus dans les salles**. Le joueur peut en choisir un qui le suit (bouton
    « ANIMAUX », qui montre aussi tout l'enclos). Chaque rareté a son mélange de couleurs.
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

Les familiers (paliers de valeur, chances des raretés, temps de couvaison, prix des places) sont dans `src/shared/Pets.luau`.
Tous les autres chiffres sont dans `src/shared/Config.luau` : prix, gains par niveau, durée des manches, pièces, et la
liste des salles (`Config.ROOMS`) avec les réglages de chaque événement. Pour qu'une salle demande un autre niveau :
changer `jump` (lave), `level` (plafond, grande pluie) et la ligne `need` de la salle (le panneau). Les textes sont dans
`src/shared/Texts.luau`.

## Fichiers

- `src/server/World.luau` : construit tout le décor au démarrage (rien n'est posé à la main dans Studio).
- `src/server/Themes.luau` : le style de chaque salle (matières du sol et des murs, décors, habillage des
  plateformes) : entrepôt, désert, bunker, volcan, temple de jungle, salle de concert, mine, crypte, glace, château.
- `src/server/GymModels.luau` : les machines, faites de blocs.
- `src/server/Gym.luau` : l'espace de chaque joueur, l'entraînement sur les machines, vitesse et saut, raccourci.
- `src/server/Rooms.luau` : le déroulement d'une salle (attente, compte à rebours, événement, porte ouverte).
- `src/server/Events/` : un fichier par événement.
- `src/server/Eggs.luau` : tickets, boutique, œufs, places de l'enclos, revenu des familiers.
- `src/server/PlayerData.luau` : sauvegarde.
- `src/client/Main.client.luau` : l'écran du joueur ; `src/client/Animals.luau` : enclos, familiers.
- `assets/library` : modèles gratuits de la bibliothèque Roblox (voir son README).
- `assets/pets` : les 5 compagnons de la bibliothèque ; géométrie et matériaux seulement, sans scripts importés.

## Essayer et tester

Construire la place : `rojo build default.project.json -o Survive.rbxl`, puis l'ouvrir dans Studio et lancer Play.

Tests automatiques dans Studio (une fenêtre Studio s'ouvre toute seule ; ne pas toucher au PC pendant ce temps) :

- `powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1` : tout le jeu
  (270 vérifications, environ 12 minutes, captures dans `tools\studio-test\out`).
- `powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test jump -Seconds 560` : mesure la
  hauteur de marche qu'un personnage grimpe d'un saut (a servi à régler `Config.stepHeight`).

Le test déplace le joueur lui-même et accélère le temps : il vérifie les règles (pièces, portes, lave, plafond),
pas le plaisir de jeu. La difficulté des salles n'a pas encore été essayée par un vrai joueur.

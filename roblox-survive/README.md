# SURVIVE!

Jeu Roblox : on améliore son personnage dans une **salle de sport**, puis on traverse des **salles à la suite**.
Dans chaque salle il faut survivre 60 secondes à un événement ; la porte du bout s'ouvre alors sur la salle suivante.
Un mort réapparaît dans la salle de sport avec ses pièces.

Ce dossier est séparé du jeu de tours (`roblox-ranked-td`) : rien n'est partagé entre les deux.

## Ce qu'il y a dans le jeu

- **Salle de sport** : tapis de course (vitesse), trampoline (saut), musculation (force pour repousser le plafond).
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
- **Œufs et animaux** : chaque salle réussie donne l'œuf de son animal. On le pose dans une des 2 couveuses de la
  salle de sport (30 secondes × le numéro de la salle, même hors du jeu) ; à l'ouverture, la rareté est tirée
  (commun, rare, épique, légendaire ; plus de chances dans les salles du fond). L'animal prend le mélange de
  couleurs de sa rareté (corps, reflets et contour de trois couleurs qui tournent) : ses couleurs d'origine, puis
  bleu-turquoise-vert, doré-orange-rose, et violet-rose-bleu-turquoise avec des étincelles pour le légendaire. Un animal déjà trouvé en aussi
  bien donne des pièces. On en équipe un seul (bouton « ANIMAUX ») et il suit le joueur en bougeant à sa façon
  (le dragon et la chouette volent, le caillou rebondit, le lapin saute, le golem marche en balançant les bras) :
  - Dragon de lave (salles 1, 5, 9) : sauter une 2e fois en l'air = vol plané de 1 à 3 secondes, le dragon passe
    sous le joueur.
  - Caillou de météorite (salle 2) : encaisse 40 à 160 dégâts par salle (pas la lave ni le plafond).
  - Lapin éclair (salles 3, 8) : +4 à +15 % de vitesse.
  - Golem (salles 4, 7, 10) : +10 à +50 % de force.
  - Chouette (salle 6) : +5 à +25 % de pièces.
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

Les animaux (pouvoirs, chances des raretés, temps de couvaison) sont dans `src/shared/Pets.luau`.
Tous les autres chiffres sont dans `src/shared/Config.luau` : prix, gains par niveau, durée des manches, pièces, et la
liste des salles (`Config.ROOMS`) avec les réglages de chaque événement. Pour qu'une salle demande un autre niveau :
changer `jump` (lave), `level` (plafond, grande pluie) et la ligne `need` de la salle (le panneau). Les textes sont dans
`src/shared/Texts.luau`.

## Fichiers

- `src/server/World.luau` : construit tout le décor au démarrage (rien n'est posé à la main dans Studio).
- `src/server/GymModels.luau` : les machines, faites de blocs.
- `src/server/Gym.luau` : achats, vitesse et saut du personnage, raccourci.
- `src/server/Rooms.luau` : le déroulement d'une salle (attente, compte à rebours, événement, porte ouverte).
- `src/server/Events/` : un fichier par événement.
- `src/server/Eggs.luau` : œufs, couveuses, animaux ; `src/server/Stats.luau` : les bonus de l'animal équipé.
- `src/server/PlayerData.luau` : sauvegarde.
- `src/client/Main.client.luau` : l'écran du joueur ; `src/client/Animals.luau` : couveuses, animaux, vol plané.
- `assets/library` : modèles gratuits de la bibliothèque Roblox (voir son README).
- `assets/pets` : les 5 compagnons de la bibliothèque ; géométrie et matériaux seulement, sans scripts importés.

## Essayer et tester

Construire la place : `rojo build default.project.json -o Survive.rbxl`, puis l'ouvrir dans Studio et lancer Play.

Tests automatiques dans Studio (une fenêtre Studio s'ouvre toute seule ; ne pas toucher au PC pendant ce temps) :

- `powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1` : tout le jeu
  (244 vérifications, environ 7 minutes, captures dans `tools\studio-test\out`).
- `powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test jump -Seconds 560` : mesure la
  hauteur de marche qu'un personnage grimpe d'un saut (a servi à régler `Config.stepHeight`).

Le test déplace le joueur lui-même et accélère le temps : il vérifie les règles (pièces, portes, lave, plafond),
pas le plaisir de jeu. La difficulté des salles n'a pas encore été essayée par un vrai joueur.

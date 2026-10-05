# SURVIVE!

Jeu Roblox : on améliore son personnage dans une **salle de sport**, puis on traverse des **salles à la suite**.
Dans chaque salle il faut survivre 60 secondes à un événement ; la porte du bout s'ouvre alors sur la salle suivante.
Un mort réapparaît dans la salle de sport avec ses pièces.

Ce dossier est séparé du jeu de tours (`roblox-ranked-td`) : rien n'est partagé entre les deux.

## Ce qu'il y a dans cette première version

- **Salle de sport** : tapis de course (vitesse, +8 % par niveau), trampoline (saut, +15 % par niveau),
  musculation (force, pour repousser le plafond). 6 niveaux chacun : 500, 1 500, 4 000, 10 000, 25 000 pièces.
- **10 salles** : compte à rebours de 10 secondes quand on entre, puis 60 secondes d'événement.
  - Lave : un parcours qui grimpe en spirale ; la dernière plateforme (verte) est le seul endroit sûr à la fin.
    Les grandes marches (violettes) demandent un niveau de saut.
  - Météorites : un cercle rouge prévient, puis ça explose.
  - Explosions : le sol est en 16 dalles ; celles qui clignotent en rouge explosent.
  - Plafond (toujours avec la lave) : 30 secondes pour grimper, puis le plafond descend. En haut du parcours,
    on le repousse en appuyant très vite sur E (gros bouton sur téléphone) ; chaque appui pousse plus fort
    avec plus de force.
- **Pièces** : salle réussie = 100 × le numéro de la salle ; mort après 30 secondes = la moitié ; +1 000 pour
  la dernière salle.
- **Raccourci** dans la salle de sport : mène devant la salle 6 quand la salle 5 est réussie.
- **Sauvegarde** des pièces, des niveaux et de la meilleure salle (dans le jeu publié ; dans Studio, tout reste
  en mémoire le temps du test).
- Textes en français ou en anglais selon la langue Roblox du joueur.

Pas encore fait : sons, vélo et machine spéciale, monstre, inondation, sol glissant, machines qui changent
d'apparence, achats en Robux, coffre et compagnons.

## Régler le jeu

Tous les chiffres sont dans `src/shared/Config.luau` : prix, gains par niveau, durée des manches, pièces, et la
liste des salles (`Config.ROOMS`) avec les réglages de chaque événement. Les textes sont dans
`src/shared/Texts.luau`.

## Fichiers

- `src/server/World.luau` : construit tout le décor au démarrage (rien n'est posé à la main dans Studio).
- `src/server/GymModels.luau` : les machines, faites de blocs.
- `src/server/Gym.luau` : achats, vitesse et saut du personnage, raccourci.
- `src/server/Rooms.luau` : le déroulement d'une salle (attente, compte à rebours, événement, porte ouverte).
- `src/server/Events/` : un fichier par événement.
- `src/server/PlayerData.luau` : sauvegarde.
- `src/client/Main.client.luau` : l'écran du joueur.

## Essayer et tester

Construire la place : `rojo build default.project.json -o Survive.rbxl`, puis l'ouvrir dans Studio et lancer Play.

Tests automatiques dans Studio (une fenêtre Studio s'ouvre toute seule ; ne pas toucher au PC pendant ce temps) :

- `powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1` : tout le jeu, environ 4 minutes
  (155 vérifications, captures dans `tools\studio-test\out`).
- `powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test jump -Seconds 560` : mesure la
  hauteur de marche qu'un personnage grimpe d'un saut (a servi à régler `Config.stepHeight`).

Le test déplace le joueur lui-même et accélère le temps : il vérifie les règles (pièces, portes, lave, plafond),
pas le plaisir de jeu. La difficulté des salles n'a pas encore été essayée par un vrai joueur.

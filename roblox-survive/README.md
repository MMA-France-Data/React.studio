# SURVIVE!

Jeu Roblox. Chaque joueur a son **espace** dans le lobby : ses machines de sport et son enclos.
Il améliore son personnage sur les machines, puis traverse des **salles à la suite** : dans chaque salle il faut
survivre 60 secondes à un événement, et la porte du bout s'ouvre sur la salle suivante. Chaque salle réussie donne
un ticket (pas de pièces), à échanger contre un œuf à poser dans son enclos ; le familier qui en sort **rapporte
des pièces à chaque seconde**, qui servent à améliorer les machines pour aller plus loin. Un mort réapparaît dans son espace.

Ce dossier est séparé du jeu de tours (`roblox-ranked-td`) : rien n'est partagé entre les deux.

## Ce qu'il y a dans le jeu

- **Lobby** : une allée qui mène à la porte des salles, et 6 espaces (un par joueur du serveur), chacun avec ses
  3 machines et son enclos. Le joueur apparaît dans le sien ; les machines des autres espaces ne lui servent pas.
- **Machines et stats** : la vitesse, le saut et la force sont des nombres de points, affichés à gauche de l'écran.
  On monte sur sa machine (touche E) : le personnage s'entraîne tant qu'on veut (il court sur le tapis, pousse la
  barre couché sur le banc, rebondit sur le trampoline) et gagne des points à chaque pas, deux pas par seconde ;
  on redescend avec E ou le bouton « ARRÊTER ». Le panneau « Améliorer » à côté de chaque machine la fait monter
  d'un niveau avec des pièces (500, puis 6 fois plus à chaque niveau : 3 000, 18 000, 108 000, 648 000) : elle donne alors 10 fois plus de points par pas
  (1, 10, 100, 1 000, 10 000, 100 000). Les paliers de stat : 120, 2 500, 50 000, 1 000 000, 20 000 000, 400 000 000 points (1 minute d'entraînement pour le
  premier, puis 2, 4, 8, 16 et 32 minutes avec la machine du même niveau) ; chaque palier
  donne +15 % de vitesse, +15 % de saut ou +50 % de force.
- **Marcher et courir** : le personnage marche à 70 % de sa vitesse. Il court à pleine vitesse tant qu'on tient
  la touche Maj, ou après un appui sur le bouton « COURIR » de l'écran (un 2e appui le remet à la marche).
- **10 salles** : compte à rebours de 10 secondes quand on entre, puis 60 secondes d'événement. Le panneau de
  chaque salle dit les points de stat conseillés (« Saut 500 recommandé »), et le bandeau dit en rouge ce qui manque
  au joueur.
  - Bombe (salle 1) : un parcours qui grimpe en zigzag de l'entrée vers la sortie, sans lave : si on tombe, on remonte. Tout en haut, une
    bombe avec un gros compte à rebours. Chaque joueur monte couper SON fil (E maintenu 3 secondes). À zéro, elle
    élimine ceux qui n'ont pas coupé le leur ; si tous l'ont coupé, la porte s'ouvre tout de suite.
  - Lave : un parcours qui grimpe en zigzag, et finit du côté de la sortie ; la dernière plateforme (verte) est le seul endroit sûr à la fin.
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
| 2 | le prédateur (un loup par joueur, autour du bloc transparent ; il feinte en ressortant d'un terrier devant le joueur) | vitesse 120 |
| 3 | explosions | rien |
| 4 | lave + plafond | saut 120, force 120 |
| 5 | lave + météorites | saut 2 500 |
| 6 | mélodie | rien |
| 7 | lave + plafond | saut 50 000, force 2 500 |
| 8 | le monstre (salle de course) | vitesse 50 000 |
| 9 | lave + météorites | saut 1 000 000 |
| 10 | lave + plafond + météorites | saut 20 000 000, force 1 000 000 |

  Les paliers se gagnent en s'entraînant ; les pièces servent à améliorer les machines (pour s'entraîner plus
  vite) et l'enclos (voir « LA PROGRESSION » dans `Config.luau`).
- **Pièces** : les salles n'en donnent pas (une salle réussie = un ticket, un mort ne gagne rien). Les pièces
  viennent seulement des familiers de l'enclos (revenu par seconde, ou vente).
- Mélodie (salle 6, casse-tête) : le mur joue une suite de notes en allumant des couleurs ; il faut la refaire en
    marchant sur les dalles de couleur, dans l'ordre. 3 manches (3, 4 puis 5 notes). Une fausse note blesse ;
    réussir ouvre la porte tout de suite ; ne pas finir à temps élimine tout le monde.
- **Tickets, œufs et familiers** :
  1. chaque salle réussie donne un **ticket** de cette salle ;
  2. à la **boutique des œufs** (le stand « ŒUFS » de l'allée), les tickets s'échangent contre des œufs de la
     salle ; le **rang** de l'œuf est tiré à ce moment-là : commun 45 %, peu commun 30 %, rare 14 %, épique 7 %,
     légendaire 3,5 %, super rare 0,5 %. Le joueur **porte son œuf sur la tête** ;
  3. dans son enclos, il **pose l'œuf par terre** où il veut (touche E ou bouton « POSER L'ŒUF »). L'œuf y couve :
     30 s, 1 min, 2 min 30, 5 min, 10 min ou 20 min selon le rang, multiplié par 0,6 (salle 1) à 1,5 (salle 10) ;
     le temps continue hors du jeu ;
  4. à l'éclosion, le familier reçoit une **valeur cachée** tirée dans le palier de son rang : 1 à 50, 50 à 100,
     100 à 200, 200 à 400, 400 à 800, et 1 600 à 3 200 pour le super rare ; ces paliers sont ceux de la salle 1,
     et chaque salle suivante les multiplie par 3. Il **se promène dans l'enclos** et rapporte chaque seconde sa
     valeur / 100, tant que le joueur est dans le jeu ; le gain s'envole au-dessus de lui.
  - **Les collections** (`Pets.COLLECTIONS`, modèles dans `assets/collections`) : dans les salles 1 à 5, le rang
    de l'œuf donne l'animal, six par salle, du plus courant au super rare :
    salle 1 : lapin, tortue, chat, chien, chouette, **renard** ;
    salle 2 : hérisson, écureuil, moufette, castor, raton laveur, **blaireau** ;
    salle 3 : canard, coq, cochon, mouton, chèvre, **cheval** ;
    salle 4 : sanglier, bélier, cerf, lynx, loup, **ours brun** ;
    salle 5 : capybara, toucan, singe, anaconda, crocodile, **jaguar**.
    Ces animaux sont articulés et animés (repos, marche) par `StarterAnimator.luau`. Les salles 6 à 10 gardent
    pour l'instant l'animal de la salle (dragon, golem, chouette, lapin éclair), peint selon son rang.
  - **Le familier qui suit** (bouton « Suivre ») donne un bonus de chance d'œuf rare : sa valeur cachée / 16, en %
    (x 1,15 par salle ; la valeur d'un super rare compte pour moitié). Il s'ajoute au bonus de la salle chanceuse,
    et le ticket garde la chance du moment. Le familier rapporte quand même ses pièces.
  - **L'enclos** : une clôture à la couleur de l'espace. Niveau 1 = 5 places (familiers + œufs). Le panneau
    « Améliorer l'enclos », sur la clôture, ajoute une place par niveau : 1 000 pièces, puis 6 fois plus à chaque
    niveau (6 000, 36 000, 216 000...), jusqu'à 20 places.
  - **Doublons et vente** : on peut avoir plusieurs fois le même familier. Le stand « VENDRE » (ou la patte, à
    droite de l'écran) ouvre la liste de ses familiers, avec « Vendre » (deux appuis ; il rend ce qu'il rapporte
    en 100 secondes) et « Suivre » (ce familier suit le joueur et lui porte chance).
  - **À droite de l'écran** : le bouton œuf déplie « Œufs en croissance » (une barre par œuf qui couve, et le
    nombre de tickets et d'œufs à poser) ; le bouton patte déplie la liste des familiers (« 7/8 Actifs », le
    bouton « +1 place », le revenu de chacun). La flèche rouge replie le panneau.
  - Les familiers ne donnent **aucun bonus de force, de saut ou de vitesse dans les salles**.
- **La fermeture de la porte** (`Cycle.luau`, réglages `Config.CYCLE`) : toutes les 5 minutes, la porte du lobby
  vers les salles se ferme 10 secondes. Pendant ce temps, les œufs de tous les enclos couvent 10 fois plus vite
  (10 secondes en valent 100). À la réouverture, une salle tirée au hasard reçoit un bonus de chance tiré au hasard
  (+100, +200, +300, +400 ou +500 %) : un ticket gagné dans cette salle garde le bonus, et son œuf a 2 à 6 fois
  plus de chances d'être autre chose que commun. Le bonus dure jusqu'à la fermeture suivante ; il est
  écrit en haut de l'écran dans le lobby et en doré sur le panneau de la salle.
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
  (339 vérifications, environ 14 minutes, captures dans `tools\studio-test\out`).
- `powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test jump -Seconds 560` : mesure la
  hauteur de marche qu'un personnage grimpe d'un saut (a servi à régler `Config.stepHeight`).

Le test déplace le joueur lui-même et accélère le temps : il vérifie les règles (pièces, portes, lave, plafond),
pas le plaisir de jeu. La difficulté des salles n'a pas encore été essayée par un vrai joueur.

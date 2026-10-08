# Collections originales — MONDE

- [Savane, salle 7](salle-07-savane/README.md) : hyène, buffle, guépard, rhinocéros, éléphant, lion royal ; six rigs, attaques et six œufs sans nid. [Animaux](salle-07-savane/Apercu-animaux.png), [œufs](salle-07-savane/Apercu-oeufs.png), [attaques](salle-07-savane/Apercu-attaques.gif).
- [Monde 1 — ferme, maillages retouchés](monde-01-ferme-maillages/README.md) : Duck, Horse boss arc-en-ciel, Rooster, Pig, Sheep, Goat. FBX par animal, articulations et clips locaux conservés ; yeux noirs symétriques, raccords corrigés. Œufs de la ferme inchangés. [Rendus des modèles](monde-01-ferme-maillages/Apercu-ferme.png).
- [Monde 3 — jungle, maillages](monde-03-jungle-maillages/README.md) : Capybara, Anaconda, Crocodile, Jaguar doré tacheté, Gorilla dos argenté, Tiger orange rayé **boss**. FBX, Motor6D, KeyframeSequence et assembleurs. Œufs inchangés dans le dernier lot. [Rendus](monde-03-jungle-maillages/Apercu-jungle.png).
- [Monde 2 — forêt, maillages](monde-02-foret-maillages/README.md) : Boar, Ram, Deer, Lynx, Wolf ; Bear boss arc-en-ciel conservé. FBX, rigs et clips d'origine ; 17 à 19 pièces par animal. Œufs inchangés. [Rendus](monde-02-foret-maillages/Apercu-foret.png).
- [Monde 4 — Lion, boss en maillage](monde-04-savane-maillages/README.md) : 19 pièces, 4 744 triangles, vraie crinière raccordée, rig et quatre clips conservés.

Les gabarits `*-rig-template.rbxmx` des maillages sont transparents : **importer le FBX puis assembler dans Studio**, avant de remplacer les modèles actifs. Aucun identifiant de maillage Roblox n'est inventé. Le lecteur d'animations actuel reste inchangé.

Les templates et les dimensions générées de Bear, Lion et des nouveaux animaux de la jungle et de la forêt sont raccordés au système `MeshRigs` existant. Les FBX restent à importer dans Studio ; les anciens visuels de secours, les sauvegardes, les probabilités et les œufs ne sont pas modifiés. Tests dans Roblox Studio et sur téléphone encore à faire.

## Ordre de migration demandé

1. **Livrés : Bear (monde 2), Lion (monde 4).**
2. **Livrés : Capybara, Anaconda, Crocodile, Jaguar, pour terminer la jungle.** Jaguar n'est plus le boss ; Tiger garde ce rôle.
3. **Livrés : Boar, Ram, Deer, Lynx, Wolf, pour terminer la forêt.**
4. En dernier : Hyena, Buffalo, Cheetah, Rhino, Elephant, pour terminer la savane.

Les premières collections historiques se trouvent dans `roblox-survive/assets/collections/`. Les versions avec attaques des salles 1 à 6 se trouvent dans `roblox-monde/assets/combat/animaux/`.

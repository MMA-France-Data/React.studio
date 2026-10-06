# Œufs SURVIVE V3 — cinq rares arc-en-ciel

Cette version corrige la mauvaise interprétation de la référence : **coquille arc-en-ciel saturée, taches blanches et contour violet**, et non coquille entièrement violet pastel. La forme étagée, sans nid, reste celle des modèles demandés au départ.

Seuls les cinq œufs à 0,5 % sont retouchés : Renard, Blaireau, Cheval, Ours brun et Jaguar. Les oreilles, les bandes du blaireau, la crinière du cheval, l'empreinte de l'ours et les motifs du jaguar restent distincts. Les vingt-cinq autres fichiers de modèle sont identiques à la V1, empreintes vérifiées.

## Palette des rares

Du haut vers le bas : rose vif, orange, jaune, vert vif, cyan, bleu, violet et magenta. Petites taches blanches stylisées en pièces Roblox, adaptées au style en briques. Le violet sert au contour `RareAura` (Highlight natif), pas à une recoloration uniforme. Les extrémités de la coquille comportent six pièces Neon au total. Aucun script embarqué, aucune texture externe, aucun MeshPart, aucune génération payante.

## Tableau de référence du joueur

| Salle | 45 % | 30 % | 14 % | 7 % | 3,5 % | 0,5 % — arc-en-ciel |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Lapin | Tortue | Chat | Chien | Chouette | Renard |
| 2 | Hérisson | Écureuil | Moufette | Castor | Raton laveur | Blaireau |
| 3 | Canard | Coq | Cochon | Mouton | Chèvre | Cheval |
| 4 | Sanglier | Bélier | Cerf | Lynx | Loup | Ours brun |
| 5 | Capybara | Toucan | Singe | Anaconda | Crocodile | Jaguar |

Les taux de `RARITY_REFERENCE.json` et les légendes de la galerie sont uniquement des références. Aucun taux de drop, tirage, prix ou gain du jeu n'est modifié. Ce dossier est la version **V3 arc-en-ciel validée par le joueur**, pas la V2 violet pastel refusée. Les versions précédentes restent uniquement en local.

## Fichiers et aperçu

- `models/AnimalEgg.rbxmx` : trente modèles séparés, mêmes noms que les versions précédentes. Insérer depuis un fichier dans Studio ; ce ne sont pas des GLB.
- `Salle-N-6-oeufs.rbxmx` et `Collection-30-oeufs.rbxmx` : modèles groupés dans l'ordre du tableau.
- `Galerie-30-oeufs.rbxl` : galerie indépendante. Ouvrir et lancer **Play**, puis utiliser les boutons de salle. Sources dans `ReplicatedStorage/Models`.
- `Apercu-5-rares-arc-en-ciel.png`, `Apercu-salle-N.png`, `Apercu-30-oeufs.png` : rendus de la géométrie livrée.
- `Rares-0_5-pourcent.blend` : scène éditable des cinq rares, pas un rig d'animation.

Les rendus Blender montrent les pièces et couleurs réellement exportées. Le contour Highlight spécifique à Roblox n'est pas simulé dans ces rendus. Le Bloom est configuré uniquement dans la galerie indépendante ; l'effet final dépendra de l'éclairage du jeu et des réglages graphiques du téléphone.

## Pour Claude, avant intégration

Les œufs sont des Model statiques, ancrés, avec `EggRoot` invisible et pivot au sol. Les pièces sont soudées à la racine, sans collision, toucher ni requête physique. Déplacer tout le modèle par son pivot. Le lecteur d'animations des animaux n'est pas nécessaire.

Le code actuel `src/client/Animals.luau` fabrique un œuf en Part unique et modifie directement `.CFrame`, `.Position`, `.Material`. Ces opérations doivent être adaptées aux Model : ce pack n'est pas un remplacement automatique. Ne pas passer toutes les pièces en Neon à la fin du minuteur.

Dans la version du jeu consultée avant l'envoi, la clé `Bunny` utilise `RabbitEgg.rbxmx` et la clé `Owlet` utilise `OwlEgg.rbxmx`. Les autres espèces portent le même identifiant que leur fichier, suivi d'`Egg`. Ne pas renommer les clés des inventaires ou sauvegardes pour correspondre aux noms de modèles.

Le jeu cache actuellement l'espèce avant l'éclosion dans les salles de collection. Les détails d'animal et l'apparence arc-en-ciel des rares sont reconnaissables. Le pack ne décide pas si ce secret doit être conservé et ne touche pas à cette règle.

## Vérifications

Géométrie et rotations contrôlées hors ligne, XML et références internes vérifiés, trente empreintes de modèles vérifiées, cinq rares exactement, six pièces Neon et six taches blanches à trois pièces par rare, vingt-cinq modèles non rares inchangés, références de chances totalisant 100 % par salle, compilation Luau et assemblage Rojo de la galerie. L'archive est contrôlée après génération.

Pack publié dans `roblox-survive/assets/collections/oeufs` sur la branche `claude/exciting-gauss-ggwcwm`. Aucun code du jeu ni `default.project.json` modifié par cet envoi. Pas encore testé dans Roblox Studio ni sur téléphone : validation visuelle des couleurs hors ligne uniquement. La galerie est un projet de test indépendant. Les V1 et V2 restent conservées localement. Le ZIP local n'est pas dupliqué dans Git ; les fichiers du pack sont directement disponibles dans ce dossier.

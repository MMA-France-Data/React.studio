# SURVIVE! — salle 5 : les animaux de la jungle

Six modèles originaux en pièces Roblox natives, articulés et animés localement.
Le crocodile est la vedette visuelle ; le capybara ouvre la collection.
Les animaux sont naturels, sans armures ou effets magiques. Ce pack ne change pas le jeu.

| Fichier dans `models/` | Silhouette et mouvement |
| --- | --- |
| `Capybara.rbxmx` | Corps bas et large, tête longue et carrée, petites oreilles ; pas de queue visible |
| `Toucan.rbxmx` | Gros bec jaune-orangé, corps noir, poitrine jaune, deux pattes ; ailes repliées |
| `Monkey.rbxmx` | Singe à longues mains, face claire, grandes oreilles et queue courbée articulée |
| `Anaconda.rbxmx` | Long corps tacheté, tête large, chaîne articulée qui ondule ; aucune patte |
| `Jaguar.rbxmx` | Épaules puissantes, tête large, rosettes dorées/noires, grande queue articulée |
| `Crocodile.rbxmx` | Corps aplati, long museau denté, dos à écailles, quatre pattes latérales et longue queue |

La progression, les revenus, prix, chances, raretés et définitions des salles restent
à régler dans le jeu séparément.

## Contenu et utilisation

Insérer les RBXMX depuis un fichier dans Studio, et non via l'importateur de
maillage GLB/FBX. `models/` contient les six animaux séparés ;
`Collection-6-animaux.rbxmx` les regroupe. Aucun MeshPart, texture externe ou
script dans les fichiers des animaux. Pas d'ID d'animation distant requis.

`Galerie-6-animaux.rbxl` est une place de démonstration indépendante, avec le
bouton marche/repos. Ne pas l'utiliser pour écraser le jeu. Elle se reconstruit
avec `gallery.project.json` et Rojo.

Pivot invisible `RigRoot`, orientation -Z. Pièces ancrées, sans collision,
contact ou requête. AnimationController, Motor6D, Weld et deux séquences locales
en boucle `Idle` / `Walk` par animal. Le clip `Walk` de l'anaconda correspond
au déplacement en ondulation ; celui du toucan est une marche, pas un vol.
Le crocodile a aussi une mâchoire indépendante avec un léger mouvement.

Le lecteur `StarterAnimator.luau` est le même que pour les salles précédentes.
Appeler `StarterAnimator.bind(model)` une fois puis
`StarterAnimator.step(rig, time, mode)` côté client après `model:PivotTo(...)`.
L'anaconda et les queues ont une chaîne de membres, pas un changement d'échelle.

Les PNG individuels, `Crocodile-profile.png`, `Apercu-collection.png` et
`Apercu-animations.gif` sont des rendus des vrais modèles et de leurs poses.
`Collection-6-animaux.blend` est une scène modifiable de pièces, pas une
armature Blender animée. Géométrie, articulations et clips sont aussi dans
`collection-data.json` ; dimensions et empreintes sont dans `MANIFEST.json`.

## Vérifications et limites

Chaînes de rig, poses de repos, références XML, empreintes, matrices et continuité
des boucles vérifiées hors ligne. Modules Luau compilés et galerie construite
avec Rojo. Rendus au repos et en mouvement inspectés avant livraison.

Les pièces et articulations sont détaillées dans le manifeste. L'éclairage des
rendus diffère de celui du jeu. Exécution dans Roblox Studio et fluidité sur
téléphone encore à valider, surtout si beaucoup d'animaux sont visibles.
Aucun crédit Meshy utilisé, aucune publication Roblox, aucune intégration
au jeu ou modification des sauvegardes.

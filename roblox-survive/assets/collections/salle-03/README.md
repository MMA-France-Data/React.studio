# SURVIVE! — salle 3 : les animaux de la ferme

Six modèles 3D originaux en pièces Roblox natives, articulés et animés localement.
Chaque espèce a sa propre silhouette. Le cheval est le modèle vedette de cette
collection : plus haut, avec des jambes à deux segments et un cou indépendant.
Il reste un cheval naturel, sans armure, couronne, aura ou effet magique.

| Fichier dans `models/` | Animal et caractéristiques |
| --- | --- |
| `Rooster.rbxmx` | Coq : crête rouge, cou doré, deux pattes à doigts, queue verte courbée |
| `Duck.rbxmx` | Canard colvert : tête verte, bec plat, ailes repliées et pieds palmés |
| `Pig.rbxmx` | Cochon : corps bas rose, gros groin à deux narines, queue en tire-bouchon |
| `Sheep.rbxmx` | Mouton : toison en petits volumes, tête sombre et petites pattes fines |
| `Goat.rbxmx` | Chèvre : corps élancé, oreilles horizontales, petites cornes et barbiche |
| `Horse.rbxmx` | Cheval bai : grand cou, tête longue, crinière sombre, sabots et longue queue |

La rareté du cheval, les prix, les pouvoirs et les statistiques du jeu ne sont
pas configurés par ce pack : seul son rôle visuel d'animal vedette est préparé.

## Contenu du pack

- Six modèles séparés dans `models/`.
- `Collection-6-animaux.rbxmx` : les six disposés ensemble.
- `Galerie-6-animaux.rbxl` : place indépendante de démonstration avec bouton marche/repos.
- `StarterAnimator.luau` : lecteur local des séquences des rigs ancrés.
- `Collection-6-animaux.blend` : scène de rendu modifiable des mêmes pièces.
- Six aperçus individuels et `Horse-profile.png` pour voir le cheval de côté.
- `Apercu-collection.png`, `collection-render.png` et `Apercu-animations.gif`.
- `collection-data.json` et `MANIFEST.json` : géométrie, rig, clips, dimensions et empreintes.

Les aperçus sont des rendus des fichiers 3D livrés, pas des concepts générés.
Leur éclairage diffère de celui du jeu. La scène Blender n'est pas une armature
Blender destinée à remplacer les articulations natives Roblox.

## Import et animation

Insérer les RBXMX depuis un fichier dans Studio, sans utiliser l'import de
maillage GLB/FBX. Les modèles n'ont ni maillage, ni texture, ni ressource externe
à téléverser, et aucun script dans les RBXMX. La galerie contient son propre
lecteur et sa démonstration locale, sans accès aux données du jeu.

Le pivot est centré et nommé `RigRoot`. Les animaux regardent vers -Z. Toutes
les pièces sont ancrées, sans collision, contact ou requête. Les détails sont
soudés au membre qu'ils doivent suivre. Chaque modèle possède un
AnimationController et deux séquences en boucle `Idle` et `Walk`.

Le coq et le canard ont 7 Motor6D, le mouton et la chèvre 9, le cochon 10,
et le cheval 15. Le cheval anime aussi les segments inférieurs de ses quatre
jambes, son cou, ses oreilles et sa queue. Les ailes des oiseaux restent
repliées : les séquences sont des marches, pas des vols.

Utiliser `StarterAnimator.bind(model)` une fois, puis
`StarterAnimator.step(rig, time, mode)` côté client après `model:PivotTo(...)`.
Aucun identifiant d'animation distant requis. Le lecteur est le même que dans
les collections précédentes ; l'intégration aux systèmes du jeu reste séparée.

## Vérifications et limites

- Chaînes de rig et poses de repos vérifiées numériquement.
- 6 rigs, 12 séquences, 204 poses échantillonnées sans matrices invalides.
- Références XML, absence de scripts dans les modèles et empreintes vérifiées.
- Modules Luau compilés et galerie construite avec Rojo.
- Rendus des modèles et des poses inspectés avant livraison.
- Test d'exécution dans Roblox Studio et fluidité sur téléphone encore à valider.

49 à 68 pièces par modèle, détails et petits plots compris. Le cheval atteint
3,1 studs de haut ; les autres restent plus petits. Mesurer la fluidité avant
publication si beaucoup de compagnons sont affichés simultanément.

Aucun crédit Meshy consommé, aucune publication Roblox. L'envoi GitHub de ce pack ne change pas
du jeu, des collections déjà livrées, des chances, de la progression ou des sauvegardes.

# SURVIVE! — salle 2, version 2 : une silhouette par espèce

Six modèles Roblox originaux retravaillés après le retour sur leurs ressemblances.
Les fichiers de la première version restent archivés localement.
La publication de ce pack sur GitHub ne change pas le jeu.
Aucun service de génération ni crédit Meshy utilisé pour cette retouche locale.

## Changements visuels

| Modèle | Construction propre à l'espèce |
| --- | --- |
| `Squirrel.rbxmx` | Écureuil dressé, petites mains hautes, cuisses larges, queue en C |
| `Hedgehog.rbxmx` | Hérisson très bas, dos bombé à piquants, petite tête et nez fin |
| `Raccoon.rbxmx` | Raton laveur à quatre pattes, masque horizontal, queue annelée décalée |
| `Skunk.rbxmx` | Moufette longue et fine, museau pointu, grande queue en éventail rayé |
| `Beaver.rbxmx` | Castor assis, ventre large, grosses joues, incisives et queue en pagaie |
| `Badger.rbxmx` | Blaireau bas et allongé, épaules fortes, tête effilée, bandes jusqu'aux oreilles |

Les yeux, oreilles, proportions, pattes et museaux ne reprennent plus le même
gabarit de tête carrée aux grands yeux. Le style reste fait de briques et de plots.

## Contenu

- Six modèles séparés dans `models/` et `Collection-6-animaux.rbxmx` pour les insérer ensemble.
- `Galerie-6-animaux.rbxl` : place indépendante de démonstration, avec bouton marche/repos.
- `StarterAnimator.luau` : lecteur local des animations. Pas d'identifiant distant requis.
- `Collection-6-animaux.blend` : scène de rendu modifiable constituée des mêmes pièces.
- `Apercu-collection.png`, six rendus individuels et `Apercu-animations.gif`.
- `collection-data.json` et `MANIFEST.json` : géométrie, dimensions, clips et empreintes.

## Import et animation

Insérer les fichiers RBXMX depuis un fichier dans Studio ; ce ne sont pas des
maillages GLB/FBX. Les modèles utilisent exclusivement des pièces Roblox natives,
sans textures, maillages ou ressources externes à téléverser, et sans scripts
dans les modèles. La galerie contient seulement son lecteur et sa démonstration locale.

Le pivot est `RigRoot`, les animaux regardent vers -Z. Les pièces sont ancrées,
sans collision, contact ou requête. Chaque rig contient 9 ou 10 Motor6D,
un AnimationController, des soudures et les séquences en boucle `Idle` et `Walk`.

Utiliser `StarterAnimator.bind(model)` une fois puis
`StarterAnimator.step(rig, time, mode)` côté client après `model:PivotTo(...)`.
Le lecteur reste compatible avec la première version ; les noms des six modèles
et des articulations sont conservés. La marche des petites mains de l'écureuil
et du castor a une amplitude réduite ; les quadrupèdes ont une démarche basse.
L'intégration dans les systèmes du jeu reste un travail séparé.

## Vérifications et limites

- Chaînes de rig et reconstruction des poses de repos vérifiées numériquement.
- 6 rigs, 12 séquences, 204 poses échantillonnées sans matrices invalides.
- Références internes XML et empreintes des modèles vérifiées.
- Modules Luau compilés et galerie construite avec Rojo.
- Rendus de la géométrie et des poses inspectés avant livraison.
- Exécution dans Roblox Studio et fluidité sur téléphone encore à valider.

50 à 87 pièces par modèle, détails et plots compris. L'éclairage des aperçus
diffère de celui du jeu. Le fichier Blender est une scène de rendu de pièces,
pas une armature Blender destinée à remplacer le rig Roblox.

Les prix, pouvoirs, statistiques, sauvegardes et salles du jeu ne sont pas modifiés.

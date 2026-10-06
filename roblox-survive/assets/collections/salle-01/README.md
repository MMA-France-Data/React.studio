# SURVIVE! — salle 1, version 2 : lapin retravaillé

Seul le lapin a été redessiné. Les cinq autres animaux et leurs animations sont
identiques aux fichiers de la première collection, ce qui est vérifié par leurs
empreintes SHA256. La première collection reste archivée localement.
La publication de ce pack sur GitHub ne modifie aucun fichier du jeu.
Aucun crédit Meshy utilisé.

## Le nouveau lapin

- Silhouette assise, arrière-train large et tête plus petite.
- Grosses cuisses et longues pattes arrière, petites pattes avant.
- Yeux modestes placés sur les côtés, joues claires et nez rose.
- Longues oreilles roses, dont une légèrement pliée au bout.
- Petite queue de coton étagée.
- Animation en petits bonds : les deux pattes arrière bougent ensemble.

Le modèle conserve l'identifiant `Rabbit`, son pivot `RigRoot` et les mêmes
noms d'articulations et de séquences. Il comporte 69 pièces et 9 Motor6D.
Le style reste composé de briques et de petits plots Roblox.

## Fichiers

Pour remplacer seulement le lapin, utiliser `models/Rabbit.rbxmx`.
Le pack complet contient aussi les cinq autres modèles inchangés, une insertion
groupée `Collection-6-animaux.rbxmx` et la galerie `Galerie-6-animaux.rbxl`.
Cette galerie est une place de démonstration indépendante, pas le jeu SURVIVE!.

`Rabbit.png` et `Rabbit-profile.png` montrent la géométrie livrée sous deux angles.
`Apercu-collection.png` montre
le nouveau lapin aux côtés des rendus précédents des cinq animaux inchangés.
`Apercu-animations.gif` montre uniquement les petits bonds du lapin retravaillé.
`Collection-6-animaux.blend` est la scène de rendu modifiable des six modèles,
pas une armature Blender. `collection-data.json` et `MANIFEST.json` conservent
les descriptions de géométrie, animations, dimensions et empreintes.

## Import et animation

Insérer le fichier RBXMX depuis un fichier dans Studio. Ne pas utiliser l'import
de maillage GLB/FBX. Les modèles contiennent uniquement des pièces Roblox natives,
sans texture, maillage, ressource externe ou script à importer.

Le pivot est centré et l'animal regarde vers -Z. Les pièces sont ancrées et sans
collision, contact ou requête. Le lecteur fourni `StarterAnimator.luau` anime
les Motor6D à partir des séquences locales `Idle` et `Walk`, sans identifiant
d'animation distant. Appeler `StarterAnimator.bind(model)` une fois, puis
`StarterAnimator.step(rig, time, mode)` côté client après `model:PivotTo(...)`.

L'intégration dans les systèmes du jeu reste séparée. Les prix, pouvoirs,
statistiques, sauvegardes et définitions de salles n'ont pas été changés.

## Vérifications et limites

- Structure XML, références internes et empreintes des modèles vérifiées.
- Reconstruction exacte des poses de repos et 204 poses numériques vérifiées.
- Modules Luau compilés et galerie construite avec Rojo.
- Aperçus du nouveau lapin au repos et en mouvement inspectés.
- Cinq autres modèles et leurs clips conservés à l'identique.
- Test d'exécution dans Roblox Studio et fluidité sur téléphone encore à faire.

L'éclairage des rendus diffère de celui du jeu. Mesurer la fluidité avant
publication, surtout si beaucoup de compagnons sont affichés simultanément.

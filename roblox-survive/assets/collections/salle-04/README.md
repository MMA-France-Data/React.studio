# SURVIVE! — salle 4, version 2 : loup retravaillé

Seul le loup a changé après le retour visuel du joueur. Les fichiers des cinq
autres animaux (lynx, bélier, sanglier, cerf, ours brun), géométrie et animations,
sont identiques à la salle 4 originale : empreintes SHA256 comparées.
La salle 5 est inchangée. La première version de la salle 4 reste archivée
localement. Aucun fichier du jeu n'a été modifié par cette livraison d'assets.

## Nouveau loup

- Corps long et tête portée vers l'avant, plus basse.
- Museau effilé, nez sombre, petits yeux jaunes latéraux et sourcils marqués.
- Pas de masque blanc de husky : dos sombre, gris naturels et collerette anguleuse.
- Oreilles plus compactes et pointues, petites canines visibles, queue basse touffue.
- Cou et mâchoire indépendants, quatre jambes à deux segments et queue à trois segments.

Le modèle conserve l'identifiant `Wolf`, le pivot invisible `RigRoot`,
l'orientation -Z, les séquences `Idle` et `Walk` et le lecteur fourni.
Il comporte 85 pièces et 17 Motor6D, contre 48 pièces et 9 Motor6D pour
la première version. Aucune piste d'échelle n'est utilisée.

## Fichiers

Pour remplacer uniquement le loup : `models/Wolf.rbxmx`.
Le pack contient aussi les cinq autres modèles inchangés, l'insertion groupée
`Collection-6-animaux.rbxmx`, une galerie indépendante `Galerie-6-animaux.rbxl`,
son projet Rojo et son lecteur local `StarterAnimator.luau`.

`Wolf.png` et `Wolf-profile.png` montrent le modèle livré. L'aperçu de collection
associe le nouveau rendu du loup aux rendus précédents des cinq animaux inchangés.
Le GIF montre uniquement le nouveau loup en marche. La scène `.blend`
contient les pièces de rendu modifiables, pas une armature Blender animée.
`collection-data.json` décrit géométrie, articulations et clips ; `MANIFEST.json`
donne les dimensions et empreintes des fichiers.

## Import et animation

Insérer les RBXMX depuis un fichier dans Studio, pas via l'importateur GLB/FBX.
Aucun MeshPart, texture hébergée ou script dans les modèles. Les pièces sont
ancrées et sans collision, contact ou requête. Ne pas écraser une place ouverte
avec du travail non sauvegardé en ouvrant la galerie.

Appeler `StarterAnimator.bind(model)` une fois puis
`StarterAnimator.step(rig, time, mode)` côté client après `model:PivotTo(...)`.
Pas d'identifiant d'animation à publier. La nouvelle chaîne d'articulations
du loup nécessite de relancer `bind` si l'on remplace un modèle déjà chargé.
Les prix, revenus, chances, raretés et sauvegardes restent hors de ce pack.

## Vérifications et limites

Références XML, empreintes, poses de repos, matrices, continuité des boucles
et syntaxe Luau vérifiées hors ligne. Galerie construite avec Rojo et rendus
du loup au repos et en mouvement inspectés avant livraison.
Exécution réelle dans Roblox Studio et fluidité sur téléphone encore à vérifier.

Rendu local en pièces Roblox : aucun crédit Meshy, aucune publication Roblox.
Ce pack est livré sur GitHub avec l'accord du joueur, sans intégrer les animaux
au jeu ni modifier sa logique.

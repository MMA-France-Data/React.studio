# Garde du dragon — troupes des vagues 81 à 90

Proposition demandée : des unités humaines avec un thème dragon, **pas de petits dragons**. `Swarm_8`, `Normal_8`, `Fast_8`, `Tank_8`, `Giant_8` : écuyer, fantassin, cavalier, chevalier lourd et colosse. Visages et anatomie humains conservés, armures sombres/cramoisies, petites écailles fermées sur les cuirasses, cornes de casque balayées vers l'arrière et détails de crocs sur les lourds. Le cheval reste un cheval avec un caparaçon thématique, sans ailes.

Le boss dragon de la vague 90 n'est pas créé ou installé par cette livraison. Un mesh skinné et un matériau texturé par unité ; atlas 1024 px humains, 2048 px cavalier. Nombres de triangles et filiation dans `manifest.json`. Aucun effet, lumière ou changement de gameplay ajouté.

## Import

Les `.blend` sont les sources éditables et les `.glb` incluent les clips et textures. Importer chaque humain depuis son `*_Walking_Studio.fbx` comme nouveau rig Custom, puis charger ce même fichier dans l'Éditeur pour tester la marche. Charger ensuite le `*_Death_Studio.fbx` correspondant sur le même squelette.

Pour le cavalier : importer `Fast_8_Gallop_Studio.fbx` et charger ce même fichier comme animation. Vérifier quatre jambes en mouvement et soldat assis droit ; tester `Fast_8_Death_Studio.fbx` sur le même rig. Garder les modèles précédents, publier les animations seulement après validation sous le propriétaire de l'expérience. PNG couleur fourni séparément comme secours.

Humains : 41 os KayKit et clips `Idle`, `Walking_A`, `Running_A`, `Death_A`. Cheval : 48 os de la base corrigée, `Gallop`, `Death`, `Rider` enfant de `Back`. Repos, noms et parents ne sont pas modifiés ; aucun rerig nécessaire.

## Contrôles et limites

Les cinq GLB et dix FBX finaux sont réimportés dans Blender. Rapports `validation.json` et `validation-fbx.json` : texture/UV, poids normalisés/quatre influences maximum, repos identique aux références, absence d'animation d'échelle, mouvements des membres et rigidité du cavalier. Échantillonnage FBX 30 images/s et texture embarquée comparée au PNG.

`apercu-famille.png`, `apercu-galop.gif` et `controle-animations.png` montrent les exports réellement réimportés dans Blender. **Import, animations, texture, orientation et performances Roblox Studio restent à confirmer.** Aucun `.rbxm`, identifiant Roblox, script, interface ou fichier `tools/` n'est modifié ou installé. Envoi GitHub après validation visuelle.

## Provenance et coût

Variantes locales KayKit Adventurers, Kay Lousberg (CC0) ; cheval Quaternius Ultimate Animated Animal Pack (CC0). Licence KayKit jointe et sources listées dans les JSON. Aucun appel Meshy et aucun crédit consommé pour cette famille. Les bases précédentes sont intactes.

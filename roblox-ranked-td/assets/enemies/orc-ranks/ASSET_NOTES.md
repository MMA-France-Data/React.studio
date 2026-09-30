# Horde orc — proposition de troupes pour les vagues 91 à 100

Le propriétaire a demandé des orcs ; cette proposition occupe la tranche verte de fin du cycle, initialement appelée Horde gobeline. Le numéro de tranche n'est pas modifié dans le gameplay : cette correspondance reste à valider. Le nouveau boss orc Meshy est livré séparément ; les cinq troupes sont des variantes locales sans crédits supplémentaires.

`Swarm_9`, `Normal_9`, `Fast_9`, `Tank_9`, `Giant_9` : éclaireur/écuyer, fantassin, cavalier, lourd et colosse. Les visages humains sont retirés et remplacés par de vrais volumes verts : crâne fermé, mâchoire, nez, yeux ambre, sourcils menaçants, défenses et oreilles pointues. Les protège-visages des grands casques sont reculés pour dégager les faces ; pas de tête collée devant un visage conservé. Corps et équipement sont repris des bases existantes.

Un mesh skinné et un matériau par unité, texture couleur 1024 px pour les humains et 2048 px pour le cavalier. Nombres de triangles et sources dans `manifest.json`. Les modèles sont stylisés et plus légers que le boss, pas des miniatures de sa géométrie détaillée. Aucun effet lumineux ou particule ajouté.

## Import

Les `.blend` sont éditables ; les `.glb` embarquent modèle, texture et clips. Pour Studio, importer le `*_Walking_Studio.fbx` humain comme nouveau rig Custom, puis charger ce même FBX dans l'Éditeur. Tester le `*_Death_Studio.fbx` correspondant sur ce même rig.

Pour le cheval : importer `Fast_9_Gallop_Studio.fbx`, charger ce même FBX comme animation et vérifier ses quatre jambes plus le soldat assis. Tester `Fast_9_Death_Studio.fbx` sur le même squelette. Ne pas remplacer les modèles précédents avant validation. Publier sous le propriétaire de l'expérience après test. Le PNG `*_Color.png` est fourni séparément si la texture demande une réaffectation.

Humains : squelette KayKit original à 41 os, `Idle`, `Walking_A`, `Running_A`, `Death_A`. Cavalier : squelette corrigé de 48 os, `Gallop` et `Death`, `Rider` enfant de `Back`. Noms, parents et matrices de repos sont conservés.

## Contrôles

`validation.json` : cinq GLB réimportés, texture/UV, poids normalisés, échelles unitaires, aucune piste d'échelle et poses échantillonnées. `validation-fbx.json` : dix FBX réimportés à 30 images/s, comparaison du repos aux rigs de référence, quatre poids maximum, échelle osseuse fixe à chaque image, membres en mouvement, texture comparée au PNG et cavalier rigide.

Les aperçus sont des rendus Blender des exports réimportés. **Roblox Studio : import, marche, galop, mort, texture, orientation et performances restent à confirmer.** Aucun `.rbxm`, numéro d'animation, code, interface ou fichier `tools/` n'est installé ou modifié. Aucun envoi GitHub avant validation visuelle.

## Provenance

Bases KayKit Adventurers, Kay Lousberg (CC0), et cheval Quaternius Ultimate Animated Animal Pack (CC0). Licence KayKit jointe, filiation dans les JSON. Travail local, aucune tâche Meshy et zéro crédit pour ces unités. Les fichiers antérieurs sont conservés.

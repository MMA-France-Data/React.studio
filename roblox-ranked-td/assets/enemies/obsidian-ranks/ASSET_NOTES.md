# Chevaliers d'obsidienne — troupes des vagues 71 à 80

Proposition visuelle locale à valider par le propriétaire avant transmission à Claude. Cette famille accompagne le Seigneur d'obsidienne, boss de la vague 80 livré séparément. Aucun modèle installé ni script de jeu n'est remplacé.

| Source | Unité | Triangles |
| --- | --- | --- |
| `Swarm_7` | Écuyer masqué, équipement léger | 3916 |
| `Normal_7` | Fantassin, épée et bouclier | 4746 |
| `Fast_7` | Cavalier masqué, cheval ardoise | 7042 |
| `Tank_7` | Chevalier lourd, épaulières et pointes | 5328 |
| `Giant_7` | Colosse, casque renforcé, masse et bouclier | 5706 |

Armures noir bleuté, tissus bordeaux sombre, masques facettés et yeux de braise. Les îlots de l'ancienne tête humaine sont retirés et remplacés par des volumes fermés dans l'espace du visage d'origine. Les grands casques sont conservés ; leur ancien protège-visage saillant est reculé pour dégager le nouveau visage. Aucun décalage du masque vers l'avant : son volume arrière rejoint le crâne, au lieu d'une plaque mince extérieure. Les ornements sont soudés au mesh final et liés aux os existants, sans particules ni lumières de gameplay.

Un seul mesh skinné et un seul matériau par unité ; atlas couleur 1024 px pour les humains et 2048 px pour le cavalier. Ces nombres ne garantissent pas les performances à six parcelles : un test en situation reste nécessaire.

## Import et animations

Les `.blend` sont les sources éditables. Les `.glb` contiennent modèle, texture et clips. Les FBX séparés sont fournis pour tester puis publier les animations dans Studio :

- Importer le `*_Walking_Studio.fbx` de chaque humain comme nouveau rig Custom. Charger ce même FBX dans l'Éditeur pour vérifier la marche, puis le `*_Death_Studio.fbx` correspondant sur ce même rig.
- Pour le cavalier, utiliser `Fast_7_Gallop_Studio.fbx`, puis charger ce même fichier dans l'Éditeur. Vérifier le mouvement des quatre jambes et le soldat assis droit. Tester ensuite `Fast_7_Death_Studio.fbx` sur le même squelette.
- Garder les modèles précédents jusqu'à validation. Les textures PNG séparées sont fournies en secours. Publier les animations sous le propriétaire de l'expérience uniquement après test.

Humains : 41 os KayKit, clips `Idle`, `Walking_A`, `Running_A`, `Death_A`. Cavalier : 48 os de la base corrigée, `Gallop` et `Death`, soldat rigidement lié à `Rider`, enfant de `Back` et non au `Torso` retourné. Matrices de repos, noms et parents sont conservés ; aucun nouveau rig ni animation générée.

## Contrôles et limites

`validation.json` consigne les cinq GLB réellement réimportés : mesh, matériau, texture, UV, poids normalisés, échelles unitaires, absence de pistes d'échelle, poses échantillonnées et rigidité du cavalier.

`validation-fbx.json` consigne les dix réimports FBX à 30 images/s : repos et parents des os comparés aux exports de référence, quatre influences maximum, poids normalisés, échelles unitaires à chaque image, mouvement des membres et texture embarquée comparée au PNG final. Les poses échantillonnées sont contrôlées pour les étirements ; le cavalier reste rigide par rapport à son os.

`apercu-famille.png` montre les GLB exportés puis réimportés. Les tailles de présentation ne changent pas le gameplay. `apercu-galop.gif` et `controle-animations.png` montrent les FBX réimportés dans Blender.

**Import, texture, orientation, lecture des animations et performances dans Roblox Studio : encore à confirmer.** Les contrôles Blender ne remplacent pas ces tests. Aucun `.rbxm`, identifiant Roblox, script, interface ou fichier du dossier `tools/` n'est modifié ou installé.

## Provenance et coût

Variantes locales à partir des bases existantes : KayKit Adventurers, Kay Lousberg (CC0), et Quaternius Ultimate Animated Animal Pack (CC0) pour le cheval. Licence KayKit jointe ; filiation dans `manifest.json` et `provenance.json`. Sources antérieures conservées. **Aucune requête Meshy et aucun crédit dépensé pour cette famille.**

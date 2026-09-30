# Boss 80 — Seigneur d'obsidienne

Look validé par le propriétaire le 30 septembre 2026, avec accord pour transmettre les sources sur GitHub à Claude. Modèle séparé : le roi carmin original est conservé intact. Cette validation visuelle ne valide pas l'import ou les animations Roblox Studio, qui restent à tester.

Variante du roi carmin de la vague 10 fourni par le propriétaire : armure charbon/acier, tissus sombres, masque facetté fermé, yeux et cœur couleur braise, éclats d'obsidienne aux épaules et à la couronne. La silhouette de base, ses 23 os, les noms/parents et ses clips `Walking` et `Dead` sont conservés. Le fichier de mort s'appelle `Death_Studio.fbx` pour rester cohérent avec les packs récents, mais son action source demeure `Dead`.

## Premier test dans Studio

1. Dans un espace de test, importer **un nouveau modèle** depuis `SeigneurObsidienne_Walking_Studio.fbx` avec un rig Custom.
2. Sélectionner ce modèle dans l'Éditeur d'animation, charger ce même FBX et vérifier la marche sur tout le clip : jambes, bras, masque, cape et orientation.
3. Charger `SeigneurObsidienne_Death_Studio.fbx` sur ce même squelette et vérifier la mort entière.
4. Contrôler texture, échelle et orientation en situation de jeu. Garder les anciens modèles tant que les tests ne sont pas validés. Publier les animations sous le propriétaire de l'expérience seulement après validation.

`SeigneurObsidienne_StudioRig.glb` est un modèle statique texturé, pas un clip à publier. Les deux `.blend` sont les sources éditables. `SeigneurObsidienne_Color.png` est la texture couleur 2048 px de secours, également embarquée dans les exports. Si l'import est gris, vérifier le chargement et les droits, puis raccorder le PNG au `ColorMap` d'un `SurfaceAppearance` ou au `TextureID` si aucun `SurfaceAppearance` n'est utilisé. Ne pas modifier le rig pour résoudre un défaut de texture.

## Contrôles locaux et limites

10806 triangles, un mesh skinné, un matériau, une UV, 23 os. L'ancienne échelle globale 0,01 de la source a été appliquée au mesh et à l'armature ; les translations des animations ont été adaptées en conservant les poses. L'écart maximal des sommets avant/après normalisation sur les poses échantillonnées est de 0,000016 unité Blender environ. Les durées des clips sont conservées à l'arrondi d'échantillonnage à 30 images/s. Ne pas supposer que les anciens identifiants d'animation du roi carmin sont directement compatibles avec le nouveau rig normalisé : tester et publier les FBX fournis sur ce nouveau modèle.

`validation.json` consigne les réimports des deux FBX : squelette identique à la source normalisée, un seul parent racine, poids normalisés et quatre influences maximum, échelles unitaires à chaque image, mouvement des pieds/mains, poses échantillonnées sans étirement et texture embarquée comparée au PNG final.

Les nouveaux ornements et le masque sont des volumes fermés. Le maillage d'origine comporte déjà 68 bords ouverts après soudure de contrôle ; le résultat conserve ce nombre, sans ajout de bords ouverts. Ce modèle n'est donc pas revendiqué comme entièrement étanche ou prêt à l'impression. La géométrie de base et la cape n'ont pas été rebouchées arbitrairement.

Les aperçus fixes et animés sont rendus depuis les FBX réimportés dans Blender, pas des captures Studio. Les braises sont des couleurs géométriques, **pas** des lumières, particules ou effets électriques de gameplay.

Aucun `.rbxm`, identifiant d'animation Roblox, script, interface, outil ou réglage de gameplay n'est installé. Ces sources ne sont pas chargées automatiquement par Rojo. **Tests d'import, d'animation, de texture et de performances dans Roblox Studio : à confirmer.**

## Provenance et coût

Source locale : `outputs/unites-01-10/RoiCarmin_Master.blend`, composée à partir des exports Meshy du propriétaire, dont le forfait payant a été confirmé le 29 septembre 2026. Les identifiants des anciennes tâches Meshy fournies par le propriétaire ne sont pas disponibles dans ce pack. `provenance.json` conserve la filiation locale. Aucun nouvel appel Meshy : **0 crédit consommé pour cette variante**.

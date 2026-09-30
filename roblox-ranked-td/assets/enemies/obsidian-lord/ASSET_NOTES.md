# Seigneur d'obsidienne — boss vague 80

Look validé par le propriétaire le 30 septembre 2026, avec accord pour transmettre les sources à Claude sur `claude/exciting-gauss-ggwcwm`. Variante locale du roi carmin (vague 10) : armure charbon/acier, masque fermé, yeux et cœur couleur braise, éclats aux épaules et à la couronne. Aucune requête Meshy ni crédit consommé pour cette variante.

Les deux FBX `SeigneurObsidienne_Walking_Studio.fbx` et `SeigneurObsidienne_Death_Studio.fbx` fournissent le modèle texturé avec les animations séparées. Importer un nouveau rig Custom depuis la marche, charger cette même marche dans l'Éditeur, puis tester la mort sur ce même modèle. Le GLB est statique ; les deux `.blend` sont les sources éditables ; le PNG couleur 2048 px est fourni séparément et embarqué dans les exports. Consignes complètes dans `IMPORT-STUDIO.md`.

10806 triangles, un mesh/matériau/UV, 23 os. Le rig source était à l'échelle 0,01 : cette échelle et les translations d'animation ont été normalisées, avec poses conservées à environ 0,000016 unité Blender près sur les échantillons. Ne pas réutiliser les anciens identifiants d'animation sans test : publier les FBX fournis sur ce nouveau modèle après validation. L'action source de mort s'appelle `Dead`.

`validation.json` documente les deux réimports FBX dans Blender : squelette de repos et parents identiques à la source normalisée, échelles unitaires à chaque image, poids normalisés/quatre influences maximum, membres en mouvement, poses sans étirement et texture embarquée comparée au PNG final. La cape et la base comportent déjà 68 bords ouverts après soudure de contrôle ; aucun bord ouvert supplémentaire n'est introduit. Les nouveaux ornements sont fermés. Aucun modèle entièrement étanche n'est revendiqué.

Les aperçus sont des rendus Blender des fichiers exportés, pas des captures Roblox. **Import, marche, mort, orientation, texture et performances Studio : encore à confirmer.** Garder les anciens modèles durant les tests. Les braises ne sont pas des lumières ou des particules de gameplay.

Aucun `.rbxm`, identifiant Roblox, script de rendu, gameplay, interface ou outil n'est modifié par cet envoi. Les sources de ce dossier ne sont pas automatiquement chargées par Rojo. L'intégration après test reste à effectuer par Claude. Le modèle carmin original est conservé intact ; filiation locale et forfait Meshy payant du propriétaire documentés dans `provenance.json`.

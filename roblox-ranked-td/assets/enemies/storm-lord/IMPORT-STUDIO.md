# Boss vague 70 — Seigneur de la tempête

Look validé par le propriétaire le 30 septembre 2026, avec accord pour transmettre les sources sur GitHub à Claude. Cette validation visuelle ne valide pas l'import ou les animations dans Studio. Ne pas remplacer un boss installé avant les tests Roblox.

Base : Titan du givre de la vague 40, nouvelle palette indigo/or, ornements d'éclairs fermés liés aux os existants. Ce boss réutilise la silhouette du Titan, son rig et ses clips ; ce n'est pas une nouvelle génération Meshy. Le roi carmin est réservé comme base possible au boss d'obsidienne de la vague 80, non créé ici.

Importer `SeigneurTempete_Walking_Studio.fbx` avec un rig Custom dans un espace de test. Dans l'Éditeur d'animation, charger ce même fichier et vérifier la marche. Tester ensuite `SeigneurTempete_Death_Studio.fbx` sur le même squelette. Garder les anciens modèles tant que les deux clips ne sont pas validés. Publier les animations uniquement après ce test, sous le propriétaire de l'expérience.

Le rig statique est dans `SeigneurTempete_StudioRig.glb`, les sources éditables dans les deux `.blend`. Texture couleur embarquée et également fournie sous `SeigneurTempete_Color.png` (2048 px). L'UV d'origine est conservé, avec une étroite bande pour les couleurs des ornements. Si le modèle apparaît gris, vérifier l'import, les permissions et le chargement avant de modifier le rig ; raccorder le PNG au ColorMap du SurfaceAppearance ou au TextureID si aucun SurfaceAppearance n'est utilisé.

24 os, un mesh, un matériau, 16216 triangles, animations séparées à 30 images/s. Les noms et matrices de repos restent inchangés par rapport à la source. Les éclairs sont des ornements géométriques liés au rig, pas des effets électriques dynamiques ajoutés au gameplay. validation.json consigne les réimports des FBX : texture/UV, poids normalisés, quatre influences maximum, surface sans bords ouverts après soudure de contrôle, échelles fixes et mouvement des membres.

Les rendus `preview-v3-walking.png`, `preview-v3-death.png` et l'aperçu animé proviennent des fichiers réimportés dans Blender. La texture embarquée a également été comparée au PNG final. **Import, animations et performances dans Roblox Studio : à confirmer.** Aucun `.rbxm`, identifiant Roblox, script, interface ou réglage de gameplay n'est installé.

Coût de cette variante : 0 crédit, aucune requête Meshy. provenance.json conserve la filiation vers les tâches payées du Titan original, sans les compter comme une dépense de cette variante.

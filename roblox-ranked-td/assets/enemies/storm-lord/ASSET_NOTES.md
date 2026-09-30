# Seigneur de la tempête — boss vague 70

Rendu approuvé par le propriétaire le 30 septembre 2026. Sources transmises à Claude sur la branche `claude/exciting-gauss-ggwcwm`, sans intégration automatique au jeu. Le boss clôture la tranche 61–70 ; les troupes de cette tranche ne sont pas incluses dans cet envoi.

Variante locale du Titan du givre (vague 40) : palette indigo/or et ornements d'éclairs liés aux os existants. La silhouette, le squelette à 24 os et les animations du Titan sont conservés. Aucun nouvel appel Meshy ni crédit consommé. `provenance.json` conserve la filiation vers les tâches payées du Titan, sans les compter comme une dépense de cette variante.

## Fichiers et premier test

- `SeigneurTempete_Walking_Studio.fbx` : importer comme nouveau rig Custom dans un espace de test, puis charger ce même FBX dans l'Éditeur d'animation pour vérifier la marche.
- `SeigneurTempete_Death_Studio.fbx` : charger la mort sur ce même squelette et vérifier l'ensemble du clip.
- `SeigneurTempete_StudioRig.glb` : modèle statique texturé et rig, pas un fichier d'animation à publier.
- Deux `.blend` : sources éditables, textures regroupées incluses.
- `SeigneurTempete_Color.png` : texture couleur 2048 px, également embarquée dans les exports.
- `preview-v3-walking.png`, `preview-v3-death.png`, `apercu-marche.gif` : rendus des FBX réimportés dans Blender, pas des captures Studio.

Voir `IMPORT-STUDIO.md` pour les précautions d'import et de texture. Un mesh, un matériau, 16216 triangles ; ornements géométriques seulement, aucun effet électrique dynamique ou son installé.

## État exact des validations

`validation.json` consigne les deux réimports FBX dans Blender : matrices de repos identiques à la source, 24 os, échelles unitaires à chaque image, poids normalisés et quatre influences maximum, mouvements des mains/pieds, UV unique et texture embarquée retrouvée. Le PNG embarqué a aussi été comparé au PNG final. Les clips sont échantillonnés à 30 images/s, avec leurs durées originales.

**Roblox Studio : import, marche, mort, affichage de texture et performances encore à confirmer.** L'approbation du propriétaire porte uniquement sur le rendu visuel. Garder les anciens modèles intacts durant les tests et publier les animations sous le propriétaire de l'expérience seulement après validation.

Les FBX/GLB de ce dossier ne sont pas chargés automatiquement par Rojo. Aucun `.rbxm`, identifiant d'animation Roblox, script de rendu, interface, outil ou réglage de gameplay n'est ajouté ou modifié par cet envoi. L'intégration après test reste à effectuer par Claude.

# Les 7 épées Meshy retenues — fichiers source pour Studio

Les **vrais modèles choisis**, pas les anciens modèles en Parts ni les lames témoins des animations. Livraison du 7 octobre 2026, sans nouvelle génération ni crédits Meshy.

| Apparence | Fichier à importer | Sélection conservée |
| --- | --- | --- |
| Fer | `Iron/Sword_Iron.fbx` | Nouveau modèle téléchargé par le joueur |
| Acier | `Steel/Sword_Steel.fbx` | Nouveau modèle téléchargé par le joueur |
| Or | `Gold/Sword_Gold.fbx` | Version corrigée validée, un seul manche |
| Glace | `Frost/Sword_Frost.fbx` | Ancienne glace expressément conservée |
| Feu | `Flame/Sword_Flame.fbx` | Nouveau modèle téléchargé par le joueur |
| Foudre | `Storm/Sword_Storm.fbx` | Nouveau modèle jaune doré téléchargé par le joueur |
| Arc-en-ciel | `Prismatic/Sword_Prismatic.fbx` | Nouveau modèle téléchargé par le joueur |

Chaque dossier contient le FBX et ses quatre cartes PNG d'origine : couleur, normal, métallique, rugosité. Les longs noms des textures des cinq nouveaux téléchargements sont conservés pour ne pas casser les références du FBX. `MANIFEST.json` donne les noms exacts, leur rôle et leur empreinte SHA-256.

Les FBX et PNG sont **copiés à l'identique**, sans redimensionnement, remesh, modification des UV, ni reconstruction de lame. L'or est le résultat de la réparation déjà approuvée, pas une nouvelle modification. Les GLB/ZIP dupliqués ne sont pas ajoutés pour éviter de gonfler inutilement le dépôt.

## Ce qui est prêt / ce qui reste à faire

Les **sources sont sur GitHub**, mais ce ne sont pas encore des assets Roblox publiés. Aucun MeshId ni TextureId n'est inventé. Le jeu continue donc d'utiliser ses visuels de secours tant que les modèles ne sont pas importés et raccordés dans Studio.

Les `preview.png` sont des rendus des FBX livrés avec les PNG livrés. `IMPORT_QA.json` décrit la lecture des FBX hors Roblox, leurs UV et le nombre de triangles. Il ne certifie ni la compatibilité finale Studio, ni la topologie parfaite.

La géométrie de l'or conservait déjà quelques arêtes ouvertes hors de la jointure réparée ; cette livraison ne les modifie pas. Ne pas présenter ce modèle comme globalement fermé / étanche.

## Attention : cinq modèles à alléger avant l'import Roblox

Les [spécifications Roblox](https://create.roblox.com/docs/art/modeling/specifications) limitent chaque mesh à **20 000 triangles**. Les sept fichiers ont été lus dans Blender ; chacun contient un seul mesh. Les cinq nouveaux téléchargements dépassent cette limite : ce sont des sources haute définition, **pas des fichiers prêts à importer tels quels**.

| Modèle | Triangles | Sous la limite de triangles |
| --- | ---: | --- |
| Fer | 119 302 | Non |
| Acier | 111 038 | Non |
| Or | 3 987 | Oui |
| Glace | 5 778 | Oui |
| Feu | 220 154 | Non |
| Foudre | 252 074 | Non |
| Arc-en-ciel | 311 622 | Non |

Préparer une **copie optimisée** de ces cinq modèles, en conservant leur silhouette et leurs textures, puis vérifier le résultat dans Studio. Garder les originaux de ce dossier comme références. Cette livraison ne réduit pas les meshes et n'utilise aucun crédit Meshy. Être sous la limite ne confirme pas à lui seul que l'import Studio est validé.

## Import et branchement pour Claude

1. Après optimisation des cinq sources trop détaillées, importer les FBX dans Studio. Les FBX peuvent contenir les textures de base ; si les PBR ne suivent pas, utiliser les quatre PNG indiqués dans `MANIFEST.json` avec une `SurfaceAppearance`. Voir [Importer Roblox](https://create.roblox.com/docs/studio/importer) et [textures PBR](https://create.roblox.com/docs/art/modeling/surface-appearance).
2. Conserver la forme choisie. Ne pas remplacer ces modèles par les anciens `assets/combat/personnage/models/Sword_*.rbxmx`, ni par les lames de test de la galerie v3.
3. Calibrer la prise **au centre du manche**, pas au centre de la boîte du modèle. Utiliser un petit `Grip` transparent comme `PrimaryPart` si nécessaire. Alignement canonique : longueur de lame **-Z**, largeur/tranchants **Y**, épaisseur **X**. Déplacer/aligner l'ensemble ne doit pas déformer sa géométrie.
4. Ajouter `TrailBase` au début de la lame et `TrailTip` à sa pointe ; attacher ces deux `Attachment` au modèle qui suit la main. Leur position est à vérifier sur le vrai mesh, pas à recopier au hasard depuis la lame témoin.
5. Ranger les modèles calibrés sous `ReplicatedStorage/SwordMeshes`, nommés exactement `Iron`, `Steel`, `Gold`, `Frost`, `Flame`, `Storm`, `Prismatic`. `SwordVisuals` utilise automatiquement les six identités déjà reliées à la boutique. Le rattachement de Gold à un nouveau niveau reste à décider sans décaler les sauvegardes existantes.
6. Les effets sont déjà dans `src/client/SwordEffects.luau` et la prise dans `SwordGrip.luau`. Ils suivent la main / les vrais points de lame. Auras et traînée sont **générées dans Roblox**, pas incluses comme géométrie figée dans les FBX. Pour une intégration manuelle : `SwordEffects.attach(model, id)`, puis `SwordEffects.update(model, dt, swinging)` après placement sur la main.
7. Vérifier chaque épée au repos, sur les deux coups, en marche et sur téléphone. Les dégâts, les prix et les niveaux ne sont pas changés par cette livraison.

## Provenance

Fer, acier, feu, foudre et arc-en-ciel : exports FBX des cinq archives Meshy téléchargées par le joueur le 7 octobre. Leurs identifiants de tâches ne sont pas fournis dans les archives et ne sont pas inventés.

Glace : ressource Meshy `text-to-3d`, tâche `01a11702-686b-7749-a83f-066ffa979129` du projet local `MONDE-seven-swords-20261007`. Or : même projet, tâche source `01a11701-1ef8-72fb-ab75-b4a48dabd47b`, réparation locale validée `Gold-single-grip-v2`. Aucune de ces tâches n'a été relancée pour cette livraison.

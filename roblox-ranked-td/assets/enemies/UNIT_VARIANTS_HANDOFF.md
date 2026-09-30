# Bases visuelles cuivre, ronces et givre — transmission à Claude

Le propriétaire a validé le rendu des deux fantassins et demandé de décliner les autres unités, puis de transmettre ces assets sur GitHub pour créer des variantes. Ces fichiers sont des sources 3D, pas encore des modèles Roblox intégrés.

## Contenu

| Dossier | Vagues | Suffixe | Style |
| --- | --- | --- | --- |
| `copper-ranks/` | 11–20 | `_1` | Pillards de cuivre : armure cuivre, cuir sombre, haches et masses |
| `bramble-ranks/` | 21–30 | `_2` | Gardiens des ronces : capuche verte, branches, bois et feuilles |
| `frost-ranks/` | 31–40 | `_3` | Légion du givre : armure argentée, tissus bleu nuit, cristaux liés aux os, cheval gris |

Chaque dossier contient cinq unités : `Swarm` (écuyer), `Normal` (fantassin), `Fast` (cavalier), `Tank` (chevalier lourd), `Giant` (colosse).
Tous les boss restent séparés de ces troupes : aucun boss n'est remplacé par cet envoi.

## Ajout du 30 septembre : givre et cavalier carmin corrigé

Le propriétaire a demandé d'envoyer les cinq troupes du givre sur GitHub pour Claude. `frost-ranks/ASSET_NOTES.md` donne les noms d'import et l'état exact des tests. Les cinq GLB et les dix FBX (marche/galop et mort) ont été réimportés et contrôlés dans Blender. Les animations et l'apparence givre ne sont **pas encore confirmées dans Studio**. Aucun fichier de gameplay, `.rbxm` ou identifiant d'animation Roblox n'est modifié.

`crimson-cavalry-studio/` contient le cavalier carmin 1–10 corrigé. Après le lien `Fast_0_Gallop_Studio.fbx`, le propriétaire a répondu « parfait ça marche ». Le **galop carmin est donc désormais confirmé dans Studio**, comme le galop cuivre ; cette confirmation ne concerne pas sa mort ni les nouvelles variantes givre. Les anciens fichiers dans `crimson-ranks/` sont conservés intacts. La source Blender ajoutée conserve le galop ; la mort est livrée dans son FBX séparé.

- `.glb` : modèle, texture embarquée, squelette et clips d'animation.
- `.blend` : source Blender 5.2 éditable, rig et textures regroupées inclus.
- `*_Color.png` : texture séparée de secours ; 1024 px pour les humains, 2048 px pour les cavaliers.
- `Fast_*_Gallop_Studio.fbx` / `Fast_*_Death_Studio.fbx` : exports séparés du cavalier à tester dans l'Éditeur d'animation.
- `apercu-famille.png` : rendu des modèles GLB réimportés ; tailles de présentation, pas chiffres de gameplay.
- `manifest.json` et `validation.json` : inventaire et contrôles locaux.
- `preview-cavalry-variants.gif` : rendu animé du FBX cuivre réimporté dans Blender, pas une capture Studio.

## État exact du cavalier : galops cuivre et carmin confirmés par le propriétaire

Le propriétaire précise que l'ancien cavalier pouvait être droit au repos, mais que **seule la tête bougeait dans l'Éditeur d'animation Roblox**. L'import au repos ne constituait donc pas une validation de l'animation.

Les quatre jambes bougent dans les nouveaux GLB et FBX réimportés dans Blender. Le 30 septembre 2026, après le test proposé dans l'Éditeur d'animation, le propriétaire confirme que **le nouveau cavalier cuivre fonctionne** ("ça marche", puis précise "le cavalier"). Cette confirmation concerne le galop cuivre `Fast_1_Gallop_Studio.fbx` des vagues 11–20, pas le cavalier carmin des vagues 1–10.

La mort cuivre et les animations du cavalier ronces n'ont pas encore reçu de confirmation Studio. La cause exacte du problème de l'ancien import reste à déterminer ; ne pas généraliser les validations cuivre et carmin aux autres clips. Le nouvel export carmin ajouté dans `crimson-cavalry-studio/` est confirmé pour le galop seulement, sans remplacer les anciennes sources.

Précautions dans les nouveaux cavaliers :

- un seul mesh, un seul matériau, échelles d'objets de 1, une racine unique, squelette à 48 os ;
- soldat et selle rattachés à `Rider`, enfant de `Back` ;
- aucune piste d'échelle dans les GLB ; échelles constantes de 1 dans les FBX ;
- FBX échantillonnés à 30 images/s, durée des clips préservée ;
- `Root` et `Body` ont une influence de skinning très faible (0,0001 sur un sommet chacun), précaution contre l'omission d'os sans influence à l'import. Il s'agit d'une piste de robustesse, pas d'une cause démontrée.

Premier test proposé : importer un **nouveau** modèle depuis `copper-ranks/Fast_1_Gallop_Studio.fbx`, sélectionner ce modèle dans l'Éditeur, puis importer le même FBX comme animation. Vérifier les quatre jambes, le corps, la tête et la position assise. Tester ensuite `Fast_1_Death_Studio.fbx` sur le même squelette. Garder les anciens modèles intacts pendant ce test.

Les fichiers `validation-cavaliers-fbx.json` et `preview-cavalry-variants.gif` documentent seulement les tests Blender. La confirmation utilisateur du galop cuivre est consignée dans cette note ; aucune capture ou animation publiée n'est fournie dans cet envoi. Vérifier les autres clips avant leur intégration.

## Création de variantes

Les humains utilisent la même base KayKit à 41 os que les troupes carmin. Les clips inclus sont `Idle`, `Walking_A`, `Running_A`, `Death_A`. Le cavalier utilise un squelette différent à 48 os et ses clips `Gallop`, `Death`.

Conserver les noms, parents et matrices de repos des os ; modifier d'abord les matériaux, les silhouettes et équipements. Les pièces rattachées à la tête ou à une main doivent conserver leur skinning. Éviter d'appliquer des transformations sur un rig en pose animée, de réintroduire des pistes d'échelle ou de réduire un maillage aux sommets non soudés.

`variant-source-kit/` contient les sources CC0 non fusionnées `Knight.glb`, `Rogue_Hooded.glb` et `Barbarian.glb`, utiles pour modifier séparément têtes, casques, membres et équipements. Leurs squelettes humains sont compatibles entre eux ; ne pas utiliser leurs animations humaines sur le cheval. La réutilisation des animations déjà publiées doit être vérifiée dans Studio sur les nouveaux modèles.

Les variantes lourdes sont renforcées aux épaules et au torse. Les colosses possèdent une masse et des cornes/branches supplémentaires. L'écuyer est plus simple et sans bouclier. Les couleurs et les tailles vues dans les rendus ne modifient pas les statistiques du jeu.

## Intégration après validation

Les GLB/FBX ne sont pas chargés automatiquement par Rojo. Après import et validation Studio, enregistrer les modèles en `.rbxm` sous leur nom exact, par exemple `Normal_1.rbxm`, dans `assets/EnemyModels/`. Ce dossier est placé dans `ReplicatedStorage.EnemyModels` par le projet.

L'envoi actuel n'ajoute aucun `.rbxm`, aucun numéro d'animation et aucune modification de `CustomModels`, `PlotRenderer`, `Effects`, des chiffres de gameplay, de l'interface ou du dossier `tools/`. Pas de mesure de performances dans Studio revendiquée.

## Licences et coûts

Personnages et pièces : KayKit Adventurers (Kay Lousberg), CC0 ; licence copiée dans `variant-source-kit/LICENSE-KayKit-CC0.txt`. Le cheval réutilise la base Quaternius déjà présente dans `crimson-ranks/` et documentée dans son fichier `ASSET_NOTES.md`.

Ce travail a été effectué localement à partir des assets existants. Aucune nouvelle génération Meshy ni dépense de crédits.

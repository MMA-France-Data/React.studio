# Troupes carmin — vagues 1 à 9

Ces GLB sont les **sources à importer dans Roblox Studio** pour le premier royaume du mode infini.

| Fichier | Ennemi existant | Usage |
| --- | --- | --- |
| `Normal.glb` | `Normal` / fantassin | Troupe courante |
| `Cavalry.glb` | `Fast` / cavalier | Rig au repos à importer en premier |
| `Cavalry_Gallop.glb` | `Fast` / cavalier | Animation de galop du même rig |
| `Cavalry_Death.glb` | `Fast` / cavalier | Animation de mort du même rig |
| `Tank.glb` | `Tank` / chevalier lourd | Troupe résistante |
| `Giant.glb` | `Giant` / chevalier colossal | Vagues 5, 15… ; variante de la même base, pas une génération Meshy supplémentaire |

Chaque modèle contient un mesh skinné et un squelette. `preview-ranks.png` montre les quatre silhouettes ; `preview-cavalry-studio.png` montre le cavalier réexporté. Le boss de la vague 10 est dans `../crimson-king/`.

`Cavalry.glb` remplace le précédent export qui se déformait après import dans Studio. Le propriétaire a confirmé que cette nouvelle version s'importe correctement dans Roblox Studio le 29/09/2026. Elle contient un seul mesh skinné, un seul matériau avec texture regroupée, une racine de squelette unique et aucune animation. L'armature et le mesh ont une échelle de 1. Le soldat, la selle et le tissu sont attachés à 100 % à l'os `Rider`, plus à l'os `Torso` retourné.

Importer d'abord `Cavalry.glb`, puis les clips séparés `Cavalry_Gallop.glb` et `Cavalry_Death.glb` sur ce même squelette. Chaque GLB de clip contient une seule animation, sans piste d'échelle. Les deux clips ont été réimportés et vérifiés dans Blender ; leur import **dans Roblox Studio reste à confirmer**. Un modèle déjà importé ne se met pas à jour automatiquement : réimporter ce fichier pour obtenir le correctif.

Ces modèles réutilisent les éléments CC0 de [KayKit Adventurers](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0) (Kay Lousberg). Le cheval animé provient du [Quaternius Ultimate Animated Animal Pack](https://quaternius.com/packs/ultimateanimatedanimals.html), lui aussi CC0. Les variantes d'armure et l'assemblage du cavalier ont été créés pour ce projet.

À l'import Roblox, vérifier le sens de marche, l'échelle, l'apparence des textures et la fluidité quand plusieurs parcelles sont visibles. Le code de gameplay, les statistiques et les valeurs des vagues restent indépendants de ces sources 3D.

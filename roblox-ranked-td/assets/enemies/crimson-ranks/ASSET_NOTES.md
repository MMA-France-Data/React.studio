# Troupes carmin — vagues 1 à 9

Ces GLB sont les **sources à importer dans Roblox Studio** pour le premier royaume du mode infini. Ils ne sont pas encore chargés par Rojo ni visibles dans le jeu.

| Fichier | Ennemi existant | Usage |
| --- | --- | --- |
| `Normal.glb` | `Normal` / fantassin | Troupe courante |
| `Cavalry.glb` | `Fast` / cavalier | Un cavalier sur un cheval animé |
| `Tank.glb` | `Tank` / chevalier lourd | Troupe résistante |
| `Giant.glb` | `Giant` / chevalier colossal | Vagues 5, 15… ; variante de la même base, pas une génération Meshy supplémentaire |

Chaque fichier contient un mesh skinné et un squelette. Les quatre exports ont été réimportés et la marche contrôlée dans Blender. `preview-ranks.png` montre les quatre silhouettes. Le boss de la vague 10 est dans `../crimson-king/`.

`Cavalry.glb` a été réexporté pour corriger le cavalier inversé dans Studio. L'armature et le mesh ont une échelle de 1. Le soldat, la selle et le tissu sont attachés à 100 % à l'os vertical `Rider` (enfant de `Back`), plus à l'os `Torso` retourné. Cet export ne contient que les animations `Gallop` et `Death`, sans piste d'échelle. Les poses de repos, galop et mort ont été réimportées et vérifiées dans Blender. Il faut réimporter ce GLB dans Roblox Studio : le modèle déjà importé ne se met pas à jour automatiquement.

Ces modèles réutilisent les éléments CC0 de [KayKit Adventurers](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0) (Kay Lousberg). Le cheval animé provient du [Quaternius Ultimate Animated Animal Pack](https://quaternius.com/packs/ultimateanimatedanimals.html), lui aussi CC0. Les variantes d'armure et l'assemblage du cavalier ont été créés pour ce projet.

À l'import Roblox, vérifier le sens de marche, l'échelle, l'apparence des textures et la fluidité quand plusieurs parcelles sont visibles. Le code de gameplay, les statistiques et les valeurs des vagues restent indépendants de ces sources 3D.

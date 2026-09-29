# Chef pillard de cuivre — vague 20

Sources 3D destinées à l'import dans Roblox Studio, **pas encore intégrées au jeu**. Le boss termine les vagues 11 à 20, puis revient à la vague 120, 220, etc.

| Fichier | Contenu |
| --- | --- |
| `ChefPillardCuivre_WalkingStudio.fbx` | **À utiliser** : modèle texturé, rig normalisé et marche. Validé dans Studio par le propriétaire du jeu. |
| `ChefPillardCuivre_DeathStudio.fbx` | **À utiliser** : même modèle et même rig, animation de mort. Validé dans Studio par le propriétaire du jeu. |
| `ChefPillardCuivre_Rig.glb` | Modèle texturé, squelette skinné de 24 os |
| `ChefPillardCuivre_Walking.glb` | Archive de l'export GLB : se déforme pendant l'animation dans Studio ; ne pas utiliser. |
| `ChefPillardCuivre_Death.glb` | Archive de l'export GLB : ne pas utiliser pour publier l'animation. |
| `preview.png` | Aperçu du modèle simplifié |

La version simplifiée comporte environ 12 462 triangles. Les deux FBX ont été exportés depuis le **même rig** à échelle 1 et leurs poses ont été vérifiées après réimport dans Blender. Pour publier la mort, utiliser le modèle importé depuis `ChefPillardCuivre_WalkingStudio.fbx` et charger l'animation du FBX de mort sur ce modèle, pas sur l'ancien `Boss_1_sans_animation.rbxm`.

Le projet Rojo ne charge pas directement les FBX/GLB de `assets/` ; aucun identifiant Roblox ni code de rendu n'est ajouté ici. L'intégration dans le jeu reste donc à faire après publication des animations Roblox. Les sources Meshy et les aperçus complets restent dans le dossier de livraison local.

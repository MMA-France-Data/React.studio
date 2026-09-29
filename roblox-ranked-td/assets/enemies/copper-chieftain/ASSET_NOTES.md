# Chef pillard de cuivre — vague 20

Sources 3D destinées à l'import dans Roblox Studio, **pas encore intégrées au jeu**. Le boss termine les vagues 11 à 20, puis revient à la vague 120, 220, etc.

| Fichier | Contenu |
| --- | --- |
| `ChefPillardCuivre_Rig.glb` | Modèle texturé, squelette skinné de 24 os |
| `ChefPillardCuivre_Walking.glb` | Même modèle et squelette avec animation de marche, sans pistes d'échelle |
| `ChefPillardCuivre_Death.glb` | Même modèle et squelette avec animation de mort, sans pistes d'échelle |
| `preview.png` | Aperçu du modèle simplifié |

La version simplifiée comporte environ 12 462 triangles. Vérifier l'import, l'orientation, l'échelle, les textures et les animations dans Studio avant de l'utiliser en jeu. Le projet Rojo ne charge pas directement les GLB de `assets/` ; aucun identifiant Roblox ni code de rendu n'est ajouté ici. Les sources Meshy et les aperçus complets restent dans le dossier de livraison local.

Les deux GLB animés ont été corrigés après un étirement constaté dans Studio : seules leurs 24 pistes d'animation d'échelle ont été retirées, sans rééchantillonner les translations ni les rotations. Le maillage, le squelette et les poses vérifiées dans Blender restent identiques aux originaux. Le comportement des nouveaux imports dans Studio doit encore être confirmé avant publication des animations Roblox.

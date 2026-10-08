# Nouvelle épée or — Golden Nature Cutlass

Remplacement visuel de **Gold**, troisième épée de MONDE. La lame est dorée et courbée,
avec une garde en branches, des feuilles et une gemme violette. Aucun changement de prix,
de dégâts, de sauvegarde, de progression, d'attaque ou d'aura dans cette livraison.

## Fichiers

- `A-IMPORTER/Sword_GoldV2.fbx` : fichier à importer, textures intégrées.
- `A-IMPORTER/Sword_GoldV2.fbm/` : les quatre textures externes de secours.
- `GoldV2/` : même FBX, textures, `info.json`, `apercu.png` et `comparaison.png`.
- `comparaison.png` : source à gauche, modèle allégé à droite, sans effets Roblox.
- `tools/swords/RangerLesEpees.lua` : plugin de rangement compatible avec les deux versions.

L'ancien `Gold/`, son fichier d'import et **SwordMeshes.rbxm restent inchangés**.
La nouvelle épée n'est donc pas encore utilisée par le jeu : l'import ci-dessous est nécessaire.

## Import par le créateur ou Claude dans Studio

1. Mettre à jour le plugin local depuis `tools/swords/RangerLesEpees.lua`.
2. Importer uniquement `A-IMPORTER/Sword_GoldV2.fbx` avec Import 3D.
   Conserver le nom **Sword_GoldV2** du modèle ou du MeshPart dans le Workspace.
3. Cliquer sur **Ranger les épées**. Pour Gold, le plugin préfère Sword_GoldV2 s'il existe
   et applique sa calibration propre. Le modèle rangé s'appelle toujours **Gold**.
   Sans Sword_GoldV2, l'ancien Sword_Gold garde sa calibration habituelle.
4. Vérifier la poignée en main, la pointe courbée, la traînée et le rendu des textures en Play,
   puis enregistrer le dossier complet `ReplicatedStorage/SwordMeshes` dans
   `assets/swords-roblox/SwordMeshes.rbxm` en conservant toutes les autres épées et les stands.

Pas de nouvelle ligne dans la boutique ni de changement dans `default.project.json` : le jeu
charge déjà le modèle nommé Gold et applique ses effets dorés existants.

## Préparation gratuite et vérifications

Source téléchargée par le créateur :
`Meshy_AI_Golden_Nature_Cutlass_1008094110_image-to-3d-texture_fbx.zip`.
Le FBX source contient **362 086 triangles**. Copie locale allégée : **18 950 triangles**,
une seule pièce visible, UV conservés, quatre textures PBR réduites à 1024 × 1024.
Longueur du fichier : 5,2 studs ; le jeu applique son agrandissement existant de 1,6.

Le milieu du manche est à l'origine. La garde extérieure n'a pas été prise pour une deuxième
poignée : les sections du vrai manche ont été mesurées entre 16 et 24 % de la longueur.
`TrailBase` et `TrailTip` tiennent compte de la courbure de la lame.

Préparation avec Blender en local, **aucun appel à l'API Meshy et aucun crédit dépensé par
cette préparation**. Le coût de génération initial, réalisée par le créateur, n'est pas connu.
Les archives d'origine restent dans les téléchargements. Aucun identifiant de tâche Meshy
n'a été fourni dans l'archive ; le nom et le SHA-256 du FBX source figurent dans `info.json`.

Contrôles effectués :

- réimport du FBX exporté dans Blender : triangles, UV, textures, orientation, centre du manche
  et proximité des points de traînée avec la lame ;
- contrat du vrai plugin avec objets simulés : priorité de la nouvelle version, compatibilité
  de l'ancienne, prise sur le manche, nom Gold conservé, source importée non modifiée ;
- syntaxe Luau, contrôles des attaques/auras existantes et construction des projets avec Rojo.

Commandes reproductibles depuis `roblox-monde` :

```powershell
./tools/swords/check.ps1
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python tools/swords/verify_additions.py
```

Le rendu dans Roblox Studio, l'import sur le compte Roblox et les tests sur téléphone ne sont
**pas** effectués ici. Les aperçus sont des rendus du véritable modèle, pas une capture du jeu.

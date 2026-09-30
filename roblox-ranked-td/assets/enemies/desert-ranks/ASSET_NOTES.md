# Gardes des dunes — palier 4, vagues 41 à 50

Sources pour Claude : cinq variantes humaines/cavalier, pas encore intégrées au jeu.

| Rôle | Nom Roblox cible | Premier FBX |
| --- | --- | --- |
| Écuyer | Swarm_4 | Swarm_4_Walking_Studio.fbx |
| Fantassin | Normal_4 | Normal_4_Walking_Studio.fbx |
| Cavalier | Fast_4 | Fast_4_Gallop_Studio.fbx |
| Chevalier lourd | Tank_4 | Tank_4_Walking_Studio.fbx |
| Colosse | Giant_4 | Giant_4_Walking_Studio.fbx |

Style : armures sable/or, tissus et bijoux turquoise, coiffes à pans latéraux, cheval couleur dune. Les boss restent visuellement distincts et séparés. Les couleurs et tailles de présentation ne changent aucun chiffre de gameplay.

Chaque modèle a un mesh et un matériau, une texture de 1024 px (humains) ou 2048 px (cavalier), et de 4675 à 7872 triangles. Les humains conservent les 41 os des bases KayKit et Idle, Walking_A, Running_A, Death_A. Le cheval conserve 48 os et Gallop/Death, Rider enfant de Back. Conserver noms, parents et matrices de repos pour les variantes futures.

Les `.blend` regroupent les textures et conservent les actions NLA ; GLB et PNG inclus. Les dix FBX sont échantillonnés à 30 images/s avec la marche/galop et la mort séparées. Les matrices de repos correspondent entre clips. Les fichiers validation.json et validation-fbx.json documentent les réimports Blender et le mouvement des membres ; les quatre pattes sont animées et les échelles sont fixes. L'aperçu de famille est un rendu des GLB réimportés, pas une capture Studio.

**Studio : en attente.** La confirmation des anciens galops carmin/cuivre ne valide pas automatiquement ce nouveau cavalier. Tester marche/galop et mort sur de nouveaux imports avant d'enregistrer les `.rbxm` et les identifiants d'animation. Rien n'est publié automatiquement, aucun fichier de gameplay, d'interface ou d'outil n'est changé.

Sources humaines KayKit Adventurers, CC0 : ../variant-source-kit/LICENSE-KayKit-CC0.txt. Cheval Quaternius hérité du cavalier carmin : ../crimson-ranks/ASSET_NOTES.md. Aucune requête Meshy, coût : 0 crédit.

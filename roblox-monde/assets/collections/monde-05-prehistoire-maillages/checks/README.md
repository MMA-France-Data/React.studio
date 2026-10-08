# Contrôles de la collection Préhistoire

Ces outils vérifient les fichiers livrés, sans ouvrir Studio ni modifier le jeu. Prérequis pour les contrôles de structure : PowerShell, Node.js et `luau-compile` accessibles dans le terminal.

Depuis le dossier `monde-05-prehistoire-maillages`, vérifier les six animaux et leurs œufs :

```powershell
foreach ($animalId in @('Velociraptor', 'Dilophosaurus', 'Pteranodon', 'Triceratops', 'Spinosaurus', 'Trex')) {
    & ./checks/check-native-mesh.ps1 -AssetDirectory "./$animalId"
    if ($LASTEXITCODE -ne 0) { throw "Échec de structure : $animalId" }
    node ./checks/check-raptor-egg.cjs "./$animalId"
    if ($LASTEXITCODE -ne 0) { throw "Échec de l'œuf : $animalId" }
}
```

Le nom historique `check-raptor-egg.cjs` est conservé ; l'outil prend en charge les six œufs. Les contrôles réécrivent les rapports de validation locaux correspondants.

Les scripts Python supplémentaires servent à réimporter les FBX dans Blender et à vérifier les contacts statiques ou animés. Les scripts `preview-*-poses.cjs` préparent les poses de prévisualisation. Consulter leurs paramètres en tête de fichier et les rapports `*-VALIDATION.json` dans chaque dossier animal.

Ces vérifications ne remplacent pas l'import final, la lecture des animations et les essais dans Roblox Studio ou sur téléphone. Les FBX sont des maillages rigides, à assembler avec leurs gabarits RBXMX et assembleurs ; aucun identifiant Roblox n'est inventé. Utiliser gain 1 pour ces clips. L'intégration aérienne du Pteranodon reste séparée.

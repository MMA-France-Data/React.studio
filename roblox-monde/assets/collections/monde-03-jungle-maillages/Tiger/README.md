# Tigre à facettes — livraison pour MONDE

La forme est un vrai maillage polygonal, avec faces planes inclinées, rayures et plots en relief. Les oreilles ont été abaissées et leurs pivots placés à la base, dans le crâne. Le modèle précédent et le jeu ne sont pas modifiés.

## Fichiers à utiliser dans le jeu

- `Tiger.fbx` : les **17 maillages rigides**, séparés par membre, texture embarquée. Pas de squelette Bone dans ce FBX.
- `Tiger-rig-template.rbxmx` : la structure `Tiger`, racine `RigRoot`, **17 Motor6D**, dossier `Animations` contenant `Idle`, `Walk`, `Attack` et `Bite` en `KeyframeSequence`.
- `Assembler-Tiger.luau` : assemblage à exécuter dans la Command Bar de Studio, en mode édition. Aucun lecteur d'animations du jeu à modifier.
- `Tiger_Colour_1024.png` : texture de secours si l'importeur ne reprend pas la texture embarquée.
- `TigerEgg.rbxmx` : œuf natif orange/noir/crème, sans nid ni scripts. Aucune rareté attribuée.

**Important : le `.rbxmx` est un gabarit d'articulations, pas un modèle visuel autonome.** Ses 17 pièces transparentes sont remplacées par les vrais MeshParts après l'import. Les identifiants des maillages et textures ne peuvent être attribués localement : ils proviennent de l'import dans votre compte/groupe Roblox. Ne pas remplacer le modèle du jeu par le gabarit seul.

## Import et assemblage

1. Dans une place de test, importer `Tiger.fbx`. Conserver tous les objets et leurs noms ; **Merge Meshes désactivé**, **No Rig**, unité **Studs**, axes **Front / Top**. Importer sous le propriétaire/groupe du jeu. [Réglages officiels de l'importeur Roblox](https://create.roblox.com/docs/studio/importer).
2. Insérer `Tiger-rig-template.rbxmx` dans la même place.
3. Sélectionner les deux modèles dans Explorer, puis exécuter le contenu de `Assembler-Tiger.luau` dans la Command Bar. Il crée un nouveau modèle `Tiger` ; les deux originaux sont conservés.
4. Vérifier les couleurs et les clips avec le lecteur existant, puis enregistrer le modèle assemblé en `.rbxm` avant de l'intégrer à `PetVisuals`. Aucun script importé ou animation distante n'est nécessaire.

Le modèle final contient **18 BaseParts** : 17 MeshParts et la racine invisible. **4 088 triangles**, une texture 1024 × 1024. `Idle` et `Walk` bouclent ; `Attack` et `Bite` sont à lecture unique et conservent le repère `Impact`. Les noms des membres et les clips sources sont conservés ; C0/C1 sont recalculés pour le centre des nouveaux maillages. Les membres droits sont des miroirs géométriques des membres gauches.

## Vérifications et limites

Les exports ont été réimportés dans Blender ; les maillages, UV et dimensions ont été contrôlés. La structure XML, les références, la syntaxe Luau et 5 508 cas de pose ont été vérifiés. `NATIVE-VALIDATION.json`, `FBX-VALIDATION.json` et `CONTACT-VALIDATION.json` donnent les résultats.

**L'import et l'exécution dans Roblox Studio n'ont pas été testés.** La compatibilité du contrat d'animations est vérifiée localement, pas la validation finale des assets par Roblox. Aucun fichier du lecteur ou de la configuration du jeu n'a été changé. Aucun crédit Meshy consommé.

`Tiger-facettes.blend` est la source éditable avec un squelette de prévisualisation Blender. Ce squelette sert uniquement à l'édition/rendu : pour le jeu, utiliser exclusivement **Tiger.fbx** et le gabarit ci-dessus.

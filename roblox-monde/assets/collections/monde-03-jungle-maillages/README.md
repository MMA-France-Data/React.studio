# Monde 3 — jungle, animaux en maillage

- **Tiger** : boss orange à rayures, 17 maillages et `RigRoot`, 17 `Motor6D`, clips `Idle`, `Walk`, `Attack`, `Bite`. Oreilles raccordées au crâne, yeux noirs symétriques.
- **Gorilla** : 16 maillages et `RigRoot`, 16 `Motor6D`, clips `Idle`, `Walk`, `Attack`. Corps massif, longs bras, mains à doigts et dos argenté.
- **TigerEgg** et **GorillaEgg** : œufs natifs sans nid ni scripts, thème de leur animal. Aucune rareté attribuée et aucun œuf existant remplacé.

![Rendus des modèles et œufs](Apercu-jungle.png)

## Import et assemblage

Dans le sous-dossier de l'animal, importer `Tiger.fbx` ou `Gorilla.fbx` avec **Merge Meshes désactivé**, **No Rig**, unité **Studs**, axes **Front / Top**, sous le propriétaire/groupe du jeu. [Documentation de l'importeur](https://create.roblox.com/docs/studio/importer).

Insérer le `*-rig-template.rbxmx` correspondant, sélectionner le modèle FBX et le gabarit, puis exécuter `Assembler-Tiger.luau` ou `Assembler-Gorilla.luau` dans la Command Bar de Studio en édition. Le résultat garde les noms, `RigRoot`, les articulations et `KeyframeSequence` attendus par le lecteur actuel. Aucun changement de lecteur nécessaire.

**Le gabarit transparent n'est pas un modèle visuel autonome.** Importer le FBX pour obtenir les identifiants Roblox des MeshParts/textures, puis assembler. Contrôler les animations et enregistrer le modèle final avant de remplacer l'ancien. Les deux originaux sélectionnés sont conservés.

Les œufs `.rbxmx` s'insèrent directement. Les FBX des animaux n'ont pas de Bones ; leur animation est assurée par la structure Motor6D et les clips locaux livrés.

Les nombres précis de triangles, pièces et articulations figurent dans les manifestes et rapports de contrôle de chaque animal. Vérifications locales de géométrie, réimport FBX, XML, syntaxe et poses réalisées ; **import/exécution dans Studio et mobile non testés**. Le jeu actif et ses anciens assets ne sont pas modifiés.

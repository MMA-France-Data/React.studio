# Les 7 épées, prêtes à importer dans Roblox Studio

**Ajout du 8 octobre :** deux modèles supplémentaires, `Sword_Fusion.fbx` et `Sword_Void.fbx`, sont prêts dans
`A-IMPORTER`. Le créateur les a depuis importés dans `SwordMeshes.rbxm` (commit `0d38f6a`). Les doubles frappes
traversent maintenant le corps vers le côté opposé, et les auras sont renforcées : brume violet sombre continue,
feu et glace plus visibles. Le rendu en Play reste à valider. Voir [les instructions et vérifications](AJOUTS-FUSION-VOID.md).

Copies **allégées** des sources de `../swords-meshy` (qui ne sont pas modifiées), faites par
`tools/swords/optimise.py` avec Blender :

- au plus 14 000 triangles par épée (Roblox en accepte 20 000) ; l'or et la glace étaient déjà sous la limite ;
- mêmes UV : les textures d'origine s'appliquent telles quelles ; elles sont réduites à 1024 et rangées dans le FBX ;
- toutes dans le même repère : lame le long de -Z, largeur sur Y, épaisseur sur X, longueur totale 5,2 studs,
  milieu de la poignée à l'origine.

`apercu.png` montre les sept épées allégées avec leur texture de couleur. `RAPPORT.json` et les `info.json` donnent,
pour chacune, le nombre de triangles et la place du bas et de la pointe de la lame (pour la traînée).

## Ce qui reste à faire, à la main, dans Studio

Importer un modèle l'envoie sur le compte Roblox du créateur : c'est à lui de le faire.

Les sept fichiers à importer sont tous dans le même dossier : **`A-IMPORTER`** (les textures sont dedans).

1. Ouvrir le jeu dans Studio, puis **Accueil → Importer** (« Import 3D »), et importer les sept fichiers de
   `A-IMPORTER` (on peut les choisir tous d'un coup). Ils arrivent dans le Workspace : `Sword_Iron`, `Sword_Steel`…
2. Onglet **Plugins** → bouton **« Ranger les épées »** (plugin `tools/swords/RangerLesEpees.lua`, installé dans
   Studio). Il retrouve chaque épée par son nom, la met à la bonne taille, lui ajoute sa prise et les points de la
   traînée, et range le tout dans `ReplicatedStorage > SwordMeshes` (Iron, Steel, Gold, Frost, Flame, Storm,
   Prismatic). Les épées rangées apparaissent côte à côte, dans l'ordre.
3. Le dossier `SwordMeshes` est sélectionné : clic droit → **Enregistrer dans un fichier…**, ici, sous le nom
   **`SwordMeshes.rbxm`**.

Ensuite Claude branche `SwordMeshes.rbxm` dans le projet (une ligne dans `default.project.json`).

# Les 7 épées, prêtes à importer dans Roblox Studio

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

1. Ouvrir le jeu dans Studio, puis **Accueil → Importer** (« Import 3D »).
2. Choisir `Iron/Sword_Iron.fbx`, laisser les réglages, cliquer **Importer**. Recommencer pour les six autres.
3. Les sept modèles sont dans le Workspace (`Sword_Iron`, `Sword_Steel`, …). Les sélectionner tous les sept, clic droit
   → **Enregistrer dans un fichier…**, et enregistrer ici sous le nom **`Epees.rbxm`**.

Ensuite Claude branche `Epees.rbxm` dans le jeu (prise dans la main, traînée, une épée par niveau).

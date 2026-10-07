# MONDE — le jeu en monde ouvert

Deuxième jeu, à côté de `roblox-survive` (qui n'est pas modifié). Il reprend ses animaux, ses œufs et son enclos.

## Le jeu

- **La base** : chaque joueur a son enclos. On y pose ses œufs, on y vend ses familiers, et la **forge** améliore l'épée.
- **Les zones**, à la suite derrière la grande porte : 1 la ferme, 2 la forêt, 3 la jungle. Chaque zone a cinq camps
  (un animal par camp, du plus faible au plus fort), quatre coffres, et un boss au bout du chemin.
- **Le combat** : un clic (ou le bouton ⚔, ou AUTO) donne un coup d'épée. Un monstre n'attaque jamais le premier.
  Celui qu'on frappe se défend : il tape d'abord les familiers de l'équipe, et le joueur en dernier.
- **L'équipe** : 3 familiers suivent le joueur et se battent. Ils gagnent de l'XP et des niveaux.
- **Ce qu'on gagne** : des pièces, de l'XP, et des œufs des animaux de la zone. Battre le boss ouvre la zone suivante.

Tous les chiffres sont dans `src/shared/Config.luau`.

## Pour ChatGPT : les animations de combat

Les sept **vrais modèles d'épées Meshy retenus** (FBX + textures) sont dans [`assets/swords-meshy`](assets/swords-meshy/README.md). Les animations et mini-auras v3 sont déjà branchées dans `src/client` ; les nouveaux meshes restent à importer et calibrer dans Studio. Ne pas confondre ces fichiers avec les anciens modèles de secours en Parts ni les lames témoins de la galerie.

Les animaux sont ceux de `roblox-survive/assets/collections` (ce projet lit ces fichiers, il n'en a pas de copie).
Le jeu joue déjà les séquences `Idle` et `Walk` de chaque modèle avec `StarterAnimator`.

Pour ajouter une attaque à un animal : mettre dans le même modèle une troisième `KeyframeSequence` nommée
**`Attack`**, au même format que `Walk` et `Idle` (mêmes noms de poses, dans le dossier où sont déjà les deux
autres). Rien d'autre à changer : dès qu'un modèle a un clip `Attack`, le jeu le joue quand l'animal frappe (monstre
ou familier). Sans ce clip, l'animal fait un petit bond en avant.

- Un clip court, en boucle : environ 0,4 à 0,8 seconde.
- Ne pas renommer les modèles ni les pièces : les sauvegardes des joueurs gardent le nom de l'animal.

## Fabriquer et tester

```bash
rojo build default.project.json -o A-PUBLIER/Monde-v1.rbxl
```

```bash
powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test world -Seconds 150
```

Le test joue une partie dans Studio (combat, équipe, coffre, forge, boss, porte, voyage) et prend des photos dans
`tools/studio-test/out/`.

# Icônes d’épées — MONDE

13 icônes créées à partir des modèles 3D existants, avec un vrai fond transparent.

- `PNG-512/` : fichiers pour les menus, 512 × 512 pixels.
- `PNG-1024/` : versions haute définition, 1024 × 1024 pixels.
- `Apercu-13-icones.png` : toute la collection sur fond bleu.
- `Apercu-menu.png` : maquette du menu « Mon épée », pas une capture du jeu.
- `MONDE-13-icones-epees.zip` : pack complet prêt à télécharger.
- `correspondance-modeles.json` : noms des modèles et images correspondantes.
- `prompts.json` : consignes de génération et références aux modèles du dépôt.
- `verification.json` : contrôle des tailles et de la transparence des originaux.

## Correspondance importante

`Gold.png` représente **GoldV2**, la nouvelle épée or à garde en bois et feuilles.
`Void.png` représente **les deux lames violettes croisées**.
Les fichiers gardent les identifiants utilisés pour les modèles : Iron, Steel,
Gold, Frost, Flame, Storm, Fusion, Void, Prismatic, TigerClaw, HyenaFang,
TrexJaw et Meteorite. La présence d’une image ne change pas la progression du magasin.

## Import dans Roblox

Importer les PNG dans Roblox, puis renseigner leurs identifiants d’image dans
la correspondance : ils sont volontairement vides ici, aucun identifiant n’est inventé.
Utiliser ensuite les images dans des `ImageLabel`, avec `ScaleType = Fit` et
`BackgroundTransparency = 1`, à la place des petits aperçus 3D du menu.
La transparence des PNG permet de garder le fond bleu des cartes existantes.

Cette livraison contient uniquement les images et leur documentation.
Elle ne modifie ni les scripts du jeu, ni les modèles 3D, ni les dégâts,
prix, animations ou effets. Les images ne sont pas encore importées dans Roblox.

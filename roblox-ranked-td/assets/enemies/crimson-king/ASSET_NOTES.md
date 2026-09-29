# Roi carmin — vague 10

`RoiCarmin_Studio.glb` est le modèle allégé fourni par le propriétaire du jeu, préparé à partir de ses exports Meshy. Il contient un mesh skinné de 10 360 triangles, un squelette de 23 os, une texture intégrée et deux animations : `Walking` et `Dead`. Sa texture a été réencodée dans le GLB pour réduire la taille du fichier à environ 3,3 Mo ; l'original Meshy du propriétaire n'a pas été modifié.

`preview-walking.png` montre le modèle réellement chargé et animé dans Blender. Le test de réimport a confirmé les deux animations et le mouvement des sommets.

Ce fichier est une **source pour l'importateur Roblox Studio**. Le projet Rojo n'importe pas directement les GLB depuis `assets/` ; il faut encore importer le modèle, obtenir les identifiants des assets Roblox, puis le brancher au rendu client du mode infini. L'appel `decorateEnemy(root, def, palier)` doit être conservé. Le roi carmin correspond au palier 0, vague 10, puis 110, 210, etc. La mort ne nécessite pas d'animation d'attaque : les ennemis atteignent la zone ou meurent sous les tirs des tours.

Provenance : modèle généré par le propriétaire avec Meshy à partir d'un concept créé pour ce projet. Vérifier la licence du compte Meshy utilisé avant une publication publique ; le forfait gratuit peut imposer une attribution.

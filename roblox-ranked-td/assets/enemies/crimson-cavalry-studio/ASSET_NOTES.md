# Cavalier carmin corrigé — vagues 1 à 10

Le propriétaire a confirmé « parfait ça marche » après le nouvel import de `Fast_0_Gallop_Studio.fbx` le 30 septembre 2026. Cette validation concerne le galop carmin dans Studio. La mort reste à tester.

`Fast_0_Gallop_Studio.fbx` : cavalier et galop, 30 images/s. `Fast_0_Death_Studio.fbx` : même modèle et même squelette avec sa mort. `Fast_0_StudioRig.glb` : modèle statique avec rig et texture. `Fast_0.blend` : source éditable du galop ; utiliser le FBX séparé pour la mort, qui n'est pas conservée comme action dans cette source Blender.

48 os, une racine, échelles uniformes, soldat et selle liés à Rider, fils de Back. Root et Body ont une très faible influence de skinning pour conserver les os structuraux à l'import. Quatre pattes animées après réimportation dans Blender, rapports inclus. `apercu-galop.gif` est un rendu Blender, pas une capture Studio.

Les anciens modèles de `../crimson-ranks/` ne sont ni remplacés ni supprimés. Aucun `.rbxm`, identifiant d'animation ou code de gameplay n'est modifié. Source et licences héritées de la base carmin déjà documentée. Aucune dépense Meshy.

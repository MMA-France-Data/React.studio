# Dilophosaure — deuxième animal de la Préhistoire

Modèle original bleu pétrole, petites taches foncées, deux crêtes rouges intégrées au crâne et collerette orange en deux éventails articulés. La collerette est stylisée selon la proposition du jeu ; elle est repliée au repos et s'ouvre pendant l'attaque.

## Fichiers

- `Dilophosaurus-Import3D-Motor6D.fbx` : 18 maillages rigides, 4 100 triangles, texture et UV inclus.
- `Dilophosaurus-rig-template.rbxmx` : RigRoot et 18 Motor6D ; 19 pièces après assemblage. Dossier Animations avec Idle, Walk, Attack et Bite en KeyframeSequence.
- `Assembler-Dilophosaurus.luau` : assemble le FBX importé et le gabarit dans un nouveau modèle. Ne supprime pas les originaux.
- `Dilophosaurus_Colour_512.png` : atlas couleur de secours si l'importeur ne récupère pas la texture intégrée.
- `DilophosaurusEgg.rbxmx` : œuf assorti, sans nid, à insérer directement dans Studio. 101 pièces statiques, racine invisible comprise. Aucun script incorporé.
- `DilophosaurusEgg.fbx` : version optionnelle ; préférer le RBXMX pour les couleurs exactes de l'œuf.
- `.blend` : sources locales modifiables. PNG et GIF : rendus des vrais maillages, pas concepts générés à la place des modèles.

## Import Studio

1. Importer le FBX avec Import 3D, **Merge Meshes désactivé**. Garder les 18 maillages séparés ; ne pas convertir ce modèle en rig à Bones.
2. Insérer `Dilophosaurus-rig-template.rbxmx`, transparent avant l'assemblage.
3. En mode édition, sélectionner le modèle FBX importé et le gabarit. Exécuter le contenu de `Assembler-Dilophosaurus.luau` dans la barre de commandes.
4. Le nouveau modèle `Dilophosaurus` contient les vrais maillages, RigRoot, Motor6D et Animations. Les originaux restent présents.
5. Insérer séparément `DilophosaurusEgg.rbxmx` pour l'œuf.

Le FBX seul ne contient pas les Motor6D ou les KeyframeSequence : le gabarit et l'assembleur sont nécessaires.

## Anatomie et lecture des animations

Le poids est porté uniquement par les deux pattes arrière. Les membres antérieurs sont de petits bras non porteurs. Les chevilles compensent les mouvements des genoux, et la queue équilibre le corps. FrillL et FrillR sont attachés à Head et s'ouvrent en miroir.

Le lecteur générique StarterAnimator reconnaît les pistes et les noms de membres sans remplacement. Pour la future intégration, jouer Walk avec **gain 1** et vitesse de référence 1 : la marche bipède a déjà son amplitude. Le gain global 2.6 prévu pour les anciens quadrupèdes détruirait les appuis. La collerette de l'attaque doit également être lue avec gain 1.

Cette livraison ne change aucun script de jeu, manifeste, équilibrage ou animal actif. L'intégration dans le jeu et l'import final dans Studio restent à faire.

## Vérifications

Les rapports JSON joints distinguent les contrôles locaux de la validation dans Studio : réimportation FBX, compte réel des triangles, UV et dimensions, contacts et symétrie au repos, structure du gabarit, syntaxe de l'assembleur, transformations des quatre clips, appuis bipèdes et collerette en mouvement. Tous les aperçus animés utilisent les transformations des clips livrés.

Les GIF répètent l'animation pour l'aperçu seulement ; les clips Attack et Bite livrés ne bouclent pas et possèdent chacun un seul repère Impact.

`Frill.gif` montre la même attaque de face pour mieux voir l'ouverture et le repli. `Attack.gif` la montre de profil. Le contrôle des raccords en mouvement comporte 108 vérifications, sur les 36 images de marche, d'attaque et de morsure.

Fabrication locale gratuite, sans API Meshy et sans consommation de crédits. Sources livrées sur la branche claude/exciting-gauss-ggwcwm.

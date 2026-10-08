# Préhistoire — six animaux et six œufs

La collection complète et les six œufs assortis sont livrés, sans nid. Le jeu n'est pas modifié. Les décors de salle (volcan, marais et fougères) ne font pas partie de ce lot d'animaux.

| Ordre | Dossier / nom du modèle | Pièces avec RigRoot | Triangles | Mouvement |
| --- | --- | ---: | ---: | --- |
| 1 | Velociraptor | 17 | 4 712 | Bipède, bond griffé et morsure |
| 2 | Dilophosaurus | 19 | 4 100 | Bipède, collerette articulée |
| 3 | Pteranodon | 18 | 4 560 | Vol, piqué et coup de bec |
| 4 | Triceratops | 19 | 4 698 | Quadrupède, charge aux trois cornes |
| 5 | Spinosaurus | 18 | 4 698 | Bipède, voile dorsale et morsure |
| Boss | Trex | 17 | 4 686 | Bipède massif, robe arc-en-ciel — forme v2 |

Le boss s'appelle `Trex` dans les fichiers et le gabarit, T-rex à l'affichage. Aucun identifiant du jeu n'est modifié. Les budgets du tableau concernent les animaux, pas les œufs statiques.

Chaque dossier contient son FBX, son gabarit RigRoot/Motor6D et son assembleur. Le FBX seul n'a pas de Motor6D ni de KeyframeSequence : utiliser aussi le gabarit RBXMX et l'assembleur. Garder **Merge Meshes désactivé** à l'import, puis sélectionner les deux modèles source en mode édition et exécuter l'assembleur correspondant. Les originaux restent intacts.

Lire tous les clips avec **gain 1** et vitesse de référence 1. Le gain global 2.6 des anciens animaux casserait les appuis et exagérerait les ailes. Les clips gardent les noms Idle, Walk, Attack et Bite. Pour le Ptéranodon, **Walk est le cycle de vol**, sous ce nom pour le lecteur générique. Le placement en hauteur, la trajectoire aérienne et les collisions d'un ennemi volant restent à intégrer séparément.

Les quatre derniers modèles ont aussi un contrôle des contacts parent/enfant sur 36 poses animées et un contrôle de locomotion sur 121 instants. Les œufs sont des assemblages statiques de pièces soudées : tous leurs volumes forment un seul ensemble connecté, sans script incorporé. Les rapports distinguent les vérifications locales de l'import Studio encore à faire.

Les instructions détaillées ci-dessous prennent le Vélociraptor comme exemple. Chaque modèle a aussi son propre guide. Les sources .blend sont conservées et incluses dans le pack complet ; les PNG et GIF montrent les vrais maillages, pas des concepts à leur place.

## Modèle et animations

- `Velociraptor-Import3D-Motor6D.fbx` : 16 maillages rigides, 4 712 triangles, UV et atlas couleur inclus.
- `Velociraptor-rig-template.rbxmx` : RigRoot + 16 articulations Motor6D ; 17 pièces une fois assemblé.
- `Assembler-Velociraptor.luau` : assemble le FBX importé avec le gabarit, sans supprimer les originaux.
- `Velociraptor_Colour_512.png` : atlas de texture si l'importeur ne récupère pas la texture intégrée.
- Dossier `Animations` du gabarit : Idle, Walk, Attack, Bite, tous en KeyframeSequence.
- `VelociraptorEgg.rbxmx` : œuf vert à griffures, sans nid, prêt à insérer dans Studio ; modèle statique de 81 pièces avec racine invisible. Aucun script incorporé.
- Les `.blend` sont les sources locales. L'œuf dispose aussi d'un FBX optionnel, mais son RBXMX est le format conseillé pour préserver exactement ses couleurs.

## Import dans Roblox Studio

1. Importer le FBX de l'animal avec **Import 3D**, sans fusionner les maillages (*Merge Meshes désactivé*). Ce FBX ne contient pas de rig à Bones : les Motor6D sont dans le gabarit Roblox.
2. Insérer le fichier `Velociraptor-rig-template.rbxmx`. Il est transparent avant assemblage : c'est normal.
3. Sélectionner le modèle FBX importé et le gabarit, en mode édition. Exécuter le contenu de `Assembler-Velociraptor.luau` dans la barre de commandes.
4. Le nouveau modèle `Velociraptor` contient les vrais maillages, les Motor6D et les animations. Les deux modèles source restent intacts.
5. Insérer séparément `VelociraptorEgg.rbxmx` pour l'œuf.

La racine, les Motor6D et les pistes par nom de membre respectent le lecteur `StarterAnimator` existant. Ne pas convertir les bras en pattes avant ni ajouter un cycle de quadrupède.

### Important pour l'intégration future

La marche bipède a déjà une vraie amplitude et une compensation des chevilles. La tester avec **gain = 1** (vitesse de lecture de référence = 1) ; le multiplicateur global actuel de `Animals.luau`, `MESH_WALK_GAIN = 2.6`, casserait les appuis de ce nouveau clip. L'intégrateur devra utiliser le gain 1 pour cet animal, plutôt qu'amplifier la marche de quadrupède. Le lecteur lui-même n'a pas besoin d'être remplacé. Aucun fichier de jeu ou de configuration n'est modifié dans cette livraison.

## Contrôles réellement effectués

- Réimportation du FBX : 16 maillages, 4 712 triangles, UV, matériaux et dimensions vérifiés.
- Contacts de tous les membres avec leur parent et symétrie gauche/droite vérifiés sur le FBX.
- Structure RBXMX, références, Motor6D, quatre KeyframeSequence et syntaxe de l'assembleur vérifiés.
- 5 184 cas de transformation des membres, sur les quatre animations.
- Marche bipède testée sur 121 instants : pieds arrière alternés, chevilles horizontales, bras à plus de 0,74 unité au-dessus du sol. Les bras ne portent jamais l'animal.
- Attack et Bite contiennent chacun un seul repère Impact et ne bouclent pas.

Les aperçus animés sont rendus à partir des vrais maillages avec les transformations des clips livrés. **L'import final et le rendu dans Roblox Studio restent à vérifier.** Aucun crédit Meshy consommé. Sources de ce lot livrées sur la branche claude/exciting-gauss-ggwcwm.

Voir `CONTRAT-ANIMATIONS-PREHISTOIRE.md` pour la consigne commune aux quatre dinosaures bipèdes.

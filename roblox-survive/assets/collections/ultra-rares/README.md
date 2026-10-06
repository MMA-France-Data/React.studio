# SURVIVE! — six super animaux ultra-rares, 0,5 %

Pack validé visuellement par le joueur pour l'envoi GitHub le 6 octobre 2026.
Chemin : `roblox-survive/assets/collections/ultra-rares/` sur la branche
`claude/exciting-gauss-ggwcwm`. Les six animaux
à 0,5 % utilisent la palette arc-en-ciel saturée des œufs rares V3, avec des
détails de visage lisibles et un contour violet natif. Aucune modification du
jeu, de ses chances, de ses revenus, de ses sauvegardes ou des œufs.

| Salle de collection | Animal | Fichier |
| --- | --- | --- |
| 1 | Renard | `models/Fox.rbxmx` |
| 2 | Blaireau | `models/Badger.rbxmx` |
| 3 | Cheval | `models/Horse.rbxmx` |
| 4 | Ours brun | `models/Bear.rbxmx` |
| 5 | Jaguar | `models/Jaguar.rbxmx` |
| 6 | Varan géant | `models/MonitorLizard.rbxmx` |

## Pour Claude : fichiers à utiliser

Pour l'apparence des animaux à 0,5 %, prendre les six fichiers de **ce dossier**,
pas les versions aux couleurs naturelles conservées dans `salle-01` à `salle-05`.
Les originaux ne sont pas écrasés. Ce sont des remplacements visuels des mêmes
animaux, pas six nouvelles entrées d'inventaire ou de nouveaux tirages.
Le varan est le seul modèle de salle 6 publié par cet envoi ; les cinq autres
animaux et les œufs de cette salle restent dans les packs locaux séparés.

L'envoi ne modifie ni `src/`, ni `default.project.json`, ni les sauvegardes.
L'intégration de ces nouveaux chemins et leurs tests dans le jeu restent à faire
séparément. Ne pas recopier les paramètres de Lighting de la galerie dans le jeu.

Voir [l'aperçu des six animaux](Apercu-6-super-animaux.png) et
[la marche du varan](Varan-animations.gif). Les modèles et la galerie sont livrés
directement, sans le ZIP en doublon.

## Apparence

Palette exacte des œufs approuvés : magenta `#ff1599`, violet `#951cff`, bleu
`#184eff`, cyan `#00c9f5`, vert `#36ee28`, jaune `#ffe414`, orange `#ff9414`,
rose `#ff287d`. Chaque animal garde sa silhouette ; les yeux, nez, crinière,
rayures du blaireau et rosettes du jaguar restent reconnaissables. Les dents
et griffes sont claires. Huit petites bandes de peau colorées sont soudées au
corps, dont quatre en Neon. Highlight violet `#c12dff`, sans traverser les murs.

Le varan seul est remodelé : 5,8 studs de long contre 3,8, 2,52 de large contre
1,61 et 1,51 de haut contre 0,84. Épaules épaisses, tête plus large, regard
menaçant, mâchoire ouverte, dents et griffes, toujours un varan sans cornes/ailes.
Les cinq autres ultra-rares conservent exactement leurs pièces originales,
articulations, dimensions et animations ; seules les couleurs/effets et les
bandes visuelles sont ajoutés. Les 30 autres animaux des salles 1 à 6 sont
strictement identiques aux versions validées. Les originaux restent conservés.

## Utilisation

Modèles originaux en Parts Roblox, Motor6D, Welds et séquences locales `Idle`
et `Walk`. Aucun MeshPart, script embarqué, texture distante ou modèle de
bibliothèque. Pas de génération payante, aucun crédit Meshy.

Insérer les `.rbxmx` depuis un fichier. `Galerie-6-ultra-rares.rbxl` est une
place indépendante pour tester la marche/repos, les couleurs et le contour.
Ne pas l'ouvrir en écrasant une place contenant du travail non sauvegardé.
Le lecteur `StarterAnimator.luau` reste celui des salles précédentes :
`bind(model)`, puis `step(rig, time, "Idle"/"Walk")` après `PivotTo`.

Ces fichiers gardent les identifiants d'asset existants. Vérifier les clés
persistantes utilisées dans le jeu avant de remplacer des assets ; ne pas
renommer inventaires/sauvegardes pour suivre les noms des fichiers.
Le rang 0,5 % est une référence, pas une modification des tirages.

## Vérifications

Rendus issus des véritables pièces, pas d'images conceptuelles. Le contour
écran du Highlight Roblox n'apparaît pas dans Blender : il est dans les modèles
et reste à examiner dans Studio. Le BloomEffect de cette galerie ne touche pas
le Lighting du jeu.

`MANIFEST.json` contient les empreintes. `UNCHANGED_CHECK.json` atteste les
trente animaux inchangés et les cinq rigs/animations rares conservés.
`VALIDATION.json` contient les contrôles hors ligne : matrices, références,
XML, géométrie, clips, syntaxe Luau et construction Rojo.
**Exécution réelle dans Studio, intégration et fluidité sur téléphone à vérifier.**

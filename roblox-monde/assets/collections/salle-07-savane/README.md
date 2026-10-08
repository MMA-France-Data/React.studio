# MONDE — Savane, salle 7

Collection originale créée le 8 octobre 2026, livrée pour la branche `claude/exciting-gauss-ggwcwm`, séparée du jeu actuel. Aucun crédit Meshy utilisé, aucun asset de bibliothèque, aucune modification des sauvegardes ou du système de combat. Le pack n'est pas encore intégré dans le jeu.

**Chemin à utiliser pour Claude : `roblox-monde/assets/collections/salle-07-savane/`.** Les animaux sont dans `animaux/models/`, les œufs dans `oeufs/models/`. Ne pas chercher cette nouvelle collection dans `roblox-survive`.

## Les six animaux et leurs œufs

| Ordre | Animal | Probabilité de référence | Attaque fournie |
| --- | --- | --- | --- |
| 1 | Hyène | 45 % | Morsure en bondissant |
| 2 | Buffle | 30 % | Charge et coup de cornes |
| 3 | Guépard | 14 % | Bond |
| 4 | Rhinocéros | 7 % | Charge lourde |
| 5 | Éléphant | 3,5 % | Balayage de trompe |
| 6 | Lion royal | 0,5 % | Grand coup de patte |

Ces pourcentages sont une référence pour la future intégration, pas une modification des tirages en jeu. Le lion et son œuf reprennent l'arc-en-ciel saturé et le contour violet des ultra-rares approuvés. Les six œufs ont une coque en paliers, sans nid.

## Pour regarder

- `Apercu-animaux.png` : les six modèles dans l'ordre.
- `Apercu-oeufs.png` : les six œufs avec leurs pourcentages.
- `Apercu-attaques.gif` : mouvements rendus à partir des articulations et poses livrées.
- `animaux/Galerie-6-animaux.rbxl` : ouvrir dans Roblox Studio puis lancer **Play**. Les boutons permettent de tester les attaques, les morsures, le repos et la marche. Le bouton Mordre ne concerne que la hyène, le guépard et le lion.
- `oeufs/Galerie-6-oeufs.rbxl` : ouvrir puis lancer **Play** pour voir les œufs, notamment le contour violet réel du lion.

Les aperçus PNG/GIF sont des rendus locaux des mêmes pièces et couleurs, pas des captures de Roblox. Ils ne simulent pas le contour `Highlight` violet ; celui-ci est bien présent dans les deux fichiers du lion.

## Fichiers utilisables

Les douze `.rbxmx` individuels sont dans `animaux/models/` et `oeufs/models/`. Les fichiers groupés et les deux scènes Blender sont également fournis. Aucun modèle ne contient de script, de téléchargement ou d'identifiant d'animation externe.

Les animaux sont des rigs en **Parts + Motor6D**, pas des meshes FBX skinnés. Ils comportent 14 à 18 articulations chacun, avec quatre pattes à deux articulations. La trompe de l'éléphant, les oreilles et les queues sont articulées. Budget : 66 à 96 Parts par animal et 80 à 124 par œuf, racine invisible incluse.

Chaque animal contient `Animations/Idle`, `Walk` et `Attack`. La hyène, le guépard et le lion ont aussi `Bite`. Les attaques ne bouclent pas, possèdent un seul keyframe nommé `Impact` et reviennent à la pose de départ.

### Intégration ultérieure par Claude

Copier les modèles choisis et les trois modules `AttackTimeline`, `CombatAnimator`, `ActionAnimator` dans le projet cible. Ces rigs visuels sont ancrés : utiliser le lecteur fourni, qui applique les articulations et les soudures aux pièces. Ne pas lancer simplement un Animator physique sur le modèle ancré.

Après placement du modèle, appeler `ActionAnimator.bind(model)`. À chaque mise à jour, placer la racine à la position voulue, puis appeler `ActionAnimator.step(rig, temps, "Idle" ou "Walk")`. `playAttack(rig, temps, "Attack" ou "Bite")` lance une action si aucune n'est encore active. Le premier résultat de `step` signale l'impact une seule fois.

Le signal d'impact est **visuel uniquement** : il ne calcule aucun dégât. Le jeu doit garder son autorité serveur, sa cadence et ses propres décisions de combat. Ne pas brancher les dégâts directement sur un événement client. La galerie illustre le signal en faisant clignoter une cible.

Les œufs sont des modèles visuels statiques à racine `EggRoot`, sans collision, contact ni requête. Les animaux ont une racine `RigRoot`. Ne pas renommer les membres du rig sans adapter les poses.

## Vérifications effectuées

- Douze fichiers XML valides, références internes reliées, budgets et empreintes SHA-256 vérifiés.
- Géométrie, poses finies, rotations valides, liaison au repos et quatre pattes animées vérifiées.
- 2 121 poses interpolées contrôlées avec la protection contre le passage sous le sol.
- Boucles repos/marche continues ; retour au repos et un seul impact par attaque/morsure.
- Syntaxe des cinq fichiers Luau et construction des deux galeries Roblox vérifiées.
- Rendus locaux inspectés ; archive contrôlée.

**À faire : test Play dans Roblox Studio et validation sur téléphone dans le vrai jeu.** Les rendus et contrôles hors ligne ne remplacent pas ce test. Le jeu actuel et les autres salles sont inchangés.

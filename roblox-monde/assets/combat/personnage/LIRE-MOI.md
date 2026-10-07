# MONDE — exactement deux coups circulaires (version 2)

7 octobre 2026. Remplace la proposition de combat personnage v1. La v1 reste conservée séparément.

## Ce que cette version change

1. **Gauche → droite**, puis **droite → gauche**, par rapport aux côtés du personnage.
2. Pas de frappe verticale ni de troisième variation. La poignée et la lame balaient un arc horizontal devant le buste ; le bassin et le haut du corps accompagnent le mouvement.
3. Un pied devant l'autre, avec genoux et chevilles articulés.
4. Alternance mémorisée par personnage à chaque nouveau PunchAt, pas calculée à partir des millisecondes du timestamp. Un timestamp légèrement futur attend avant d'être consommé.
5. Le croissant lumineux balaie dans le même sens que la lame. Les six formes d'épée, les étincelles et l'impact confirmé sont conservés.

Durée : 0,38 seconde par coup. Délai entre les attaques, dégâts, prix, monnaies et progression du serveur inchangés.

## Aperçus et test

- `Deux-coups-circulaires.gif` montre les deux coups l'un après l'autre, au ralenti ×2.
- `Apercu-personnage-effets.gif` les montre côte à côte à leur durée réelle.
- `Evolutions-epees.png` présente les six formes, inchangées depuis la v1.
- Ouvrir une **copie** de `Galerie-personnage-epees-effets.rbxl` dans Studio, puis Jouer, pour voir la galerie isolée.
- `Monde-COMBAT-A-TESTER.rbxl` est une copie locale du jeu pour tester l'intégration. Ne pas la publier directement à la place du jeu actuel.

Les GIF sont des aperçus géométriques des modèles et des poses livrés, **pas des captures de Roblox Studio**. Le rendu des effets et les proportions de ton avatar restent à contrôler en exécution. Les appuis ont été calculés pour le mannequin R15 fourni ; ce n'est pas un système universel d'adaptation aux terrains ou aux proportions des avatars.

## Pour Claude : fusion ciblée

- Ajouter `src/client/CombatMotion.luau`, `SwordVisuals.luau`, `CombatVFX.luau`.
- Fusionner la proposition `Poses.luau` avec la version actuelle, sans écraser d'autres changements. Les références de départ et leurs empreintes sont dans `MANIFEST.json`. Pose superposée en PreSimulation, épée alignée après résolution de la main en PreRender ; port d'œufs, familiers et banc conservés. R15 Motor6D / AnimationConstraint, pas de nouveaux gestes R6.
- `Main.client.luau` ne change que l'impact cosmétique de l'épée : pas les dégâts ni les chiffres.
- `animations/` contient **seulement SlashRight et SlashLeft**, séquences natives avec un Impact chacune. La lecture locale fournie ne nécessite pas d'identifiant d'animation publié.
- Les modèles et aides animaux déjà livrés sont conservés dans la copie de test : aucun nouvel animal, aucune nouvelle zone et aucun changement de probabilités dans cette révision. `Animals.luau` est une proposition d'intégration ; les aides se trouvent dans `../shared/`.

La progression actuelle utilise des paliers Sword discrets. Formes : 1 fer, 2 acier, 3 glace, 4 feu, 5 foudre, puis arc-en-ciel pour tous les niveaux ≥ 6. Aucun achat ni dégât au-delà du septième palier n'est supprimé. Ne jamais écrire le palier visuel dans l'attribut Sword. Conserver le multiplicateur ×3,2 et les deux améliorations débloquées par zone.

## Vérifications

Deux trajectoires opposées et monotones vérifiées : moins de 2° d'inclinaison de la lame pendant la coupe, variation verticale de la pointe inférieure à 0,1 stud, appuis du mannequin conservés. Matrices et références XML valides ; neuf assets natifs sans scripts embarqués, syntaxe Luau, 88 tests d'alternance et deux constructions Rojo vérifiés.

**Livraison GitHub séparée : aucun fichier du jeu original remplacé et aucune publication Roblox. Pas encore testé en exécution dans Studio.** Vérifier le personnage réel, la marche pendant le coup, le téléphone, les autres joueurs, le respawn, les activités du camp et la charge maximale des effets avant publication. La copie complète est un instantané local daté, pas la dernière version du jeu ; ne pas écraser une branche plus récente avec elle. Voir le [guide principal](../README.md).

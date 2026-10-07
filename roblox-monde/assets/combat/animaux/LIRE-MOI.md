# Animaux — attaques et morsures, salles 1 à 6

36 modèles articulés, 36 clips Attack et 17 clips Bite : **53 clips de combat**. Les Idle et Walk existants sont conservés. Les formes approuvées, le grand varan et les couleurs des ultra-rares sont conservés.

- `salle-N/Apercu-combat.gif` montre la salle ; `previews/` contient chaque animal et chaque action.
- Ouvrir une **copie** de `Galerie-combat-salle-N.rbxl` dans Studio puis Jouer : boutons Attaquer, Mordre, Auto et marche/repos.
- Les modèles sont dans `salle-N/models/`. Les morsures ont une vraie articulation Jaw ; pas seulement un déplacement du modèle entier.
- Le cheval se cabre sur ses pattes arrière et retombe sur les pattes avant. Son clip dure 1,85 seconde.

Les modèles sont des pièces natives liées par Motor6D/Weld et contiennent leurs KeyframeSequence. Pas de script embarqué ni d'asset externe à télécharger. Attack et Bite ne bouclent pas et possèdent un seul marqueur Impact.

## Intégration

Utiliser `ActionAnimator`, `CombatAnimator` et `AttackTimeline` ensemble. API : bind(model), playAttack(rig, time, "Attack" ou "Bite"), PivotTo(base), step(rig, time, "Idle" ou "Walk"), cancelAttack(rig).

Le lecteur StarterAnimator historique répétait les clips et ne doit pas lire les nouvelles attaques en boucle. `ActionAnimator` garde Idle/Walk et restitue Attack après une morsure. Le signal Impact ne modifie pas les dégâts : le serveur reste l'autorité.

Le dossier s'appelle encore `survive-combat-...` car les modèles viennent de cette collection ; ils servent aussi à MONDE. La copie de test du pack personnage relie les 30 animaux déjà utilisés par MONDE, sans ajouter sa salle 6 à la progression.

Vérifications hors Studio : géométrie/articulations/appuis, références XML, classes autorisées, conservation des palettes et des Idle/Walk, syntaxe Luau, temporisation de lecture et six galeries Rojo. Voir `VALIDATION.json`.

**Livraison GitHub séparée : aucun fichier du jeu original remplacé et aucun déploiement Roblox de ce pack. Aucun test en exécution dans Studio.** Les GIF sont des aperçus géométriques, pas des captures de Studio. Les longues actions demandent de vérifier leur cadence face aux dégâts du jeu. Voir le [guide principal](../README.md) et ses aides `shared/` pour l'intégration.

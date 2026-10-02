# Effets de combat — client, 30 septembre 2026

(Écrit pour l'ancien jeu ; les effets servent aujourd'hui aux niveaux et au camp d'entraînement, sans changement.
« Parcelle » = une zone de combat : un niveau ou un camp.)

Livraison séparée du HUD, préparée après récupération de `943bdfa` (unités 61–100 et tests de Claude). Modules : `src/client/CombatVFX.luau`, `Effects.luau` et `PlotRenderer.luau`. Rojo charge automatiquement le nouveau module.

## Visuels

- Flèches et carreaux : pointe, empennage, traînée ; flèches enflammées de l'Archer avec flammes et braises en vol.
- Feu au sol : foyers, braises et fumée plutôt qu'un disque orange opaque.
- Catapulte/trébuchet : projectile visible, poussière, étincelles et petits fragments ancrés qui disparaissent, sans physique.
- Givre : onde creuse brève, brume froide et éclats aux pieds des ennemis ralentis.
- Foudre : zigzag clair, halo et étincelles sur les ennemis contrôlés.
- Étourdissement : étoiles au-dessus de l'ennemi, hauteur adaptée aux modèles personnalisés.
- Fragilité : particules violettes légères, contour de barre de vie existant conservé.
- Rayon arcanique : Beam en deux couches, montée en puissance et étincelles au contact.
- Baliste perçante : sillage fin qui ne masque pas la route.

## Limites

Textures natives Roblox : aucun asset à publier ou crédit Meshy. Budget commun de 96 racines transitoires, 16 feux et 48 statuts les plus proches. Mise à jour des distances quatre fois par seconde. Extinction/nettoyage à expiration ou destruction ; décorations sans collision, toucher ou requête spatiale. Ces plafonds portent sur les effets visuels, pas sur les dégâts serveur.

Aucun changement aux statistiques, dégâts, durées de gameplay, ralentissements, configurations ou fichiers serveur. Les cibles suivies, la vitesse de simulation et les gardes de génération de parcelle sont conservées. Les animations mécaniques existantes des tours restent en place. `tools/` n'est pas modifié par cet envoi.

## Vérification

282 assertions automatisées (API simulée) : budgets, distance, statuts, extinction, nettoyage, projectiles suivis, rayons et vrais appels du module Effects. Compilation Luau et construction Rojo réussies avec les dernières unités de Claude.

**À tester dans Studio avant publication du jeu** : lisibilité/intensité des flammes, moment des impacts, suivi d'une cible mobile, givre/stun/fragilité sur les grands boss, extinction des rayons, fin de vague et éloignement de parcelle. Mesurer ensuite les FPS avec plusieurs parcelles et un appareil modeste. Les tests automatisés ne sont ni une validation visuelle Roblox ni une mesure de performance réelle. La session Studio existante n'a pas été modifiée ou fermée.

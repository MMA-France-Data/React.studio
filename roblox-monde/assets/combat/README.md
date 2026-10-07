# Pack combat complet — MONDE

Livraison du 7 octobre 2026 pour la branche `claude/exciting-gauss-ggwcwm`, vérifiée contre `456314d`.

**Ce dossier contient les fichiers à intégrer, pas une modification du jeu en ligne. Les fichiers actuels de `roblox-monde/src` et les collections originales restent inchangés.**

## Ce qui est livré

- [Animaux](animaux/LIRE-MOI.md) : 36 modèles des salles 1 à 6, leurs Idle/Walk, 36 attaques et 17 morsures. Le cheval se cabre puis frappe avec les sabots avant. Les couleurs ultra-rares et les formes approuvées sont conservées.
- [Personnage](personnage/LIRE-MOI.md) : exactement deux coupes circulaires horizontales, gauche → droite puis droite → gauche, avec appuis décalés et rotation du bassin. R15, pas de troisième coup vertical.
- Six formes d'épée : fer, acier, glace, feu, foudre, arc-en-ciel ; croissants blancs, traînées colorées, étincelles et impacts confirmés. Aucune texture à importer.
- Sept galeries isolées `.rbxl`, projets Rojo portables, modèles `.rbxmx`, GIF/PNG, modules candidats, aides [shared](shared) et [tests](tests).

## Voir et tester

- [Deux coups, au ralenti ×2](personnage/Deux-coups-circulaires.gif), [épées](personnage/Evolutions-epees.png).
- Aperçus animaux dans `animaux/salle-N/Apercu-combat.gif` et `previews/`.
- Ouvrir une **copie** de `personnage/Galerie-personnage-epees-effets.rbxl` ou `animaux/salle-N/Galerie-combat-salle-N.rbxl`, puis Jouer dans Studio.
- `personnage/Monde-COMBAT-A-TESTER.rbxl` est un **instantané local de référence daté**, pas la dernière version du jeu. Ne pas publier ce fichier à la place du jeu actuel.

Les GIF montrent la géométrie et les poses livrées : **ce ne sont pas des captures de Studio**. Les contrôles hors Studio sont fournis dans les `VALIDATION.json`. Aucun test d'exécution Studio n'est revendiqué.

## Pour Claude : intégration ciblée

1. Ajouter les trois nouveaux modules de `personnage/src/client/` : `CombatMotion`, `SwordVisuals`, `CombatVFX`.
2. Fusionner les changements de combat de `Poses.luau`, `Main.client.luau` et `Animals.luau` avec les fichiers actuels. Ce sont des propositions complètes de fichiers, **pas une consigne de remplacement aveugle**. Les références de départ et empreintes sont dans le manifeste du personnage.
3. Conserver ensemble les phases `PreAnimation` / `PreSimulation` / `PreRender` de Poses : retrait de l'ancienne surcouche, application de la pose, puis épée alignée sur la main résolue. Préserver les œufs/familiers portés, banc/barre, support Motor6D/AnimationConstraint et nettoyage au respawn.
4. Ajouter `shared/ActionAnimator.luau`, `CombatAnimator.luau` et `AttackTimeline.luau` dans le Shared existant et les déclarer dans le projet Rojo actuel. Les modules candidats utilisent aussi les dépendances existantes `Pets`, `PetRig`, `StarterAnimator`, `Config`, `Texts` et les objets/remotes du jeu : ne pas les remplacer.
5. Remplacer les modèles d'animaux souhaités par les versions de `animaux/salle-N/models/`, avec les mêmes identifiants. Le lecteur historique StarterAnimator convient aux Idle/Walk, **pas aux nouvelles attaques à lecture unique** : utiliser ActionAnimator pour Attack/Bite. Garder les marqueurs Impact cosmétiques, le serveur décide toujours des dégâts.

### Ne pas changer l'économie ni la progression

Les six formes sont uniquement visuelles. Tout niveau d'épée **≥ 6** utilise la forme arc-en-ciel ; les achats et niveaux au-delà de 7 restent disponibles. Ne jamais écrire ce palier visuel dans l'attribut `Sword`.

Conserver les règles actuelles : multiplicateur ×3,2, deux améliorations débloquées par zone, `swordMax(zone)=1+2*zone`, prix et dégâts serveur. Le délai d'attaque du personnage reste inchangé ; chaque coupe visuelle dure 0,38 s.

Les 36 animaux sont livrés, mais la copie de référence n'en relie que 30 : l'ajout de la salle 6 à la progression est un travail séparé, non effectué ici. Les longues animations, notamment le cheval (1,85 s), nécessitent une vérification de cadence sans modifier les dégâts.

## Vérifications reproductibles

Avec `luau`, `luau-compile` et `rojo` disponibles, lancer `tools/check-combat.ps1`. Il vérifie la syntaxe de tous les modules livrés, les 388 assertions de temporisation/alternance, les modèles, puis reconstruit les sept galeries dans un dossier temporaire. Il ne modifie pas le jeu.

Avant toute publication Roblox : tester avatar réel, déplacement pendant les coups, téléphone, plusieurs joueurs, respawn, port d'œufs/familiers, banc et charge maximale des effets. Les appuis sont calculés pour le mannequin fourni, pas adaptés automatiquement à tous les terrains et proportions.

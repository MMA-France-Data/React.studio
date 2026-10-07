# MONDE — coups amples, vraie prise et mini-auras (v3)

Historique de la v3. La version active est maintenant [la v4](../personnage-v4/LIRE-MOI.md), déjà branchée dans `roblox-monde/src/client`. Les anciens dossiers `personnage` restent des archives : leurs copies de modules ne sont pas la version active.

## Ce qui change

- Deux coups alternés, gauche → droite / droite → gauche, balayage de 224° avec rotation du bassin et pieds décalés.
- Largeur de lame / tranchants **horizontaux**, épaisseur verticale pendant le coup. La marche ne peut plus ajouter une rotation parasite au poignet au milieu de la frappe.
- Le centre du manche suit **`RightGripAttachment`** de la main, image par image après la pose du personnage. Le pivot du modèle est compensé : il ne décale pas le manche. Le poignet contrôle l'orientation.
- Une traînée blanche et son bord élémentaire suivent **les vrais attachments de la lame**, pas un cercle indépendant autour du joueur.
- Mini-éléments tournants et mobiles autour de la lame : fer, acier, or, glace, feu, foudre **jaune dorée**, arc-en-ciel. Plafonds mobile, culling à distance, nettoyage à la destruction, traînée effacée aux téléportations.

Aucun changement aux dégâts, aux prix, aux sauvegardes, aux monstres ni au délai serveur. Durée visuelle : 0,38 s. Les modèles Meshy choisis n'ont pas été modifiés. Aucun crédit Meshy dépensé.

## Essai

Le projet habituel `roblox-monde/default.project.json` utilise directement les nouveaux modules. Refaire son build puis tester Play dans Studio.

La galerie indépendante est `assets/combat/personnage-v3/gallery.project.json` : deux mannequins et sept lames témoins pour examiner les effets. Les GIF sont des **prévisualisations hors Studio**, pas des captures du jeu ; leurs lames témoins ne sont pas les épées Meshy retenues.

Depuis `roblox-monde`, `tools/combat-v3/check.ps1` vérifie la syntaxe, l'alternance, les exports XML et construit la galerie et le jeu dans un dossier temporaire.

**Test d'exécution dans Studio et sur téléphone encore à faire.** `VALIDATION.json` décrit les contrôles hors moteur (géométrie, direction, tranchant, pieds et 242 contrôles de prise avec pivot décalé).

## Import des nouvelles épées

Les nouveaux fichiers Meshy téléchargés ne sont **pas encore importés comme assets Roblox dans ce dépôt**. En leur absence, le jeu utilise ses visuels de secours existants. Ne pas confondre ces visuels avec les nouveaux modèles choisis.

Les **sept vrais modèles source** et leurs textures sont maintenant regroupés dans [`../../swords-meshy`](../../swords-meshy/README.md), avec une fiche d'import. Ils restent à importer/publier dans Roblox Studio avant de remplacer les visuels de secours.

`SwordVisuals` peut cloner un modèle déjà importé dans `ReplicatedStorage/SwordMeshes`, avec son identité (`Iron`, `Steel`, `Frost`, `Flame`, `Storm`, `Prismatic`). Le modèle doit posséder :

- un `PrimaryPart` de prise, au **centre du manche**, dont les axes sont calibrés : longueur de lame vers **-Z**, largeur sur **Y**, épaisseur sur **X** ;
- deux `Attachment` : `TrailBase` au début de la lame et `TrailTip` à sa pointe.

Calibrer le repère/pivot de l'ensemble sans découper ni régénérer la géométrie. La prise et la trace ne doivent jamais être estimées à partir du centre de la boîte englobante d'un GLB.

Les six niveaux visuels de la boutique actuelle restent inchangés pour ne pas décaler la progression des joueurs. Le nouvel effet **Gold** existe (`SwordEffects.attach(model, "Gold")`) ; son ajout aux niveaux de boutique relève d'une intégration séparée, pas de ce correctif d'animation.

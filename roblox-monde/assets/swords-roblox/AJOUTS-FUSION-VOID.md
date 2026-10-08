# Deux nouvelles armes — 8 octobre 2026

Ordre visuel : **fer → acier → or → glace → feu → foudre → feu/glace → doubles lames violettes**.
Les prix, les dégâts, les sauvegardes, le délai entre les coups et les règles de combat ne sont pas changés.
La progression serveur dépassait déjà six épées : ces modèles habillent les paliers 7 et 8 existants.
L'arc-en-ciel reste de côté.

## Modèles préparés, puis importés par le créateur

- `A-IMPORTER/Sword_Fusion.fbx` : feu/glace, 18 950 triangles au lieu de 320 780.
- `A-IMPORTER/Sword_Void.fbx` : lame violette, 18 950 triangles au lieu de 172 996.
- Les dossiers `.fbm` voisins contiennent les quatre textures PBR réduites à 1024.
- Les FBX ont aussi les textures incorporées. Les UV et les couleurs d'origine sont conservés.
- La préparation est locale et gratuite ; aucune génération, conversion ou remesh Meshy payant n'a été lancé.
- Les téléchargements originaux ne sont pas modifiés. Leur nom et leur empreinte SHA-256 sont dans les `info.json`.

Chaque fichier fait 5,2 studs de long. Le jeu garde son grossissement actuel de 1,6, soit 8,32 studs.
Le pivot est au milieu de la vraie poignée, y compris pour la lame courbée dont le centre de boîte est décalé.
Les points de traînée sont mesurés sur la lame et sa pointe, pas sur le centre de sa boîte.

**Mise à jour du 8 octobre :** le créateur a importé Fusion et Void ; Claude a remis le dossier dans
`SwordMeshes.rbxm` au commit `0d38f6a`. Les retouches d'aura et de sens des coups décrites ci-dessous partent
de cette version. Elles ne remplacent ni les maillages, ni les textures PBR, ni le fichier `.rbxm`.
Les `info.json` décrivent l'étape de préparation locale : leur indicateur d'import est historique.
Sans modèle dans un autre checkout, le jeu conserve une foudre de secours et écrit un avertissement explicite.

## Pour Claude / le créateur dans Studio

L'import ci-dessous est **déjà fait** sur cette branche. Pour ces nouvelles auras, récupérer le code et
reconstruire/synchroniser le projet suffit : aucune nouvelle image, aucun nouveau modèle ni animation à publier.
Garder les étapes 1 à 5 comme procédure pour un nouvel import seulement, puis faire les vérifications de l'étape 6.

1. Récupérer cette branche et mettre à jour le plugin depuis `tools/swords/RangerLesEpees.lua`.
2. Ouvrir le jeu MONDE. Garder son dossier `ReplicatedStorage > SwordMeshes` existant (anciennes épées et stands).
3. Importer **seulement** les deux nouveaux FBX ci-dessus avec Import 3D. Garder les noms `Sword_Fusion` et
   `Sword_Void`, et importer leurs textures. Cette étape publie les maillages sur le compte Roblox du créateur.
4. Cliquer sur **Ranger les épées** : le plugin ajoute `Fusion` et `Void`, sans retirer les autres modèles.
   Il place les pivots et ajoute `TrailBase`, `TrailTip`, `AuraHot1…4`, `AuraCold1…4` ou `AuraShadow1…4`.
5. Enregistrer le dossier COMPLET `SwordMeshes` dans `assets/swords-roblox/SwordMeshes.rbxm`, puis le remettre sur
   GitHub. Le projet Rojo référence déjà ce fichier : aucune nouvelle ligne d'asset ID à inventer.
6. En Play, essayer les épées 7 et 8 avec la molette de test Studio. Vérifier aussi sur téléphone : prises dans
   chaque main, deux pointes vers le ciel au repos, alternance des mains, traînée seulement sur la lame active,
   disparition des fumées et retour à une seule arme en changeant d'épée.

## Auras renforcées, sans coque rigide

- **Void** : un seul voile courbe de fumée par lame, au lieu de dix/quatorze morceaux orientés séparément.
  Le créateur voyait des angles triangulaires : l'ancienne construction pouvait faire se chevaucher les
  bords de ces rubans. Elle est remplacée par un unique Beam cubique, échantillonné en 16 subdivisions
  sur téléphone et 24 sur PC. Une seule texture étirée, pas de motif de ronds répété. Les deux bouts sont
  transparents ; le bout supérieur garde une petite largeur physique pour éviter un capuchon triangulaire.
  Le violet est nettement plus foncé (RGB central 54/5/84), sans surcouche lumineuse, émission additive ni
  influence de l'éclairage ambiant. Son opacité est renforcée. La fumée libre au-dessus de la pointe est
  elle aussi sombre ; elle monte, s'affine et meurt en 0,8 à 1,25 seconde. Au plus huit particules vivantes
  par lame sur téléphone. Le voile respire, ondule doucement et son sommet flotte pendant les coups.
- **Fusion** : le même principe de voiles courbes, un orange et un bleu, placés selon les points Hot/Cold
  mesurés sur le modèle. Leur séparation minimale évite de les superposer entièrement en un nuage gris.
  **Aucun ParticleEmitter sur Fusion**, ni le long de la lame ni à sa pointe : plus de ronds distincts.
  Deux voiles au total, 16 subdivisions chacun sur téléphone, 24 sur PC. Les sommets s'affinent et deviennent
  invisibles au-dessus de la pointe. Pas de BOOST global ni de nouvel asset.
- **Feu** : flammes plus amples (pic 2,1 studs), qui quittent la lame et montent ; les braises sont conservées.
- **Glace** : brume cyan plus visible, pic 2,46 studs, au lieu de fumée presque entièrement transparente.
- **Foudre** : inchangée par ces retouches.

Les effets sont coupés à distance, nettoyés lors d'une téléportation ou d'un changement d'arme.
Les textures de fumée/flamme sont celles fournies avec Roblox : aucun asset supplémentaire à importer.

## Doubles lames violettes

Le palier 8 crée deux exemplaires du modèle `Void`, l'un sur `RightGripAttachment`, l'autre sur
`LeftGripAttachment`. Les deux bras sont en garde, coudes pliés et lames vers le ciel.
Premier coup **du bras droit vers la gauche**, en travers du corps ; deuxième coup **du bras gauche vers la droite**.
La version précédente prenait le geste extérieur gauche → droite du bras droit : le doute du créateur était fondé.
`DualSwordMotion.sourceClip` utilise maintenant le clip existant `SlashLeft`, qui est bien une frappe du bras
droit de droite à gauche ; le second coup reflète ce geste complet. Les noms des deux événements sélectionnent
la main active, pas la direction du clip d'origine. Échange des bras et des jambes, rotation du bassin et
déplacement latéral en miroir. Aucune échelle négative appliquée au personnage.
Une seule main active et une seule traînée par coup ; **aucun double dégât**.
Les deux modèles et leurs effets sont nettoyés lors du changement d'arme, du port d'un œuf ou de la disparition
du personnage. Les six anciennes épées restent à une main avec leurs attaques existantes.

## Vérifications réellement effectuées

- Réimport des deux FBX dans Blender : 18 950 triangles chacun, UV, quatre textures PBR 1024 et pivots contrôlés.
- Points de fumée à environ 0,025 stud de la surface réelle ; traînées à la pointe réelle.
- `tools/swords/check.ps1` : contrôles du miroir et des profils de fumée, 89 contrôles du rythme des attaques,
  syntaxe de 34 fichiers Luau et du plugin, deux clips XML inchangés, construction du jeu et de l'aperçu.
- Contrôle indépendant sur le **tableau de poses actuel de production** et le vrai squelette R15 de la galerie :
  32 poses pendant le balayage. Prise droite : de +0,665 à -0,313 stud par rapport au torse ; gauche exactement
  inverse. Tranchant horizontal. Ce contrôle ne se contente pas de vérifier les noms des clips.
- Contrat d'objets simulés PC/téléphone : un seul voile sur Void, deux sur Fusion, aucun rond sur Fusion,
  aucune instance créée par frame, base orthonormale des courbes, bouts entièrement transparents et sans
  géométrie dégénérée, texture étirée non répétée, séparation des couleurs, violet non additif, nettoyage
  à la téléportation et au changement de visibilité, destruction idempotente et capacité réutilisable.
  **Ce n'est pas le moteur Roblox ; ces contrôles ne prouvent pas l'absence de tout artefact à l'écran.**
- Comparaisons rendues : `Fusion/comparaison.png`, `Void/comparaison.png`. Original à gauche, version allégée à
  droite. Les trois `Void/duo-*.png` sont des poses rendues **hors Roblox**, avec le vrai modèle, sans fumées.

**Pas de capture ni de test Play Studio/téléphone pendant ces retouches.** L'écran du créateur n'a pas été
piloté. Le rendu réel de la brume texturée, l'amélioration des angles visibles et l'animation sur l'avatar du joueur
restent à vérifier dans Studio. Les anciennes images `duo-*.png` sont des poses de la préparation précédente,
sans aura : elles ne montrent pas la nouvelle brume ni le nouveau sens du mouvement.

## Refaire la préparation, sans toucher aux autres armes

`tools/swords/prepare_addition.py` prend `--id Fusion` ou `--id Void`, `--source` (dossier FBX/PBR extrait) et
`--output` (dossier `assets/swords-roblox`). Il est lancé avec Blender en arrière-plan. Il ne modifie que les
fichiers du modèle choisi et sa copie dans `A-IMPORTER` ; il ne modifie jamais `SwordMeshes.rbxm`.
`tools/swords/verify_additions.py` contrôle les deux FBX exportés, sans les modifier.

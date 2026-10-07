# Deux nouvelles armes — 8 octobre 2026

Ordre visuel : **fer → acier → or → glace → feu → foudre → feu/glace → doubles lames violettes**.
Les prix, les dégâts, les sauvegardes, le délai entre les coups et les règles de combat ne sont pas changés.
La progression serveur dépassait déjà six épées : ces modèles habillent les paliers 7 et 8 existants.
L'arc-en-ciel reste de côté.

## Modèles prêts, import Roblox encore à faire

- `A-IMPORTER/Sword_Fusion.fbx` : feu/glace, 18 950 triangles au lieu de 320 780.
- `A-IMPORTER/Sword_Void.fbx` : lame violette, 18 950 triangles au lieu de 172 996.
- Les dossiers `.fbm` voisins contiennent les quatre textures PBR réduites à 1024.
- Les FBX ont aussi les textures incorporées. Les UV et les couleurs d'origine sont conservés.
- La préparation est locale et gratuite ; aucune génération, conversion ou remesh Meshy payant n'a été lancé.
- Les téléchargements originaux ne sont pas modifiés. Leur nom et leur empreinte SHA-256 sont dans les `info.json`.

Chaque fichier fait 5,2 studs de long. Le jeu garde son grossissement actuel de 1,6, soit 8,32 studs.
Le pivot est au milieu de la vraie poignée, y compris pour la lame courbée dont le centre de boîte est décalé.
Les points de traînée sont mesurés sur la lame et sa pointe, pas sur le centre de sa boîte.

`SwordMeshes.rbxm` **n'a pas encore ces deux nouveaux modèles**. Sans l'import, le jeu conserve une foudre de
secours et écrit un avertissement explicite : les nouvelles armes ne sont pas présentées comme déjà importées.

## Pour Claude / le créateur dans Studio

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

## Petites fumées, sans voile conique

Les particules naissent sur des points relevés dans les vraies zones colorées des textures : orange côté feu,
bleu pâle côté glace, violet sur le tranchant sombre. Elles dérivent librement et deviennent invisibles après
0,45 à 0,85 seconde. Taille maximale : 0,38 stud. Pas de grosse enveloppe, de tube, de cône ni de BOOST ×3.
Elles sont moins nombreuses sur téléphone et coupées à distance. Les téléportations nettoient les particules.
Les textures de fumée sont celles fournies avec Roblox : aucune image ni aucun effet 3D à importer en plus.

## Doubles lames violettes

Le palier 8 crée deux exemplaires du modèle `Void`, l'un sur `RightGripAttachment`, l'autre sur
`LeftGripAttachment`. Les deux bras sont en garde, coudes pliés et lames vers le ciel.
Premier coup à droite ; deuxième coup à gauche : réflexion du premier geste complet, avec échange des bras et
des jambes, rotation du bassin et déplacement latéral en miroir. Aucune échelle négative appliquée au personnage.
Une seule main active et une seule traînée par coup ; **aucun double dégât**.
Les deux modèles et leurs effets sont nettoyés lors du changement d'arme, du port d'un œuf ou de la disparition
du personnage. Les six anciennes épées restent à une main avec leurs attaques existantes.

## Vérifications réellement effectuées

- Réimport des deux FBX dans Blender : 18 950 triangles chacun, UV, quatre textures PBR 1024 et pivots contrôlés.
- Points de fumée à environ 0,025 stud de la surface réelle ; traînées à la pointe réelle.
- `tools/swords/check.ps1` : 139 contrôles du miroir et des profils de fumée, 89 contrôles du rythme des attaques,
  syntaxe de 32 fichiers Luau et du plugin, deux clips XML inchangés, construction du jeu et de l'aperçu.
- Contrôle indépendant sur le squelette R15 : prise gauche exactement en miroir de la droite pour le geste,
  et direction des deux lames vers le haut au repos.
- Comparaisons rendues : `Fusion/comparaison.png`, `Void/comparaison.png`. Original à gauche, version allégée à
  droite. Les trois `Void/duo-*.png` sont des poses rendues **hors Roblox**, avec le vrai modèle, sans fumées.

**Pas de capture ni de test Play Studio/téléphone pendant cette préparation.** L'écran du créateur n'a pas été
piloté. Le rendu réel des particules, l'import Roblox et l'animation sur l'avatar du joueur restent à vérifier
dans Studio après l'import. Les images hors Roblox ne prouvent pas que les effets sont chargés dans le jeu.

## Refaire la préparation, sans toucher aux autres armes

`tools/swords/prepare_addition.py` prend `--id Fusion` ou `--id Void`, `--source` (dossier FBX/PBR extrait) et
`--output` (dossier `assets/swords-roblox`). Il est lancé avec Blender en arrière-plan. Il ne modifie que les
fichiers du modèle choisi et sa copie dans `A-IMPORTER` ; il ne modifie jamais `SwordMeshes.rbxm`.
`tools/swords/verify_additions.py` contrôle les deux FBX exportés, sans les modifier.

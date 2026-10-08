# Quatre nouvelles épées — téléchargements du 8/9 octobre

Les quatre modèles du créateur sont préparés pour Import 3D. Leur import sur le compte Roblox, l'enregistrement du modèle Studio et leur attribution dans la progression restent à faire. Aucun rang, prix ou dégât n'est imposé dans ce lot. `SwordMeshes.rbxm` reste inchangé. Le client prépare la tenue à deux mains de la hyène ; aucun script serveur ni règle de combat n'est modifié.

| Modèle | Fichier dans `A-IMPORTER` | Triangles source | Triangles livrés |
| --- | --- | ---: | ---: |
| Tigre | `Sword_TigerClaw.fbx` | 944 334 | 18 950 |
| Hyène | `Sword_HyenaFang.fbx` | 1 772 810 | 18 950 |
| Mâchoire de T-rex | `Sword_TrexJaw.fbx` | 497 274 | 18 950 |
| Météorite | `Sword_Meteorite.fbx` | 558 050 | 18 950 |

Chaque épée contient un seul maillage visible, les UV d'origine et quatre textures PBR réduites à 1024 × 1024. Les textures sont intégrées au FBX ; son dossier `.fbm` contient les copies de secours. La longueur est normalisée à environ 5,2 studs avant l'agrandissement existant du jeu. Le milieu du vrai manche est à l'origine, avec `Grip`, `TrailBase` et `TrailTip` calibrés par le plugin.

La hyène était inclinée dans son export : une rotation mesurée redresse l'ensemble avant réduction, sans changer le dessin. Sa calibration tient compte du décalage réel du manche par rapport à la boîte englobante.

## Hyène : une seule épée, deux mains

- Au repos, la lame repose sur l'épaule droite, les deux mains sur le même manche.
- Deux coupes circulaires horizontales : gauche → droite puis droite → gauche. La rotation des hanches et l'appui décalé des pieds restent ceux des attaques existantes.
- `RightHold` et `LeftHold` sont dans la portion étroite et enroulée du véritable manche, à −0,16 et +0,16 stud du milieu, avant l'agrandissement ×1,6. Les paumes sont donc espacées de 0,512 stud dans le jeu.
- Le plugin pose `TwoHanded = true` uniquement sur `HyenaFang`. `SwordGrip` place l'arme par `RightHold`. Les deux bras suivent un seul repère rigide, adapté aux articulations R15 ; aucune seconde arme ni translation artificielle des bras n'est créée.
- Les fichiers `assets/combat/hyena-two-hand/Idle.rbxmx`, `SlashRight.rbxmx`, `SlashLeft.rbxmx` sont des `KeyframeSequence` natifs. `R15Preview.rbxmx` contient le rig de contrôle et son dossier `Animations`. Ces clips sont une référence pour le rig livré ; le lecteur du client ajuste la tenue à d'autres proportions R15.
- Les anciens modes à une main et les deux lames `Void` ne sont pas remplacés. Porter un œuf ou s'entraîner garde la priorité.

`TwoHandSwordPath.luau` et `TwoHandSwordMotion.luau` fournissent le repos et le verrouillage des mains. L'activation demande encore l'import Studio ET l'attribution de `HyenaFang` à un rang visuel validé. Le catalogue de couleurs connaît les nouveaux identifiants, mais `SwordPalette.gameOrder` n'est pas déplacé automatiquement. Ce lot n'ajoute donc pas une épée achetable sans décision sur son emplacement.

## Import dans Studio

1. Sauvegarder le dossier `ReplicatedStorage/SwordMeshes` actuel avant tout nouvel import.
2. Mettre à jour le plugin local avec `roblox-monde/tools/swords/RangerLesEpees.lua` de cette livraison. Aucun plugin local n'est installé automatiquement ici.
3. Importer les quatre FBX ci-dessus avec Import 3D, en conservant les noms exacts `Sword_TigerClaw`, `Sword_HyenaFang`, `Sword_TrexJaw`, `Sword_Meteorite`.
4. Utiliser le bouton **Ranger les nouvelles épées**. Il ajoute uniquement ces quatre modèles calibrés dans `ReplicatedStorage/SwordMeshes`, sous les noms `TigerClaw`, `HyenaFang`, `TrexJaw`, `Meteorite`. Les sources importées restent intactes ; les autres épées et les stands ne sont pas rerangés par ce bouton.
5. Vérifier les textures, les manches et les points de traînée, puis enregistrer le dossier complet dans `assets/swords-roblox/SwordMeshes.rbxm`, sans perdre les autres modèles.
6. Attribuer ensuite les nouveaux identifiants dans la progression visuelle de `SwordPalette.gameOrder`. Aucun ordre de progression n'est décidé par le plugin ; les sauvegardes, prix et dégâts ne doivent pas être déplacés accidentellement. Tester en Play et sur téléphone avant de considérer l'intégration terminée.

Les pièces visibles sont non collisionnantes et massless. Le point de prise invisible est la PrimaryPart, comme pour les épées existantes ; le système `SwordGrip` peut ainsi utiliser l'attache de la main. Les traînées suivent les extrémités mesurées des nouvelles lames, pas celles d'une ancienne épée.

## Aperçus et contrôles

Chaque dossier possède `comparaison.png` : original à gauche, copie allégée à droite. Ce sont des rendus des vrais maillages sans aura simulée, pas des captures Roblox.

- `MONDES-IMPORT-VALIDATION.json` : réimport des quatre FBX dans Blender, compte réel des triangles, UV, quatre textures, longueur, manche et proximité des points de traînée avec la lame.
- `MONDES-MANIFEST.json` : sources, empreintes des fichiers, état d'intégration et absence d'opération payante.
- `info.json` et `calibration.json` par modèle : mesures de prise et repère source.
- `tools/swords/check-world-additions.cjs` : contrat du vrai plugin sur les quatre identifiants, centrage de la prise, points de traînée, conservation des sources et absence de script embarqué dans les copies. Ce test utilise des objets simulés, pas Studio.
- `tools/swords/check-two-hand.cjs` : vrai module client + vrai lecteur des coupes + vraie fonction de prise, calcul complet des articulations sur 5 292 poses. Neuf combinaisons de taille de corps/bras, deux types d'articulations simulées, deux directions ; contacts et orientations des paumes, plan de coupe horizontal et absence d'étirement des bras. Il ne remplace pas un essai Play/Studio.

Depuis `roblox-monde` :

```powershell
node tools/swords/check-world-additions.cjs
./tools/swords/check.ps1
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python tools/swords/verify_world_additions.py -- --assets assets/swords-roblox
```

Préparation locale gratuite avec Blender : aucun appel à l'API Meshy, aucune génération répétée, aucun crédit consommé par cette préparation. Les originaux restent dans Téléchargements. Le coût de génération initial, réalisé par le créateur, est inconnu. Les archives ne fournissent pas d'identifiant de tâche Meshy ; les noms et SHA-256 des FBX source sont conservés.

L'import Roblox et les essais Studio/téléphone ne sont pas effectués ici. Les modèles sont prêts à importer, pas encore actifs dans le jeu.

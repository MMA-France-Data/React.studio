# Garde de la tempête — troupes vagues 61 à 70

Proposition visuelle locale, à valider par le propriétaire avant transmission à Claude. Ces troupes accompagnent le Seigneur de la tempête (boss vague 70, livré séparément). Aucun boss ni modèle déjà installé n'est remplacé.

| Source | Unité | Triangles |
| --- | --- | --- |
| `Swarm_6` | Écuyer, équipement léger indigo | 4567 |
| `Normal_6` | Fantassin, armure or et emblème d'éclair | 5328 |
| `Fast_6` | Cavalier, soldat or/indigo et cheval ardoise | 7720 |
| `Tank_6` | Chevalier lourd, épaulières et visière sombre | 6134 |
| `Giant_6` | Colosse, renforts et masse | 6520 |

Chaque unité possède un seul mesh skinné et un seul matériau texturé. Texture couleur regroupée : 1024 px pour les humains, 2048 px pour le cavalier. Les ornements d'éclairs sont de petits volumes fermés liés aux os existants, sans particules, lumières ou effets de gameplay. Les corps et visages humains originaux sont conservés, pas remplacés par les crânes de la faction précédente.

## Import Studio

Les `.blend` sont les sources éditables et les `.glb` contiennent modèles, textures et clips. Préférer les FBX séparés pour le test et la publication des animations dans Studio :

- Importer `Swarm_6_Walking_Studio.fbx`, `Normal_6_Walking_Studio.fbx`, `Tank_6_Walking_Studio.fbx` et `Giant_6_Walking_Studio.fbx` comme nouveaux rigs Custom. Charger ce même fichier dans l'Éditeur pour tester la marche, puis le `*_Death_Studio.fbx` correspondant sur le même rig.
- Pour le cavalier, importer `Fast_6_Gallop_Studio.fbx`, puis charger ce même FBX dans l'Éditeur. Vérifier les quatre jambes, le corps et le cavalier assis. Tester ensuite `Fast_6_Death_Studio.fbx` sur ce même squelette.
- Garder les anciens modèles durant les tests. Publier les animations sous le propriétaire de l'expérience seulement après validation. Si la texture est grise, le PNG `*_Color.png` séparé est fourni comme secours.

Les humains conservent leur squelette KayKit à 41 os et les clips `Idle`, `Walking_A`, `Running_A`, `Death_A`. Le cavalier conserve les 48 os de la base déjà corrigée, `Gallop` et `Death` ; son soldat est lié rigidement à `Rider`, enfant de `Back`, pas au `Torso` retourné. Noms, parents et matrices de repos sont conservés. Aucun rerig ni nouvelle animation n'a été généré.

## Contrôles et limites

`manifest.json` donne les sources locales, clips et nombres de triangles. `validation.json` consigne les cinq réimports GLB : un mesh/matériau, texture, UV, poids normalisés, échelles unitaires, absence de pistes d'échelle, poses échantillonnées sans étirement et cavalier rigide.

`validation-fbx.json` consigne les dix réimports FBX : matrices et parents des os identiques aux exports de référence, échelles unitaires à chaque image, quatre influences maximum et poids normalisés, mouvement des membres, texture embarquée comparée au PNG final, absence d'étirement sur les poses échantillonnées et rigidité du cavalier. Les FBX sont échantillonnés à 30 images/s.

`apercu-famille.png` est un rendu des GLB réellement exportés et réimportés. Les tailles de présentation ne modifient pas le gameplay. `apercu-galop.gif` montre le cavalier depuis son FBX réimporté dans Blender ; `controle-animations.png` montre des poses des dix FBX.

**Import, animations, orientation, affichage des textures et performances Roblox Studio : encore à confirmer.** Les tests locaux ne remplacent pas ces vérifications. Aucun `.rbxm`, numéro d'animation Roblox, chiffre de gameplay, script, interface ou fichier du dossier `tools/` n'est modifié ou installé.

## Provenance et coût

Travail local uniquement à partir des bases déjà utilisées : KayKit Adventurers, Kay Lousberg (CC0), et Quaternius Ultimate Animated Animal Pack (CC0) pour le cheval. Licence KayKit copiée dans le pack ; filiation précise dans `manifest.json` et `provenance.json`. Les modèles, clips et licences antérieurs restent intacts. Aucune requête Meshy ni dépense de crédits pour cette famille.

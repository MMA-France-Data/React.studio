# SURVIVE! — collections originales, salles 1 à 5

30 animaux originaux en pièces Roblox natives, avec rigs Motor6D, détails soudés
et séquences locales `Idle` / `Walk`. Versions retenues après les retours visuels
du joueur, préparées le 6 octobre 2026. Aucun modèle ou script de bibliothèque.

| Collection | Animaux |
| --- | --- |
| [Salle 1](salle-01/README.md) | Lapin corrigé, chouette, chien, chat, renard, tortue |
| [Salle 2](salle-02/README.md) | Écureuil, hérisson, raton laveur, moufette, castor, blaireau retravaillés |
| [Salle 3](salle-03/README.md) | Coq, canard, cochon, mouton, chèvre, cheval |
| [Salle 4](salle-04/README.md) | Lynx, bélier, sanglier, loup corrigé, cerf, ours brun |
| [Salle 5](salle-05/README.md) | Capybara, toucan, singe, anaconda, jaguar, crocodile |

Chaque dossier contient les six modèles dans `models/`, une insertion groupée,
les rendus individuels et l'aperçu de collection, un aperçu animé, une scène Blender,
les descriptions de géométrie/rig/clips, les empreintes SHA256 et une galerie
Roblox indépendante. Les anciennes versions restent archivées localement, pas
dans ce dossier. Les fichiers ZIP et les images intermédiaires sont exclus pour
éviter les doublons dans Git.

## Pour Claude : intégrer sans changer les règles à l'aveugle

Ces livraisons sont **uniquement des envois d'assets**. Aucun fichier de `src/`,
`default.project.json`, sauvegarde, chance, revenu ou définition de salle n'est
modifié par ces envois. Les modèles de bibliothèque existants dans `assets/pets/`
sont conservés. Claude a ajouté l'intégration des salles 1 à 3 séparément ;
le présent ajout fournit les salles 4 et 5 sans changer cette intégration.

La salle 4 est la **version validée avec le loup retravaillé**, pas le premier loup.
Son fichier `models/Wolf.rbxmx` contient 17 Motor6D : cou, mâchoire, quatre jambes
à deux segments et queue à trois segments. Les cinq autres animaux de cette salle
sont identiques à leurs modèles validés précédemment. Le GIF de la salle 4 montre
uniquement le nouveau loup ; celui de la salle 5 montre les six animaux.
Le singe a la queue corrigée et continue. L'anaconda n'a pas de pattes et son clip
`Walk` est une ondulation ; le toucan marche avec les ailes repliées.

1. Ouvrir les aperçus et tester une galerie `Galerie-6-animaux.rbxl` séparément,
   sans écraser une place ouverte avec du travail non sauvegardé.
2. Les RBXMX s'insèrent **depuis un fichier**, pas via l'importateur GLB/FBX.
   Ils n'ont ni MeshPart, ni texture hébergée, ni script. Pivot centré `RigRoot`,
   orientation -Z ; pièces ancrées et sans collision.
3. Le lecteur fourni est `StarterAnimator.luau`, identique dans les cinq packs.
   Appeler `bind(model)` une fois, puis `step(rig, time, "Idle"/"Walk")` après
   `model:PivotTo(...)`. Il résout les Motor6D et les Weld des pièces ancrées,
   et tient compte de `model:GetScale()`. Aucune animation à publier sur Roblox.
4. Ne pas simplement écraser les modèles existants : leur pivot `Body` et leurs
   rigs de bibliothèque ne sont pas ceux de ces fichiers. Adapter le chargement
   et l'animation des nouveaux rigs au lecteur fourni ; conserver les anciens
   chemins si leur prise en charge reste nécessaire.
5. Les numéros sont ceux des **collections visuelles** décidées avec le joueur,
   pas une modification automatique des événements de `Config.ROOMS`.
   Le choix des six espèces par salle, leurs identifiants de sauvegarde et leur
   lien avec les raretés doivent être décidés avant d'intégrer.
6. Préserver les chances, pouvoirs, revenus, inventaires et sauvegardes tant
   qu'une modification précise n'a pas été demandée. Pas de règle économique
   nouvelle implicite dans l'apparence du cheval ou des autres animaux.

## Vérifications déjà faites / encore à faire

Fichiers XML, références, empreintes, poses de repos, matrices et boucles
vérifiés hors ligne ; modules Luau compilés et cinq galeries construites avec
Rojo. Les rendus proviennent des vrais modèles livrés et ont été inspectés.
Le GIF de la salle 1 montre uniquement les bonds du lapin corrigé ; les cinq
autres modèles/animations sont conservés à l'identique de la première version.

**Pour les nouvelles salles 4 et 5 : exécution réelle dans Studio, qualité visuelle
dans le jeu et fluidité sur téléphone encore à vérifier** avant publication.
Les vérifications de ce pack sont hors ligne ; elles ne remplacent pas les tests
de l'intégration effectués séparément par Claude. La scène Blender contient
les pièces de rendu, pas une armature Blender animée. Aucun crédit Meshy,
aucune publication Roblox et aucune intégration au jeu par cet envoi GitHub.

# Compagnons gratuits de SURVIVE!

Ces modèles remplacent les compagnons en blocs, sans modifier les pouvoirs, les chances,
les œufs, les couveuses, l'inventaire ou les sauvegardes. Gratuité vérifiée sur le Creator
Store le 5 octobre 2026. Les identifiants et empreintes sont dans `PROVENANCE.json`.

| Compagnon | Modèle source et créateur | Géométrie conservée |
| --- | --- | --- |
| Dragon | [Dragon Pet — maxito121207](https://create.roblox.com/store/asset/12473517134/Dragon-Pet) | 1 MeshPart ; le SpecialMesh est converti avec ses dimensions exactes et sa texture |
| Caillou | [Realistic Meteor — SionixKev](https://create.roblox.com/store/asset/2847767720/Realistic-Meteor) | 1 MeshPart ; visage et petites braises ajoutés localement |
| Lapin | [rabbit — dandansoydaniel](https://create.roblox.com/store/asset/101886867632017/rabbit) | 1 MeshPart, matériaux PBR conservés |
| Golem | [Golem — ILegacyGamesI](https://create.roblox.com/store/asset/101927195223511/Golem) | 42 pièces, dont 22 MeshParts ; runes lumineuses conservées |
| Chouette | [Realistic owl (PBR) — creepercatchanel](https://create.roblox.com/store/asset/14798191327/Realistic-owl-PBR) | 2 MeshParts, matériaux PBR conservés ; support retiré |

## Intégration et sécurité

- `default.project.json` place les 5 modèles dans `ReplicatedStorage.PetVisuals`.
- `src/shared/PetModels.luau` clone le modèle local et crée le pivot invisible `Body`.
- `Pets.build(name, rarity)` conserve son interface et ajoute les effets de rareté existants.
- Géométrie centrée sur l'origine, taille de compagnon, avant orienté vers -Z.
- Toutes les pièces sont ancrées, sans collision, contact, requête ou ombre.
- Aucun script de bibliothèque, Humanoid, contrainte, son ou logique de PNJ n'est importé.
  Les 4 scripts de la météorite d'origine sont exclus ; les 4 nouveaux modèles n'en contenaient aucun.
- Le golem exclut `HumanoidRootPart` et la décoration en union `RootsArm2`.
  La chouette exclut le support `baked_mesh.001`.
- Pas de chargement de modèle depuis le Creator Store pendant la partie. Les maillages et
  textures référencent les ressources hébergées sur Roblox, comme les modèles de la salle de sport.
- Aucun rig ou animation de combat ajouté : le suivi et le vol plané existants sont conservés.
  Les ailes du dragon ne battent pas encore.

Les anciens builders de `Pets.luau` restent comme secours pour une place qui n'aurait pas
encore le dossier `PetVisuals`. La place construite avec ce projet utilise les nouveaux modèles.

## Vérifications

- Compilation syntaxique de tous les fichiers `src/**/*.luau` : réussie.
- Construction de la place avec Rojo : réussie.
- Aperçu client isolé dans Studio, avec les fonctions `PetModels.build` et `Pets.build` :
  les 20 combinaisons animal/rareté sont construites, avec vérification du pivot `Body`,
  des MeshParts, de l'absence de script et de collision, de l'anneau, de l'échelle et des pouvoirs.
- Inspection des textures et de l'orientation dans cet aperçu.

La suite complète de gameplay et la performance sur un vrai téléphone n'ont pas été
retestées dans cette intervention. Ne pas remplacer une place ouverte contenant du travail
non sauvegardé : reconstruire une nouvelle place, puis tester et publier séparément.

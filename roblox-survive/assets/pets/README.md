# Compagnons riggés de SURVIVE!

Les cinq compagnons utilisent maintenant de véritables os ou articulations, pas seulement
une oscillation du modèle entier. Les pouvoirs, chances, œufs, couveuses, inventaires,
sauvegardes et effets de rareté existants sont conservés. Gratuité des sources vérifiée
sur le Creator Store le 5 octobre 2026 ; sources et empreintes dans `PROVENANCE.json`.

| Compagnon | Source et créateur | Rig et animation |
| --- | --- | --- |
| Dragon | [A soaring dragon (HAS A RIG) — mangysuperboy](https://create.roblox.com/store/asset/13323202284/A-soaring-dragon-HAS-A-RIG) | 1 MeshPart, 218 os d'origine ; ailes, cou et queue animés localement |
| Caillou | [Realistic Meteor — SionixKev](https://create.roblox.com/store/asset/2847767720/Realistic-Meteor) | Rig créé pour SURVIVE! : corps, deux mains, deux pieds ; 5 Motor6D |
| Lapin | [Rabbit Rig Animations — Magus_ArtStudios](https://create.roblox.com/store/asset/12725036090/Rabbit-Rig-Animations) | 1 MeshPart, 22 os ; séquences `Walk` et `Idle` du modèle source |
| Golem | [Golem — ILegacyGamesI](https://create.roblox.com/store/asset/101927195223511/Golem) | 17 Motor6D d'origine ; marche articulée locale, décorations soudées aux membres |
| Chouette | [The Owl — noobAcker1114](https://create.roblox.com/store/asset/8240793375/The-Owl) | Rig ajouté aux pièces séparées : corps, tête, deux ailes, deux pieds ; 6 Motor6D |

Le dragon source n'a pas de texture : sa couleur rouge-brun est définie localement pour
la rareté commune. Le lapin et le golem conservent leurs ressources graphiques d'origine.
La chouette est un modèle en pièces, et non le précédent maillage PBR statique.
Aucune génération payante ni crédit Meshy utilisé.

## Intégration et sécurité

- `default.project.json` place les modèles dans `ReplicatedStorage.PetVisuals`.
- `PetModels.build` clone les modèles locaux et normalise leur taille avec `ScaleTo`,
  sans réécrire séparément la pose de liaison des os ou les attaches du rig.
- Le pivot invisible `Body` est centré et orienté normalement. La correction visuelle
  d'orientation du golem reste dans les pièces quand le suivi appelle `PivotTo`.
- `VisualBaseScale` conserve la taille de base du rig ; les facteurs de rareté et la
  taille spéciale du dragon restent ceux de `Pets.luau`.
- `PetRig.luau` anime les os et résout les liaisons Motor6D/Weld des pièces ancrées.
  `Animals.luau` le branche au suivi existant, y compris le dragon monté en vol plané.
- Toutes les pièces sont sans collision, contact, requête ni ombre. Aucun Humanoid,
  script de bibliothèque, son ou logique de PNJ n'est importé. Les 4 scripts de la
  météorite source sont exclus. Les os, Motor6D, Weld et séquences de poses sont conservés.
- Le golem conserve son `HumanoidRootPart` invisible comme racine des articulations,
  mais pas le Humanoid ni la décoration en union `RootsArm2`.
- Aucun modèle n'est chargé depuis le Creator Store pendant la partie. Les maillages
  et textures continuent à utiliser les ressources hébergées sur Roblox.
- Pas d'ID d'animation à publier : les séquences de poses et mouvements sont locaux.

Les anciens builders restent en secours pour les places sans `PetVisuals`.
Il faut reconstruire une place depuis ce projet pour utiliser les nouveaux rigs :
remplacer seulement les modules dans un ancien fichier `.rbxl` ne remplace pas les assets.

## Vérifications et passage à Claude

- Références internes des cinq fichiers RBXMX : vérifiées ; aucun script embarqué.
- Compilation de tous les fichiers `src/**/*.luau` et construction de la place complète
  avec Rojo : réussies avant cet envoi.
- Test client isolé dans Studio : les 20 combinaisons animal/rareté ont été construites,
  leurs pouvoirs inchangés et leurs articulations mobiles vérifiés automatiquement
  (`SURVIVE_RIG_TEST_OK 20`). Ce test ne prouve pas la qualité visuelle du skinning.
- La correction finale du pivot du golem a été ajoutée après ce test : vérifier son
  orientation dans la nouvelle place reconstruite.

À la demande du joueur, l'inspection visuelle est confiée à Claude. Avant publication :

1. Équiper les cinq compagnons : regarder les ailes du dragon et de la chouette,
   les pattes du lapin, les bras/jambes du golem, les mains/pieds du caillou.
2. Vérifier à l'arrêt et en déplacement : pas d'étirement du maillage, de membre
   détaché, de saut de pose ou de modèle qui regarde de côté.
3. Vérifier les quatre raretés, les textures et la taille du dragon, puis le vol plané.
4. Vérifier les bonus et sauvegardes avec la suite habituelle de gameplay.
5. Mesurer la fluidité sur téléphone et avec plusieurs joueurs ; le dragon a 218 os.

La qualité visuelle, le gameplay complet et la performance sur téléphone ne sont pas
validés par cet envoi. Construire une nouvelle place ; ne pas écraser une place ouverte
contenant du travail non sauvegardé. Rien n'est publié sur Roblox par ce commit.

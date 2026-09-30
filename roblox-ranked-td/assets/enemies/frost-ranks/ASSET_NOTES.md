# Légion du givre — palier visuel 3, vagues 31 à 40

Sources 3D destinées à Claude pour import et variantes. Pas encore installées dans le jeu.

| Rôle | Nom cible du modèle | Premier FBX |
| --- | --- | --- |
| Écuyer | Swarm_3 | Swarm_3_Walking_Studio.fbx |
| Fantassin | Normal_3 | Normal_3_Walking_Studio.fbx |
| Cavalier | Fast_3 | Fast_3_Gallop_Studio.fbx |
| Chevalier lourd | Tank_3 | Tank_3_Walking_Studio.fbx |
| Colosse | Giant_3 | Giant_3_Walking_Studio.fbx |

Les fichiers `*_Death_Studio.fbx` fournissent la mort séparément. Les GLB incluent les clips nommés ; les `.blend` sont les sources éditables, avec les actions conservées dans les pistes NLA. Texture unique et mesh unique par modèle. 1024 px pour les humains, 2048 px pour le cavalier. De 4543 à 7692 triangles selon le rôle.

Les humains conservent les 41 os et matrices de repos de la base KayKit, avec Idle, Walking_A, Running_A et Death_A. Le cavalier conserve les 48 os, Rider sous Back, le galop et la mort du cavalier carmin corrigé. Les cristaux sont des sommets skinnés aux os existants, pas de nouveaux os ou de pièces physiques supplémentaires. Conserver noms, parents et matrices de repos pour les prochaines variantes.

`validation.json` : contrôles de réimportation des cinq GLB, UV, texture, échelles, poids et poses. `validation-fbx.json` : réimportation des dix FBX à 30 images/s, mouvements des membres, échelles uniformes, squelettes de repos identiques entre clips, quatre influences maximum par sommet. Les quatre pattes du cheval bougent. `apercu-famille.png` est un rendu des GLB exportés puis réimportés, avec des tailles de présentation seulement.

**Validation Studio givre : en attente.** Les galops carmin et cuivre ont été confirmés par le propriétaire, pas ce nouveau cavalier. Tester avec la même procédure sur un nouvel import, garder les anciens modèles intacts, puis enregistrer les `.rbxm` sous les noms exacts seulement après validation. Aucun identifiant d'animation n'est publié dans cet envoi.

Sources humaines KayKit Adventurers, CC0 : licence dans `../variant-source-kit/LICENSE-KayKit-CC0.txt`. Cheval Quaternius réutilisé depuis la base carmin, voir `../crimson-ranks/ASSET_NOTES.md`.

Traitement local : aucune requête Meshy, aucun crédit consommé. Aucun gameplay, chiffre, interface, outil ou boss modifié.

# Légion des os — palier 5, vagues 51 à 60

Sources visuelles transmises pour Claude après validation du rendu par le propriétaire le 30 septembre 2026, puis sa demande d'envoi sur GitHub. Pas encore installées dans Roblox. Le Roi mort-vivant de la vague 60 reste un boss séparé.

| Rôle | Nom Roblox cible | Premier FBX |
| --- | --- | --- |
| Écuyer | Swarm_5 | Swarm_5_Walking_Studio.fbx |
| Fantassin | Normal_5 | Normal_5_Walking_Studio.fbx |
| Cavalier | Fast_5 | Fast_5_Gallop_Studio.fbx |
| Chevalier lourd | Tank_5 | Tank_5_Walking_Studio.fbx |
| Colosse | Giant_5 | Giant_5_Walking_Studio.fbx |

Style : revenants en armure sombre, tissus violets, crânes en volume avec dents et yeux verts. Les têtes humaines originales ont été retirées par pièces entières (tête, yeux, nez, oreilles, sourcils, petits visors des lourds). Le nouveau crâne remplace la tête sous le casque, pas un masque ajouté devant le visage. Le cavalier reçoit le même crâne adapté à sa pose montée. Les corps et rigs existants restent réutilisés. Le cheval garde sa géométrie originale, avec robe gris sombre et ornements d'os. Les ornements sont liés aux os existants et réunis dans un mesh et un matériau par unité.

De 5258 à 8464 triangles par modèle, textures 1024 px pour les humains et 2048 px pour le cavalier. Humains : 41 os KayKit avec Idle, Walking_A, Running_A, Death_A. Cavalier : 48 os de la base corrigée, Rider enfant de Back, Gallop et Death. Noms et poses de repos sont inchangés ; conserver ces rigs pour toute variante future.

Les GLB incluent les clips et textures ; les `.blend` sont les sources regroupées et éditables. FBX à 30 images/s, marche/galop et mort séparés, textures PNG de secours. validation.json et validation-fbx.json documentent les réimports Blender : poids normalisés, quatre influences maximum dans les FBX, squelettes de repos correspondants, échelles fixes et mouvement des jambes/quatre pattes. L'aperçu est un rendu des GLB réimportés.

**Studio : à confirmer.** Les anciens galops carmin/cuivre confirmés ne valident pas ce nouveau cavalier. Tester les deux clips sur un nouvel import Custom avant de publier les animations et enregistrer les `.rbxm`. Aucun identifiant Roblox, `.rbxm` ou code gameplay/UI/tools n'est modifié. Les tailles de présentation ne changent aucune statistique ; pas de mesure de performance Studio revendiquée.

Licence humaine : KayKit Adventurers CC0, ../variant-source-kit/LICENSE-KayKit-CC0.txt. Cheval : base Quaternius héritée du cavalier carmin, ../crimson-ranks/ASSET_NOTES.md. Travail entièrement local, aucun appel Meshy et 0 crédit consommé.

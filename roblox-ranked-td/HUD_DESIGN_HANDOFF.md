# HUD et panneaux — 30 septembre 2026

Présentation uniquement, sur `claude/exciting-gauss-ggwcwm`.

- Palette ardoise/or, chiffres principaux distincts et textes secondaires plus discrets.
- Parcelle : cartes de tours défilantes, dégâts par coup (ou dégâts/s pour le rayon), cadence, portée, détails et runes. Les confirmations de vente/remplacement et les noms utilisés par le tutoriel sont conservés.
- Autel/forge : contenu défilant, achats et fermeture fixes, quantités défilantes horizontalement et résultat amené dans la zone visible. Prix, chances, blocages et achats serveur inchangés.
- Ranked : santé, or et revenu séparés ; boutique et niveaux de tours défilants sur téléphone sans écraser horizontalement les textes.
- Entrées : support `Sign` réutilisé avec plaque `OwnerBoard` recto verso, nom, pseudonyme et vignette d'avatar. Les six parcelles ont le même panneau et la même construction locale. La couleur de chaque parcelle reste distincte.
- Centre : classement existant habillé et recopié en direct sur l'autre face ; deux panneaux Ranked identiques de chaque côté du mur, chacun recto verso. Aucun second système de classement ou de matchmaking.

## Intégration

Deux nouveaux modules sont requis automatiquement par `HubMap` : `PlotIdentity` et `RankedBoardDisplay`. `Hub/init`, `Plots`, les fichiers d'équilibrage et `tools/` ne sont pas modifiés. L'interface `ownerLabel` de `Plots` reste compatible ; l'identité affichée suit `OwnerUserId` publié par `PlotGame`.

La vignette est récupérée avec l'API Roblox, avec cache, trois tentatives maximum et initiale de secours. Une réponse tardive ne peut pas afficher l'avatar de l'ancien propriétaire.

Les effets de combat en préparation ne sont pas inclus dans cet envoi.

## Vérification

139 assertions automatisées avec mocks : dimensions ordinateur/téléphone, construction des vrais modules d'interface, requête d'achat, forge bloquée, sélection de tour, DPS ranked, vignette, réattribution de parcelle et synchronisation du classement. Compilation des scripts et construction Rojo réussies.

Ce n'est pas une validation visuelle dans Roblox Studio. Après récupération en conservant les modifications locales de Claude, vérifier : panneau d'entrée et avatar, lecture recto verso, autel/forge et résultats, pose/amélioration/runes, tutoriel, et affichage sur mobile. Aucun test Studio ni mesure FPS n'est revendiqué.

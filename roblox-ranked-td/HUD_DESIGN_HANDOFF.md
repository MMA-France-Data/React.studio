# HUD et panneaux — 30 septembre 2026

## Après essai à la taille d'un vrai téléphone — 1 octobre 2026 (Claude)

L'envoi « Correction lisibilité » ci-dessous a été testé dans Studio avec la fenêtre réduite à la taille d'un
téléphone (`tools/studio-test/phone.ps1`, nouveau : 706 × 300, l'écran du propriétaire, puis 750 × 332, 568 × 262 et
645 × 268). Gardé : le panneau des tours sur presque tout l'écran, les pages ◀ ▶, « Détails & effets ». Changé :

- **Ordinateur et tablette : comme avant l'envoi.** Panneau des tours en bas de l'écran (760 × 460, à côté du chat,
  4 cartes par page ; 760 × 566 et les 8 tours d'un coup quand l'écran fait au moins 790 px de haut). Le grand
  panneau centré de 1040 × 720 cachait la vue, le compteur de pièces et le tuto (10 tests du tuto échouaient).
  Flèches ◀ ▶ cachées quand il n'y a qu'une page.
- **`UI.touchLayout` = `UI.isPhone`** (la taille de l'écran seulement, plus « tactile sans clavier ») : une tablette
  garde la disposition d'ordinateur, et le test peut afficher exactement ce que voit un téléphone.
- **Raccourcis sur téléphone** (disposition choisie par le propriétaire, d'après deux captures d'autres jeux Roblox
  sur son téléphone) : Autel et Forge = deux icônes carrées de 38 px contre le bord droit (🏰, 🔨) ; Renaissance =
  un petit bouton avec son nom et son gain dessous (104 × 36), contre le bord droit sous les icônes ; Boutique =
  son bouton « ★ BOUTIQUE » (104 × 34) en haut à gauche, sous les boutons de Roblox ; Défis = une icône ⚔ à droite
  (`UI.leftColumnSlot`, `UI.placeInLeftColumn(bouton, index, icône)`). Les icônes sont des emojis : de vraies
  icônes dessinées (images) peuvent les remplacer, il suffit de changer l'étiquette « PhoneIcon » en ImageLabel. La
  barre de 5 boutons de 44 px sous le compteur passait devant le haut de la vue.
- **Compteur de pièces, SON et Vitesse petits, dans la barre du haut de Roblox** (demande du propriétaire : « l'icône
  son est trop grande et gêne, et même mes pièces ») : « 💰 22.6M » sans titre (120 × 34), SON = une icône, Vitesse
  = « x1 » / « x2 » (40 × 34), tout en haut à droite, au-dessus de la zone de jeu (`UI.phoneTopRight`, hauteurs
  négatives). Plus rien au milieu de la vue.
- **Bouton « ▲ »** (demande du propriétaire : pouvoir masquer, sans jamais perdre le bouton) : collé au compteur de
  pièces, il cache les raccourcis, SON et Vitesse et devient « ▼ » ; il ne bouge pas et les remet
  (`UI.startShortcutToggle`). L'astuce de la Renaissance et la fin du tuto les remettent toutes seules.
- **Tuto sur téléphone** : panneau tout en haut de la zone de jeu, au milieu (il était au milieu de l'écran), et son
  astuce finale parle des icônes 🏰 et 🔨 « à droite ».
- **Panneau des tours sur téléphone** : 4 cartes par page dès 560 px de large (2 avant), pièces du joueur à côté du
  X (le panneau couvre le compteur), fiche resserrée sur les écrans bas (sur 645 × 268, « Détails & effets » et
  « Remplacer… » passaient sous la ligne des runes), ligne des runes cachée pendant « Détails & effets ».
- **Autel et forge sur téléphone** : dans une fenêtre basse, titre et bas resserrés et sous-titre retiré ; il ne
  restait que 2 px de haut aux chances (elles doivent se voir : le lancer Robux est un objet aléatoire payant).

## Correction lisibilité PC / téléphone — 1 octobre 2026

- `TowerPanel` centré, jusqu'à 1040 × 720 sur PC ; presque toute la zone sûre sur téléphone, portrait comme paysage (tactile sans clavier compris). Aucun rétrécissement global des textes.
- Les cartes entières restent dans le panneau : huit à la fois sur les grands écrans, pages ◀ / ▶ quand la hauteur manque. Plus de défilement vertical pour choisir une tour. La première page conserve `Card_MachineGun` pour le tutoriel.
- Dégâts, cadence et portée restent fixes sur la fiche. Sur les petits écrans, « Détails & effets » ouvre les explications séparément ; achats, amélioration, vente, remplacement et runes conservent leurs règles / confirmations.
- Raccourcis Autel, Forge, Renaissance, Boutique et Défis en haut sur mobile, hors de la zone du joystick ; ils se cachent pendant la consultation d'une tour et reviennent à sa fermeture.
- `LangEN/Plot` reçoit uniquement les trois nouvelles traductions d'interface. Aucun changement de chiffres, de serveur ni de `tools/`.
- Vérification locale : 236 assertions de construction / comportement avec mocks, 73 scripts compilés et construction Rojo réussie. Cela ne remplace pas les essais Studio / appareil réel : tester rotation, tutoriel, runes, vente et remplacement.

Les sections ci-dessous décrivent l'envoi initial du 30 septembre ; les cartes défilantes mentionnées ci-dessous sont remplacées par la pagination ci-dessus.

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

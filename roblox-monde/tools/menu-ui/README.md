# MONDE : menus et icônes

Passe de présentation sur le HUD et les cinq fenêtres existantes : œufs, familiers,
sac, épée et boutique. Aucun nouveau service, image à importer ou achat externe.

- `src/client/MenuUI.luau` : palette, contours, styles de texte et pictogrammes natifs.
- `src/client/MenuLayout.luau` : dispositions PC, téléphone paysage et portrait.
- `src/shared/NumberFormat.luau` : grands nombres abrégés, avec virgule en français.
- `Main.client.luau` et la partie menus de `Animals.luau` utilisent ces styles.

Les noms d'objets existants, traductions, événements réseau et règles du jeu sont
conservés. Les portraits restent les ViewportFrame du jeu. Les nouveaux noms
`Glyph`, `MenuHeader`, `MenuIcon`, `AnimalName`, `MenuBackdrop`, `ActionCaption`,
`ActionIcon` et `ActiveMark` ne servent qu'à l'affichage. `Sheet` reste au même
emplacement et garde ses enfants ; son type devient ScrollingFrame pour rendre
les actions du bas accessibles sur téléphone.

## Vérification sans prendre la main sur l'écran

Depuis `roblox-monde` :

```powershell
./tools/studio-test/check.ps1
```

Requiert les outils déjà utilisés par le projet : Node, Luau et Rojo. Aucune
installation ni ouverture de Studio. Le contrôle des menus exécute le vrai HUD
et la vraie section menus de `Animals` avec des services Roblox simulés :

- 1 136 assertions de disposition, contraste, nombres et actions ;
- huit dimensions, dont 706 × 300, 360 × 640 et 320 × 568 ;
- ouverture/fermeture des cinq fenêtres, états des achats et de l'attaque auto ;
- arguments des actions équiper/ranger/acheter et double confirmation de nourrissage ;
- compilation de tous les fichiers Luau et construction du jeu ;
- contrôle existant des deux attaques, sans les modifier.

Les résultats et instantanés de propriétés sont placés dans un dossier temporaire
`monde-menu-ui-*`. Ces tests ne remplacent pas une validation visuelle dans
Roblox Studio, notamment des portraits 3D, polices et commandes tactiles natives.

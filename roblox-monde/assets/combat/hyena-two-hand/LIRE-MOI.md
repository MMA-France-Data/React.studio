# HyenaFang — prise à deux mains

Une seule arme, repos sur l'épaule droite, deux coupes horizontales opposées avec les deux paumes sur le même manche. Les hanches et les pieds reprennent le combat circulaire existant ; le rythme, les événements de frappe et les dégâts ne changent pas.

`R15Preview.rbxmx` : rig de contrôle avec un dossier `Animations`. `Idle.rbxmx`, `SlashRight.rbxmx`, `SlashLeft.rbxmx` : séquences natives, 0,38 s pour chaque attaque, un seul repère `Impact` à 0,1824 s. Les clips natifs correspondent aux proportions du rig de référence ; le client utilise `TwoHandSwordMotion` pour adapter les bras au personnage réel.

Le vrai modèle `Sword_HyenaFang.fbx` se trouve dans `assets/swords-roblox/HyenaFang`. Le plugin de rangement lui ajoute `TwoHanded`, `RightHold`, `LeftHold`. Seule cette épée utilise la nouvelle pose ; elle ne duplique pas la lame dans la main gauche.

Après import et rangement, valider sa place dans `SwordPalette.gameOrder`. Les rangs sauvegardés, les prix et les dégâts ne sont pas déplacés par cette livraison. Les modèles importés dans le compte et l'essai en Play/sur téléphone restent à faire.

`Apercu-hyena-deux-mains.png` et `Hyena-deux-mains-ralenti.gif` sont des rendus de contrôle 3D, pas des captures Roblox. Le ralenti ×2 n'est pas la vitesse du jeu. `VERIFICATION.json` décrit la vérification géométrique de référence ; `tools/swords/check-two-hand.cjs` teste les vrais modules client sur plusieurs proportions.

Contrôle : `node tools/swords/check-two-hand.cjs` puis `./tools/swords/check.ps1` depuis `roblox-monde`. Le script ancien `tools/studio-test/check.ps1` a été supprimé en amont ; le contrôle restant compile tous les fichiers du client et construit le jeu avec Rojo.

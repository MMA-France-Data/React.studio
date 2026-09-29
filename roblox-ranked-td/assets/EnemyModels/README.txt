MODÈLES PERSO DES MONSTRES (mode solo)
======================================

Chaque fichier .rbxm (ou .rbxmx) de ce dossier = un modèle de monstre. Rojo le range dans
ReplicatedStorage > EnemyModels, avec le nom du fichier. Les ennemis du mode solo de ce type
l'utilisent à la place des blocs. Le ranked ne change pas.
(Dans Studio, ce fichier apparaît aussi dans EnemyModels, en StringValue « README » : c'est normal.
Garde-le : sans lui, un dossier vide n'irait pas sur GitHub et rojo build échouerait.)

NOM DU FICHIER = QUEL MONSTRE
  Normal = Fantassin          Fast  = Cavalier
  Tank   = Chevalier lourd    Boss  = Seigneur de guerre
  Swarm  = Écuyer             Giant = Chevalier colossal

  Boss.rbxm     -> le boss de toutes les vagues
  Boss_9.rbxm   -> le boss des vagues 91 à 100 seulement (passe avant Boss.rbxm)
  Swarm_0.rbxm  -> les écuyers des vagues 1 à 10
  Le chiffre = la tranche de 10 vagues : _0 = vagues 1-10, _1 = 11-20 ... _9 = 91-100,
  puis ça recommence (vagues 101-110 = _0).
  Pas de fichier pour un type = les blocs habituels.

ÉTAPES (exemple : un gobelin pour les écuyers, son chef pour le boss)
  1. Ouvre le jeu dans Studio. Toolbox (onglet Accueil > Boîte à outils) : cherche « goblin » et
     clique sur un modèle pour l'insérer. Ou importe ton fichier 3D (Meshy, Tripo, Mixamo...) :
     Accueil > Importer 3D.
  2. SÉCURITÉ : dans l'Explorer, déplie tout le modèle et supprime TOUS les Script, LocalScript et
     ModuleScript. Repère-les à leur icône de script, pas à leur nom : une porte dérobée porte
     souvent un nom anodin (« Weld », « Config »...). Le jeu les retire aussi tout seul et l'écrit
     dans la Sortie, mais un script piégé peut agir avant.
     Exception utile : si c'est un personnage Roblox avec un LocalScript « Animate », déplie-le,
     glisse l'Animation « WalkAnim » (dans « walk ») directement dans le modèle, renomme-la
     « Marche », puis supprime le script : ton monstre gardera sa marche.
  3. Renomme le modèle : Swarm (ou Swarm_0...), Boss, etc. Pas besoin de régler sa taille ni sa
     position : le jeu le met à la bonne hauteur, les pieds au sol.
  4. Pour l'essayer tout de suite : glisse-le dans ReplicatedStorage > EnemyModels (crée un
     Folder nommé « EnemyModels » s'il n'existe pas), puis Play. Le bouton « GALERIE (Studio) »
     montre tous les ennemis ; une plaque dit « modèle perso » ou « blocs » sous chacun.
  5. Pour le garder : clic droit sur le modèle > « Enregistrer dans un fichier... » (Save to
     File...), choisis CE dossier et le même nom (Swarm.rbxm). Un seul modèle par fichier.
     Ensuite rojo build (ou rojo serve), et pousse le fichier sur GitHub.

RÉGLAGES FACULTATIFS (attributs du modèle : Propriétés > Attributs > +, type Number)
  FacingOffset : il marche à reculons -> 180 ; de côté -> 90 ou -90.
  HeightScale  : 1.3 = 30 % plus grand, 0.8 = 20 % plus petit.
  AnimSpeed    : vitesse de l'animation de marche (si les pieds glissent), 1 par défaut.

ANIMATIONS DE MARCHE ET DE MORT (facultatif)
  Le plus simple : publie tes animations (Animation Editor > Publier sur Roblox) et donne leurs
  numéros à Claude, qui les écrit dans CustomModels.SETTINGS (src/shared/CustomModels.luau).
  Sinon, dans le modèle : un objet Animation nommé « Marche » (ou « Walk », « Walking ») et un
  nommé « Mort » (ou « Dead », « Death »), chacun avec son AnimationId. La mort est jouée une fois
  quand le monstre est tué (le corps reste un instant puis s'efface) ; la galerie la montre
  toutes les 6 s.
  Il faut un personnage articulé (Humanoid ou AnimationController, avec des Motor6D ou des os).
  L'animation doit être à toi (publiée avec ton compte depuis l'Animation Editor, par exemple
  une marche Mixamo importée) ou à Roblox : sinon Roblox refuse de la jouer et le monstre avance
  sans bouger les jambes. Si c'est ta communauté (groupe) qui publie le jeu, publie l'animation
  pour la communauté. Elle est jouée plus lentement quand il est ralenti, figée quand il est
  étourdi, 2 fois plus vite avec la Vitesse x2.

SENS DE MARCHE
  Trouvé tout seul pour un personnage à os (orteils, ou tête d'un cheval). Si son animation le
  retourne d'un demi-tour (défaut de l'import de Studio : Roi carmin, fantassin), le jeu le mesure
  et le corrige tout seul.

IMPORTER UN .GLB AVEC SES ANIMATIONS
  Fichier > Importer le fichier qui contient le modèle ET l'animation (rig « Custom »), puis
  Éditeur d'animation > ⋯ > Charger > Publier sur Roblox. L'import d'un clip seul dans l'Éditeur
  d'animation (⋯ > Importer > depuis un fichier) marche mal avec ces fichiers. Enregistre toujours
  le « Scene » qui est sous Workspace (pas celui de ServerStorage > RBX_ANIMSAVES).

MODÈLES EN PLACE : vagues 1-10 : Boss_0 (Roi carmin), Normal_0, Tank_0, Giant_0 (troupes carmin) ;
  vague 20 : Boss_1 (Chef pillard de cuivre, importé en FBX : ses GLB lui retournaient la tête).
  Le cavalier (Fast_0) attend un squelette corrigé.
  Si un GLB s'anime mal dans Studio, essayer le même modèle en FBX (ça a marché pour le chef).

ROI CARMIN (ChatGPT : assets/enemies/crimson-king/RoiCarmin_Studio.glb)
  Boss des vagues 10, 110, 210... Un .glb ne passe pas par Rojo : importe-le une fois dans Studio
  (Importer, type de rig « Custom »), enregistre le modèle ici sous le nom Boss_0.rbxm, puis publie
  ses animations « Walking » et « Dead » et donne leurs numéros à Claude.

PERFORMANCES
  Des dizaines d'ennemis par parcelle (IdleConfig.MAX_ENEMIES au plus) sur 6 parcelles : préfère
  des modèles légers (quelques MeshPart, pas des centaines de pièces), sans sons ni particules en
  masse.

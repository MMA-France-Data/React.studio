# Avant la sortie du jeu

Liste des choses à faire avant de rendre le jeu public. On coche au fur et à mesure.

## Contenu du jeu

- [ ] Monstres des vagues 51 à 100 : troupes et boss importés dans Studio, puis vérifiés par les tests
      (toutes les troupes 1-100 sont faites ; boss faits : 10, 20, 30, 40, 50, 70, 80 et le dragon de la vague 100 ;
      restent le boss 60 (Roi mort-vivant, fichier donné à part), le boss 90 (orc) et la mort du dragon).
- [x] Tuto pour les nouveaux joueurs : arène classée, ta parcelle, poser une tour, l'améliorer, lancer
      l'autel une fois, la forge (à essayer toi-même dans Studio : il s'affiche à chaque Play).
- [x] Monstres et tirs des autres parcelles affichés seulement quand on s'en approche ; interactions
      seulement avec sa propre parcelle (à revoir à 2 joueurs dans le jeu publié).
- [x] Limite de tours identiques sur sa parcelle : 5 par tour commune, 4 par rare, 3 par épique, 2 par
      légendaire (mode solo seulement ; les tours déjà posées au-delà sont gardées).
- [x] Fenêtres de l'autel, de la forge et de la renaissance adaptées aux téléphones (trop grandes : le
      bouton x1 sort presque de l'écran). Toutes les fenêtres se réduisent pour tenir à l'écran, et la colonne
      de boutons de gauche aussi (la Boutique et les Défis sortaient de l'écran). À revoir sur un vrai téléphone.
- [ ] Sons : écoutés et validés dans Studio (bouton « SONS (Studio) »).

## Publication (Studio et Creator Dashboard)

- [x] Publier le jeu sur ton compte personnel (Fichier > Publier sur Roblox) : « Tower 22 », privé, publié le 30/09.
      Mises à jour : ouvrir la copie propre préparée par Claude, Publier sur Roblox > « Mettre à jour l'expérience
      existante… » > Tower 22.
- [x] Taille des serveurs : 6 joueurs (une parcelle par joueur) : Hub Création > Lieux > Tower 22 > Accès.
- [x] Remplir le questionnaire sur le contenu : fait le 30/09 (violence légère répétée -> « Léger » ; objets aléatoires
      payants : oui, et PolicyService respecté ; tout le reste : non).
- [x] Créer les pass (30/09) et les mettre dans le jeu (`Config.GamePasses`) : Auto Collect 99, Speed x2 199,
      Coins x2 249. Un pass « Forge Spin » créé par erreur reste sans prix : personne ne peut l'acheter.
- [x] Lancer de la forge en Robux (produit « Forge Spin », 49 Robux) RETIRÉ du jeu le 01/10 : plus aucun objet
      aléatoire payant (l'autel et la forge ne se paient qu'en pièces gagnées en jouant). Les chances affichées par
      la forge font toujours exactement 100 %.
- [ ] Après la publication de cette version : refaire le questionnaire sur le contenu (objets aléatoires payants :
      non). Pas avant : tant que l'ancienne version tourne, le lancer Robux existe encore.
- [x] Version anglaise (décidé le 30/09 : pas de sortie sans elle) : les joueurs francophones gardent le
      français, tous les autres voient l'anglais, phrases à chiffres comprises (src/shared/Lang.luau,
      dictionnaires src/shared/LangEN, voir le README). Le test Studio « version anglaise » dit 0 texte encore en
      français. La traduction automatique de Roblox peut se réactiver toute seule : le jeu protège déjà ses textes
      anglais (AutoLocalize = false) ; à faire plus tard : la même protection pour les textes français.
- [ ] Page du jeu (Hub Création) : description anglaise « Ranked 1v1 coming soon » (et sa traduction française dans
      Localisation), icône, miniatures (sa miniature + images du tournage : Vidéos\Tower 22\Images), vidéo
      `Vidéos\Tower 22\Tower22-compilation-finale.mp4` (17,8 s ; Roblox : 30 s au plus, en anglais, compte vérifié de
      13 ans et plus pour l'envoyer).
- [ ] Public des moins de 16 ans (règles Roblox 2026) : tout nouveau jeu commence en 16+ ; pour Roblox Kids (5-8 ans)
      et Select (9-15 ans) : âge vérifié, double authentification, Roblox Premium 2 mois de suite (ou frais
      remboursables), puis 250 parties de joueurs « très engagés » en 60 jours (tableau « Audience Reach »).

## Le classé (sortie sans lui, décidé le 30/09)

- [x] Classé fermé pour la sortie : `Config.RANKED_OPEN = false` (dans le cercle « BIENTÔT DISPONIBLE », le serveur
      refuse tout, défis classés cachés, tuto adapté). La description du jeu doit le dire : « Ranked 1v1 coming soon ».
- [ ] Avant de l'ouvrir : classé avec 2 vrais joueurs (inscription dans le cercle, « MATCH TROUVÉ ! », accepter, match,
      retour sur la map), dans une version publiée avec le classé ouvert (jeu encore privé, ou une copie du jeu).
- [ ] Ouvrir le classé : `Config.RANKED_OPEN = true` (dans `src/shared/Config.luau`), puis publier la mise à jour.

## Derniers essais dans le jeu publié

- [ ] Boutique : tu possèdes déjà tes 3 pass (le créateur d'un pass l'a toujours) ; un ami achète le plus petit
      (Auto Collect, 99) et vérifie qu'il marche tout de suite.
- [ ] Classement solo (panneaux « CLASSEMENT SOLO » à l'est et à l'ouest de la place) : avec les vrais DataStores,
      vérifier qu'on y apparaît (record de vague et DPS, mis à jour chaque minute) depuis deux serveurs différents,
      et la liste des joueurs (colonnes DPS et Money).
- [ ] Sur téléphone : boutons, textes, tuto, fluidité.
- [ ] Rendre le jeu public.

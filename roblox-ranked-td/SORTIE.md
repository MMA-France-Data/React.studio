# Avant la sortie du jeu

Liste des choses à faire avant de rendre le jeu public. On coche au fur et à mesure.

## Contenu du jeu

- [ ] Monstres des vagues 51 à 100 : troupes et boss importés dans Studio, puis vérifiés par les tests
      (vagues 51-60 : troupes faites, boss 60 à importer ; boss 70 et 80 faits ; troupes 61-100 et boss 90 / 100
      pas encore livrés par ChatGPT ; le dragon est le boss de la vague 100).
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

- [ ] Publier le jeu sur ton compte personnel (Fichier > Publier sur Roblox).
- [ ] Taille des serveurs : 6 joueurs (une parcelle par joueur).
- [ ] Autoriser l'accès de Studio aux services API (sauvegardes testables dans Studio).
- [ ] Remplir le questionnaire sur le contenu (âge conseillé), obligatoire pour être public.
- [ ] Créer les pass (Ramassage auto, Vitesse x2, Pièces x2) et le produit Robux, puis donner leurs
      numéros à Claude pour les mettre dans le jeu.
- [ ] Version anglaise (décidé le 30/09 : pas de sortie sans elle) : les joueurs francophones gardent le
      français, tous les autres voient l'anglais, phrases à chiffres comprises (src/shared/Lang.luau,
      dictionnaires src/shared/LangEN, voir le README). Le test Studio « version anglaise » doit dire
      0 texte encore en français ; puis jouer un peu avec Config.STUDIO_LANGUAGE = "en" pour relire l'anglais.
      Ne PAS activer la traduction automatique de Roblox (Creator Dashboard, Localisation) : elle prendrait
      les textes anglais pour du français.

## Derniers essais dans le jeu publié

- [ ] Classé avec 2 vrais joueurs : inscription dans le cercle, « MATCH TROUVÉ ! », accepter, match,
      retour sur la map.
- [ ] Sur téléphone : boutons, textes, tuto, fluidité.
- [ ] Rendre le jeu public.

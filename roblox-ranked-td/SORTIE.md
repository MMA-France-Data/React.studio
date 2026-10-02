# Avant de rendre le jeu public

Liste des choses à faire avant d'ouvrir le jeu à tout le monde. On coche au fur et à mesure.

Le jeu sort comme une **nouvelle expérience Roblox** (décision du 02/10/2026) : plus rien n'est publié sur
« Tower 22 ». L'ancien jeu est gardé dans le dépôt, à l'étiquette git `ancien-jeu-complet`.

## Le jeu lui-même

- [x] 20 niveaux en 2 territoires (les niveaux 11 à 20 ajoutés le 02/10/2026 : autre carte, monstres suivants), camp
      d'entraînement, évolutions des tours, boutique à prix fixes (voir `NIVEAUX.md`).
- [x] Tout l'ancien jeu enlevé (classé, autel, forge, vagues infinies, renaissance, défis, passes, ancien tuto).
- [x] **Tuto** pour un nouveau joueur : une flèche dorée lui montre quoi toucher, du camp à la fin du niveau 1,
      puis la boutique (voir `NIVEAUX.md`, « Le tuto des nouveaux joueurs »). Celui qui la suit gagne le niveau 1.
- [x] **Version anglaise** : tous les écrans, le tuto, les messages et les panneaux sont traduits pour les joueurs
      non francophones (voir `README.md`, « Langues »). Vérifié par `run.ps1 -Test english` : aucun texte ne reste
      en français.
- [ ] **Essai sur un vrai téléphone** : boutons, textes, pose d'une tour au doigt, zoom en pinçant, fluidité. (Les
      tests automatiques ne vérifient que la taille de l'écran, pas le toucher.)
- [ ] **Un nouveau joueur passe-t-il le niveau 1 ?** La difficulté est réglée avec des joueurs simulés et un seul
      vrai joueur (toi). Le tuto aide : un joueur simulé qui suit seulement la flèche gagne le niveau 1.
- [ ] **Joue les niveaux 11 à 20** : ils n'ont été essayés que par les joueurs simulés (trop durs ? trop faciles ?).
- [x] La Baliste et le Trébuchet renforcés (02/10/2026, voir `NIVEAUX.md`, « Ce que chaque tour de la boutique
      apporte »).
- [ ] Les niveaux 21 et plus (une carte et un réglage par territoire) : après la sortie.
- [ ] Monstres : il manque les boss des territoires 6 et 9 (niveaux 60 et 90) et la mort du dragon. Sans importance
      tant que le jeu a 20 niveaux.
- [ ] Des passes Robux pour ce jeu ? Il n'y en a plus aucun.

## Publication (Studio et Hub Création)

- [ ] Publier comme une **nouvelle expérience** sur ton compte personnel (Fichier > Publier sur Roblox > « Créer une
      nouvelle expérience »), en privé. Les mises à jour ensuite : ouvrir la copie propre préparée par Claude,
      Publier sur Roblox > « Mettre à jour l'expérience existante… » > la nouvelle expérience (**pas** « Tower 22 »).
- [ ] Sur ton compte, pas sur une communauté : les animations des monstres sont publiées sur ton compte, elles ne se
      jouent que dans tes expériences.
- [ ] Taille des serveurs : **6 joueurs** (une parcelle par joueur) : Hub Création > Lieux > le lieu > Accès.
- [ ] Questionnaire sur le contenu : violence légère répétée -> « Léger » ; objets aléatoires payants : **non**
      (plus aucun tirage, plus aucun achat) ; tout le reste : non.
- [ ] Ne pas activer la traduction automatique de Roblox (Hub Création > Localisation).
- [ ] Page du jeu : nom, description (français et anglais), icône, miniatures, vidéo (Roblox : 30 s au plus, textes
      et son en anglais, compte vérifié de 13 ans et plus pour l'envoyer). Les images et vidéos tournées pour
      « Tower 22 » montrent l'ancien jeu : à refaire. Une description prête à coller est plus bas (« Textes pour la
      page du jeu »).
- [ ] Public des moins de 16 ans (règles Roblox 2026) : tout nouveau jeu commence en 16+ ; pour Roblox Kids (5-8 ans)
      et Select (9-15 ans) : âge vérifié, double authentification, Roblox Premium 2 mois de suite (ou frais
      remboursables), puis 250 parties de joueurs « très engagés » en 60 jours (tableau « Audience Reach »). Ne pas
      payer l'examen accéléré.

## Textes pour la page du jeu (à coller, à changer comme tu veux)

Le nom du jeu est à toi de choisir. Description en anglais (c'est elle que la plupart des joueurs liront) :

```text
Defend your castle in fast 2-3 minute levels!

- Place your towers anywhere and upgrade them non-stop: the monsters never stop getting stronger.
- 20 levels across 2 territories, with mini-bosses and bosses.
- 8 towers to unlock in the shop: fixed prices, no luck.
- Your own training camp: your towers train and evolve, even while you're away.
- Plays on PC and phone. No pay-to-win.
```

La même en français :

```text
Défends ton château dans des niveaux rapides de 2 à 3 minutes !

- Pose tes tours où tu veux et améliore-les sans arrêt : les monstres deviennent de plus en plus forts.
- 20 niveaux dans 2 territoires, avec des mini-boss et des boss.
- 8 tours à débloquer à la boutique : prix fixes, aucun hasard.
- Ton camp d'entraînement : tes tours s'entraînent et évoluent, même quand tu es parti.
- Sur ordinateur et sur téléphone. Rien à acheter pour gagner.
```

## Derniers essais dans le jeu publié (encore privé)

- [ ] Le tuto : à ta première visite, la flèche t'emmène au niveau 1 puis à la boutique ; à la deuxième, elle ne
      revient pas.
- [ ] La sauvegarde : gagner un niveau, quitter, revenir : le niveau, les pièces et les tours achetées sont là.
- [ ] L'entraînement pendant l'absence : mettre une tour dans le camp, revenir une heure plus tard.
- [ ] À deux joueurs : chacun sa parcelle, on voit le camp de l'autre en s'approchant, les invites de l'autre
      parcelle ne marchent pas, deux niveaux joués en même temps.
- [ ] Les sons et les animations des monstres se chargent (dans une nouvelle expérience, une animation qui ne
      t'appartient pas ne se joue pas : le monstre glisse sans bouger les jambes).
- [ ] Rendre le jeu public.

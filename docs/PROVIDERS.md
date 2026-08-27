# Brancher un provider de personnage

Le rendu du personnage est la seule brique que `reaction-studio` ne fabrique
pas lui-même. Elle passe par une commande externe, ce qui permet de brancher
n'importe quel service (hébergé ou local) sans modifier le pipeline.

## Le contrat

Vous fournissez une commande dans `RS_AVATAR_CMD`. Quatre placeholders sont
remplacés à l'exécution :

| Placeholder | Contenu |
|---|---|
| `{audio}` | la piste voix complète, WAV 48 kHz mono, de la longueur exacte de la vidéo |
| `{image}` | le portrait du personnage (`RS_REACTOR_IMAGE`), chaîne vide si non défini |
| `{out}` | le fichier vidéo à écrire |
| `{duration}` | la durée attendue, en secondes |
| `{width}` | largeur du panneau du personnage, en pixels |
| `{height}` | hauteur du panneau du personnage, en pixels |

La commande doit écrire une vidéo à `{out}`. **Ni le cadrage ni la durée n'ont
besoin d'être exacts** : le montage recadre au format du panneau et cale sur la
durée (le dernier cadre est figé si le clip est trop court, il est coupé s'il
est trop long).

```bash
RS_AVATAR_PROVIDER=cmd \
RS_REACTOR_IMAGE=./assets/personnage.jpg \
RS_AVATAR_CMD='./mon-provider.sh {image} {audio} {out} {duration}' \
node bin/rs.js render ma-video.mp4
```

## Exemple fourni, qui marche tout de suite

`examples/providers/still-zoom.sh` : un portrait avec un lent zoom avant. Pas
de synchronisation labiale, mais aucun service externe, aucun coût, et un cadre
qui ne semble pas figé. Il gère les portraits détourés (fond transparent) en
composant le sujet sur un fond uni, et se règle avec `RS_REACTOR_BG`,
`RS_REACTOR_FILL` (plan plus ou moins serré) et `RS_REACTOR_Y` (hauteur du
sujet dans le cadre).

```bash
RS_AVATAR_PROVIDER=cmd \
RS_REACTOR_IMAGE=./assets/personnage.jpg \
RS_AVATAR_CMD='./examples/providers/still-zoom.sh {image} {out} {duration} {width} {height}' \
node bin/rs.js render ma-video.mp4
```

## Brancher un service de lip-sync

`examples/providers/lipsync-http.sh` est un squelette complet : création de la
tâche, attente avec plafond de temps, téléchargement, et un message d'erreur
lisible à chaque étape qui peut échouer.

```bash
export LIPSYNC_API_URL="https://api.exemple.com/v1"
export LIPSYNC_API_KEY="..."

RS_AVATAR_PROVIDER=cmd \
RS_REACTOR_IMAGE=./assets/personnage.png \
RS_AVATAR_CMD='./examples/providers/lipsync-http.sh {image} {audio} {out} {duration}' \
node bin/rs.js render ma-video.mp4 --layout pip
```

Trois blocs y sont marqués `ADAPTER` : la création de la tâche, la lecture du
statut, et le champ contenant l'URL du résultat. **Ce sont les seuls endroits à
modifier**, et leurs valeurs se prennent dans la documentation à jour du service
que vous utilisez — les noms de champs de cette catégorie d'API changent souvent.

Le principe reste le même partout : vous envoyez une image et un audio, vous
récupérez une vidéo. Votre script fait trois choses — envoyer, attendre, et
télécharger le résultat vers `{out}`.

```bash
#!/usr/bin/env bash
set -euo pipefail
IMAGE="$1"; AUDIO="$2"; OUT="$3"; DURATION="$4"

# 1. envoyer l'image et l'audio, récupérer un identifiant de tâche
job=$(curl -sS -X POST "$SERVICE_URL/generations" \
  -H "Authorization: Bearer $SERVICE_API_KEY" \
  -F "image=@$IMAGE" -F "audio=@$AUDIO" | jq -r '.id')

# 2. attendre la fin du rendu
until [ "$(curl -sS "$SERVICE_URL/generations/$job" \
  -H "Authorization: Bearer $SERVICE_API_KEY" | jq -r '.status')" = "complete" ]; do
  sleep 5
done

# 3. télécharger vers {out}
url=$(curl -sS "$SERVICE_URL/generations/$job" \
  -H "Authorization: Bearer $SERVICE_API_KEY" | jq -r '.url')
curl -sS -L "$url" -o "$OUT"
```

Les noms de champs et d'endpoints diffèrent d'un service à l'autre et changent
régulièrement : **prenez-les dans la documentation à jour du service que vous
utilisez**, ce squelette ne donne que la forme.

Quelques repères pour choisir :

- **Services hébergés de lip-sync** (image + audio → vidéo) : le meilleur
  rapport cohérence/coût quand le personnage doit être le même d'une vidéo à
  l'autre. Rendu en quelques minutes, facturé à la durée générée.
- **Modèles locaux** (LivePortrait, MuseTalk, SadTalker) : gratuits, mais il
  faut un GPU et le rendu est plus lent. Même contrat de commande.
- **Génération complète de plan** (Veo, Kling, Sora) : facturé à la seconde,
  cher pour une production quotidienne. Intéressant pour un plan marquant, pas
  pour chaque épisode.

## Coûts, en ordre de grandeur

Pour un épisode de 30 secondes : l'écriture du script coûte quelques centimes,
la voix quelques centimes, le personnage est de loin le poste principal et
dépend entièrement du service choisi. Vérifiez la grille tarifaire courante
avant de lancer une série — les prix de cette catégorie bougent vite.

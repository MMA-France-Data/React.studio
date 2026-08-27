#!/usr/bin/env bash
# Modele de provider pour un service de lip-sync hebergé : on envoie un portrait
# et une piste voix, on recupere une video ou le personnage parle.
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │ CE SCRIPT EST UN SQUELETTE, PAS UN CLIENT PRÊT À L'EMPLOI.              │
# │ Les URL, noms de champs et valeurs de statut different d'un service à   │
# │ l'autre et changent souvent. Prenez-les dans la documentation à jour du │
# │ service que vous utilisez et adaptez les trois blocs marques ADAPTER.   │
# └─────────────────────────────────────────────────────────────────────────┘
#
# Usage :
#   export LIPSYNC_API_URL="https://api.exemple.com/v1"
#   export LIPSYNC_API_KEY="..."
#   RS_AVATAR_PROVIDER=cmd \
#   RS_REACTOR_IMAGE=./assets/personnage.png \
#   RS_AVATAR_CMD='./examples/providers/lipsync-http.sh {image} {audio} {out} {duration}' \
#   node bin/rs.js render ma-video.mp4 --layout pip
set -euo pipefail

IMAGE="$1"
AUDIO="$2"
OUT="$3"
DURATION="$4"

: "${LIPSYNC_API_URL:?variable LIPSYNC_API_URL manquante}"
: "${LIPSYNC_API_KEY:?variable LIPSYNC_API_KEY manquante}"

POLL_INTERVAL="${LIPSYNC_POLL_INTERVAL:-5}"
# Un rendu de quelques secondes prend souvent plusieurs minutes : sans plafond,
# un service en panne bloquerait le pipeline indefiniment.
TIMEOUT="${LIPSYNC_TIMEOUT:-900}"

for tool in curl jq; do
  command -v "$tool" >/dev/null || { echo "lipsync-http.sh : $tool est requis." >&2; exit 1; }
done

echo "lip-sync : envoi (${DURATION}s de voix)" >&2

# --- ADAPTER 1/3 : creation de la tache ------------------------------------
# Certains services attendent du multipart, d'autres des URL de fichiers deja
# televerses, d'autres du base64. Voici la forme multipart, la plus courante.
create_response=$(curl -sS --fail-with-body -X POST "$LIPSYNC_API_URL/generations" \
  -H "Authorization: Bearer $LIPSYNC_API_KEY" \
  -F "image=@$IMAGE" \
  -F "audio=@$AUDIO")

job_id=$(echo "$create_response" | jq -r '.id // empty')
if [ -z "$job_id" ]; then
  echo "lip-sync : aucune tache creee. Reponse du service :" >&2
  echo "$create_response" | head -c 800 >&2
  exit 1
fi

# --- ADAPTER 2/3 : attente de la fin du rendu ------------------------------
# Adaptez le chemin du statut et les valeurs terminales.
elapsed=0
while :; do
  status_response=$(curl -sS --fail-with-body "$LIPSYNC_API_URL/generations/$job_id" \
    -H "Authorization: Bearer $LIPSYNC_API_KEY")
  status=$(echo "$status_response" | jq -r '.status // "unknown"')

  case "$status" in
    complete|completed|succeeded|done) break ;;
    failed|error|canceled)
      echo "lip-sync : le service a echoue ($status)" >&2
      echo "$status_response" | head -c 800 >&2
      exit 1 ;;
  esac

  if [ "$elapsed" -ge "$TIMEOUT" ]; then
    echo "lip-sync : abandon apres ${TIMEOUT}s (dernier statut : $status)" >&2
    exit 1
  fi

  sleep "$POLL_INTERVAL"
  elapsed=$((elapsed + POLL_INTERVAL))
  echo "lip-sync : $status (${elapsed}s)" >&2
done

# --- ADAPTER 3/3 : telechargement du resultat ------------------------------
video_url=$(echo "$status_response" | jq -r '.url // .output_url // .video_url // empty')
if [ -z "$video_url" ]; then
  echo "lip-sync : pas d'URL de video dans la reponse finale :" >&2
  echo "$status_response" | head -c 800 >&2
  exit 1
fi

curl -sS --fail-with-body -L "$video_url" -o "$OUT"
echo "lip-sync : recu dans $OUT" >&2

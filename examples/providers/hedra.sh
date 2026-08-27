#!/usr/bin/env bash
# Provider avatar : Hedra (Character-3). Envoie le portrait et la piste voix,
# recupere une video ou le personnage parle avec micro-expressions et
# mouvements de tete.
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │ ENDPOINTS À VÉRIFIER AU PREMIER LANCEMENT.                              │
# │ Ils sont tous regroupes dans le bloc « API » ci-dessous et surchargeables│
# │ par variable d'environnement, sans toucher au script. Lancez d'abord     │
# │ HEDRA_DRY_RUN=1 pour voir les requetes sans les envoyer, puis un vrai    │
# │ rendu : en cas d'echec, le script affiche la requete ET la reponse       │
# │ complete, ce qui suffit a corriger la constante fautive.                 │
# └─────────────────────────────────────────────────────────────────────────┘
#
# Usage :
#   export HEDRA_API_KEY="..."
#   RS_AVATAR_PROVIDER=cmd \
#   RS_REACTOR_IMAGE=./assets/personnage.png \
#   RS_AVATAR_CMD='./examples/providers/hedra.sh {image} {audio} {out} {duration} {width} {height} {persona}' \
#   node bin/rs.js render ma-video.mp4 --layout pip
set -euo pipefail

IMAGE="$1"
AUDIO="$2"
OUT="$3"
DURATION="$4"
WIDTH="${5:-512}"
HEIGHT="${6:-512}"
PERSONA="${7:-}"

# --- API : les constantes a verifier ---------------------------------------
# Attention : `{id}` ne peut pas apparaitre dans une valeur par defaut
# `${VAR:-...}` — l'accolade fermante y terminerait l'expansion. D'ou la
# variable dediee et l'affectation en deux temps pour les chemins qui en
# contiennent un.
ID_PLACEHOLDER='{id}'
BASE="${HEDRA_BASE_URL:-https://api.hedra.com/web-app/public}"
EP_MODELS="${HEDRA_EP_MODELS:-/models}"
EP_ASSETS="${HEDRA_EP_ASSETS:-/assets}"
EP_UPLOAD="${HEDRA_EP_UPLOAD:-}"
: "${EP_UPLOAD:=/assets/$ID_PLACEHOLDER/upload}"
EP_GENERATIONS="${HEDRA_EP_GENERATIONS:-/generations}"
EP_STATUS="${HEDRA_EP_STATUS:-}"
: "${EP_STATUS:=/generations/$ID_PLACEHOLDER/status}"
AUTH_HEADER="${HEDRA_AUTH_HEADER:-X-API-Key}"
# Chemins jq des champs lus dans les reponses (`//` = repli si absent).
JQ_ASSET_ID="${HEDRA_JQ_ASSET_ID:-.id // .asset_id // empty}"
JQ_GENERATION_ID="${HEDRA_JQ_GENERATION_ID:-.id // .generation_id // empty}"
JQ_STATUS="${HEDRA_JQ_STATUS:-.status // .state // \"unknown\"}"
JQ_VIDEO_URL="${HEDRA_JQ_VIDEO_URL:-.url // .video_url // .output_url // .asset.url // empty}"
STATUS_DONE="${HEDRA_STATUS_DONE:-complete completed succeeded success done}"
STATUS_FAILED="${HEDRA_STATUS_FAILED:-error failed canceled cancelled}"
# ---------------------------------------------------------------------------

POLL_INTERVAL="${HEDRA_POLL_INTERVAL:-5}"
# Un rendu prend souvent plusieurs minutes ; sans plafond, un service en panne
# bloquerait le pipeline indefiniment.
TIMEOUT="${HEDRA_TIMEOUT:-900}"
DRY_RUN="${HEDRA_DRY_RUN:-0}"

for tool in curl jq; do
  command -v "$tool" >/dev/null || { echo "hedra.sh : $tool est requis." >&2; exit 1; }
done

if [ "$DRY_RUN" != "1" ]; then
  : "${HEDRA_API_KEY:?variable HEDRA_API_KEY manquante}"
fi
API_KEY="${HEDRA_API_KEY:-DRY-RUN-NO-KEY}"

say() { echo "hedra : $*" >&2; }

# Le format demande a Hedra suit le panneau que le montage doit remplir.
if [ "$WIDTH" -eq "$HEIGHT" ]; then ASPECT="1:1"
elif [ "$WIDTH" -gt "$HEIGHT" ]; then ASPECT="16:9"
else ASPECT="9:16"; fi
ASPECT="${HEDRA_ASPECT_RATIO:-$ASPECT}"
RESOLUTION="${HEDRA_RESOLUTION:-540p}"

PROMPT="${HEDRA_PROMPT:-${PERSONA:-a person reacting to a video}, expressive face, natural head movement, looking at camera}"

# Toute requete passe par ici : une seule place pour le mode dry-run, la
# verification du code HTTP et l'affichage diagnostique en cas d'echec.
request() {
  local method="$1" url="$2"; shift 2

  if [ "$DRY_RUN" = "1" ]; then
    {
      echo "--- DRY RUN ---------------------------------------------------"
      echo "$method $url"
      echo "$AUTH_HEADER: <cle masquee>"
      for arg in "$@"; do
        case "$arg" in
          -d|-F|--data|--form) ;;
          -H) ;;
          *) [ -n "$arg" ] && echo "  $arg" ;;
        esac
      done
    } >&2
    echo '{"id":"dry-run-id","status":"complete","url":"dry-run"}'
    return 0
  fi

  local body status
  body=$(curl -sS -w $'\n%{http_code}' -X "$method" "$url" -H "$AUTH_HEADER: $API_KEY" "$@") || {
    say "echec reseau sur $method $url"
    return 1
  }
  status=$(echo "$body" | tail -n1)
  body=$(echo "$body" | sed '$d')

  if [ "$status" -ge 400 ]; then
    say "HTTP $status sur $method $url"
    say "reponse : $(echo "$body" | head -c 800)"
    say "si le chemin est faux, corrigez la constante correspondante (HEDRA_EP_*)."
    return 1
  fi
  echo "$body"
}

# --- 1. modele -------------------------------------------------------------
MODEL_ID="${HEDRA_MODEL_ID:-}"
if [ -z "$MODEL_ID" ] && [ "$DRY_RUN" = "1" ]; then
  MODEL_ID="dry-run-model-id"
elif [ -z "$MODEL_ID" ]; then
  say "recherche du modele Character"
  models=$(request GET "$BASE$EP_MODELS")
  MODEL_ID=$(echo "$models" | jq -r '[.. | objects | select(has("id"))] | map(select((.name // "") | test("character";"i"))) | .[0].id // empty')
  if [ -z "$MODEL_ID" ]; then
    say "aucun modele « character » trouve. Modeles disponibles :"
    echo "$models" | jq -r '[.. | objects | select(has("id"))] | map({id, name}) | .[]' >&2 || echo "$models" | head -c 800 >&2
    say "choisissez-en un et exportez HEDRA_MODEL_ID."
    exit 1
  fi
  say "modele : $MODEL_ID"
fi

# --- 2. televersement des deux fichiers ------------------------------------
# Hedra separe la creation de l'asset (metadonnees) de l'envoi des octets.
upload_asset() {
  local file="$1" type="$2"
  local created id upload_path

  created=$(request POST "$BASE$EP_ASSETS" \
    -H 'Content-Type: application/json' \
    -d "$(jq -nc --arg name "$(basename "$file")" --arg type "$type" '{name: $name, type: $type}')")

  id=$(echo "$created" | jq -r "$JQ_ASSET_ID")
  if [ -z "$id" ]; then
    say "pas d'identifiant d'asset dans la reponse : $(echo "$created" | head -c 400)"
    say "ajustez HEDRA_JQ_ASSET_ID."
    return 1
  fi

  upload_path="${EP_UPLOAD//$ID_PLACEHOLDER/$id}"
  request POST "$BASE$upload_path" -F "file=@$file" >/dev/null
  echo "$id"
}

say "televersement du portrait"
IMAGE_ID=$(upload_asset "$IMAGE" image)
say "televersement de la voix (${DURATION}s)"
AUDIO_ID=$(upload_asset "$AUDIO" audio)

# --- 3. lancement du rendu -------------------------------------------------
say "rendu ${ASPECT} ${RESOLUTION}"
generation=$(request POST "$BASE$EP_GENERATIONS" \
  -H 'Content-Type: application/json' \
  -d "$(jq -nc \
        --arg model "$MODEL_ID" \
        --arg image "$IMAGE_ID" \
        --arg audio "$AUDIO_ID" \
        --arg prompt "$PROMPT" \
        --arg resolution "$RESOLUTION" \
        --arg aspect "$ASPECT" \
        '{
           type: "video",
           ai_model_id: $model,
           start_keyframe_id: $image,
           audio_id: $audio,
           generated_video_inputs: {
             text_prompt: $prompt,
             resolution: $resolution,
             aspect_ratio: $aspect
           }
         }')")

GENERATION_ID=$(echo "$generation" | jq -r "$JQ_GENERATION_ID")
if [ -z "$GENERATION_ID" ]; then
  say "pas d'identifiant de generation : $(echo "$generation" | head -c 400)"
  say "ajustez HEDRA_JQ_GENERATION_ID."
  exit 1
fi

# --- 4. attente ------------------------------------------------------------
elapsed=0
status_path="${EP_STATUS//$ID_PLACEHOLDER/$GENERATION_ID}"

while :; do
  status_response=$(request GET "$BASE$status_path")
  status=$(echo "$status_response" | jq -r "$JQ_STATUS")

  if grep -qiw -- "$status" <<<"$STATUS_DONE"; then break; fi
  if grep -qiw -- "$status" <<<"$STATUS_FAILED"; then
    say "rendu en echec ($status) : $(echo "$status_response" | head -c 500)"
    exit 1
  fi

  if [ "$elapsed" -ge "$TIMEOUT" ]; then
    say "abandon apres ${TIMEOUT}s (dernier statut : $status)"
    exit 1
  fi

  sleep "$POLL_INTERVAL"
  elapsed=$((elapsed + POLL_INTERVAL))
  say "$status (${elapsed}s)"
done

# --- 5. recuperation -------------------------------------------------------
VIDEO_URL=$(echo "$status_response" | jq -r "$JQ_VIDEO_URL")
if [ -z "$VIDEO_URL" ]; then
  say "pas d'URL de video dans la reponse finale : $(echo "$status_response" | head -c 500)"
  say "ajustez HEDRA_JQ_VIDEO_URL."
  exit 1
fi

if [ "$DRY_RUN" = "1" ]; then
  # Le pipeline attend un fichier : on pose un clip temoin pour que le montage
  # aille jusqu'au bout et qu'on puisse verifier le reste de la chaine.
  ffmpeg -y -loglevel error \
    -f lavfi -i "color=c=0x1B2430:s=${WIDTH}x${HEIGHT}:d=${DURATION}:r=30" \
    -t "$DURATION" -c:v libx264 -pix_fmt yuv420p "$OUT"
  say "dry run : aucun appel envoye, clip temoin ecrit dans $OUT"
  exit 0
fi

curl -sS --fail-with-body -L "$VIDEO_URL" -o "$OUT"
say "video recue dans $OUT"

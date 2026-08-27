#!/usr/bin/env bash
# Provider avatar minimal, sans service externe : un portrait fixe avec un
# lent zoom avant. Pas de synchronisation labiale, mais le cadre est vivant et
# le rendu est instantane et gratuit.
#
# Usage via reaction-studio :
#   RS_AVATAR_PROVIDER=cmd \
#   RS_REACTOR_IMAGE=./assets/mon-personnage.jpg \
#   RS_AVATAR_CMD='./examples/providers/still-zoom.sh {image} {audio} {out} {duration}' \
#   npx rs render ma-video.mp4
set -euo pipefail

IMAGE="$1"
AUDIO="$2"       # non utilise ici : conserve pour respecter le contrat du provider
OUT="$3"
DURATION="$4"

if [ -z "$IMAGE" ]; then
  echo "still-zoom.sh : aucun portrait fourni (RS_REACTOR_IMAGE)." >&2
  exit 1
fi

ffmpeg -y -loglevel error \
  -loop 1 -t "$DURATION" -i "$IMAGE" \
  -vf "scale=1440:-2,zoompan=z='min(zoom+0.0006,1.14)':d=1:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=1080x768:fps=30,format=yuv420p" \
  -an -t "$DURATION" \
  -c:v libx264 -preset veryfast -crf 20 \
  "$OUT"

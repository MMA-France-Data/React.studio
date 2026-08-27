#!/usr/bin/env bash
# Provider avatar minimal, sans service externe : un portrait avec un lent zoom
# avant. Pas de synchronisation labiale, mais le cadre est vivant, le rendu est
# instantane et gratuit — de quoi valider le personnage et le cadrage avant de
# payer un rendu anime.
#
# Gere les portraits detoures (fond transparent) : le sujet est compose sur un
# fond uni, sinon la transparence sort en noir.
#
# Usage :
#   RS_AVATAR_PROVIDER=cmd \
#   RS_REACTOR_IMAGE=./assets/personnage.png \
#   RS_AVATAR_CMD='./examples/providers/still-zoom.sh {image} {out} {duration} {width} {height}' \
#   node bin/rs.js render ma-video.mp4
#
# Reglages optionnels :
#   RS_REACTOR_BG    couleur de fond            (defaut : 0x141A22)
#   RS_REACTOR_FILL  hauteur du sujet / panneau (defaut : 1.30, >1 = plan serre)
#   RS_REACTOR_Y     decalage vertical / panneau (defaut : -0.10, negatif = monte)
set -euo pipefail

IMAGE="$1"
OUT="$2"
DURATION="$3"
WIDTH="${4:-1080}"
HEIGHT="${5:-768}"

BG="${RS_REACTOR_BG:-0x141A22}"
FILL="${RS_REACTOR_FILL:-1.30}"
Y_SHIFT="${RS_REACTOR_Y:--0.10}"

if [ -z "$IMAGE" ]; then
  echo "still-zoom.sh : aucun portrait fourni (RS_REACTOR_IMAGE)." >&2
  exit 1
fi

# Le sujet est mis a l'echelle en hauteur, pas en largeur : c'est la tete qui
# doit tenir dans le cadre, quel que soit le format de la photo d'origine.
SUBJECT_H=$(awk "BEGIN { printf \"%d\", int($HEIGHT * $FILL / 2) * 2 }")
OFFSET_Y=$(awk "BEGIN { printf \"%d\", $HEIGHT * $Y_SHIFT }")

ffmpeg -y -loglevel error \
  -f lavfi -t "$DURATION" -i "color=c=${BG}:s=${WIDTH}x${HEIGHT}:r=30" \
  -loop 1 -t "$DURATION" -i "$IMAGE" \
  -filter_complex "\
[1:v]scale=-2:${SUBJECT_H}:flags=lanczos,format=rgba[subject];\
[0:v][subject]overlay=x=(W-w)/2:y=${OFFSET_Y}:shortest=1[flat];\
[flat]zoompan=z='min(zoom+0.0005,1.10)':d=1:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=${WIDTH}x${HEIGHT}:fps=30,\
format=yuv420p[v]" \
  -map "[v]" -an -t "$DURATION" \
  -c:v libx264 -preset veryfast -crf 20 \
  "$OUT"

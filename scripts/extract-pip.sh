#!/usr/bin/env bash
# Extract a small picture-in-picture MP4 from a source MXF clip.
#
# Usage:
#   scripts/extract-pip.sh <clip-num> <crop-w> <crop-h> <crop-x> <crop-y> [trim-start] [trim-duration]
#
# Required:
#   clip-num       2-digit chapter number (01..07). Maps to Clip00<n+10>.MXF and media/pip/<n>-pip.mp4.
#   crop-w/h       Crop region size on the 1920x1080 source.
#   crop-x/y       Crop region offset (top-left corner) on the source.
#
# Optional:
#   trim-start     ffmpeg -ss value (HH:MM:SS or seconds). Empty/omitted = no head trim.
#   trim-duration  ffmpeg -t value (seconds).              Empty/omitted = clip end.
#
# Example:
#   scripts/extract-pip.sh 01 720 720 600 80 00:00:08 220
set -euo pipefail

if [[ $# -lt 5 ]]; then
  echo "usage: $0 <clip-num 01..07> <crop-w> <crop-h> <crop-x> <crop-y> [trim-start] [trim-duration]" >&2
  exit 2
fi

CHAPTER="$1"
CROP_W="$2"
CROP_H="$3"
CROP_X="$4"
CROP_Y="$5"
TRIM_START="${6-}"
TRIM_DURATION="${7-}"

case "$CHAPTER" in
  01) SRC="Clip0011.MXF" ;;
  02) SRC="Clip0012.MXF" ;;
  03) SRC="Clip0013.MXF" ;;
  04) SRC="Clip0014.MXF" ;;
  05) SRC="Clip0015.MXF" ;;
  06) SRC="Clip0016.MXF" ;;
  07) SRC="Clip0017.MXF" ;;
  *) echo "error: chapter must be 01..07, got '$CHAPTER'" >&2; exit 2 ;;
esac

if [[ ! -f "$SRC" ]]; then
  echo "error: source clip not found: $SRC" >&2
  exit 1
fi

OUT="media/pip/${CHAPTER}-pip.mp4"
mkdir -p "$(dirname "$OUT")"

TRIM_ARGS=()
[[ -n "$TRIM_START"    ]] && TRIM_ARGS+=( -ss "$TRIM_START" )
[[ -n "$TRIM_DURATION" ]] && TRIM_ARGS+=( -t  "$TRIM_DURATION" )

VF="crop=${CROP_W}:${CROP_H}:${CROP_X}:${CROP_Y},scale=480:270:flags=lanczos"

echo ">>> $SRC -> $OUT"
echo "    crop=${CROP_W}x${CROP_H}@(${CROP_X},${CROP_Y})  scale=480x270  trim=${TRIM_START:-<none>} dur=${TRIM_DURATION:-<full>}"

ffmpeg -hide_banner -y \
  "${TRIM_ARGS[@]}" \
  -i "$SRC" \
  -an \
  -vf "$VF" \
  -c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -movflags +faststart \
  -r 30 \
  "$OUT"

echo
echo ">>> probe:"
ffprobe -v error -select_streams v:0 \
  -show_entries stream=codec_name,width,height,r_frame_rate,duration,nb_frames \
  -of default=noprint_wrappers=1 "$OUT"

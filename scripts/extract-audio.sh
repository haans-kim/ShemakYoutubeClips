#!/usr/bin/env bash
# Extract the lecture audio from a source MXF clip into AAC m4a.
#
# Usage:
#   scripts/extract-audio.sh <clip-num 01..07> [channel-index]
#
# Required:
#   clip-num       2-digit chapter number (01..07).
#
# Optional:
#   channel-index  Source mono channel index (0..3). Default omitted -> CH1 (index 0, main mic).
#                  MXF carries 4 mono PCM tracks (CH1..CH4). Override only after listening.
#
# Audio is NOT trimmed here — keep the full track and trim inside HyperFrames via
# data-media-start / data-duration.
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <clip-num 01..07> [channel-index 0..3]" >&2
  exit 2
fi

CHAPTER="$1"
CH_INDEX="${2-0}"

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

case "$CH_INDEX" in
  0|1|2|3) ;;
  *) echo "error: channel-index must be 0..3, got '$CH_INDEX'" >&2; exit 2 ;;
esac

if [[ ! -f "$SRC" ]]; then
  echo "error: source clip not found: $SRC" >&2
  exit 1
fi

OUT="media/audio/${CHAPTER}-audio.m4a"
mkdir -p "$(dirname "$OUT")"

echo ">>> $SRC (audio ch=$CH_INDEX) -> $OUT"

ffmpeg -hide_banner -y \
  -i "$SRC" \
  -map "0:a:${CH_INDEX}" \
  -c:a aac -b:a 192k \
  "$OUT"

echo
echo ">>> probe:"
ffprobe -v error -select_streams a:0 \
  -show_entries stream=codec_name,channels,sample_rate,duration,bit_rate \
  -of default=noprint_wrappers=1 "$OUT"

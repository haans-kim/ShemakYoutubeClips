#!/usr/bin/env bash
# Sync iPhone dashboard recording with Sony talking-head clip via clap cross-correlation,
# trim both to the same time window, and emit:
#   media/pip/0N-pip.mp4       (Sony, portrait crop, no audio)
#   media/audio/0N-audio.m4a   (Sony CH1, AAC)
#   media/dashboard/0N-dashboard.mp4  (iPhone, 1080p H.264)
#
# Window:
#   common_t0  = sony_clap_t + head
#   common_end = sony_duration - tail
#   sony  trim: [common_t0,           common_end]
#   iPhone trim: [common_t0 + offset, common_end + offset]
#   offset = iphone_clap_t - sony_clap_t
#
# Usage:
#   scripts/sync-clap.sh <chapter-NN> [--head SEC] [--tail SEC]
#                                     [--crop-w W] [--crop-h H] [--crop-x X] [--crop-y Y]
#                                     [--pip-w W] [--pip-h H]
#                                     [--dry-run]
set -euo pipefail

# ---------- args ----------
HEAD_PAD="1.0"
TAIL_PAD="0.0"
DRY_RUN=0
CROP_W=""; CROP_H=""; CROP_X=""; CROP_Y=""
PIP_W="360"; PIP_H="480"   # default portrait 3:4 baseline (per DESIGN.md)
SKIP_INITIAL="1.5"         # ignore first N seconds (camera-start transient)
SONY_CLAP_OVERRIDE=""
IP_CLAP_OVERRIDE=""

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <chapter-NN 01..07> [--head SEC] [--tail SEC]" >&2
  echo "         [--skip-initial SEC]  [--sony-clap SEC] [--ip-clap SEC]" >&2
  echo "         [--crop-w W --crop-h H --crop-x X --crop-y Y]" >&2
  echo "         [--pip-w W --pip-h H] [--dry-run]" >&2
  exit 2
fi

CHAPTER="$1"; shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --head)         HEAD_PAD="$2";            shift 2 ;;
    --tail)         TAIL_PAD="$2";            shift 2 ;;
    --skip-initial) SKIP_INITIAL="$2";        shift 2 ;;
    --sony-clap)    SONY_CLAP_OVERRIDE="$2";  shift 2 ;;
    --ip-clap)      IP_CLAP_OVERRIDE="$2";    shift 2 ;;
    --crop-w)       CROP_W="$2";              shift 2 ;;
    --crop-h)       CROP_H="$2";              shift 2 ;;
    --crop-x)       CROP_X="$2";              shift 2 ;;
    --crop-y)       CROP_Y="$2";              shift 2 ;;
    --pip-w)        PIP_W="$2";               shift 2 ;;
    --pip-h)        PIP_H="$2";               shift 2 ;;
    --dry-run)      DRY_RUN=1;                shift ;;
    *) echo "error: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

case "$CHAPTER" in
  01) SONY="source/mxf/Clip0011.MXF"; IP="source/mov/Clip1.mov"; CHAPTER_DIR="chapters/01-workforce-planning" ;;
  02) SONY="source/mxf/Clip0012.MXF"; IP="source/mov/Clip2.mov"; CHAPTER_DIR="chapters/02-attendance-monitoring" ;;
  03) SONY="source/mxf/Clip0013.MXF"; IP="source/mov/Clip3.mov"; CHAPTER_DIR="chapters/03-skills-monitoring" ;;
  04) SONY="source/mxf/Clip0014.MXF"; IP="source/mov/Clip4.mov"; CHAPTER_DIR="chapters/04-org-leadership" ;;
  05) SONY="source/mxf/Clip0015.MXF"; IP="source/mov/Clip5.mov"; CHAPTER_DIR="chapters/05-team-lead-agent" ;;
  06) SONY="source/mxf/Clip0016.MXF"; IP="source/mov/Clip6.mov"; CHAPTER_DIR="chapters/06-executive-agent" ;;
  07) SONY="source/mxf/Clip0017.MXF"; IP="source/mov/Clip7.mov"; CHAPTER_DIR="chapters/07-hr-comp-agent" ;;
  *) echo "error: chapter must be 01..07, got '$CHAPTER'" >&2; exit 2 ;;
esac

[[ -f "$SONY" ]] || { echo "error: $SONY not found" >&2; exit 1; }
[[ -f "$IP"   ]] || { echo "error: $IP not found"   >&2; exit 1; }
[[ -d "$CHAPTER_DIR" ]] || { echo "error: $CHAPTER_DIR not found" >&2; exit 1; }

# ---------- helpers ----------
duration_of() {
  ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$1"
}

# Detect the loudest single transient in the first SCAN_S seconds of an audio track.
# Returns the timestamp (seconds, float) of peak RMS in a 50ms window — robust enough
# for one sharp clap recorded in a quiet room.
detect_clap() {
  local file="$1"; local map="$2"; local scan_s="$3"; local skip_s="${4:-0}"
  ffmpeg -hide_banner -nostats -y \
    -t "$scan_s" -i "$file" \
    -map "$map" -ac 1 -ar 48000 \
    -af "astats=metadata=1:reset=0.05,ametadata=print:key=lavfi.astats.Overall.RMS_level:file=-" \
    -f null - 2>/dev/null | \
  awk -v skip="$skip_s" '
    BEGIN { peak = -1e9; pt = "0.0000"; t = "0" }
    /pts_time:/ {
      if (match($0, /pts_time:[0-9.]+/)) {
        t = substr($0, RSTART + 9, RLENGTH - 9)
      }
    }
    /lavfi\.astats\.Overall\.RMS_level=/ {
      if ((t + 0) < (skip + 0)) next
      n = split($0, a, "=")
      lvl_str = a[n]
      if (lvl_str == "-inf" || lvl_str == "nan") next
      lvl = lvl_str + 0
      if (lvl > peak) { peak = lvl; pt = t }
    }
    END { printf("%s\n", pt) }
  '
}

# ---------- detect claps ----------
SCAN_S="30"
echo ">>> chapter=$CHAPTER  sony=$SONY  iphone=$IP"
echo ">>> scanning first ${SCAN_S}s for clap peak (skip first ${SKIP_INITIAL}s)..."

if [[ -n "$SONY_CLAP_OVERRIDE" ]]; then
  SONY_CLAP="$SONY_CLAP_OVERRIDE"
  echo "    sony  clap (override) = $SONY_CLAP s"
else
  SONY_CLAP="$(detect_clap "$SONY" "0:a:0" "$SCAN_S" "$SKIP_INITIAL")"
fi

if [[ -n "$IP_CLAP_OVERRIDE" ]]; then
  IP_CLAP="$IP_CLAP_OVERRIDE"
  echo "    iphone clap (override) = $IP_CLAP s"
else
  IP_CLAP="$(detect_clap "$IP" "0:a:0" "$SCAN_S" "$SKIP_INITIAL")"
fi

if [[ -z "$SONY_CLAP" || -z "$IP_CLAP" ]]; then
  echo "error: clap detection failed (empty timestamp)" >&2
  exit 1
fi

OFFSET=$(awk "BEGIN { printf \"%.4f\", $IP_CLAP - $SONY_CLAP }")

SONY_DUR="$(duration_of "$SONY")"
IP_DUR="$(duration_of "$IP")"

COMMON_T0=$(awk  "BEGIN { printf \"%.4f\", $SONY_CLAP + $HEAD_PAD }")
COMMON_END=$(awk "BEGIN { printf \"%.4f\", $SONY_DUR  - $TAIL_PAD }")

IP_T0=$(awk  "BEGIN { printf \"%.4f\", $COMMON_T0  + $OFFSET }")
IP_END=$(awk "BEGIN { printf \"%.4f\", $COMMON_END + $OFFSET }")

# Clamp: if iPhone runs out before Sony does, pull both end points back so the
# two streams stay the same length and end on real audio (no padded silence).
CLAMPED=0
if awk "BEGIN { exit !($IP_END > $IP_DUR) }"; then
  IP_END="$IP_DUR"
  COMMON_END=$(awk "BEGIN { printf \"%.4f\", $IP_END - $OFFSET }")
  CLAMPED=1
fi

COMMON_LEN=$(awk "BEGIN { printf \"%.4f\", $COMMON_END - $COMMON_T0 }")

cat <<REPORT

=== sync report ===
sony duration    : $SONY_DUR s
iphone duration  : $IP_DUR s
sony  clap @     : $SONY_CLAP s
iphone clap @    : $IP_CLAP s
offset (ip - sony): $OFFSET s
head pad         : $HEAD_PAD s
tail pad         : $TAIL_PAD s
clamped (iphone-short): $CLAMPED
common window    : [$COMMON_T0, $COMMON_END]  (len $COMMON_LEN s)
sony  trim       : [$COMMON_T0, $COMMON_END]
iphone trim      : [$IP_T0, $IP_END]
===================
REPORT

# sanity
awk "BEGIN { exit !($COMMON_LEN > 5) }" || { echo "error: common window too short ($COMMON_LEN s)" >&2; exit 1; }
awk "BEGIN { off = $OFFSET; if (off<0) off=-off; exit !(off < 60) }" || echo "warn: |offset|>60s — clap detection may be wrong" >&2

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo ">>> dry-run: stopping before transcode"
  exit 0
fi

# ---------- transcode ----------
DERIVED_DIR="${CHAPTER_DIR}/derived"
mkdir -p "$DERIVED_DIR"

# Build PIP video filter
if [[ -n "$CROP_W" && -n "$CROP_H" && -n "$CROP_X" && -n "$CROP_Y" ]]; then
  PIP_VF="crop=${CROP_W}:${CROP_H}:${CROP_X}:${CROP_Y},scale=${PIP_W}:${PIP_H}:flags=lanczos"
else
  echo "warn: no --crop-* args, falling back to a centered 810x1080 portrait crop on the source"
  PIP_VF="crop=810:1080:555:0,scale=${PIP_W}:${PIP_H}:flags=lanczos"
fi

PIP_OUT="${DERIVED_DIR}/pip.mp4"
AUDIO_OUT="${DERIVED_DIR}/audio.m4a"
DASH_OUT="${DERIVED_DIR}/dashboard.mp4"

echo
echo ">>> [1/3] sony -> pip portrait video + audio : $PIP_OUT"
ffmpeg -hide_banner -y \
  -ss "$COMMON_T0" -to "$COMMON_END" -i "$SONY" \
  -map 0:v:0 -map 0:a:0 \
  -vf "$PIP_VF" \
  -c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -movflags +faststart \
  -r 30 \
  -c:a aac -b:a 192k \
  "$PIP_OUT"

echo
echo ">>> [2/3] sony -> audio only (CH1)           : $AUDIO_OUT"
ffmpeg -hide_banner -y \
  -ss "$COMMON_T0" -to "$COMMON_END" -i "$SONY" \
  -map 0:a:0 -c:a aac -b:a 192k \
  "$AUDIO_OUT"

echo
echo ">>> [3/3] iphone -> dashboard 1080p (silent) : $DASH_OUT"
# Dashboard is the visual reference for slide pointing — audio comes from Sony PIP only.
ffmpeg -hide_banner -y \
  -ss "$IP_T0" -to "$IP_END" -i "$IP" \
  -map 0:v:0 -an \
  -vf "scale=1920:1080:flags=lanczos" \
  -c:v libx264 -preset slow -crf 21 -pix_fmt yuv420p -movflags +faststart \
  -r 30 \
  "$DASH_OUT"

echo
echo "=== probes ==="
for f in "$PIP_OUT" "$AUDIO_OUT" "$DASH_OUT"; do
  echo "--- $f"
  ffprobe -v error -show_entries format=duration:stream=codec_type,codec_name,width,height,channels \
    -of default=noprint_wrappers=1 "$f"
done

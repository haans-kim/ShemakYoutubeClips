#!/usr/bin/env bash
# Convert a PPTX deck into per-slide PNGs at 200dpi via LibreOffice + pdftoppm.
#
# Usage:
#   scripts/pptx-to-png.sh <pptx-file> <chapter-slug>
#
# Example:
#   scripts/pptx-to-png.sh "영상 목자와 적정 인력.pptx" 01-workforce-planning
#
# Output:
#   slides/<chapter-slug>/01.png, 02.png, ...
#
# Requires:
#   - LibreOffice  (brew install --cask libreoffice)
#   - poppler      (brew install poppler  -> provides pdftoppm)
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <pptx-file> <chapter-slug>" >&2
  exit 2
fi

PPTX="$1"
SLUG="$2"

if [[ ! -f "$PPTX" ]]; then
  echo "error: pptx not found: $PPTX" >&2
  exit 1
fi

if ! command -v soffice >/dev/null 2>&1; then
  echo "error: 'soffice' not found. Install LibreOffice: brew install --cask libreoffice" >&2
  exit 1
fi
if ! command -v pdftoppm >/dev/null 2>&1; then
  echo "error: 'pdftoppm' not found. Install poppler: brew install poppler" >&2
  exit 1
fi

OUT_DIR="slides/${SLUG}"
mkdir -p "$OUT_DIR"

TMP_DIR="$(mktemp -d -t pptx2png)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo ">>> $PPTX -> PDF"
soffice --headless --convert-to pdf "$PPTX" --outdir "$TMP_DIR" >/dev/null

PDF_FILE="$(find "$TMP_DIR" -maxdepth 1 -name '*.pdf' -print -quit)"
if [[ -z "$PDF_FILE" ]]; then
  echo "error: PDF conversion produced no output" >&2
  exit 1
fi

echo ">>> $PDF_FILE -> $OUT_DIR/*.png (200dpi)"
pdftoppm -r 200 -png "$PDF_FILE" "$OUT_DIR/slide"

# Renumber to zero-padded 01.png, 02.png, ... (pdftoppm default: slide-1.png, slide-10.png — bad sort)
i=1
for f in "$OUT_DIR"/slide-*.png; do
  [[ -e "$f" ]] || { echo "error: pdftoppm produced no PNGs" >&2; exit 1; }
  printf -v NEW "%s/%02d.png" "$OUT_DIR" "$i"
  mv "$f" "$NEW"
  i=$((i+1))
done

echo ">>> $((i-1)) slides written to $OUT_DIR/"
ls -1 "$OUT_DIR"

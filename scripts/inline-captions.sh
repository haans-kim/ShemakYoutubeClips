#!/usr/bin/env bash
# Round-trip caption edits into the HyperFrames composition.
#
# 효단님 edits the human-friendly .srt file. This script regenerates the
# matching .json (so the HyperFrames runtime gets it deterministically) and
# embeds it inline into index.html.
#
# Usage:
#   scripts/inline-captions.sh <chapter-dir-relative-to-repo>
#
# Examples:
#   scripts/inline-captions.sh chapters/01-workforce-planning/work
#   scripts/inline-captions.sh chapters/01-workforce-planning/final
#
# Lookup order (newest mtime wins between SRT and JSON):
#   1. captions.srt + captions.json    (work flow)
#   2. captions.srt + caption-groups.json   (also work flow legacy)
#   3. caption-groups.srt + caption-groups.json   (final flow)
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <chapter-dir>" >&2
  exit 2
fi

DIR="$1"
HTML="${DIR}/index.html"
[[ -f "$HTML" ]] || { echo "error: $HTML not found" >&2; exit 1; }

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRT_UTILS="${REPO_ROOT}/scripts/srt-utils.py"

# Pick the JSON path (and matching SRT path) for this dir.
if   [[ -f "${DIR}/captions.json" || -f "${DIR}/captions.srt" ]]; then
  JSON="${DIR}/captions.json"
  SRT="${DIR}/captions.srt"
elif [[ -f "${DIR}/caption-groups.json" || -f "${DIR}/caption-groups.srt" ]]; then
  JSON="${DIR}/caption-groups.json"
  SRT="${DIR}/caption-groups.srt"
else
  echo "error: no caption files in ${DIR}" >&2
  exit 1
fi

# If SRT is the canonical source (newer or sole) — sync JSON from it first.
if [[ -f "$SRT" && ( ! -f "$JSON" || "$SRT" -nt "$JSON" ) ]]; then
  echo ">>> regenerating $(basename "$JSON") from $(basename "$SRT")"
  python3 "$SRT_UTILS" srt2json "$SRT" "$JSON"
elif [[ -f "$JSON" && ( ! -f "$SRT" || "$JSON" -nt "$SRT" ) ]]; then
  # JSON is newer (e.g. just rebuilt by build-captions.py). Refresh SRT for editing.
  echo ">>> refreshing $(basename "$SRT") from $(basename "$JSON")"
  python3 "$SRT_UTILS" json2srt "$JSON" "$SRT"
fi

[[ -f "$JSON" ]] || { echo "error: no JSON file produced at $JSON" >&2; exit 1; }

python3 <<EOF
import json, re, sys
groups = json.load(open("$JSON"))
html = open("$HTML").read()
new_inline = "window.__CAPTION_GROUPS = " + json.dumps(groups, ensure_ascii=False) + ";"
new_html, n = re.subn(r'window\.__CAPTION_GROUPS = \[.*?\];', new_inline, html, count=1, flags=re.DOTALL)
if n != 1:
    print(f"error: could not find inline placeholder in $HTML", file=sys.stderr)
    sys.exit(1)
open("$HTML", "w").write(new_html)
print(f"inlined {len(groups)} groups from $JSON -> $HTML")
EOF

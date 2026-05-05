#!/usr/bin/env bash
# Inline a captions.json file into the matching index.html composition.
# Used to round-trip caption edits back into the HyperFrames composition without
# breaking deterministic sync (HyperFrames timelines must be built synchronously).
#
# Usage:
#   scripts/inline-captions.sh <chapter-dir-relative-to-repo>
#
# Examples:
#   scripts/inline-captions.sh chapters/01-workforce-planning           (uses caption-groups.json)
#   scripts/inline-captions.sh chapters/01-workforce-planning/work       (uses captions.json)
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <chapter-dir>" >&2
  exit 2
fi

DIR="$1"
HTML="${DIR}/index.html"
[[ -f "$HTML" ]] || { echo "error: $HTML not found" >&2; exit 1; }

# Prefer captions.json (work flow), fall back to caption-groups.json (final flow)
if   [[ -f "${DIR}/captions.json" ]];        then JSON="${DIR}/captions.json"
elif [[ -f "${DIR}/caption-groups.json" ]];  then JSON="${DIR}/caption-groups.json"
else
  echo "error: neither captions.json nor caption-groups.json in ${DIR}" >&2
  exit 1
fi

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

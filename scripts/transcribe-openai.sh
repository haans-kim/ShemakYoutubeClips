#!/usr/bin/env bash
# Transcribe a chapter's audio via OpenAI Whisper API (whisper-1, cloud).
# Produces word-level JSON identical in shape to the local hyperframes transcribe output:
#   [ { "text": "...", "start": s, "end": s }, ... ]
#
# Usage:
#   scripts/transcribe-openai.sh <chapter-NN 01..07> [language]
#   scripts/transcribe-openai.sh 01 ko
#
# Reads OPENAI_API_KEY from .env.local (or environment).
# Cost: ~$0.006 per audio minute.
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <chapter-NN 01..07> [language]" >&2
  exit 2
fi

CHAPTER="$1"
LANG="${2:-ko}"

# Load OPENAI_API_KEY from .env.local if not already exported
if [[ -z "${OPENAI_API_KEY:-}" && -f .env.local ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env.local
  set +a
fi

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo "error: OPENAI_API_KEY not set (export it or place in .env.local)" >&2
  exit 1
fi

case "$CHAPTER" in
  01|02|03|04|05|06|07) ;;
  *) echo "error: chapter must be 01..07, got '$CHAPTER'" >&2; exit 2 ;;
esac

CHAPTER_DIR="chapters/${CHAPTER}-*"
CHAPTER_DIR="$(ls -d $CHAPTER_DIR 2>/dev/null | head -1)"
[[ -d "$CHAPTER_DIR" ]] || { echo "error: chapter dir for $CHAPTER not found" >&2; exit 1; }

AUDIO="${CHAPTER_DIR}/derived/audio.m4a"
[[ -f "$AUDIO" ]] || { echo "error: $AUDIO not found" >&2; exit 1; }

RAW_OUT="${CHAPTER_DIR}/derived/transcript-openai.raw.json"
WORDS_OUT="${CHAPTER_DIR}/derived/transcript.json"

echo ">>> POST /v1/audio/transcriptions  (whisper-1, language=$LANG, audio=$AUDIO)"

# `prompt` biases Whisper toward domain vocabulary that it otherwise mishears
# (e.g. "Shemak"/쉐막 → "쇠막", brand and Korean HR terms).
PROMPT="쉐막(Shemak)은 HR/AI Agent 솔루션 기업입니다. 인력 계획, 적정 인원, 근무 적정성, 역량/스킬 모니터링, 조직 및 리더십 진단, 팀장 AI Agent, 임원 AI Agent, HR AI Agent, 보상, 인력 동인, 회귀관계, 결측치, 영업이익, 재래식 방식."

curl -sS https://api.openai.com/v1/audio/transcriptions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@${AUDIO}" \
  -F "model=whisper-1" \
  -F "language=${LANG}" \
  -F "response_format=verbose_json" \
  -F "timestamp_granularities[]=word" \
  -F "timestamp_granularities[]=segment" \
  -F "prompt=${PROMPT}" \
  -o "$RAW_OUT"

if [[ ! -s "$RAW_OUT" ]]; then
  echo "error: empty response" >&2
  exit 1
fi

# Detect API error
if python3 -c "import json,sys; d=json.load(open('$RAW_OUT')); sys.exit(0 if 'words' in d else 1)" 2>/dev/null; then
  python3 <<EOF
import json
d = json.load(open("$RAW_OUT"))
words = [{"text": w["word"], "start": w["start"], "end": w["end"]} for w in d["words"]]
json.dump(words, open("$WORDS_OUT", "w"), ensure_ascii=False, indent=1)
print(f">>> wrote {len(words)} words to $WORDS_OUT")
print(f">>> total duration: {words[-1]['end'] if words else 0:.2f}s")
EOF
else
  echo "error: API response missing 'words' field. Raw response:" >&2
  cat "$RAW_OUT" >&2
  exit 1
fi

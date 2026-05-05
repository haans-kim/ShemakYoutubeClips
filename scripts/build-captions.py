#!/usr/bin/env python3
"""
Build caption groups from a Whisper word-level transcript.json,
breaking on sentence boundaries (Korean) + speech pauses.

Usage:
    scripts/build-captions.py <chapter-dir>           # writes work/captions.json
    scripts/build-captions.py <chapter-dir> --final   # writes final/caption-groups.json

Heuristic:
  - Strong break: word ends with sentence punctuation (. ? !)
  - Strong break: word ends with a Korean sentence-final morpheme
    (다 요 음 함 죠 까 네 오) and word length >= 2 (avoids single-syllable false positives)
  - Strong break: silence gap to next word >= 0.45s
  - Soft break (when group already has >=4 words): word ends with ','
  - Hard cap: 8 words per group
  - Minimum: 2 words per group (to avoid stranded single words)
"""
from __future__ import annotations
import json
import sys
from pathlib import Path

SENT_END_PUNCT = set(".?!")
SENT_END_CHARS = set("다요음함죠까네오")
PAUSE_THRESHOLD = 0.45
MAX_GROUP_WORDS = 8
MIN_GROUP_WORDS = 2

# Word-level corrections applied to Whisper output before grouping.
# Handles brand/term mishears even when API prompt fails to bias the model.
CORRECTIONS_WORD = {
    "쇠막": "쉐막",
    "쇠막을": "쉐막을",
    "쇠막은": "쉐막은",
    "쇠막이": "쉐막이",
}
# Multi-word phrase corrections (applied to assembled group text).
CORRECTIONS_PHRASE = [
    ("쇠 막", "쉐막"),
    ("쇠 막을", "쉐막을"),
    ("쇠 막은", "쉐막은"),
    ("쇠 막이", "쉐막이"),
]


def is_sentence_end(text: str) -> bool:
    if not text:
        return False
    last = text[-1]
    if last in SENT_END_PUNCT:
        return True
    if last in SENT_END_CHARS and len(text) >= 2:
        return True
    return False


def apply_phrase_corrections(text: str) -> str:
    for src, dst in CORRECTIONS_PHRASE:
        text = text.replace(src, dst)
    return text


def build_groups(words: list[dict]) -> list[dict]:
    # Apply per-word corrections before grouping
    words = [
        {**w, "text": CORRECTIONS_WORD.get(w["text"], w["text"])}
        for w in words
    ]
    groups = []
    cur: list[dict] = []
    n = len(words)
    for i, w in enumerate(words):
        cur.append(w)
        next_gap = words[i + 1]["start"] - w["end"] if i + 1 < n else float("inf")

        text = w["text"]
        end_sentence = is_sentence_end(text)
        is_pause = next_gap >= PAUSE_THRESHOLD
        is_max = len(cur) >= MAX_GROUP_WORDS
        is_comma = text.endswith(",")

        should_break = False
        if len(cur) >= MIN_GROUP_WORDS and (end_sentence or is_pause or is_max):
            should_break = True
        elif is_comma and len(cur) >= 4:
            should_break = True

        if should_break or i == n - 1:
            text = " ".join(x["text"] for x in cur)
            text = apply_phrase_corrections(text)
            groups.append(
                {
                    "text": text,
                    "start": cur[0]["start"],
                    "end": cur[-1]["end"],
                }
            )
            cur = []
    return groups


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: build-captions.py <chapter-dir> [--final]", file=sys.stderr)
        return 2

    chapter_dir = Path(sys.argv[1])
    final_mode = "--final" in sys.argv[2:]

    transcript_path = chapter_dir / "derived" / "transcript.json"
    if not transcript_path.is_file():
        print(f"error: {transcript_path} not found", file=sys.stderr)
        return 1

    words = json.load(transcript_path.open())
    groups = build_groups(words)

    if final_mode:
        out_path = chapter_dir / "final" / "caption-groups.json"
    else:
        out_path = chapter_dir / "work" / "captions.json"

    out_path.parent.mkdir(parents=True, exist_ok=True)
    json.dump(groups, out_path.open("w"), ensure_ascii=False, indent=1)

    print(f"wrote {len(groups)} groups to {out_path}")
    print("first 5 groups:")
    for g in groups[:5]:
        print(f"  [{g['start']:6.2f}–{g['end']:6.2f}]  {g['text']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

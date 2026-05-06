#!/usr/bin/env python3
"""
Convert between captions.json (HyperFrames) and captions.srt (editable).

Usage:
    scripts/srt-utils.py json2srt <captions.json> [<out.srt>]
    scripts/srt-utils.py srt2json <captions.srt>  [<out.json>]

Default output paths:
    json2srt: replaces .json with .srt
    srt2json: replaces .srt with .json
"""
from __future__ import annotations
import json
import re
import sys
from pathlib import Path


def fmt_ts(seconds: float) -> str:
    """Format seconds as SRT timestamp HH:MM:SS,mmm."""
    if seconds < 0:
        seconds = 0.0
    total_ms = int(round(seconds * 1000))
    h, rem_ms = divmod(total_ms, 3_600_000)
    m, rem_ms = divmod(rem_ms, 60_000)
    s, ms = divmod(rem_ms, 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


def parse_ts(text: str) -> float:
    """Parse SRT timestamp HH:MM:SS,mmm or HH:MM:SS.mmm into seconds."""
    text = text.strip().replace(",", ".")
    h, m, s = text.split(":")
    return int(h) * 3600 + int(m) * 60 + float(s)


def json_to_srt(groups: list[dict]) -> str:
    lines = []
    for i, g in enumerate(groups, 1):
        lines.append(str(i))
        lines.append(f"{fmt_ts(g['start'])} --> {fmt_ts(g['end'])}")
        lines.append(g["text"])
        lines.append("")  # blank line between cues
    return "\n".join(lines).rstrip() + "\n"


def srt_to_json(content: str) -> list[dict]:
    # Split on blank-line boundaries between cues. Tolerate Windows newlines.
    blocks = re.split(r"\r?\n\s*\r?\n", content.strip())
    groups = []
    for block in blocks:
        lines = [ln for ln in block.splitlines() if ln.strip() != ""]
        if len(lines) < 2:
            continue
        # First line is the index — skip if it's purely numeric.
        if lines[0].strip().isdigit():
            time_line = lines[1]
            text_lines = lines[2:]
        else:
            time_line = lines[0]
            text_lines = lines[1:]
        if "-->" not in time_line:
            continue
        start_str, end_str = [s.strip() for s in time_line.split("-->")]
        groups.append(
            {
                "text": " ".join(text_lines).strip(),
                "start": parse_ts(start_str),
                "end": parse_ts(end_str),
            }
        )
    return groups


def main() -> int:
    args = sys.argv[1:]
    if len(args) < 2 or args[0] not in {"json2srt", "srt2json"}:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    cmd = args[0]
    in_path = Path(args[1])
    if not in_path.is_file():
        print(f"error: {in_path} not found", file=sys.stderr)
        return 1
    if len(args) >= 3:
        out_path = Path(args[2])
    elif cmd == "json2srt":
        out_path = in_path.with_suffix(".srt")
    else:
        out_path = in_path.with_suffix(".json")

    if cmd == "json2srt":
        groups = json.load(in_path.open())
        out_path.write_text(json_to_srt(groups), encoding="utf-8")
        print(f"wrote {len(groups)} cues to {out_path}")
    else:
        groups = srt_to_json(in_path.read_text(encoding="utf-8"))
        json.dump(groups, out_path.open("w"), ensure_ascii=False, indent=1)
        print(f"wrote {len(groups)} groups to {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

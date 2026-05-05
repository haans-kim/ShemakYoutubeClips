#!/usr/bin/env -S bash -c 'exec "$(dirname "$0")/../.venv/bin/python3" "$0" "$@"'
"""
Detect time offset between two audio tracks (Sony MXF and iPhone MOV) using
RMS envelope cross-correlation.

The clap creates an aligned transient on both tracks. After computing the 50 ms
RMS envelope of each, the cross-correlation peaks at the lag where they line up,
i.e. exactly the value we need for sync-clap (offset = iphone_clap - sony_clap).

Usage:
    scripts/detect-offset.py <sony-path> <iphone-path> [--scan SEC]

Prints `offset=<seconds>` (positive means iPhone clap is later than Sony clap,
matching sync-clap.sh's --ip-clap minus --sony-clap convention).
"""
from __future__ import annotations
import subprocess
import sys
import numpy as np


SR = 16000           # ffmpeg resample rate
ENV_MS = 50          # RMS envelope window
ENV_RATE = 100       # decimated envelope sample rate (Hz) for fast correlate
SCAN_S_DEFAULT = 30.0


def extract_pcm(path: str, scan_s: float) -> np.ndarray:
    cmd = [
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
        "-t", str(scan_s),
        "-i", path,
        "-map", "0:a:0",
        "-ac", "1",
        "-ar", str(SR),
        "-f", "s16le",
        "-",
    ]
    raw = subprocess.check_output(cmd)
    return np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0


def envelope(x: np.ndarray) -> np.ndarray:
    win = int(SR * ENV_MS / 1000)
    if win <= 0:
        return np.abs(x)
    p = x.astype(np.float64) ** 2
    return np.sqrt(np.convolve(p, np.ones(win) / win, mode="same"))


def cross_offset(sony: np.ndarray, iphone: np.ndarray) -> tuple[float, float]:
    es = envelope(sony)
    ei = envelope(iphone)
    factor = SR // ENV_RATE
    a = es[::factor]
    b = ei[::factor]

    # Whiten by removing mean and normalizing — helps separate the clap's spike
    # from slowly varying speech energy that would otherwise dominate correlation.
    a = a - np.mean(a)
    b = b - np.mean(b)
    if np.std(a) > 0:
        a = a / np.std(a)
    if np.std(b) > 0:
        b = b / np.std(b)

    corr = np.correlate(a, b, mode="full")
    peak_idx = int(np.argmax(corr))
    lag_samples = peak_idx - (len(b) - 1)
    # lag_seconds positive means sony envelope leads iphone — i.e. iPhone clap
    # is later than Sony clap by lag seconds (offset = iphone_clap - sony_clap).
    lag_seconds = lag_samples / ENV_RATE
    peak_value = float(corr[peak_idx])
    return lag_seconds, peak_value


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: detect-offset.py <sony-path> <iphone-path> [--scan SEC]", file=sys.stderr)
        return 2
    sony_path = sys.argv[1]
    ip_path = sys.argv[2]
    scan_s = SCAN_S_DEFAULT
    args = sys.argv[3:]
    while args:
        flag = args.pop(0)
        if flag == "--scan":
            scan_s = float(args.pop(0))
        else:
            print(f"error: unknown flag '{flag}'", file=sys.stderr)
            return 2

    sony = extract_pcm(sony_path, scan_s)
    iphone = extract_pcm(ip_path, scan_s)
    offset, peak = cross_offset(sony, iphone)
    print(f"offset={offset:.3f}")
    print(f"peak_score={peak:.1f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

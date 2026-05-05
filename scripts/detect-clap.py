#!/usr/bin/env -S bash -c 'exec "$(dirname "$0")/../.venv/bin/python3" "$0" "$@"'
"""
Detect the first clap onset in an audio/video file.

Approach:
- Extract first SCAN_S seconds as 16 kHz mono PCM via ffmpeg (no temp files).
- Compute 50 ms RMS envelope.
- Estimate noise floor from a quiet window after a skip-initial guard
  (ignores camera-start transient).
- Return first sample where envelope exceeds noise floor by THRESH_DB.

Usage:
    scripts/detect-clap.py <audio-or-video-path> [--scan SEC] [--skip SEC]
"""
from __future__ import annotations
import subprocess
import sys
import numpy as np


SR = 16000
SCAN_S_DEFAULT = 30.0
SKIP_S_DEFAULT = 1.0
THRESH_DB = 18.0   # how loud above noise floor counts as the clap


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


def detect_clap(samples: np.ndarray, skip_s: float) -> float | None:
    if samples.size == 0:
        return None
    # 50 ms RMS envelope
    win = int(SR * 0.05)
    power = samples.astype(np.float64) ** 2
    env = np.sqrt(np.convolve(power, np.ones(win) / win, mode="same") + 1e-12)

    skip_n = int(SR * skip_s)
    if skip_n >= env.size:
        return None

    # Noise floor: 25th percentile of 2-second window right after the skip guard.
    # Using percentile (not median) makes this robust to a clap landing inside the window.
    noise_window_end = min(skip_n + int(SR * 2.0), env.size)
    noise = np.percentile(env[skip_n:noise_window_end], 25)
    if noise <= 0:
        noise = 1e-6

    thresh = noise * (10 ** (THRESH_DB / 20.0))
    above = np.where(env[skip_n:] > thresh)[0]
    if above.size == 0:
        return None

    return (skip_n + int(above[0])) / SR


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: detect-clap.py <audio-or-video-path> [--scan SEC] [--skip SEC]", file=sys.stderr)
        return 2

    path = sys.argv[1]
    scan_s = SCAN_S_DEFAULT
    skip_s = SKIP_S_DEFAULT
    args = sys.argv[2:]
    while args:
        flag = args.pop(0)
        if flag == "--scan":
            scan_s = float(args.pop(0))
        elif flag == "--skip":
            skip_s = float(args.pop(0))
        else:
            print(f"error: unknown flag '{flag}'", file=sys.stderr)
            return 2

    samples = extract_pcm(path, scan_s)
    t = detect_clap(samples, skip_s)
    if t is None:
        print("error: no clap detected in scanned window", file=sys.stderr)
        return 1
    print(f"{t:.3f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

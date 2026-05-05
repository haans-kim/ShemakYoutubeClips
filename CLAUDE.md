# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

An asset-and-composition workspace for producing the **Shemak HR/AI Agent YouTube lecture series** — 7 chapter videos rendered from raw camera footage + slide assets.

This is **not a software codebase**. It's a media production pipeline: ffmpeg preprocessing scripts + per-chapter HyperFrames compositions. There is no library, no test suite, no `package.json` at the repo root.

## Source assets (already present, do not move or rename)

- `Clip0011.MXF` … `Clip0017.MXF` — Sony PXW-Z150 camera originals
  - 1920×1080, 59.94p, H.264 (AVC50)
  - 4 mono PCM 24-bit/48kHz audio tracks (CH1=main mic by convention)
  - Each clip ≈ 240s; total ≈ 10.5 GB
- `Clip00NNM01.XML` — NonRealTime metadata (timecode, UMID, camera settings)
- `*.pptx` — slide decks the lecturer recorded against

## Chapter map

| # | Source clip | Topic | Folder slug |
|---|-------------|-------|-------------|
| 1 | Clip0011 | 인력 계획 | `01-workforce-planning` |
| 2 | Clip0012 | 근무 적정성 모니터링 | `02-attendance-monitoring` |
| 3 | Clip0013 | 역량/스킬 모니터링 | `03-skills-monitoring` |
| 4 | Clip0014 | 조직 및 리더십 진단 | `04-org-leadership` |
| 5 | Clip0015 | 팀장 AI Agent | `05-team-lead-agent` |
| 6 | Clip0016 | 임원 AI Agent | `06-executive-agent` |
| 7 | Clip0017 | HR AI Agent — 보상 | `07-hr-comp-agent` |

## Pipeline

```
MXF (camera)  ──ffmpeg──▶  media/pip/0N-pip.mp4   (480×270, no audio, talking-head crop)
                       └─▶ media/audio/0N-audio.m4a (AAC, full track)

PPTX  ──soffice+pdftoppm──▶  slides/0N-*/01.png, 02.png, ...

(optional)  dashboard screen recording  ──▶  recordings/0N-*.mp4

slides/ + media/pip/ + media/audio/ + recordings/  ──▶  chapters/0N-*/index.html (HyperFrames)
                                                                              │
                                                                              ▼
                                                              chapters/0N-*/renders/0N-*.mp4
```

**Why ffmpeg first**: Chromium (which HyperFrames renders through) cannot decode MXF. Trim + crop + scale + transcode happens once, then HyperFrames composites the lightweight MP4.

## Renderer choice

**HyperFrames** (`npx hyperframes …`) — pure HTML+CSS+GSAP. Each chapter is an independent project under `chapters/0N-*/`. Picture-in-picture, slide compositing, audio sync, captions, and rendering are all handled by the framework. See `~/.claude/skills/hyperframes/` for full reference.

We chose HyperFrames over Remotion because:
- 7 chapters is below the threshold where React component reuse pays off
- PIP is documented as a one-block pattern in `hyperframes/patterns.md`
- Whisper transcription and Kokoro TTS are built into the CLI

## Common commands

### Preprocess a clip (chapter N)

```bash
# 1. PIP video. Crop coords = top-left (x,y) and size (w,h) on the 1920×1080 source.
#    Tune by extracting a single thumbnail first, then re-run with adjusted args.
scripts/extract-pip.sh <NN> <crop-w> <crop-h> <crop-x> <crop-y> [trim-start] [trim-duration]

# Example: ch01, square 720×720 crop centered toward right side of frame, trim head 8s, 220s long
scripts/extract-pip.sh 01 720 720 600 80 00:00:08 220

# 2. Audio (CH1 by default; pass channel index 0..3 to override)
scripts/extract-audio.sh <NN> [channel-index]
scripts/extract-audio.sh 01

# 3. PPTX -> per-slide PNGs (200dpi)
scripts/pptx-to-png.sh "<pptx-file>" <chapter-slug>
scripts/pptx-to-png.sh "영상 목자와 적정 인력.pptx" 01-workforce-planning
```

### Quick thumbnail (decide crop coords before transcoding the whole clip)

```bash
ffmpeg -ss 30 -i Clip0011.MXF -frames:v 1 -q:v 2 thumb-clip0011.jpg
```

### Author / preview / render a chapter

```bash
cd chapters/01-workforce-planning
npx hyperframes lint
npx hyperframes inspect
npx hyperframes preview --port 3017
# Studio URL: http://localhost:3017/#project/01-workforce-planning

npx hyperframes render --quality high --fps 30 --output renders/01-workforce-planning.mp4
```

### Probe a generated artifact

```bash
ffprobe -v error -show_streams media/pip/01-pip.mp4
ffprobe -v error -show_streams media/audio/01-audio.m4a
```

## HyperFrames composition rules (chapter-level recap)

The framework's full ruleset lives in `~/.claude/skills/hyperframes/SKILL.md`. The constraints that bite hardest in this project:

- `<video>` must be `muted playsinline`. **PIP audio comes from the separate `<audio>` element**, never from the video tag.
- Animate the PIP **wrapper div**, never the `<video>` dimensions.
- `data-track-index` controls timing collisions, not z-order. Use CSS `z-index` for layering.
- Duration comes from `data-duration`, not GSAP timeline length.
- All paths in chapter `index.html` are relative — slides at `../../slides/…`, media at `../../media/…`.
- Visual identity is gated: read `DESIGN.md` at the repo root before authoring any chapter HTML. If colors/fonts diverge from `DESIGN.md`, fix the composition, not the design doc — unless 효단님 explicitly redirects.

## Folder layout

```
.
├── Clip0011.MXF .. Clip0017.MXF       source camera footage (read-only)
├── Clip00NNM01.XML                    Sony NonRealTime metadata
├── *.pptx                             slide decks
├── DESIGN.md                          shared visual identity for all 7 chapters
├── slides/0N-<slug>/                  per-chapter slide PNGs (numbered 01.png ...)
├── recordings/                        optional dashboard screen captures
├── media/
│   ├── pip/0N-pip.mp4                 ffmpeg-derived PIP video
│   └── audio/0N-audio.m4a             ffmpeg-derived AAC audio
├── chapters/0N-<slug>/                one HyperFrames project per chapter
│   ├── index.html                     composition root
│   ├── package.json                   hyperframes dep
│   └── renders/                       final MP4 output
└── scripts/
    ├── extract-pip.sh
    ├── extract-audio.sh
    └── pptx-to-png.sh
```

`media/`, `chapters/*/renders/`, and `chapters/*/.hyperframes/` are derived — safe to delete and regenerate.

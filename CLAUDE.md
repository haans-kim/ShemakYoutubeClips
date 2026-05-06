# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

An asset-and-composition workspace for producing the **Shemak HR/AI Agent YouTube lecture series** — 7 chapter videos rendered from raw camera footage + slide assets.

This is **not a software codebase**. It's a media production pipeline: ffmpeg preprocessing scripts + per-chapter HyperFrames compositions. There is no library, no test suite, no `package.json` at the repo root other than for the `hyperframes` CLI dependency.

For human-readable file-location reference, point users to **[README.md](README.md)** — that doc lists every path that 효단님 (the project owner) edits or generates.

## Folder layout (chapter-self-contained)

```
ShemakYoutubeClips/
├── source/                                      # gitignored — large camera media
│   ├── mxf/Clip0011.MXF .. Clip0017.MXF + .XML  # Sony PXW-Z150 originals
│   └── mov/Clip1.mov .. Clip7.mov               # iPhone screen recordings
├── pptx/                                        # PowerPoint sources (committed)
├── chapters/0N-<slug>/                          # one project per chapter
│   ├── slides/01.png 02.png ...                 # committed PNGs
│   ├── derived/                                 # gitignored ffmpeg artifacts
│   │   ├── pip.mp4                              #   PIP video + audio (360×450, 4:5)
│   │   ├── audio.m4a                            #   Sony CH1 mono audio
│   │   ├── dashboard.mp4                        #   iPhone 1080p (silent)
│   │   ├── transcript.json                      #   Whisper word-level
│   │   └── transcript-openai.raw.json           #   raw API response (segments)
│   ├── final/index.html + caption-groups.json   # final composition (slide bg)
│   ├── work/index.html  + captions.json         # work composition (iPhone bg)
│   │   └── (each has derived/ and slides/ symlinks to ../)
│   └── renders/{final,work}.mp4                 # gitignored
├── scripts/                                     # all pipeline tooling
└── .env.local                                   # OPENAI_API_KEY (gitignored)
```

Source media (MXF + MOV + XML) and all derived artifacts are **gitignored**. Everything in `chapters/<NN>-*/` is regenerable from source via the scripts in `scripts/`.

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
source/mxf/Clip00N1.MXF  ──sync-clap.sh──▶  chapters/<NN>-*/derived/pip.mp4         (360×450 portrait + audio)
source/mov/ClipN.mov     ──   "       ──▶  chapters/<NN>-*/derived/audio.m4a       (Sony CH1 mono)
                         └─────"  ──────▶  chapters/<NN>-*/derived/dashboard.mp4   (1920×1080 silent)

audio.m4a  ──transcribe-openai.sh──▶  derived/transcript.json (word-level Whisper)
transcript.json  ──build-captions.py──▶  work/captions.json + final/caption-groups.json
captions.json  ──inline-captions.sh──▶  index.html (window.__CAPTION_GROUPS embedded)

slides/*.png + derived/* + captions  ──HyperFrames──▶  renders/{final,work}.mp4
```

**Why ffmpeg first**: Chromium (which HyperFrames renders through) cannot decode MXF. Trim + crop + scale + transcode happens once into `derived/`, then HyperFrames composites those lightweight MP4s.

**Why two compositions**: `work/` puts the iPhone screen recording as the background so 효단님 can decide slide-pointing timing visually. `final/` is the deliverable with PNG slides as background.

## Renderer

**HyperFrames** (`npx hyperframes …`) — pure HTML+CSS+GSAP. Each chapter dir has its own `final/` and `work/` subdirs; `cd` into one of them and run hyperframes commands.

The `hyperframes` package is installed at the repo root (`./node_modules`). Node module resolution lets `npx hyperframes` from any subdirectory still find it.

## Common commands

### Preprocess one chapter

```bash
# Auto offset (cross-correlation), then run sync-clap
.venv/bin/python3 scripts/detect-offset.py source/mxf/Clip00N1.MXF source/mov/ClipN.mov

scripts/sync-clap.sh <NN> --sony-clap 1.0 --ip-clap <ip-clap> \
  --crop-w 720 --crop-h 900 --crop-x 600 --crop-y 80 --pip-w 360 --pip-h 450

# Manual fallback — listen to the first 30s of each track
ffmpeg -t 30 -i source/mxf/Clip00N1.MXF -map 0:a:0 tmp/<NN>-sony-30s.mp3
ffmpeg -t 30 -i source/mov/ClipN.mov   -map 0:a:0 tmp/<NN>-iphone-30s.mp3
```

### Transcribe + caption pipeline

```bash
scripts/transcribe-openai.sh <NN> ko          # Whisper API → derived/transcript.json
scripts/build-captions.py chapters/<NN>-*     # → work/captions.json
scripts/build-captions.py chapters/<NN>-* --final   # → final/caption-groups.json
scripts/inline-captions.sh chapters/<NN>-*/work     # captions.json → index.html embed
```

### Author / preview / render

```bash
cd chapters/<NN>-*/work     # or final
npx hyperframes lint
npx hyperframes inspect
npx hyperframes preview --port 3017                          # http://localhost:3017/#project/<NN>-*
npx hyperframes render --quality high --fps 30 --output ../renders/work.mp4
```

### Probe a generated artifact

```bash
ffprobe -v error -show_streams chapters/01-workforce-planning/derived/pip.mp4
ffprobe -v error -show_streams chapters/01-workforce-planning/derived/audio.m4a
```

## HyperFrames composition rules (chapter-level recap)

The framework's full ruleset lives in `~/.claude/skills/hyperframes/SKILL.md`. The constraints that bite hardest in this project:

- `<video>` carrying audio needs `data-has-audio="true"` (otherwise lint errors with `video_missing_muted`).
- Animate the PIP **wrapper div**, never the `<video>` dimensions.
- `data-track-index` controls timing collisions, not z-order. Use CSS `z-index` for layering.
- Duration comes from `data-duration`, not GSAP timeline length.
- All paths in chapter `index.html` are relative to the composition dir (`final/` or `work/`); use the `derived/` and `slides/` symlinks set up in those dirs.
- Visual identity is gated: read [DESIGN.md](DESIGN.md) at the repo root before authoring any chapter HTML.

## Captions

- Source: OpenAI Whisper API (cloud, `whisper-1`) via [scripts/transcribe-openai.sh](scripts/transcribe-openai.sh). The script reads `OPENAI_API_KEY` from `.env.local` (gitignored). API prompt biases the model toward "쉐막"/Shemak and Korean HR vocabulary.
- Grouping: [scripts/build-captions.py](scripts/build-captions.py) breaks word-level timestamps on Korean sentence-final morphemes (다/요/음/함/죠/까/네/오) and pauses ≥0.45s, capped at 8 words/group.
- Brand-name corrections: `build-captions.py` has a `CORRECTIONS_WORD` and `CORRECTIONS_PHRASE` dict for Whisper mishears (쇠막/셀막/셰막 → 쉐막). Add new ones there if surfaced during review.
- Editing: 효단님 edits `captions.json` (work) or `caption-groups.json` (final) directly. After edit, run [scripts/inline-captions.sh](scripts/inline-captions.sh) to re-embed the JSON inline into `index.html`, then re-render or hot-reload preview.

## Sync (clap alignment)

Each clip starts with a clap that aligns Sony talking-head audio with the iPhone screen recording. [scripts/sync-clap.sh](scripts/sync-clap.sh) takes `--sony-clap` and `--ip-clap` (in seconds), trims both streams to a common window, and writes them into `chapters/<NN>-*/derived/`.

For chapters 5–7 we used [scripts/detect-offset.py](scripts/detect-offset.py) (envelope cross-correlation) to derive the offset automatically. For chapters 1–4, 효단님 listened to the 30-second mp3 previews and gave the clap times manually. Both are valid; auto-detect is ±0.25–1 s accurate, which is fine because the work composition is for slide-timing decisions, not millisecond-precise lip sync.

When 효단님 sees iPhone running 1–2s ahead in the rendered work video, add a "sync nudge" by shifting `--ip-clap` later by that amount (chapters 1–7 used +1.5s).

## Folder rules

- `source/`, `chapters/<NN>-*/derived/`, `chapters/<NN>-*/renders/` — gitignored, regenerable.
- `chapters/<NN>-*/slides/*.png` — committed, edited only by 효단님 saving fresh slide exports.
- `chapters/<NN>-*/{final,work}/index.html` — committed, edited by Claude.
- `chapters/<NN>-*/{final,work}/{captions.json,caption-groups.json}` — committed, primary surface 효단님 edits to fix transcripts.
- `pptx/` — committed (small enough).
- `.env.local` — gitignored; never commit API keys.

`media/`, `recordings/`, `slides/` (top-level) are **legacy paths from before the chapter-self-contained migration**. If you see them anywhere, you're looking at stale state — refer to README.md for the current paths.

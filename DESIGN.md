# DESIGN.md — Shemak HR/AI Agent Lecture Series

The shared visual identity for all 7 chapter compositions under `chapters/`.
HyperFrames requires this gate to be passed before any composition HTML is written.

> **Status**: provisional. Tune after first chapter preview with 효단님.
> Tag any change with the chapter that triggered it so we can roll back per-chapter.

## Style Prompt

Calm, professional Korean enterprise lecture aesthetic. Slides own the screen — composition is a quiet frame around them, not a stage competing with them. Motion is restrained, used only to mark scene boundaries and to introduce the talking-head PIP. No flourish, no dramatic typography, no chaotic transitions. Trust the content; let it breathe.

## Colors

Slide PPTX is the source of truth for chrome/UI color. The composition only adds:

- `--bg`        `#FFFFFF` — canvas fill behind slides. Slides are ~4:3 on a 16:9 canvas, so left/right pillars appear; white matches the slide background and stays invisible.
- `--accent`    `#3D6FF5` — chapter title underline, PIP border tint
- `--ink`       `#1A1F2A` — overlay text (chapter intro card, end card) — dark on white
- `--muted`     `#5C6878` — secondary overlay text
- `--shadow`    `rgba(0, 0, 0, 0.30)` — PIP frame shadow

Adjust `--accent` per chapter only if it clashes with the slide deck. Do not invent new accent values mid-chapter.

## Typography

- Display / chapter title: **Pretendard** 700 (or Apple SD Gothic Neo Bold as fallback)
- Body / captions: **Pretendard** 500
- Numerals: `font-variant-numeric: tabular-nums` on any data overlay

Embed-test with `npx hyperframes lint` — the compiler warns if a font isn't supported. If Pretendard isn't embedded, swap to a HyperFrames-supported sans-serif Korean and update this doc.

## Motion (HyperFrames + GSAP)

| Moment | Tween | Duration | Ease |
|---|---|---|---|
| PIP entry | `gsap.from` `{ scale: 0.7, opacity: 0 }` | 0.6s | `power2.out` |
| Slide -> slide | `gsap.from` next slide `{ opacity: 0 }` | 0.4s | `none` |
| Chapter title fade-in | `gsap.from` `{ y: 20, opacity: 0 }` | 0.6s | `power3.out` |
| End card fade-out | `gsap.to` `{ opacity: 0 }` | 0.5s | `power2.in` |

- All timelines start `{ paused: true }` (HyperFrames contract).
- No `repeat: -1`. No `Math.random()`.
- Entrance offset 0.1–0.3s from t=0; never start at exactly 0.
- Only the **final scene** may use exit animations (HyperFrames hard rule). Slide-to-slide is handled by the next slide's `gsap.from` entrance — never animate the outgoing slide's opacity to 0 before its `data-duration` ends.

## PIP placement (1920×1080 canvas)

Locked after chapter 1 review (option C, centered crop):

- Aspect: **4:5 slim portrait**
- Source crop on 1920×1080 MXF: 720 × 900 at x=600, y=80 (centered horizontally)
- PIP wrapper size: 240 × 300 (2/3 of original 360×450, locked by 효단님 in chapter 1 review)
- Position: `left: 1640px; top: 740px;` — 40px margin to right and bottom (1920-240-40, 1080-300-40)
- Note: PIP MP4 source is rendered at 360×450; the wrapper downscales to 240×300 via `object-fit: cover`. Re-rendering the source MP4 smaller is unnecessary unless file size matters.
- Frame: `border-radius: 12px;` `box-shadow: 0 8px 24px var(--shadow);`
- Inner `<video>` uses `object-fit: cover; width: 100%; height: 100%;`

The source crop on the 1920×1080 MXF should match the PIP aspect — if PIP is 3:4, crop a 3:4 region tightly around the speaker's head + upper torso, then `scale=360:480`. Do NOT crop 16:9 then squeeze into a portrait wrapper — the inner video would distort.

If a chapter's slide content collides with this region (data table that runs to bottom-right corner), move the PIP to bottom-LEFT for that chapter only — keep the rest of the rules.

## What NOT to do

1. No drop shadows on text. If a slide's text needs more contrast, fix the slide, not the overlay.
2. No full-screen linear gradients on the dark `--bg` color — H.264 banding will show. Use solid color or radial.
3. No animated logos, no sparkle, no parallax, no kinetic typography. This is a lecture, not a product launch.
4. No more than 2 simultaneous tweens at any moment except the very first second (PIP entry + chapter title) and the final fade.
5. No `<br>` inside body copy — let `max-width` wrap text. (HyperFrames hard rule.)
6. No styling that competes with slide content visually — assume the slide already won that fight.

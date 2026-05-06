# Shemak YouTube Clips

Shemak HR/AI Agent 강의 7챕터를 YouTube용 영상으로 만드는 프로덕션 워크스페이스.

각 챕터는 슬라이드 위에 대표이사 talking-head를 PIP로 합성한 최종 영상(`final`) + 슬라이드 시점/자막 결정용 작업 영상(`work`)으로 구성됩니다.

---

## 폴더 구조

```
ShemakYoutubeClips/
├── source/                                      # 큰 미디어 원본 (gitignored)
│   ├── mxf/                                     # Sony 핸디캠 원본 (talking-head)
│   │   ├── Clip0011.MXF + Clip0011M01.XML       #   chapter 1 (인력 계획)
│   │   ├── Clip0012.MXF + Clip0012M01.XML       #   chapter 2 (근무 적정성)
│   │   └── ... Clip0017                         #   chapter 7
│   └── mov/                                     # iPhone 화면 녹화
│       ├── Clip1.mov  ... Clip7.mov
│
├── pptx/                                        # 슬라이드 PPTX 원본 (committed)
│   ├── 4번 영상 재래식 보고서.pptx
│   └── 영상 목자와 적정 인력.pptx
│
├── chapters/                                    # 챕터별 self-contained 작업 디렉터리
│   ├── 01-workforce-planning/
│   │   ├── slides/                              # 챕터 슬라이드 PNG (committed)
│   │   │   ├── 01.png
│   │   │   └── 02.png
│   │   ├── derived/                             # ffmpeg 산출물 (gitignored, sync-clap.sh 결과)
│   │   │   ├── pip.mp4                          #   PIP 영상 + 오디오 (360×450, 4:5 portrait)
│   │   │   ├── audio.m4a                        #   Sony CH1 오디오 (transcribe 입력)
│   │   │   ├── dashboard.mp4                    #   iPhone 화면 영상 (1920×1080 무음)
│   │   │   ├── transcript.json                  #   Whisper word-level timestamps
│   │   │   └── transcript-openai.raw.json       #   raw OpenAI API response
│   │   ├── final/                               # 최종 composition (슬라이드 배경)
│   │   │   ├── index.html                       #   HyperFrames composition
│   │   │   ├── caption-groups.json              #   자막 (편집 가능)
│   │   │   ├── derived → ../derived             #   symlink
│   │   │   └── slides → ../slides               #   symlink
│   │   ├── work/                                # 작업용 composition (iPhone 배경)
│   │   │   ├── index.html                       #   HyperFrames composition
│   │   │   ├── captions.json                    #   자막 (편집 가능)
│   │   │   ├── derived → ../derived             #   symlink
│   │   │   └── slides → ../slides               #   symlink
│   │   └── renders/                             # 렌더 산출물 (gitignored)
│   │       ├── final.mp4                        #   최종 영상
│   │       └── work.mp4                         #   작업용 영상
│   ├── 02-attendance-monitoring/                # chapter 2 (근무 적정성 모니터링)
│   ├── 03-skills-monitoring/                    # chapter 3 (역량/스킬 모니터링)
│   ├── 04-org-leadership/                       # chapter 4 (조직 및 리더십 진단)
│   ├── 05-team-lead-agent/                      # chapter 5 (팀장 AI Agent)
│   ├── 06-executive-agent/                      # chapter 6 (임원 AI Agent)
│   └── 07-hr-comp-agent/                        # chapter 7 (HR AI Agent — 보상)
│
├── scripts/
│   ├── sync-clap.sh                             # MXF + MOV → derived/{pip,audio,dashboard}
│   ├── transcribe-openai.sh                     # audio.m4a → derived/transcript.json (Whisper API)
│   ├── build-captions.py                        # transcript.json → captions.json (한국어 그룹핑)
│   ├── inline-captions.sh                       # captions.json → index.html (inline embed)
│   ├── detect-offset.py                         # 박수 자동 cross-correlation offset
│   ├── detect-clap.py                           # 박수 onset 자동 검출 (RMS)
│   ├── extract-pip.sh                           # (legacy) MXF → PIP 단독
│   ├── extract-audio.sh                         # (legacy) MXF → audio 단독
│   └── pptx-to-png.sh                           # PPTX → PNG (LibreOffice headless)
│
├── tmp/                                         # 작업 중 mp3/thumbnail 미리보기 (gitignored)
├── .venv/                                       # Python venv (numpy 등, gitignored)
├── node_modules/                                # hyperframes (gitignored)
├── .env.local                                   # OPENAI_API_KEY (gitignored, 보안)
│
├── CLAUDE.md                                    # Claude Code용 가이드
├── DESIGN.md                                    # 비주얼 정체성 (PIP 위치, 자막 색 등)
├── README.md                                    # 본 문서
└── package.json                                 # hyperframes 의존성
```

### Chapter 매핑

| # | Sony 클립 | iPhone 클립 | 폴더 슬러그 | 주제 |
|---|---|---|---|---|
| 1 | Clip0011.MXF | Clip1.mov | `01-workforce-planning` | 인력 계획 |
| 2 | Clip0012.MXF | Clip2.mov | `02-attendance-monitoring` | 근무 적정성 모니터링 |
| 3 | Clip0013.MXF | Clip3.mov | `03-skills-monitoring` | 역량/스킬 모니터링 |
| 4 | Clip0014.MXF | Clip4.mov | `04-org-leadership` | 조직 및 리더십 진단 |
| 5 | Clip0015.MXF | Clip5.mov | `05-team-lead-agent` | 팀장 AI Agent |
| 6 | Clip0016.MXF | Clip6.mov | `06-executive-agent` | 임원 AI Agent |
| 7 | Clip0017.MXF | Clip7.mov | `07-hr-comp-agent` | HR AI Agent — 보상 |

---

## 자막 파일 위치 (편집용)

| 용도 | 위치 | 편집 후 갱신 명령 |
|---|---|---|
| 작업용(work) 영상 자막 | `chapters/<NN>-*/work/captions.json` | `scripts/inline-captions.sh chapters/<NN>-*/work` |
| 최종(final) 영상 자막 | `chapters/<NN>-*/final/caption-groups.json` | `scripts/inline-captions.sh chapters/<NN>-*/final` |

자막 스키마 (JSON 배열):
```json
[
  { "text": "표시할 자막 텍스트", "start": 0.0, "end": 4.52 },
  ...
]
```

`text` 텍스트만 수정하시면 OK. 시간(`start`/`end`)은 보통 그대로 두세요. 편집 후 위 inline 명령을 한 번 실행하면 HTML에 다시 박힙니다.

---

## 미디어 파일 위치

| 용도 | 위치 |
|---|---|
| Sony 핸디캠 원본 | `source/mxf/Clip00<N>1.MXF` |
| Sony NonRealTime 메타 | `source/mxf/Clip00<N>1M01.XML` |
| iPhone 화면 녹화 원본 | `source/mov/Clip<N>.mov` |
| 추출된 PIP 영상+오디오 | `chapters/<NN>-*/derived/pip.mp4` |
| 추출된 오디오만 | `chapters/<NN>-*/derived/audio.m4a` |
| 추출된 대시보드 영상 (무음) | `chapters/<NN>-*/derived/dashboard.mp4` |
| Whisper 자막 데이터 (raw) | `chapters/<NN>-*/derived/transcript.json` |
| 슬라이드 PNG | `chapters/<NN>-*/slides/01.png, 02.png, ...` |
| 슬라이드 PPTX 원본 | `pptx/*.pptx` |
| 작업용 영상 렌더 | `chapters/<NN>-*/renders/work.mp4` |
| 최종 영상 렌더 | `chapters/<NN>-*/renders/final.mp4` |

`source/`, `chapters/<NN>-*/derived/`, `chapters/<NN>-*/renders/`는 모두 **재생성 가능**한 derived 산출물이라 git에 올라가지 않습니다.

---

## 워크플로

### 새 챕터 작업 (예: chapter 2)

```bash
# 1. 폴더 + composition 템플릿 복사
mkdir -p chapters/02-attendance-monitoring/{slides,final,work}
cp chapters/01-workforce-planning/work/index.html  chapters/02-attendance-monitoring/work/index.html
cp chapters/01-workforce-planning/final/index.html chapters/02-attendance-monitoring/final/index.html

# 2. ffmpeg 전처리 (sync 맞춰 PIP/audio/dashboard 추출)
scripts/sync-clap.sh 02 --sony-clap 1.0 --ip-clap 5.0 \
  --crop-w 720 --crop-h 900 --crop-x 600 --crop-y 80 \
  --pip-w 360 --pip-h 450
#   --sony-clap, --ip-clap: 박수 시점 (수동) 또는
#   scripts/detect-offset.py source/mxf/Clip0012.MXF source/mov/Clip2.mov 로 자동 측정

# 3. chapter 안에 derived/slides symlink
( cd chapters/02-attendance-monitoring/work  && ln -sfn ../derived derived && ln -sfn ../slides slides )
( cd chapters/02-attendance-monitoring/final && ln -sfn ../derived derived && ln -sfn ../slides slides )

# 4. composition 메타 변경 (composition-id, duration, 챕터 제목)
sed -i.bak 's/ch01-work/ch02-work/g; s/ch01"/ch02"/g; s/data-duration="241.3"/data-duration="245.7"/g' \
  chapters/02-attendance-monitoring/{work,final}/index.html

# 5. 자막 생성 (Whisper API + 한국어 그룹핑)
scripts/transcribe-openai.sh 02 ko
scripts/build-captions.py chapters/02-attendance-monitoring
scripts/inline-captions.sh chapters/02-attendance-monitoring/work

# 6. 렌더
( cd chapters/02-attendance-monitoring/work && \
  npx hyperframes lint && \
  npx hyperframes render --quality high --fps 30 --output ../renders/work.mp4 )
```

### 자막 편집 → 영상 반영

```bash
# 1. captions.json (또는 caption-groups.json) 편집
# 2. HTML에 다시 inline embed
scripts/inline-captions.sh chapters/02-attendance-monitoring/work
# 3. 재렌더 (또는 preview)
( cd chapters/02-attendance-monitoring/work && \
  npx hyperframes render --quality high --fps 30 --output ../renders/work.mp4 )
```

### 미리보기 스튜디오

```bash
cd chapters/<NN>-*/work       # 또는 final
npx hyperframes preview --port 3017
# Studio: http://localhost:3017/#project/<NN>-*
```

---

## 주요 명령 reference

```bash
# 박수 자동 검출 (cross-correlation offset)
scripts/detect-offset.py source/mxf/Clip0012.MXF source/mov/Clip2.mov

# 박수 단일 트랙 onset 검출
scripts/detect-clap.py source/mxf/Clip0012.MXF

# 챕터별 thumbnail (crop 좌표 결정용)
ffmpeg -ss 30 -i source/mxf/Clip0012.MXF -frames:v 1 -vf "crop=720:900:600:80" tmp/02-crop.jpg

# 박수 시점 들어보기 (수동 sync 결정)
ffmpeg -t 30 -i source/mxf/Clip0012.MXF -map 0:a:0 -ar 48000 tmp/02-sony-30s.mp3
ffmpeg -t 30 -i source/mov/Clip2.mov   -map 0:a:0 -ar 48000 tmp/02-iphone-30s.mp3

# Whisper API key 설정 (.env.local 한 줄)
# OPENAI_API_KEY=sk-...
```

---

## 의존성

- macOS (zsh)
- **ffmpeg** 8.x (`brew install ffmpeg`)
- **Node.js 22+** + `npx` (root에 `npm install` 한 번 → `node_modules/hyperframes`)
- **Python 3** + numpy (`python3 -m venv .venv && .venv/bin/pip install numpy`)
- **OpenAI API key** (`.env.local`에 `OPENAI_API_KEY=sk-...`)
- (선택) **LibreOffice** PPTX → PNG 변환용 (`brew install --cask libreoffice`)

설계 문서:
- [DESIGN.md](DESIGN.md) — 비주얼 정체성, PIP 위치/사이즈, 자막 색
- [CLAUDE.md](CLAUDE.md) — Claude Code 협업 가이드

# Captain Claw (1997) — Linux Mint Setup & Plan

A complete, faithful setup for playing the classic 1997 platformer **Captain Claw** (Monolith Productions) on Linux Mint with:
- **Silky smooth 60 FPS** (vsync locked, no CPU cycle speed bugs)
- **Authentic PC keyboard controls** (Arrows, Space, Ctrl, Shift, Alt)
- **Full original assets** (All 14 levels, CD audio soundtrack, sound effects, and full in-game cinematic cutscenes)
- **Proper 4:3 aspect ratio preservation** with integer scaling / sharp pixel shaders (no stretched graphics on modern widescreen monitors)
- **Desktop integration** (Whisker Menu launcher, desktop icon, independent Wine prefix)
- **Clean installation path**: default under `~/games/captain-claw` managed by a configurable environment variable (`CLAW_INSTALL_DIR`)

---

## Directory Architecture & Path Variable

The installation location is defined in [`config.env`](config.env):
```bash
CLAW_INSTALL_DIR="${CLAW_INSTALL_DIR:-${HOME}/games/captain-claw}"
CLAW_GAME_DIR="${CLAW_GAME_DIR:-${CLAW_INSTALL_DIR}/game}"
CLAW_WINE_PREFIX="${CLAW_WINE_PREFIX:-${CLAW_INSTALL_DIR}/wineprefix}"
```

This variable is sourced by both `install.sh` and `launch.sh`, and can be customized at any time by editing `config.env` or exporting `CLAW_INSTALL_DIR`.

```text
~/games/captain-claw/
├── game/                    # Game binaries, CLAW.REZ, CLAW.FEC cutscenes, ddraw.ini
└── wineprefix/              # Dedicated, isolated 32-bit Wine prefix
```

---

## Component Strategy

| Component | Role | Why It's Used |
|---|---|---|
| **Original Monolith Engine (`CLAW.EXE`)** | Core Game | 100% authentic physics, animations, enemy AI, high scores, cheats, and level mechanics. |
| **CrazyHook Mod (v1.4.5.4)** | Engine Modernizer | Removes legacy Windows 95/98 memory bugs, adds custom level support, modern OS compatibility. |
| **`cnc-ddraw` (by FunkyFr3sh)** | DirectDraw to OpenGL/Vulkan | Replaces DirectX 5 DirectDraw. Handles hardware 60 FPS frame-limiting, vsync, 4:3 pillarboxing, high-DPI scaling, and smooth cutscene playback. |
| **Wine Prefix (`~/games/captain-claw/wineprefix`)** | Isolation | Keeps all game files and Windows configuration isolated from your global Wine settings. |
| **`CLAW.FEC`** | Cutscenes Archive | In-game animated cinematic cutscenes (intro, level transitions, ending). |

*(Note on **OpenClaw**: The native C++ reimplementation `pjasicek/OpenClaw` is also tracked as an alternative fallback, but CrazyHook + cnc-ddraw is the gold standard for full cutscenes, exact original physics, and mod compatibility.)*

---

## Status & Execution Plan

- [ ] **Phase 1: Prerequisites & Wine Runtime**
  - [ ] Check / install Wine (64-bit and 32-bit multiarch) and audio libraries (`wine`, `wine32:i386`, `libasound2-plugins:i386`, `curl`, `unzip`).
  - [ ] Initialize dedicated Wine prefix at `${CLAW_WINE_PREFIX}` (`~/games/captain-claw/wineprefix`).

- [ ] **Phase 2: Assets Acquisition**
  - [x] Manual download of `CLAW.FEC` (Cinematic cutscenes pack, ~349 MB verified in `downloads/`).
  - [x] Pre-installation validation script (`validate_installation_files.sh`) implemented and passing.
  - [ ] Automated download of `CLAW-1.4.5.4.zip` (Base game + CrazyHook + `cnc-ddraw` from `captainclaw.net`).
  - [ ] (Optional) Download Complete Custom Level Pack (~174 MB) for community maps.

- [ ] **Phase 3: Configuration & 60 FPS Tuning**
  - [ ] Configure `ddraw.ini` for `cnc-ddraw`:
    - `renderer=opengl` (fastest and most stable on Linux Mint)
    - `vsync=true`
    - `maxfps=60`
    - `maintas=true` (maintain 4:3 aspect ratio with black bars, no distortion)
    - `boxing=true` (integer scaling)
    - `fullscreen=true`
  - [ ] Verify MIDI / audio playback.

- [ ] **Phase 4: Launcher & Desktop Integration**
  - [ ] Deploy wrapper script `launch.sh` that initializes the prefix and executes `CLAW.EXE`.
  - [ ] Deploy `captain-claw.desktop` to `~/.local/share/applications/` so it appears in the Linux Mint application menu.
  - [ ] Extract and install high-resolution Captain Claw icon.

- [ ] **Phase 5: Verification & Quality Assurance**
  - [ ] Launch game and verify 60 FPS lock using mangohud / frame counter.
  - [ ] Verify PC keyboard responsiveness (jump, slash, magic, crouch).
  - [ ] Verify cutscenes play without stutter and can be skipped with `Esc`.
  - [ ] Verify sound effects and soundtrack play properly.

---

## Downloads Guide (What needs manual download)

### 1. Automatic: Base Game (~74 MB)
The installer script automatically fetches `CLAW-1.4.5.4.zip` directly from `captainclaw.net`.
Contains:
- `CLAW.EXE`
- `CrazyHook.dll`
- `ddraw.dll` (`cnc-ddraw`)
- `CLAW.REZ` (All level data, graphics, sounds, voice lines)

### 2. Manual Action Needed: In-Game Cutscenes `CLAW.FEC` (~349 MB)
Due to hosting on cloud file-sharing services with bot/captcha protection, the high-quality cutscenes file is downloaded manually:
- **Download Link (MediaFire):** [Download CLAW.FEC](https://www.mediafire.com/file/9yfncm88b9pjewk/CLAW.FEC)
- **Alternative (MEGA all-in-one):** [MEGA Claw Folder](https://mega.nz/folder/f0MhhbbC#lW1gBoVRbrLCxOjzJCo_0A)
- **Target Location:** Place the downloaded `CLAW.FEC` file inside:
  ```bash
  captain-claw/downloads/CLAW.FEC
  # or directly in ~/games/captain-claw/game/CLAW.FEC
  ```

---

## PC Keyboard Controls Reference

Captain Claw uses the classic 1997 PC keyboard layout:

| Key | Action |
|---|---|
| **Left / Right Arrows** | Run Left / Run Right |
| **Up Arrow** | Look Up / Climb Ropes / Climb Ladders |
| **Down Arrow** | Duck / Crouch / Drop down through bridges |
| **Spacebar** | Jump |
| **Left Ctrl** | Attack / Sword Slash |
| **Left Shift** | Magic Claw (Fires magic projectile) |
| **Left Alt** | Fire Secondary Weapon (Pistol or Dynamite) |
| **Z** | Cycle secondary weapon backward |
| **X** | Cycle secondary weapon forward |
| **Esc** | Pause Menu / Skip Cutscene |
| **F11** | Toggle Fullscreen / Windowed (via cnc-ddraw) |

---

## Files in this Setup Module

```
captain-claw/
├── config.env                       # Defines CLAW_INSTALL_DIR (~/games/captain-claw) and subpaths
├── README.md                        # Master setup plan and reference guide
├── validate_installation_files.sh   # Validates all assets & templates before any sudo/install action
├── install.sh                       # Automated setup & Wine prefix creator (to be executed)
├── launch.sh                        # Standalone runner with optimal env vars
├── ddraw.ini                        # Pre-configured 60 FPS & aspect-ratio config
├── captain-claw.desktop             # Application menu entry for Linux Mint
├── downloads/                       # Staging directory for manually downloaded files (e.g. CLAW.FEC)
└── tests/                           # TDD automated verification suite
    └── test-validate-installation.sh
```

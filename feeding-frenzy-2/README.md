# Feeding Frenzy 2: Shipwreck Showdown — Linux Mint Setup

A complete setup for playing **Feeding Frenzy 2: Shipwreck Showdown** (PopCap Games, 2006) on Linux Mint with:
- **Silky smooth 60 FPS** (vsync locked via `cnc-ddraw`, no stuttering or lag)
- **Proper 4:3 aspect ratio preservation** with clean integer scaling (no stretched fish on modern 16:9 widescreen monitors)
- **Bypasses PopCap launcher issues** (directly runs the core game engine `popcapgame1.exe` in Wine)
- **Display resolution restoration safety trap** (automatically restores native resolution via `xrandr -s 0` upon exit or crash)
- **Desktop & terminal integration**:
  - Whisker Menu launcher (`Feeding Frenzy 2`)
  - Auto-extracted high-resolution icons
  - Shell alias: `feeding-frenzy-2` added directly to `~/.bashrc`
  - Dedicated, isolated Wine prefix under `~/games/feeding-frenzy-2/wineprefix`

---

## Architecture & Directory Layout

The installation path is defined in [`config.env`](config.env):
```bash
FF2_INSTALL_DIR="${FF2_INSTALL_DIR:-${HOME}/games/feeding-frenzy-2}"
FF2_GAME_DIR="${FF2_GAME_DIR:-${FF2_INSTALL_DIR}/game}"
FF2_WINE_PREFIX="${FF2_WINE_PREFIX:-${FF2_INSTALL_DIR}/wineprefix}"
```

```text
~/games/feeding-frenzy-2/
├── game/                    # Game binaries, popcapgame1.exe, ddraw.dll, ddraw.ini, sound/art assets
└── wineprefix/              # Dedicated, isolated 32-bit Wine prefix
```

---

## Component Strategy

| Component | Role | Why It's Used |
|---|---|---|
| **Core PopCap Engine (`popcapgame1.exe`)** | Core Game | Native execution without the bloated outer launcher wrapper that causes freezes in Wine. |
| **`cnc-ddraw` (by FunkyFr3sh)** | DirectDraw to OpenGL | Intercepts legacy DirectDraw calls, enforces 60 FPS VSync, and maintains 4:3 aspect ratio with black pillarbox borders. |
| **Wine Prefix (`~/games/feeding-frenzy-2/wineprefix`)** | Isolation | Keeps all game files, DirectDraw overrides, and registry entries separate from system Wine. |
| **Shell Alias (`feeding-frenzy-2`)** | Terminal Entry Point | Lets you launch the game instantly from anywhere in the terminal, just like `claw`. |

---

## How to Install

Run the automated installer script:
```bash
cd feeding-frenzy-2
./install.sh
```

The script will:
1. Verify system prerequisites (`wine`, `wine32:i386`, `curl`, `unzip`, `icoutils`).
2. Download the installer archive if not already cached in `downloads/`.
3. Set up the isolated Wine prefix.
4. Deploy `cnc-ddraw` (`ddraw.dll` + `ddraw.ini`) for 60 FPS and 4:3 aspect ratio.
5. Extract the game icon and register `feeding-frenzy-2.desktop` in your application menu.
6. Register the `feeding-frenzy-2` alias in `~/.bashrc`.

---

## How to Play

Once installed, you can play using any of the following:

1. **Terminal alias:**
   ```bash
   feeding-frenzy-2
   ```
   *(Note: Run `source ~/.bashrc` or open a new terminal window after installing)*

2. **Application Menu:**
   Search for **"Feeding Frenzy 2"** in the Linux Mint Whisker Menu.

3. **Direct script:**
   ```bash
   ./feeding-frenzy-2/launch.sh
   ```

---

## Uninstallation

To cleanly remove the game, isolated Wine prefix, desktop entries, icons, and shell alias:
```bash
cd feeding-frenzy-2
./clean_uninstall.sh
```
*(Source installer files in `downloads/` are preserved for fast reinstallation)*

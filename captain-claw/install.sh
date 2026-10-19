#!/usr/bin/env bash
# Captain Claw — Automated Setup Script for Linux Mint
# Sets up Wine prefix, downloads modern base game (CrazyHook + cnc-ddraw),
# configures 60 FPS / aspect ratio, links cutscenes, and registers desktop launcher.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source canonical path variable from config.env if present
if [[ -f "${SCRIPT_DIR}/config.env" ]]; then
    # shellcheck source=/dev/null
    source "${SCRIPT_DIR}/config.env"
fi

CLAW_INSTALL_DIR="${CLAW_INSTALL_DIR:-${HOME}/games/captain-claw}"
CLAW_GAME_DIR="${CLAW_GAME_DIR:-${CLAW_INSTALL_DIR}/game}"
CLAW_WINE_PREFIX="${CLAW_WINE_PREFIX:-${CLAW_INSTALL_DIR}/wineprefix}"

DOWNLOADS_DIR="${SCRIPT_DIR}/downloads"
DESKTOP_DIR="${HOME}/.local/share/applications"
ICON_DIR="${HOME}/.local/share/icons/hicolor/256x256/apps"

CLAW_ZIP_URL="https://captainclaw.net/dl/CLAW-1.4.5.4.zip"
ZIP_FILE="${CLAW_INSTALL_DIR}/CLAW-1.4.5.4.zip"

echo "=== Captain Claw Setup for Linux Mint ==="
echo "Target installation directory: ${CLAW_INSTALL_DIR}"

# 0. Pre-installation validation (must pass BEFORE requesting sudo or modifying system)
echo "[0/6] Validating installation assets..."
"${SCRIPT_DIR}/validate_installation_files.sh"

# 1. Check & install prerequisites
echo "[1/6] Checking system prerequisites..."
"${SCRIPT_DIR}/install_deps.sh"

# 2. Prepare directories
echo "[2/6] Preparing directories..."
mkdir -p "${CLAW_GAME_DIR}" "${CLAW_WINE_PREFIX}" "${DOWNLOADS_DIR}" "${DESKTOP_DIR}" "${ICON_DIR}"

# 3. Download & extract base game (Claw 1.4.5.4 CrazyHook + cnc-ddraw)
if [ ! -f "${CLAW_GAME_DIR}/CLAW.exe" ] && [ ! -f "${CLAW_GAME_DIR}/CLAW.EXE" ]; then
    echo "[3/6] Downloading Captain Claw v1.4.5.4 from captainclaw.net..."
    curl -L -f --progress-bar -o "${ZIP_FILE}" "${CLAW_ZIP_URL}"
    echo "Extracting game files..."
    unzip -q -o "${ZIP_FILE}" -d "${CLAW_GAME_DIR}"
    rm -f "${ZIP_FILE}"
fi

# Ensure extracted archive folder is flattened if the zip contained a root folder
if [ -d "${CLAW_GAME_DIR}/CLAW-1.4.5.4" ]; then
    echo "Flattening extracted archive structure..."
    chmod -R u+w "${CLAW_GAME_DIR}"
    cp -r "${CLAW_GAME_DIR}/CLAW-1.4.5.4/"* "${CLAW_GAME_DIR}/"
    rm -rf "${CLAW_GAME_DIR}/CLAW-1.4.5.4"
fi

# Ensure user write permissions across all game assets
chmod -R u+w "${CLAW_GAME_DIR}"

# Ensure case-insensitive symlink exists for both CLAW.exe and CLAW.EXE
if [ -f "${CLAW_GAME_DIR}/CLAW.exe" ] && [ ! -f "${CLAW_GAME_DIR}/CLAW.EXE" ]; then
    ln -sf CLAW.exe "${CLAW_GAME_DIR}/CLAW.EXE"
fi

# 4. Apply 60 FPS & aspect ratio configuration (cnc-ddraw)
echo "[4/6] Applying 60 FPS & 4:3 aspect ratio config (ddraw.ini)..."
cp "${SCRIPT_DIR}/ddraw.ini" "${CLAW_GAME_DIR}/ddraw.ini"

# 5. Check for in-game cinematic cutscenes (CLAW.FEC)
echo "[5/6] Checking for cinematic cutscenes (CLAW.FEC)..."
FOUND_CUTSCENES=false
for candidate in "${DOWNLOADS_DIR}/CLAW.FEC" "${DOWNLOADS_DIR}/claw.fec" "${CLAW_GAME_DIR}/CLAW.FEC"; do
    if [ -f "$candidate" ]; then
        if [ "$candidate" != "${CLAW_GAME_DIR}/CLAW.FEC" ]; then
            cp "$candidate" "${CLAW_GAME_DIR}/CLAW.FEC"
        fi
        FOUND_CUTSCENES=true
        echo "Cutscenes (CLAW.FEC) installed successfully!"
        break
    fi
done

if [ "$FOUND_CUTSCENES" = false ]; then
    cat << EOF

--------------------------------------------------------------------------------
[NOTICE: Cutscenes file not found]
The base game is ready, but in-game cutscenes (CLAW.FEC, ~349 MB) need to be
downloaded manually due to cloud host bot-protection:
  1. Download CLAW.FEC from:
     https://www.mediafire.com/file/9yfncm88b9pjewk/CLAW.FEC
  2. Drop the file into:
     ${DOWNLOADS_DIR}/CLAW.FEC
     (or ${CLAW_GAME_DIR}/CLAW.FEC)
The game will still run without cutscenes, but having them gives the full original
experience!
--------------------------------------------------------------------------------

EOF
fi

# 6. Initialize isolated Wine prefix & extract icon
echo "[6/6] Initializing isolated Wine prefix and desktop shortcut..."

# If wineprefix was corrupted or initialized without 32-bit support (missing ntdll.dll), recreate it cleanly
if [ -d "${CLAW_WINE_PREFIX}" ] && [ ! -f "${CLAW_WINE_PREFIX}/drive_c/windows/system32/ntdll.dll" ]; then
    echo "Notice: Wine prefix was missing 32-bit libraries. Re-initializing prefix cleanly..."
    rm -rf "${CLAW_WINE_PREFIX}"
fi

WINEPREFIX="${CLAW_WINE_PREFIX}" WINEDEBUG="-all" wineboot --init
# Ensure Wine always loads the native cnc-ddraw DLL from the game folder
WINEPREFIX="${CLAW_WINE_PREFIX}" WINEDEBUG="-all" wine reg add "HKCU\\Software\\Wine\\DllOverrides" /v ddraw /d "native,builtin" /f 2>/dev/null || true

# Extract game icon if icoutils is available
ICON_SRC="${CLAW_GAME_DIR}/CLAW.exe"
[ ! -f "$ICON_SRC" ] && ICON_SRC="${CLAW_GAME_DIR}/CLAW.EXE"
if command -v wrestool &>/dev/null && [ -f "$ICON_SRC" ]; then
    wrestool -x -t 14 "$ICON_SRC" -o /tmp/claw_icon.ico 2>/dev/null || true
    if [ -f /tmp/claw_icon.ico ]; then
        icotool -x /tmp/claw_icon.ico -o "${ICON_DIR}/captain-claw.png" 2>/dev/null || true
        rm -f /tmp/claw_icon.ico
    fi
fi

# Install desktop shortcut
cp "${SCRIPT_DIR}/captain-claw.desktop" "${DESKTOP_DIR}/captain-claw.desktop"
sed -i "s|Exec=.*|Exec=${SCRIPT_DIR}/launch.sh|g" "${DESKTOP_DIR}/captain-claw.desktop"
chmod +x "${DESKTOP_DIR}/captain-claw.desktop"
update-desktop-database "${DESKTOP_DIR}" 2>/dev/null || true

cat << EOF

================================================================================
 Captain Claw installation complete!
 Installed at: ${CLAW_INSTALL_DIR}
 To play:
   - Launch from your application menu ("Captain Claw"), or
   - Run: ${SCRIPT_DIR}/launch.sh
 Controls:
   - Arrows: Move / Duck / Look up
   - Space: Jump
   - Ctrl: Sword Slash
   - Shift: Magic Claw
   - Alt: Secondary Weapon (Pistol / Dynamite)
   - Z / X: Cycle weapon
   - Esc: Pause / Skip cutscene
================================================================================
EOF

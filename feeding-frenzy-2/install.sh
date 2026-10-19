#!/usr/bin/env bash
# Feeding Frenzy 2: Shipwreck Showdown — Automated Setup Script for Linux Mint
# Sets up isolated Wine prefix, installs game, applies 60 FPS / aspect ratio via cnc-ddraw,
# extracts high-res icons, registers desktop launcher, and adds feeding-frenzy-2 shell alias.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source canonical path variable from config.env if present
if [[ -f "${SCRIPT_DIR}/config.env" ]]; then
    # shellcheck source=/dev/null
    source "${SCRIPT_DIR}/config.env"
fi

FF2_INSTALL_DIR="${FF2_INSTALL_DIR:-${HOME}/games/feeding-frenzy-2}"
FF2_GAME_DIR="${FF2_GAME_DIR:-${FF2_INSTALL_DIR}/game}"
FF2_WINE_PREFIX="${FF2_WINE_PREFIX:-${FF2_INSTALL_DIR}/wineprefix}"
FF2_BASHRC="${FF2_BASHRC:-${HOME}/.bashrc}"

DOWNLOADS_DIR="${SCRIPT_DIR}/downloads"
DESKTOP_DIR="${HOME}/.local/share/applications"
ICON_DIR="${HOME}/.local/share/icons/hicolor/256x256/apps"

FF2_INSTALLER_URL="https://archive.org/download/FeedingFrenzy2_706/FeedingFrenzy2Setup.exe"
INSTALLER_EXE="${DOWNLOADS_DIR}/FeedingFrenzy2Setup.exe"

echo "=== Feeding Frenzy 2: Shipwreck Showdown Setup for Linux Mint ==="
echo "Target installation directory: ${FF2_INSTALL_DIR}"

# 0. Pre-installation validation
echo "[0/6] Validating installation assets & templates..."
"${SCRIPT_DIR}/validate_installation_files.sh"

# 1. Check system prerequisites
echo "[1/6] Checking system prerequisites..."
"${SCRIPT_DIR}/install_deps.sh"

# 2. Prepare directories
echo "[2/6] Preparing directories..."
mkdir -p "${FF2_GAME_DIR}" "${FF2_WINE_PREFIX}" "${DOWNLOADS_DIR}" "${DESKTOP_DIR}" "${ICON_DIR}"

# Initialize isolated Wine prefix
if [[ ! -d "${FF2_WINE_PREFIX}" ]] || [[ ! -f "${FF2_WINE_PREFIX}/drive_c/windows/system32/ntdll.dll" ]]; then
    echo "Initializing clean isolated Wine prefix..."
    WINEPREFIX="${FF2_WINE_PREFIX}" WINEDEBUG="-all" wineboot --init
fi

# 3. Acquire & install base game
GAME_FOUND=false
for candidate in \
    "${FF2_GAME_DIR}/popcapgame1.exe" \
    "${FF2_GAME_DIR}/FeedingFrenzyTwo.exe" \
    "${FF2_GAME_DIR}/FeedingFrenzy2.exe"; do
    if [[ -f "$candidate" ]]; then
        GAME_FOUND=true
        break
    fi
done

if [[ "$GAME_FOUND" = false ]]; then
    if [[ ! -f "${INSTALLER_EXE}" ]]; then
        echo "[3/6] Downloading Feeding Frenzy 2 installer from Internet Archive (~15 MB)..."
        curl -L -f --progress-bar -o "${INSTALLER_EXE}" "${FF2_INSTALLER_URL}"
    else
        echo "[3/6] Using cached installer: ${INSTALLER_EXE}"
    fi

    echo "Running game installer inside isolated Wine prefix..."
    echo "(Please complete the setup wizard to install into the default location)"
    WINEPREFIX="${FF2_WINE_PREFIX}" WINEDEBUG="-all" wine "${INSTALLER_EXE}" || true

    # Look for installed game files in standard Wine Program Files directories
    FOUND_INSTALLED_DIR=""
    for search_dir in \
        "${FF2_WINE_PREFIX}/drive_c/Program Files (x86)/PopCap Games/Feeding Frenzy 2" \
        "${FF2_WINE_PREFIX}/drive_c/Program Files/PopCap Games/Feeding Frenzy 2" \
        "${FF2_WINE_PREFIX}/drive_c/Program Files (x86)/Feeding Frenzy 2" \
        "${FF2_WINE_PREFIX}/drive_c/Program Files/Feeding Frenzy 2"; do
        if [[ -d "$search_dir" ]]; then
            FOUND_INSTALLED_DIR="$search_dir"
            break
        fi
    done

    if [[ -n "$FOUND_INSTALLED_DIR" ]]; then
        echo "Copying game assets from '${FOUND_INSTALLED_DIR}' into '${FF2_GAME_DIR}'..."
        cp -r "${FOUND_INSTALLED_DIR}/"* "${FF2_GAME_DIR}/"
    fi
fi

# Ensure user write permissions across all game assets
chmod -R u+w "${FF2_GAME_DIR}" 2>/dev/null || true

# 4. Apply 60 FPS & aspect ratio configuration (cnc-ddraw)
echo "[4/6] Applying 60 FPS & 4:3 aspect ratio config (cnc-ddraw)..."
cp "${SCRIPT_DIR}/ddraw.ini" "${FF2_GAME_DIR}/ddraw.ini"

# Acquire cnc-ddraw DDRAW.DLL
if [[ ! -f "${FF2_GAME_DIR}/ddraw.dll" ]] && [[ ! -f "${FF2_GAME_DIR}/DDRAW.DLL" ]]; then
    if [[ -f "${HOME}/games/captain-claw/game/DDRAW.DLL" ]]; then
        echo "Using cnc-ddraw from Captain Claw setup..."
        cp "${HOME}/games/captain-claw/game/DDRAW.DLL" "${FF2_GAME_DIR}/ddraw.dll"
    else
        echo "Fetching cnc-ddraw from GitHub..."
        CNC_ZIP="/tmp/cnc-ddraw.zip"
        curl -sL "https://github.com/FunkyFr3sh/cnc-ddraw/releases/latest/download/cnc-ddraw.zip" -o "$CNC_ZIP"
        unzip -q -o "$CNC_ZIP" ddraw.dll -d "${FF2_GAME_DIR}" 2>/dev/null || unzip -q -o "$CNC_ZIP" -d "${FF2_GAME_DIR}"
        rm -f "$CNC_ZIP"
    fi
fi

# Ensure Wine overrides ddraw to native
WINEPREFIX="${FF2_WINE_PREFIX}" WINEDEBUG="-all" wine reg add "HKCU\\Software\\Wine\\DllOverrides" /v ddraw /d "native,builtin" /f 2>/dev/null || true

# 5. Extract icon and deploy desktop launcher
echo "[5/6] Extracting icon and registering desktop launcher..."
ICON_SRC=""
for candidate in \
    "${FF2_GAME_DIR}/popcapgame1.exe" \
    "${FF2_GAME_DIR}/FeedingFrenzyTwo.exe" \
    "${FF2_GAME_DIR}/FeedingFrenzy2.exe"; do
    if [[ -f "$candidate" ]]; then
        ICON_SRC="$candidate"
        break
    fi
done

if [[ -n "$ICON_SRC" ]] && command -v wrestool &>/dev/null && command -v icotool &>/dev/null; then
    wrestool -x -t 14 "$ICON_SRC" -o /tmp/ff2_icon.ico 2>/dev/null || true
    if [[ -f /tmp/ff2_icon.ico ]]; then
        icotool -x /tmp/ff2_icon.ico -o "${ICON_DIR}/feeding-frenzy-2.png" 2>/dev/null || true
        rm -f /tmp/ff2_icon.ico
    fi
fi

cp "${SCRIPT_DIR}/feeding-frenzy-2.desktop" "${DESKTOP_DIR}/feeding-frenzy-2.desktop"
sed -i "s|Exec=.*|Exec=${SCRIPT_DIR}/launch.sh|g" "${DESKTOP_DIR}/feeding-frenzy-2.desktop"
chmod +x "${DESKTOP_DIR}/feeding-frenzy-2.desktop"
if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "${DESKTOP_DIR}" 2>/dev/null || true
fi

# 6. Configure shell alias
echo "[6/6] Configuring shell alias..."
if [[ -f "${FF2_BASHRC}" ]]; then
    # Remove existing alias to maintain idempotency
    sed -i '/alias feeding-frenzy-2=/d' "${FF2_BASHRC}"
    echo "alias feeding-frenzy-2='${SCRIPT_DIR}/launch.sh'" >> "${FF2_BASHRC}"
    echo "Registered alias: feeding-frenzy-2 in ${FF2_BASHRC}"
fi

cat << EOF

================================================================================
 Feeding Frenzy 2: Shipwreck Showdown installation complete!
 Installed at: ${FF2_INSTALL_DIR}
 To play:
   - Run from terminal: feeding-frenzy-2  (or source ~/.bashrc first)
   - Launch from your application menu ("Feeding Frenzy 2"), or
   - Run: ${SCRIPT_DIR}/launch.sh
 Features:
   - 60 FPS VSync locked via cnc-ddraw
   - 4:3 Aspect ratio preserved with integer scaling
   - Display resolution auto-restoration trap on exit
================================================================================
EOF

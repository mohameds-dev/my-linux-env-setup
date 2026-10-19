#!/usr/bin/env bash
# Captain Claw Launcher
# Runs Captain Claw with an isolated Wine prefix and optimal performance settings

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

# Resolve executable (case-resilient)
CLAW_EXE=""
if [[ -f "${CLAW_GAME_DIR}/CLAW.exe" ]]; then
    CLAW_EXE="${CLAW_GAME_DIR}/CLAW.exe"
elif [[ -f "${CLAW_GAME_DIR}/CLAW.EXE" ]]; then
    CLAW_EXE="${CLAW_GAME_DIR}/CLAW.EXE"
fi

if [[ -z "${CLAW_EXE}" ]]; then
    echo "Error: Captain Claw is not installed yet at: ${CLAW_GAME_DIR}" >&2
    echo "Please run install.sh first: cd \"${SCRIPT_DIR}\" && ./install.sh" >&2
    exit 1
fi

if ! command -v wine &>/dev/null; then
    echo "Error: Wine is not installed on this machine." >&2
    echo "Please run install.sh first: cd \"${SCRIPT_DIR}\" && ./install.sh" >&2
    exit 1
fi

export WINEPREFIX="${CLAW_WINE_PREFIX}"
export WINEDEBUG="-all"
# Force Wine to load native cnc-ddraw (DDRAW.DLL in game folder) rather than Wine's built-in ddraw
export WINEDLLOVERRIDES="ddraw=n,b"

# Auto-initialize Wine prefix if missing or corrupted (prevents c0000135 ntdll.dll errors)
if [[ ! -d "${CLAW_WINE_PREFIX}" ]] || [[ ! -f "${CLAW_WINE_PREFIX}/drive_c/windows/system32/ntdll.dll" ]]; then
    echo "Initializing clean Wine prefix at: ${CLAW_WINE_PREFIX}..."
    rm -rf "${CLAW_WINE_PREFIX}"
    WINEPREFIX="${CLAW_WINE_PREFIX}" WINEDEBUG="-all" wineboot --init
    WINEPREFIX="${CLAW_WINE_PREFIX}" WINEDEBUG="-all" wine reg add "HKCU\\Software\\Wine\\DllOverrides" /v ddraw /d "native,builtin" /f 2>/dev/null || true
fi

# Display resolution restoration safety-net:
# Guarantees that upon game exit (or crash), the desktop resolution is immediately restored to native.
restore_display() {
    if command -v xrandr &>/dev/null; then
        xrandr -s 0 2>/dev/null || true
    fi
}
trap restore_display EXIT INT TERM

# Ensure working directory is the game folder so DLLs and assets load correctly
cd "${CLAW_GAME_DIR}"
wine "${CLAW_EXE}" "$@"

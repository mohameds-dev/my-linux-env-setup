#!/usr/bin/env bash
# Feeding Frenzy 2 Launcher
# Runs Feeding Frenzy 2 with an isolated Wine prefix, cnc-ddraw, and robust display restoration

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

# Capture primary display and native resolution before launching
PRIMARY_OUTPUT=$(xrandr --current 2>/dev/null | grep ' connected' | awk '{print $1}' | head -n 1 || true)
ORIG_MODE=$(xrandr --current 2>/dev/null | grep '\*' | awk '{print $1}' | head -n 1 || true)

# Display resolution restoration safety-net:
# Guarantees that upon game exit, interruption, or crash, native desktop resolution is immediately restored.
restore_display() {
    if command -v xrandr &>/dev/null; then
        if [[ -n "${PRIMARY_OUTPUT:-}" ]] && [[ -n "${ORIG_MODE:-}" ]]; then
            xrandr --output "${PRIMARY_OUTPUT}" --mode "${ORIG_MODE}" 2>/dev/null || \
            xrandr --output "${PRIMARY_OUTPUT}" --auto 2>/dev/null || \
            xrandr -s 0 2>/dev/null || true
        else
            for out in $(xrandr --current 2>/dev/null | grep ' connected' | awk '{print $1}'); do
                xrandr --output "$out" --auto 2>/dev/null || true
            done
            xrandr -s 0 2>/dev/null || true
        fi
    fi
}

trap restore_display EXIT INT TERM HUP

# In case resolution was left modified from an earlier crash, restore immediately before starting
restore_display

# Resolve executable (case-resilient and handles spaces)
FF2_EXE=""
for candidate in \
    "${FF2_GAME_DIR}/Feeding Frenzy 2.exe" \
    "${FF2_GAME_DIR}/Feeding Frenzy 2.RWG" \
    "${FF2_GAME_DIR}/FeedingFrenzyTwo.exe" \
    "${FF2_GAME_DIR}/FeedingFrenzy2.exe" \
    "${FF2_GAME_DIR}/FEEDINGFRENZY2.EXE" \
    "${FF2_GAME_DIR}/popcapgame1.exe" \
    "${FF2_GAME_DIR}/POPCAPGAME1.EXE"; do
    if [[ -f "$candidate" ]]; then
        FF2_EXE="$candidate"
        break
    fi
done

if [[ -z "${FF2_EXE}" ]]; then
    echo "Error: Feeding Frenzy 2 is not installed yet at: ${FF2_GAME_DIR}" >&2
    echo "Please run install.sh first: cd \"${SCRIPT_DIR}\" && ./install.sh" >&2
    exit 1
fi

if ! command -v wine &>/dev/null; then
    echo "Error: Wine is not installed on this machine." >&2
    echo "Please run install.sh first: cd \"${SCRIPT_DIR}\" && ./install.sh" >&2
    exit 1
fi

export WINEPREFIX="${FF2_WINE_PREFIX}"
export WINEDEBUG="-all"
# Force Wine to load native cnc-ddraw (ddraw.dll in game folder) rather than Wine's built-in ddraw
export WINEDLLOVERRIDES="ddraw=n,b"

# Auto-initialize Wine prefix if missing or corrupted
if [[ ! -d "${FF2_WINE_PREFIX}" ]] || [[ ! -f "${FF2_WINE_PREFIX}/drive_c/windows/system32/ntdll.dll" ]]; then
    echo "Initializing clean Wine prefix at: ${FF2_WINE_PREFIX}..."
    rm -rf "${FF2_WINE_PREFIX}"
    WINEPREFIX="${FF2_WINE_PREFIX}" WINEDEBUG="-all" wineboot --init
    WINEPREFIX="${FF2_WINE_PREFIX}" WINEDEBUG="-all" wine reg add "HKCU\\Software\\Wine\\DllOverrides" /v ddraw /d "native,builtin" /f 2>/dev/null || true
fi

echo "Starting Feeding Frenzy 2: Shipwreck Showdown (60 FPS)..."
cd "${FF2_GAME_DIR}"
wine "${FF2_EXE}" "$@"

#!/usr/bin/env bash
# Clean Uninstaller for Captain Claw on Linux Mint / Ubuntu
# Removes installed game binaries, isolated Wine prefix, desktop entries,
# and system icons to prepare for a clean re-installation.
#
# NOTE: Preserves downloaded source assets in downloads/ (e.g. CLAW.FEC)
# so you don't have to re-download anything when installing again.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source canonical configuration if present
if [[ -f "${SCRIPT_DIR}/config.env" ]]; then
    # shellcheck source=/dev/null
    source "${SCRIPT_DIR}/config.env"
fi

CLAW_INSTALL_DIR="${CLAW_INSTALL_DIR:-${HOME}/games/captain-claw}"
CLAW_GAME_DIR="${CLAW_GAME_DIR:-${CLAW_INSTALL_DIR}/game}"
CLAW_WINE_PREFIX="${CLAW_WINE_PREFIX:-${CLAW_INSTALL_DIR}/wineprefix}"
CLAW_DESKTOP_DIR="${CLAW_DESKTOP_DIR:-${HOME}/.local/share/applications}"
CLAW_ICON_DIR="${CLAW_ICON_DIR:-${HOME}/.local/share/icons}"

AUTO_CONFIRM=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes)
            AUTO_CONFIRM=true
            shift
            ;;
        --install-dir)
            CLAW_INSTALL_DIR="$2"
            CLAW_GAME_DIR="${CLAW_INSTALL_DIR}/game"
            CLAW_WINE_PREFIX="${CLAW_INSTALL_DIR}/wineprefix"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [-y|--yes] [--install-dir <path>]"
            echo "Cleanly removes Captain Claw installation, Wine prefix, and desktop shortcuts."
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

echo "=== Captain Claw Clean Uninstaller ==="
echo "The following will be completely removed:"
echo "  - Game files:     ${CLAW_GAME_DIR}"
echo "  - Wine prefix:    ${CLAW_WINE_PREFIX}"
echo "  - Install folder: ${CLAW_INSTALL_DIR}"
echo "  - Desktop entry:  ${CLAW_DESKTOP_DIR}/captain-claw.desktop"
echo "  - Game icons in:  ${CLAW_ICON_DIR}"
echo
echo "(Note: Downloaded assets in ${SCRIPT_DIR}/downloads will be preserved)"
echo

if [ "$AUTO_CONFIRM" = false ]; then
    read -r -p "Are you sure you want to proceed with clean uninstallation? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            ;;
        *)
            echo "Aborted by user."
            exit 0
            ;;
    esac
fi

# 1. Remove Game Files & Wine Prefix
if [ -d "${CLAW_INSTALL_DIR}" ]; then
    echo "Removing installation directory: ${CLAW_INSTALL_DIR}..."
    chmod -R u+w "${CLAW_INSTALL_DIR}" 2>/dev/null || true
    rm -rf "${CLAW_INSTALL_DIR}"
fi

# 2. Remove Desktop Shortcut
DESKTOP_FILE="${CLAW_DESKTOP_DIR}/captain-claw.desktop"
if [ -f "${DESKTOP_FILE}" ]; then
    echo "Removing desktop entry: ${DESKTOP_FILE}..."
    rm -f "${DESKTOP_FILE}"
fi

# 3. Remove Desktop Icons
if [ -d "${CLAW_ICON_DIR}" ]; then
    echo "Removing application icons..."
    find "${CLAW_ICON_DIR}" -type f -name "captain-claw.png" -delete 2>/dev/null || true
fi

# 4. Refresh Desktop & Icon Caches
if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "${CLAW_DESKTOP_DIR}" 2>/dev/null || true
fi

if command -v update-icon-caches &>/dev/null; then
    update-icon-caches "${CLAW_ICON_DIR}"/* 2>/dev/null || true
fi

echo
echo "================================================================================"
echo " Captain Claw has been cleanly uninstalled!"
echo " Everything has been wiped clean."
echo " To re-install cleanly, simply run:"
echo "   cd \"${SCRIPT_DIR}\" && ./install.sh"
echo "================================================================================"
exit 0

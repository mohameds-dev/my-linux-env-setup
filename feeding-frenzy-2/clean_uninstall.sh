#!/usr/bin/env bash
# Clean Uninstaller for Feeding Frenzy 2 on Linux Mint / Ubuntu
# Removes installed game binaries, isolated Wine prefix, desktop entries,
# system icons, and shell alias to prepare for a clean re-installation.
#
# NOTE: Preserves downloaded source assets in downloads/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source canonical configuration if present
if [[ -f "${SCRIPT_DIR}/config.env" ]]; then
    # shellcheck source=/dev/null
    source "${SCRIPT_DIR}/config.env"
fi

FF2_INSTALL_DIR="${FF2_INSTALL_DIR:-${HOME}/games/feeding-frenzy-2}"
FF2_GAME_DIR="${FF2_GAME_DIR:-${FF2_INSTALL_DIR}/game}"
FF2_WINE_PREFIX="${FF2_WINE_PREFIX:-${FF2_INSTALL_DIR}/wineprefix}"
FF2_DESKTOP_DIR="${FF2_DESKTOP_DIR:-${HOME}/.local/share/applications}"
FF2_ICON_DIR="${FF2_ICON_DIR:-${HOME}/.local/share/icons}"
FF2_BASHRC="${FF2_BASHRC:-${HOME}/.bashrc}"

AUTO_CONFIRM=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes)
            AUTO_CONFIRM=true
            shift
            ;;
        --install-dir)
            FF2_INSTALL_DIR="$2"
            FF2_GAME_DIR="${FF2_INSTALL_DIR}/game"
            FF2_WINE_PREFIX="${FF2_INSTALL_DIR}/wineprefix"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [-y|--yes] [--install-dir <path>]"
            echo "Cleanly removes Feeding Frenzy 2 installation, Wine prefix, desktop shortcuts, and alias."
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

echo "=== Feeding Frenzy 2 Clean Uninstaller ==="
echo "The following will be completely removed:"
echo "  - Game files:     ${FF2_GAME_DIR}"
echo "  - Wine prefix:    ${FF2_WINE_PREFIX}"
echo "  - Install folder: ${FF2_INSTALL_DIR}"
echo "  - Desktop entry:  ${FF2_DESKTOP_DIR}/feeding-frenzy-2.desktop"
echo "  - Game icons in:  ${FF2_ICON_DIR}"
echo "  - Shell alias:    feeding-frenzy-2 in ${FF2_BASHRC}"
echo
echo "(Note: Downloaded assets in ${SCRIPT_DIR}/downloads will be preserved)"
echo

if [[ "$AUTO_CONFIRM" = false ]]; then
    read -r -p "Are you sure you want to proceed with uninstallation? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            ;;
        *)
            echo "Uninstallation cancelled."
            exit 0
            ;;
    esac
fi

# 1. Remove game installation directory and isolated wineprefix
if [[ -d "${FF2_INSTALL_DIR}" ]]; then
    echo "Removing installation directory: ${FF2_INSTALL_DIR}..."
    rm -rf "${FF2_INSTALL_DIR}"
    echo "  [OK] Removed ${FF2_INSTALL_DIR}"
else
    echo "  [SKIP] Installation directory does not exist: ${FF2_INSTALL_DIR}"
fi

# 2. Remove desktop launcher
DESKTOP_FILE="${FF2_DESKTOP_DIR}/feeding-frenzy-2.desktop"
if [[ -f "${DESKTOP_FILE}" ]]; then
    echo "Removing desktop shortcut: ${DESKTOP_FILE}..."
    rm -f "${DESKTOP_FILE}"
    if command -v update-desktop-database &>/dev/null; then
        update-desktop-database "${FF2_DESKTOP_DIR}" 2>/dev/null || true
    fi
    echo "  [OK] Removed desktop shortcut"
else
    echo "  [SKIP] Desktop shortcut not found: ${DESKTOP_FILE}"
fi

# 3. Remove application icons
echo "Cleaning up application icons..."
find "${FF2_ICON_DIR}" -name "feeding-frenzy-2.png" -delete 2>/dev/null || true
if [[ -f "${FF2_ICON_DIR}/feeding-frenzy-2.png" ]]; then
    rm -f "${FF2_ICON_DIR}/feeding-frenzy-2.png"
fi
if command -v gtk-update-icon-cache &>/dev/null; then
    gtk-update-icon-cache "${FF2_ICON_DIR}/hicolor" 2>/dev/null || true
fi
echo "  [OK] Cleaned up icons"

# 4. Remove shell alias
if [[ -f "${FF2_BASHRC}" ]]; then
    echo "Removing alias from ${FF2_BASHRC}..."
    sed -i '/alias feeding-frenzy-2=/d' "${FF2_BASHRC}"
    echo "  [OK] Removed feeding-frenzy-2 alias"
fi

echo
echo "Feeding Frenzy 2 has been cleanly uninstalled."

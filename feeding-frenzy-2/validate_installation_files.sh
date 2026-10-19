#!/usr/bin/env bash
# Pre-installation Validator for Feeding Frenzy 2 on Linux Mint
# Checks and validates all necessary assets and configurations BEFORE the installer
# runs or requests administrative permissions (sudo).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source configuration if present
if [[ -f "${SCRIPT_DIR}/config.env" ]]; then
    # shellcheck source=/dev/null
    source "${SCRIPT_DIR}/config.env"
fi

FF2_INSTALL_DIR="${FF2_INSTALL_DIR:-${HOME}/games/feeding-frenzy-2}"
FF2_GAME_DIR="${FF2_GAME_DIR:-${FF2_INSTALL_DIR}/game}"
FF2_DOWNLOADS_DIR="${FF2_DOWNLOADS_DIR:-${SCRIPT_DIR}/downloads}"

# Parse optional CLI flags (overrides environment variables)
while [[ $# -gt 0 ]]; do
    case "$1" in
        --downloads-dir)
            FF2_DOWNLOADS_DIR="$2"
            shift 2
            ;;
        --install-dir)
            FF2_INSTALL_DIR="$2"
            FF2_GAME_DIR="${FF2_INSTALL_DIR}/game"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--downloads-dir <path>] [--install-dir <path>]"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

ERRORS=0

echo "=== Feeding Frenzy 2 Pre-Installation Validation ==="
echo "Checking installation files and required templates..."

# 1. Validate local template files
for file in "${SCRIPT_DIR}/ddraw.ini" "${SCRIPT_DIR}/launch.sh" "${SCRIPT_DIR}/feeding-frenzy-2.desktop"; do
    if [[ -f "$file" ]]; then
        echo "  [OK] Local template: $(basename "$file")"
    else
        echo "  [FAIL] Missing template: $(basename "$file") in ${SCRIPT_DIR}" >&2
        ERRORS=$((ERRORS + 1))
    fi
done

# 2. Check game asset readiness
if [[ -f "${FF2_GAME_DIR}/popcapgame1.exe" ]] || [[ -f "${FF2_GAME_DIR}/FeedingFrenzyTwo.exe" ]] || [[ -f "${FF2_GAME_DIR}/FeedingFrenzy2.exe" ]]; then
    echo "  [OK] Game binaries: already present in ${FF2_GAME_DIR}"
elif [[ -f "${FF2_DOWNLOADS_DIR}/FeedingFrenzy2Setup.exe" ]]; then
    echo "  [OK] Game installer: cached at ${FF2_DOWNLOADS_DIR}/FeedingFrenzy2Setup.exe"
else
    echo "  [INFO] Game installer: will be automatically fetched during installation (~15 MB)"
fi

# Final verdict
if [[ "$ERRORS" -gt 0 ]]; then
    cat << EOF >&2

================================================================================
 PRE-INSTALLATION VALIDATION FAILED
 Missing required template or configuration files above.
 Please verify your repository files.
================================================================================
EOF
    exit 1
fi

echo "Pre-installation validation successful!"
exit 0

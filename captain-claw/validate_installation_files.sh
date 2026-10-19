#!/usr/bin/env bash
# Pre-installation Validator for Captain Claw on Linux Mint
# Checks and validates all necessary assets and configurations BEFORE the installer
# runs or requests administrative permissions (sudo).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source configuration if present
if [[ -f "${SCRIPT_DIR}/config.env" ]]; then
    # shellcheck source=/dev/null
    source "${SCRIPT_DIR}/config.env"
fi

CLAW_INSTALL_DIR="${CLAW_INSTALL_DIR:-${HOME}/games/captain-claw}"
CLAW_GAME_DIR="${CLAW_GAME_DIR:-${CLAW_INSTALL_DIR}/game}"
CLAW_DOWNLOADS_DIR="${CLAW_DOWNLOADS_DIR:-${SCRIPT_DIR}/downloads}"

# Parse optional CLI flags (overrides environment variables)
while [[ $# -gt 0 ]]; do
    case "$1" in
        --downloads-dir)
            CLAW_DOWNLOADS_DIR="$2"
            shift 2
            ;;
        --install-dir)
            CLAW_INSTALL_DIR="$2"
            CLAW_GAME_DIR="${CLAW_INSTALL_DIR}/game"
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
MIN_CUTSCENE_SIZE_BYTES=$((10 * 1024 * 1024)) # 10 MB minimum to detect empty/html files

echo "=== Captain Claw Pre-Installation Validation ==="
echo "Checking installation files and required assets..."

# 1. Validate local configuration files
for file in "${SCRIPT_DIR}/ddraw.ini" "${SCRIPT_DIR}/launch.sh" "${SCRIPT_DIR}/captain-claw.desktop"; do
    if [[ -f "$file" ]]; then
        echo "  [OK] Local template: $(basename "$file")"
    else
        echo "  [FAIL] Missing template: $(basename "$file") in ${SCRIPT_DIR}" >&2
        ERRORS=$((ERRORS + 1))
    fi
done

# 2. Validate in-game cutscenes (CLAW.FEC)
FOUND_FEC=""
for candidate in \
    "${CLAW_DOWNLOADS_DIR}/CLAW.FEC" \
    "${CLAW_DOWNLOADS_DIR}/claw.fec" \
    "${CLAW_GAME_DIR}/CLAW.FEC" \
    "${CLAW_GAME_DIR}/claw.fec"; do
    if [[ -f "$candidate" ]]; then
        FOUND_FEC="$candidate"
        break
    fi
done

if [[ -z "$FOUND_FEC" ]]; then
    echo "  [FAIL] Missing CLAW.FEC (in-game animated cutscenes, ~349 MB)" >&2
    ERRORS=$((ERRORS + 1))
else
    # Check file size to prevent 0-byte or corrupt HTML downloads
    FEC_SIZE=$(stat -c%s "$FOUND_FEC" 2>/dev/null || wc -c < "$FOUND_FEC" || echo 0)
    if [[ "$FEC_SIZE" -lt "$MIN_CUTSCENE_SIZE_BYTES" ]]; then
        echo "  [FAIL] CLAW.FEC is invalid, empty, or corrupt (size: ${FEC_SIZE} bytes; expected ~349 MB)" >&2
        ERRORS=$((ERRORS + 1))
    else
        FEC_SIZE_MB=$((FEC_SIZE / 1024 / 1024))
        echo "  [OK] Cutscenes verified: ${FOUND_FEC} (${FEC_SIZE_MB} MB)"
    fi
fi

# 3. Check base game asset readiness
if [[ -f "${CLAW_GAME_DIR}/CLAW.EXE" ]]; then
    echo "  [OK] Base game: already extracted in ${CLAW_GAME_DIR}"
elif [[ -f "${CLAW_DOWNLOADS_DIR}/CLAW-1.4.5.4.zip" ]]; then
    echo "  [OK] Base game: archive cached at ${CLAW_DOWNLOADS_DIR}/CLAW-1.4.5.4.zip"
else
    echo "  [INFO] Base game: will be automatically downloaded from captainclaw.net (~74 MB)"
fi

# Final verdict
if [[ "$ERRORS" -gt 0 ]]; then
    cat << EOF >&2

================================================================================
 VALIDATION FAILED: Installation cannot proceed yet!
 Missing or invalid files must be provided before installing.
================================================================================

To fix missing cutscenes (CLAW.FEC):
  1. Download the file from MediaFire:
     https://www.mediafire.com/file/9yfncm88b9pjewk/CLAW.FEC
     (Alternative MEGA mirror: https://mega.nz/folder/f0MhhbbC#lW1gBoVRbrLCxOjzJCo_0A)

  2. Place the file here:
     ${CLAW_DOWNLOADS_DIR}/CLAW.FEC

Once the file is placed, re-run ./install.sh.
================================================================================
EOF
    exit 1
fi

echo "  [OK] All required files passed validation. Ready to proceed!"
exit 0

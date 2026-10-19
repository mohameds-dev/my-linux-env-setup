#!/usr/bin/env bash
# Captain Claw Prerequisites Installer for Linux Mint / Ubuntu
# Maintains list of system dependencies, their respective validation check commands,
# and automatically installs missing packages via apt.

set -euo pipefail

CHECK_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check-only)
            CHECK_ONLY=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--check-only]"
            echo "Checks and installs required runtime dependencies for Captain Claw."
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

echo "=== Checking Captain Claw System Dependencies ==="

# List of dependencies with their verification command:
# Format: "PACKAGE_NAME|VERIFICATION_COMMAND"
DEPS=(
    "curl|command -v curl"
    "unzip|command -v unzip"
    "wine|command -v wine"
    "wine64|dpkg -l wine64 2>/dev/null | grep -q '^ii'"
    "wine32:i386|dpkg -l wine32:i386 2>/dev/null | grep -q '^ii'"
    "libasound2-plugins:i386|dpkg -l libasound2-plugins:i386 2>/dev/null | grep -q '^ii'"
    "fluidsynth|command -v fluidsynth"
    "fluid-soundfont-gm|test -f /usr/share/sounds/sf2/FluidR3_GM.sf2 || (dpkg -l fluid-soundfont-gm 2>/dev/null | grep -q '^ii')"
    "icoutils|command -v icotool"
)

MISSING_PKGS=()

# Loop through dependencies and verify installation status
for entry in "${DEPS[@]}"; do
    pkg="${entry%%|*}"
    check_cmd="${entry#*|}"

    if eval "$check_cmd" &>/dev/null; then
        echo "  [OK] ${pkg} is installed."
    else
        echo "  [MISSING] ${pkg} is NOT installed."
        MISSING_PKGS+=("${pkg}")
    fi
done

if [ ${#MISSING_PKGS[@]} -eq 0 ]; then
    echo "All dependencies are satisfied and ready!"
    exit 0
fi

if [ "$CHECK_ONLY" = true ]; then
    echo "Check-only mode: missing packages: ${MISSING_PKGS[*]}"
    exit 1
fi

echo
echo "Installing missing dependencies (${MISSING_PKGS[*]})..."
echo "(Administrator privileges required)"

# Enable 32-bit architecture if 32-bit packages are among the missing list
if printf '%s\n' "${MISSING_PKGS[@]}" | grep -q ':i386'; then
    echo "Enabling i386 multiarch architecture..."
    sudo dpkg --add-architecture i386 || true
fi

sudo apt-get update
sudo apt-get install -y "${MISSING_PKGS[@]}"

# Re-verify after installation
STILL_MISSING=()
for pkg in "${MISSING_PKGS[@]}"; do
    for entry in "${DEPS[@]}"; do
        if [ "${entry%%|*}" = "$pkg" ]; then
            check_cmd="${entry#*|}"
            if ! eval "$check_cmd" &>/dev/null; then
                STILL_MISSING+=("$pkg")
            fi
            break
        fi
    done
done

if [ ${#STILL_MISSING[@]} -gt 0 ]; then
    echo "Error: Failed to install: ${STILL_MISSING[*]}" >&2
    exit 1
fi

echo "All dependencies installed successfully!"
exit 0

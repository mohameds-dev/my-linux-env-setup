#!/usr/bin/env bash
# Feeding Frenzy 2 — Dependency Installer & Checker for Linux Mint
# Checks and installs Wine (including 32-bit multiarch) and utility tools.

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
            echo "Checks and installs required runtime dependencies for Feeding Frenzy 2."
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

echo "=== Feeding Frenzy 2 Dependency Check ==="

# Define required packages and check methods
# format: "PACKAGE_NAME|VERIFICATION_COMMAND"
DEPS=(
    "wine|wine --version"
    "wine32:i386|dpkg -l wine32:i386 2>/dev/null | grep -q '^ii'"
    "curl|command -v curl"
    "unzip|command -v unzip"
    "icoutils|command -v wrestool && command -v icotool"
)

MISSING_PKGS=()

for entry in "${DEPS[@]}"; do
    pkg="${entry%%|*}"
    check_cmd="${entry#*|}"

    echo -n "Checking for ${pkg}... "
    if eval "$check_cmd" &>/dev/null; then
        echo "[OK]"
    else
        echo "[MISSING]"
        MISSING_PKGS+=("${pkg}")
    fi
done

if [[ ${#MISSING_PKGS[@]} -eq 0 ]]; then
    echo "All dependencies are satisfied!"
    exit 0
fi

if [[ "$CHECK_ONLY" == true ]]; then
    echo "Missing dependencies: ${MISSING_PKGS[*]}"
    exit 0
fi

echo "Installing missing dependencies: ${MISSING_PKGS[*]}..."

# Enable 32-bit multiarch if wine32:i386 is needed
if [[ " ${MISSING_PKGS[*]} " =~ " wine32:i386 " ]]; then
    if ! dpkg --print-foreign-architectures | grep -q "i386"; then
        echo "Adding i386 multiarch architecture..."
        sudo dpkg --add-architecture i386
        sudo apt-get update
    fi
fi

sudo apt-get update
sudo apt-get install -y "${MISSING_PKGS[@]}"

echo "Dependencies installed successfully!"

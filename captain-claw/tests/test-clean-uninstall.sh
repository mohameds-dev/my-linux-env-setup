#!/usr/bin/env bash
# TDD Test for clean_uninstall.sh
# Verifies that clean_uninstall.sh cleanly removes game files, wineprefix,
# desktop shortcut, and application icons, while preserving downloaded source assets.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAW_DIR="$(cd "${TEST_DIR}/.." && pwd)"
UNINSTALLER="${CLAW_DIR}/clean_uninstall.sh"

PASS=0
FAIL=0

check() {
    local desc="$1"; shift
    if "$@"; then
        echo "  ok   - $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL - $desc"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Running TDD tests for Captain Claw clean_uninstall.sh ==="

# 1. Script existence and executability
echo "# Step 1: Checking uninstaller script existence"
check "clean_uninstall.sh exists" test -f "$UNINSTALLER"
check "clean_uninstall.sh is executable" test -x "$UNINSTALLER"

# Create a temporary sandbox directory for testing
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

FAKE_INSTALL_DIR="$SANDBOX/games/captain-claw"
FAKE_GAME_DIR="$FAKE_INSTALL_DIR/game"
FAKE_WINE_PREFIX="$FAKE_INSTALL_DIR/wineprefix"
FAKE_DESKTOP_DIR="$SANDBOX/applications"
FAKE_ICON_DIR="$SANDBOX/icons/hicolor/256x256/apps"
FAKE_DOWNLOADS="$SANDBOX/downloads"

mkdir -p "$FAKE_GAME_DIR" "$FAKE_WINE_PREFIX" "$FAKE_DESKTOP_DIR" "$FAKE_ICON_DIR" "$FAKE_DOWNLOADS"

# Populate sandbox with dummy installed files
touch "$FAKE_GAME_DIR/CLAW.exe"
touch "$FAKE_GAME_DIR/ddraw.ini"
touch "$FAKE_WINE_PREFIX/system.reg"
touch "$FAKE_DESKTOP_DIR/captain-claw.desktop"
touch "$FAKE_ICON_DIR/captain-claw.png"
touch "$FAKE_DOWNLOADS/CLAW.FEC" # Source asset that must be preserved

# 2. Execution of clean_uninstall.sh
echo "# Step 2: Executing clean_uninstall.sh on sandbox"
set +e
OUT="$(
    CLAW_INSTALL_DIR="$FAKE_INSTALL_DIR" \
    CLAW_DESKTOP_DIR="$FAKE_DESKTOP_DIR" \
    CLAW_ICON_DIR="$SANDBOX/icons" \
    bash "$UNINSTALLER" --yes 2>&1
)"
RC=$?
set -e

check "uninstaller exits with code 0" test "$RC" -eq 0

# 3. Verify installed components are deleted
echo "# Step 3: Verifying uninstalled components are removed"
check "game directory is removed" test ! -d "$FAKE_GAME_DIR"
check "wine prefix is removed" test ! -d "$FAKE_WINE_PREFIX"
check "install root directory is removed" test ! -d "$FAKE_INSTALL_DIR"
check "desktop shortcut is removed" test ! -f "$FAKE_DESKTOP_DIR/captain-claw.desktop"
check "desktop icon is removed" test ! -f "$FAKE_ICON_DIR/captain-claw.png"

# 4. Verify downloads are preserved for a future clean install
echo "# Step 4: Verifying downloaded assets are preserved"
check "downloads directory and CLAW.FEC are preserved" test -f "$FAKE_DOWNLOADS/CLAW.FEC"

echo
echo "Results: passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]

#!/usr/bin/env bash
# TDD Test for clean_uninstall.sh in Feeding Frenzy 2
# Verifies removal of game files, wineprefix, desktop shortcut, icon, and alias.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FF2_DIR="$(cd "${TEST_DIR}/.." && pwd)"
UNINSTALLER="${FF2_DIR}/clean_uninstall.sh"

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

echo "=== Running TDD tests for Feeding Frenzy 2 clean_uninstall.sh ==="

# 1. Script existence and executability
check "clean_uninstall.sh exists" test -f "$UNINSTALLER"
check "clean_uninstall.sh is executable" test -x "$UNINSTALLER"

# Sandbox
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

FAKE_INSTALL_DIR="$SANDBOX/games/feeding-frenzy-2"
FAKE_GAME_DIR="$FAKE_INSTALL_DIR/game"
FAKE_WINE_PREFIX="$FAKE_INSTALL_DIR/wineprefix"
FAKE_DESKTOP_DIR="$SANDBOX/applications"
FAKE_ICON_DIR="$SANDBOX/icons/hicolor/256x256/apps"
FAKE_DOWNLOADS="$SANDBOX/downloads"
FAKE_BASHRC="$SANDBOX/.bashrc"

mkdir -p "$FAKE_GAME_DIR" "$FAKE_WINE_PREFIX" "$FAKE_DESKTOP_DIR" "$FAKE_ICON_DIR" "$FAKE_DOWNLOADS"

# Dummy files
touch "$FAKE_GAME_DIR/popcapgame1.exe"
touch "$FAKE_GAME_DIR/ddraw.ini"
touch "$FAKE_WINE_PREFIX/system.reg"
touch "$FAKE_DESKTOP_DIR/feeding-frenzy-2.desktop"
touch "$FAKE_ICON_DIR/feeding-frenzy-2.png"
touch "$FAKE_DOWNLOADS/FeedingFrenzy2Setup.exe"
echo "alias feeding-frenzy-2='$FAKE_INSTALL_DIR/launch.sh'" >> "$FAKE_BASHRC"

if [ -x "$UNINSTALLER" ]; then
    echo "# Step 2: Executing uninstaller in sandbox"
    FF2_INSTALL_DIR="$FAKE_INSTALL_DIR" \
    FF2_DESKTOP_DIR="$FAKE_DESKTOP_DIR" \
    FF2_ICON_DIR="$FAKE_ICON_DIR" \
    FF2_BASHRC="$FAKE_BASHRC" \
    "$UNINSTALLER" -y --install-dir "$FAKE_INSTALL_DIR"

    check "game directory is removed" test ! -d "$FAKE_GAME_DIR"
    check "wine prefix is removed" test ! -d "$FAKE_WINE_PREFIX"
    check "install folder is removed" test ! -d "$FAKE_INSTALL_DIR"
    check "desktop shortcut is removed" test ! -f "$FAKE_DESKTOP_DIR/feeding-frenzy-2.desktop"
    check "desktop icon is removed" test ! -f "$FAKE_ICON_DIR/feeding-frenzy-2.png"
    check "downloads directory is preserved" test -f "$FAKE_DOWNLOADS/FeedingFrenzy2Setup.exe"
    check "alias is removed from bashrc" bash -c '! grep -q "feeding-frenzy-2" "$1"' _ "$FAKE_BASHRC"
fi

echo "Summary: $PASS passed, $FAIL failed"
exit "$FAIL"

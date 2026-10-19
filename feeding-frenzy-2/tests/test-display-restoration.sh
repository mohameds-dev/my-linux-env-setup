#!/usr/bin/env bash
# TDD Test for Display Resolution Restoration in Feeding Frenzy 2
# Verifies that launch.sh captures original resolution and restores it on exit,
# and supports 'Feeding Frenzy 2.exe' with spaces.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FF2_DIR="$(cd "${TEST_DIR}/.." && pwd)"
LAUNCHER="${FF2_DIR}/launch.sh"

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

echo "=== Running TDD tests for display resolution restoration ==="

# 1. Check launcher existence
check "launch.sh exists" test -f "$LAUNCHER"
check "launch.sh is executable" test -x "$LAUNCHER"

# 2. Check candidate executables list includes space-separated binary
check "supports 'Feeding Frenzy 2.exe' with spaces" grep -q 'Feeding Frenzy 2.exe' "$LAUNCHER"

# 3. Check robust restoration logic
check "restores output via --auto or --mode" grep -E -q 'xrandr.*--output.*--auto|xrandr.*--output.*--mode' "$LAUNCHER"
check "traps EXIT INT TERM" grep -q 'trap.*restore_display.*EXIT' "$LAUNCHER"

# 4. Sandbox test: launch.sh resolves game executable properly with mock wine/wineboot
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

FAKE_INSTALL_DIR="$SANDBOX/games/feeding-frenzy-2"
FAKE_GAME_DIR="$FAKE_INSTALL_DIR/game"
FAKE_PREFIX="$FAKE_INSTALL_DIR/wineprefix"
FAKE_BIN="$SANDBOX/bin"
mkdir -p "$FAKE_GAME_DIR" "$FAKE_PREFIX/drive_c/windows/system32" "$FAKE_BIN"
touch "$FAKE_PREFIX/drive_c/windows/system32/ntdll.dll"

# Create mock wine tools
cat << 'EOF' > "$FAKE_BIN/wine"
#!/bin/sh
echo "MOCK_WINE_INVOKED: $@"
exit 0
EOF
chmod +x "$FAKE_BIN/wine"

cat << 'EOF' > "$FAKE_BIN/wineboot"
#!/bin/sh
exit 0
EOF
chmod +x "$FAKE_BIN/wineboot"

touch "$FAKE_GAME_DIR/Feeding Frenzy 2.exe"

set +e
RESOLVED_OUT=$(PATH="$FAKE_BIN:$PATH" FF2_INSTALL_DIR="$FAKE_INSTALL_DIR" FF2_GAME_DIR="$FAKE_GAME_DIR" FF2_WINE_PREFIX="$FAKE_PREFIX" bash "$LAUNCHER" 2>&1)
set -e

check "resolves 'Feeding Frenzy 2.exe' successfully" bash -c '! grep -q "not installed yet" <<< "$1"' _ "$RESOLVED_OUT"
check "invokes wine with resolved executable" bash -c 'grep -q "Feeding Frenzy 2.exe" <<< "$1"' _ "$RESOLVED_OUT"

echo "Summary: $PASS passed, $FAIL failed"
exit "$FAIL"

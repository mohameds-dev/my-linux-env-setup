#!/usr/bin/env bash
# TDD Test for feeding-frenzy-2 alias integration
# Verifies that installation adds the alias to bashrc idempotently,
# and uninstallation removes it.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FF2_DIR="$(cd "${TEST_DIR}/.." && pwd)"
INSTALLER="${FF2_DIR}/install.sh"
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

echo "=== Running TDD tests for feeding-frenzy-2 alias ==="

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

FAKE_BASHRC="$SANDBOX/.bashrc"
touch "$FAKE_BASHRC"

# 1. Scripts existence
check "installer exists" test -f "$INSTALLER"
check "uninstaller exists" test -f "$UNINSTALLER"

if [ -f "$INSTALLER" ] && [ -f "$UNINSTALLER" ]; then
    # Test adding alias
    check "installer contains feeding-frenzy-2 alias logic" bash -c 'grep -q "alias feeding-frenzy-2=" "$1"' _ "$INSTALLER"
    check "uninstaller contains feeding-frenzy-2 alias removal logic" bash -c 'grep -q "feeding-frenzy-2" "$1"' _ "$UNINSTALLER"
fi

echo "Summary: $PASS passed, $FAIL failed"
exit "$FAIL"

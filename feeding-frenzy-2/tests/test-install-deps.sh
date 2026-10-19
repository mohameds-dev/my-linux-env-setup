#!/usr/bin/env bash
# TDD Test for install_deps.sh in Feeding Frenzy 2
# Verifies dependencies checking and check-only mode.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FF2_DIR="$(cd "${TEST_DIR}/.." && pwd)"
DEPS_SCRIPT="${FF2_DIR}/install_deps.sh"

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

echo "=== Running TDD tests for Feeding Frenzy 2 install_deps.sh ==="

# 1. Script existence and executability
echo "# Step 1: Checking install_deps.sh existence"
check "install_deps.sh exists" test -f "$DEPS_SCRIPT"
check "install_deps.sh is executable" test -x "$DEPS_SCRIPT"

# 2. Check structure: script must contain dependencies
echo "# Step 2: Checking script contents and loop"
if [ -f "$DEPS_SCRIPT" ]; then
    check "defines wine32:i386 dependency" bash -c 'grep -q "wine32:i386" "$1"' _ "$DEPS_SCRIPT"
    check "defines icoutils/icotool dependency" bash -c 'grep -q "icotool" "$1"' _ "$DEPS_SCRIPT"
    check "defines wrestool dependency" bash -c 'grep -q "wrestool" "$1"' _ "$DEPS_SCRIPT"
    check "defines curl dependency" bash -c 'grep -q "curl" "$1"' _ "$DEPS_SCRIPT"
else
    check "defines wine32:i386 dependency" false
    check "defines icoutils/icotool dependency" false
    check "defines wrestool dependency" false
    check "defines curl dependency" false
fi

# 3. Check-only mode
echo "# Step 3: Testing check-only mode"
if [ -x "$DEPS_SCRIPT" ]; then
    set +e
    OUT_CHECK="$("$DEPS_SCRIPT" --check-only 2>&1)"
    RC_CHECK=$?
    set -e
    check "--check-only exits 0" test "$RC_CHECK" -eq 0
fi

echo "Summary: $PASS passed, $FAIL failed"
exit "$FAIL"

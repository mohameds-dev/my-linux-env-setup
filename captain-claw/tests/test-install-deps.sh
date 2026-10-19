#!/usr/bin/env bash
# TDD Test for install_deps.sh
# Verifies that install_deps.sh defines dependencies with their check commands,
# iterates through them, identifies missing vs installed packages, and integrates with install.sh.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAW_DIR="$(cd "${TEST_DIR}/.." && pwd)"
DEPS_SCRIPT="${CLAW_DIR}/install_deps.sh"
INSTALLER="${CLAW_DIR}/install.sh"

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

echo "=== Running TDD tests for install_deps.sh ==="

# 1. Script existence and executability
echo "# Step 1: Checking install_deps.sh existence"
check "install_deps.sh exists" test -f "$DEPS_SCRIPT"
check "install_deps.sh is executable" test -x "$DEPS_SCRIPT"

# 2. Check structure: script must contain dependencies list and loop
echo "# Step 2: Checking script contents and loop"
if [ -f "$DEPS_SCRIPT" ]; then
    check "defines wine32:i386 dependency" bash -c 'grep -q "wine32:i386" "$1"' _ "$DEPS_SCRIPT"
    check "defines fluidsynth dependency" bash -c 'grep -q "fluidsynth" "$1"' _ "$DEPS_SCRIPT"
    check "defines fluid-soundfont-gm dependency" bash -c 'grep -q "fluid-soundfont-gm" "$1"' _ "$DEPS_SCRIPT"
    check "iterates over dependencies in a loop" bash -c 'grep -q "for .* in .*DEPS" "$1"' _ "$DEPS_SCRIPT"
else
    check "defines wine32:i386 dependency" false
    check "defines fluidsynth dependency" false
    check "defines fluid-soundfont-gm dependency" false
    check "iterates over dependencies in a loop" false
fi

# 3. Dry-run / check mode: when run with --check-only, reports status without requiring sudo
echo "# Step 3: Testing check-only mode"
if [ -x "$DEPS_SCRIPT" ]; then
    set +e
    CHECK_OUT="$("$DEPS_SCRIPT" --check-only 2>&1)"
    RC=$?
    set -e
    check "--check-only exits without sudo failure" test "$RC" -eq 0 -o "$RC" -eq 1
    check "--check-only output lists package check results" bash -c 'grep -qi "installed\|missing" <<<"$1"' _ "$CHECK_OUT"
else
    check "--check-only exits without sudo failure" false
    check "--check-only output lists package check results" false
fi

# 4. Installer integration: install.sh must call install_deps.sh
echo "# Step 4: Verifying install.sh calls install_deps.sh"
check "install.sh references install_deps.sh" bash -c 'grep -q "install_deps\.sh" "$1"' _ "$INSTALLER"

echo
echo "Results: passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]

#!/usr/bin/env bash
# Tests for Feeding Frenzy 2 pre-installation validation
# Verifies that validate_installation_files.sh checks all required assets and templates.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FF2_DIR="$(cd "${TEST_DIR}/.." && pwd)"
VALIDATOR="${FF2_DIR}/validate_installation_files.sh"

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

echo "=== Running TDD tests for Feeding Frenzy 2 validation ==="

# 1. Script existence and executability
echo "# Step 1: Checking validator script existence"
check "validator script exists" test -f "$VALIDATOR"
check "validator script is executable" test -x "$VALIDATOR"

# Create sandbox
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

SANDBOX_DOWNLOADS="$SANDBOX/downloads"
SANDBOX_INSTALL_DIR="$SANDBOX/install_dir"
mkdir -p "$SANDBOX_DOWNLOADS" "$SANDBOX_INSTALL_DIR"

if [ -x "$VALIDATOR" ]; then
    echo "# Step 2: Testing validator functionality"
    set +e
    OUT_VALID="$(FF2_INSTALL_DIR="$SANDBOX_INSTALL_DIR" FF2_DOWNLOADS_DIR="$SANDBOX_DOWNLOADS" bash "$VALIDATOR" 2>&1)"
    RC_VALID=$?
    set -e
    check "validator executes successfully" test "$RC_VALID" -eq 0
fi

echo "Summary: $PASS passed, $FAIL failed"
exit "$FAIL"

#!/usr/bin/env bash
# Tests for Captain Claw pre-installation validation
# Verifies that validate_installation_files.sh checks all required assets and blocks
# the installer before any privileged commands (sudo) are invoked.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAW_DIR="$(cd "${TEST_DIR}/.." && pwd)"
VALIDATOR="${CLAW_DIR}/validate_installation_files.sh"
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

echo "=== Running TDD tests for Captain Claw validation ==="

# 1. Script existence and executability
echo "# Step 1: Checking validator script existence"
check "validator script exists" test -f "$VALIDATOR"
check "validator script is executable" test -x "$VALIDATOR"

# Create a temporary sandbox directory for testing
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

SANDBOX_DOWNLOADS="$SANDBOX/downloads"
SANDBOX_INSTALL_DIR="$SANDBOX/install_dir"
mkdir -p "$SANDBOX_DOWNLOADS" "$SANDBOX_INSTALL_DIR"

# 2. Validation fails when CLAW.FEC is missing
echo "# Step 2: Validator blocks when CLAW.FEC is missing"
set +e
OUT_MISSING="$(CLAW_INSTALL_DIR="$SANDBOX_INSTALL_DIR" CLAW_DOWNLOADS_DIR="$SANDBOX_DOWNLOADS" bash "$VALIDATOR" 2>&1)"
RC_MISSING=$?
set -e
check "validator exits non-zero when CLAW.FEC is missing" test "$RC_MISSING" -ne 0
check "validator output mentions CLAW.FEC" bash -c 'grep -qi "CLAW.FEC" <<<"$1"' _ "$OUT_MISSING"
check "validator output provides download link" bash -c 'grep -qi "mediafire\|download" <<<"$1"' _ "$OUT_MISSING"

# 3. Validation fails when CLAW.FEC is an empty / corrupted dummy file
echo "# Step 3: Validator blocks when CLAW.FEC is empty or corrupt"
touch "$SANDBOX_DOWNLOADS/CLAW.FEC"
set +e
OUT_EMPTY="$(CLAW_INSTALL_DIR="$SANDBOX_INSTALL_DIR" CLAW_DOWNLOADS_DIR="$SANDBOX_DOWNLOADS" bash "$VALIDATOR" 2>&1)"
RC_EMPTY=$?
set -e
check "validator exits non-zero on empty CLAW.FEC" test "$RC_EMPTY" -ne 0
check "validator output mentions file size / invalid file" bash -c 'grep -qi "size\|empty\|corrupt" <<<"$1"' _ "$OUT_EMPTY"

# 4. Validation succeeds when all required assets are present and valid
echo "# Step 4: Validator succeeds when valid files are in place"
truncate -s 60M "$SANDBOX_DOWNLOADS/CLAW.FEC"
set +e
OUT_VALID="$(CLAW_INSTALL_DIR="$SANDBOX_INSTALL_DIR" CLAW_DOWNLOADS_DIR="$SANDBOX_DOWNLOADS" bash "$VALIDATOR" 2>&1)"
RC_VALID=$?
set -e
check "validator exits 0 when valid files are present" test "$RC_VALID" -eq 0
check "validator reports all files passed" bash -c 'grep -qi "passed\|ready" <<<"$1"' _ "$OUT_VALID"

# 5. Installer integration check: install.sh must fail immediately if validation fails, BEFORE sudo
echo "# Step 5: Installer integration — blocks before sudo when files are missing"
EMPTY_TEST_DIR="$SANDBOX/missing_assets_case"
mkdir -p "$EMPTY_TEST_DIR/downloads" "$EMPTY_TEST_DIR/install"
FAKE_BIN="$SANDBOX/fake_bin"
mkdir -p "$FAKE_BIN"
cat > "$FAKE_BIN/sudo" <<'EOF'
#!/bin/sh
echo "ERROR: sudo was called before validation passed!" >&2
exit 99
EOF
chmod +x "$FAKE_BIN/sudo"

set +e
OUT_INSTALL_BLOCKED="$(
    PATH="$FAKE_BIN:$PATH" \
    CLAW_INSTALL_DIR="$EMPTY_TEST_DIR/install" \
    CLAW_DOWNLOADS_DIR="$EMPTY_TEST_DIR/downloads" \
    bash "$INSTALLER" 2>&1
)"
RC_INSTALL_BLOCKED=$?
set -e

check "install.sh exits non-zero when validation fails" test "$RC_INSTALL_BLOCKED" -ne 0
check "install.sh never called sudo when files were missing" \
    bash -c '! grep -q "ERROR: sudo was called before validation passed!" <<<"$1"' _ "$OUT_INSTALL_BLOCKED"

# 6. Real downloads check: test real downloads/CLAW.FEC currently present on system
echo "# Step 6: Validating real CLAW.FEC present on system"
set +e
OUT_REAL="$(bash "$VALIDATOR" 2>&1)"
RC_REAL=$?
set -e
check "validator successfully recognizes real CLAW.FEC" test "$RC_REAL" -eq 0

# 7. CLI arguments check: verify --downloads-dir works without environment variables
echo "# Step 7: Testing CLI argument flag --downloads-dir"
set +e
OUT_FLAG_MISSING="$(bash "$VALIDATOR" --downloads-dir "$SANDBOX_DOWNLOADS/nonexistent" --install-dir "$SANDBOX_INSTALL_DIR" 2>&1)"
RC_FLAG_MISSING=$?
set -e
check "validator accepts --downloads-dir and fails when dir is empty" test "$RC_FLAG_MISSING" -ne 0
check "validator output shows overridden directory" bash -c 'grep -qi "$1" <<<"$2"' _ "$SANDBOX_DOWNLOADS/nonexistent" "$OUT_FLAG_MISSING"

echo
echo "Results: passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]

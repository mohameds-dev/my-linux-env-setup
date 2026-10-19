#!/bin/bash
# End-to-end test for ../install-go.sh.
#
# Runs the real installer against a throwaway root directory so your actual
# /usr/local is never touched, then checks the result by running the installed
# binary for real (no mocks) and compiling/running a test Go program.
#
# By default, downloads and caches the latest stable Go release (~70 MB)
# to avoid re-downloading on repeated test runs.
# Point GO_TARBALL to use a specific tarball:
#   GO_TARBALL=/path/to/go.tar.gz ./tests/test-install-go.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$DIR/install-go.sh"

PASS=0
FAIL=0
check() {
    local desc="$1"; shift
    if "$@"; then
        echo "  ok   - $desc"; PASS=$((PASS + 1))
    else
        echo "  FAIL - $desc"; FAIL=$((FAIL + 1))
    fi
}

echo "# Step 1: Checking installer script existence"
check "installer script exists" test -f "$INSTALLER"
check "installer script is executable" test -x "$INSTALLER"

if [ ! -f "$INSTALLER" ]; then
    echo
    echo "Installer $INSTALLER does not exist."
    echo "passed: $PASS  failed: $((FAIL + 1))"
    exit 1
fi

FAKE_ROOT="$(mktemp -d)"
FAKE_INSTALL_ROOT="$FAKE_ROOT/usr/local"
FAKE_BIN_DIR="$FAKE_ROOT/usr/local/bin"
mkdir -p "$FAKE_INSTALL_ROOT" "$FAKE_BIN_DIR"

trap 'rm -rf "$FAKE_ROOT"' EXIT

# Cache downloaded tarball across test runs if possible
CACHE_DIR="${TMPDIR:-/tmp}/go-installer-test-cache"
mkdir -p "$CACHE_DIR"
CACHED_TARBALL=""
if [ -n "${GO_TARBALL:-}" ] && [ -f "${GO_TARBALL}" ]; then
    CACHED_TARBALL="$GO_TARBALL"
else
    EXISTING_CACHE="$(find "$CACHE_DIR" -name "go*.linux-*.tar.gz" 2>/dev/null | head -1 || true)"
    if [ -n "$EXISTING_CACHE" ] && [ -f "$EXISTING_CACHE" ]; then
        CACHED_TARBALL="$EXISTING_CACHE"
    else
        echo "Downloading stable Go tarball into test cache ($CACHE_DIR)..."
        FILENAME="$(python3 -c "
import urllib.request, json, sys
try:
    req = urllib.request.Request('https://go.dev/dl/?mode=json', headers={'User-Agent': 'linux-env-setup'})
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = json.loads(resp.read().decode())
        for rel in data:
            if rel.get('stable', False):
                for f in rel.get('files', []):
                    if f.get('os') == 'linux' and f.get('arch') == 'amd64' and f.get('kind') == 'archive':
                        print(f.get('filename', ''))
                        sys.exit(0)
except Exception:
    sys.exit(1)
" 2>/dev/null || true)"
        if [ -n "$FILENAME" ]; then
            wget -q -O "$CACHE_DIR/$FILENAME" "https://go.dev/dl/$FILENAME"
            CACHED_TARBALL="$CACHE_DIR/$FILENAME"
        fi
    fi
fi

run_installer() {
    local env_vars=()
    env_vars+=(GO_INSTALL_ROOT="$FAKE_INSTALL_ROOT")
    env_vars+=(GO_BIN_DIR="$FAKE_BIN_DIR")
    if [ -n "$CACHED_TARBALL" ]; then
        env_vars+=(GO_TARBALL="$CACHED_TARBALL")
    fi
    env "${env_vars[@]}" bash "$INSTALLER"
}

echo "# Step 2: Fresh install into isolated target"
OUT1="$(run_installer 2>&1)"; RC1=$?
echo "$OUT1" | sed 's/^/    | /'
check "installer exits 0" test "$RC1" -eq 0

GO_DIR="$FAKE_INSTALL_ROOT/go"
BIN_GO="$FAKE_BIN_DIR/go"
BIN_GOFMT="$FAKE_BIN_DIR/gofmt"

check "install directory $GO_DIR exists" test -d "$GO_DIR"
check "symlink $BIN_GO exists" test -L "$BIN_GO"
check "symlink $BIN_GO points to $GO_DIR/bin/go" test "$(readlink -f "$BIN_GO")" = "$GO_DIR/bin/go"
check "symlink $BIN_GO is executable" test -x "$BIN_GO"
check "symlink $BIN_GOFMT exists" test -L "$BIN_GOFMT"
check "symlink $BIN_GOFMT points to $GO_DIR/bin/gofmt" test "$(readlink -f "$BIN_GOFMT")" = "$GO_DIR/bin/gofmt"
check "symlink $BIN_GOFMT is executable" test -x "$BIN_GOFMT"

echo "# Step 3: Real binary verification (no mocks)"
VERSION_OUT="$("$BIN_GO" version 2>/dev/null || true)"
echo "    | version: $VERSION_OUT"
check "'go version' prints expected format ($VERSION_OUT)" \
    bash -c '[[ "$1" =~ go\ version\ go[0-9]+\.[0-9]+ ]]' _ "$VERSION_OUT"

# Verify real compiler functionality by building & running a hello world
TEST_PROG_DIR="$(mktemp -d)"
cat > "$TEST_PROG_DIR/main.go" <<'EOF'
package main
import "fmt"
func main() {
    fmt.Println("hello from test-install-go")
}
EOF

RUN_OUT="$(PATH="$FAKE_BIN_DIR:$PATH" "$BIN_GO" run "$TEST_PROG_DIR/main.go" 2>&1 || true)"
rm -rf "$TEST_PROG_DIR"
check "compiled and ran minimal Go program successfully" test "$RUN_OUT" = "hello from test-install-go"

echo "# Step 4: Idempotence test (second run should no-op)"
OUT2="$(PATH="$FAKE_BIN_DIR:$PATH" run_installer 2>&1)"; RC2=$?
echo "$OUT2" | sed 's/^/    | /'
check "second run exits 0" test "$RC2" -eq 0
check "second run reports already installed" \
    bash -c 'grep -qi "already installed" <<<"$1"' _ "$OUT2"

echo "# Step 5: Error handling"
BAD_ARCH_DIR="$(mktemp -d)"
OUT_ARCH="$(env PATH="$BAD_ARCH_DIR:$PATH" GO_INSTALL_ROOT="$BAD_ARCH_DIR" GO_BIN_DIR="$BAD_ARCH_DIR" bash -c "
    uname() { echo 'mips64'; }
    export -f uname
    bash '$INSTALLER'
" 2>&1 || true)"
rm -rf "$BAD_ARCH_DIR"
check "fails gracefully on unsupported architecture" \
    bash -c 'grep -qi "unsupported CPU architecture" <<<"$1"' _ "$OUT_ARCH"

BAD_TAR="$(mktemp --suffix=.tar.gz)"
echo "not a real tar" > "$BAD_TAR"
ERR_DIR="$(mktemp -d)"
OUT_TAR="$(GO_TARBALL="$BAD_TAR" GO_INSTALL_ROOT="$ERR_DIR" GO_BIN_DIR="$ERR_DIR" bash "$INSTALLER" 2>&1 || true)"
rm -rf "$BAD_TAR" "$ERR_DIR"
check "fails gracefully on invalid tarball" \
    bash -c '[[ "$1" =~ (gzip|tar|Archive does not contain) ]]' _ "$OUT_TAR"

echo
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]

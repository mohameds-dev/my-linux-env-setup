#!/bin/bash
# End-to-end test for ../install-antigravity-ide.sh.
#
# Runs the real installer against a throwaway $HOME, so your actual
# ~/.local is never touched, then checks the result by running the
# installed binary for real (no mocks).
#
# By default the installer downloads the IDE itself (~240 MB). To skip the
# download, point ANTIGRAVITY_IDE_TARBALL at an "Antigravity IDE.tar.gz"
# you already have:
#   ANTIGRAVITY_IDE_TARBALL=~/Downloads/Antigravity\ IDE.tar.gz ./tests/test-install-antigravity-ide.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$DIR/install-antigravity-ide.sh"

FAKE_HOME="$(mktemp -d)"
trap 'rm -rf "$FAKE_HOME"' EXIT

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

run_installer() {
    HOME="$FAKE_HOME" bash "$INSTALLER"
}

BIN="$FAKE_HOME/.local/bin/antigravity-ide"
DESKTOP="$FAKE_HOME/.local/share/applications/antigravity-ide.desktop"

echo "# first run (fresh install)"
check "installer script exists" test -f "$INSTALLER"
OUT1="$(run_installer 2>&1)"; RC1=$?
echo "$OUT1" | sed 's/^/    | /'
check "installer exits 0" test "$RC1" -eq 0
check "~/.local/bin/antigravity-ide is a symlink" test -L "$BIN"
check "symlink resolves to an executable" test -x "$(readlink -f "$BIN")"

VERSION_OUT="$("$BIN" --version 2>/dev/null | head -1)"
check "'antigravity-ide --version' prints a version ($VERSION_OUT)" \
    bash -c '[[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]' _ "$VERSION_OUT"

check "desktop entry exists" test -f "$DESKTOP"
EXEC_PATH="$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' "$DESKTOP" 2>/dev/null)"
ICON_PATH="$(sed -n 's/^Icon=//p' "$DESKTOP" 2>/dev/null)"
check "desktop Exec points to an executable ($EXEC_PATH)" test -x "$EXEC_PATH"
check "desktop Icon file exists ($ICON_PATH)" test -f "$ICON_PATH"
if command -v desktop-file-validate >/dev/null 2>&1; then
    check "desktop entry passes desktop-file-validate" desktop-file-validate "$DESKTOP"
fi

echo "# second run (should be a no-op)"
OUT2="$(run_installer 2>&1)"; RC2=$?
echo "$OUT2" | sed 's/^/    | /'
check "second run exits 0" test "$RC2" -eq 0
check "second run reports already installed" \
    bash -c 'grep -qi "already installed" <<<"$1"' _ "$OUT2"

# antigravity.google sometimes serves a page variant with no download links
# (seen ~40% of requests). The installer must retry instead of giving up.
# A stub `wget` on PATH serves a link-less page twice, then a page with the
# link; the "download" itself copies the real tarball.
echo "# download page flakiness (retry)"
if [ -n "${ANTIGRAVITY_IDE_TARBALL:-}" ]; then
    RETRY_HOME="$(mktemp -d)"; STUB_DIR="$(mktemp -d)"
    trap 'rm -rf "$FAKE_HOME" "$RETRY_HOME" "$STUB_DIR"' EXIT
    cat > "$STUB_DIR/wget" <<'STUB'
#!/bin/bash
url="${*: -1}"; out=""
while [ $# -gt 0 ]; do [ "$1" = "-O" ] && out="$2"; shift; done
if [[ "$url" == *antigravity.google/download* ]]; then
    n=$(( $(cat "$STUB_DIR/count" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$STUB_DIR/count"
    if [ "$n" -le 2 ]; then echo '<html>no links here</html>'
    else echo '<a href="https://example.test/stable/9.9/linux-x64/Antigravity%20IDE.tar.gz">'; fi
else
    cp "$REAL_TARBALL" "$out"
fi
STUB
    chmod +x "$STUB_DIR/wget"
    OUT3="$(env -u ANTIGRAVITY_IDE_TARBALL HOME="$RETRY_HOME" PATH="$STUB_DIR:$PATH" \
        STUB_DIR="$STUB_DIR" REAL_TARBALL="$ANTIGRAVITY_IDE_TARBALL" bash "$INSTALLER" 2>&1)"; RC3=$?
    echo "$OUT3" | sed 's/^/    | /'
    check "installer survives link-less pages and installs" test "$RC3" -eq 0 -a -x "$RETRY_HOME/.local/bin/antigravity-ide"
    check "it fetched the page more than once" test "$(cat "$STUB_DIR/count" 2>/dev/null || echo 0)" -ge 3
else
    echo "  skip - set ANTIGRAVITY_IDE_TARBALL to run this section"
fi

echo
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]

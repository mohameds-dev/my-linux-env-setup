#!/bin/bash
# Installs Go (Golang) from the official Go distribution tarball.
#
# Pulls the latest stable release from https://go.dev/dl/, extracts it into
# /usr/local/go (or $GO_INSTALL_ROOT/go), and symlinks the binaries (`go` and
# `gofmt`) into /usr/local/bin (or $GO_BIN_DIR).
#
# Set GO_TARBALL=/path/to/go.tar.gz to install from a pre-downloaded archive
# instead of fetching it over the network.
set -euo pipefail

INSTALL_ROOT="${GO_INSTALL_ROOT:-/usr/local}"
BIN_DIR="${GO_BIN_DIR:-/usr/local/bin}"
TARGET_DIR="$INSTALL_ROOT/go"

if [ -x "$BIN_DIR/go" ]; then
    echo "Go is already installed ($("$BIN_DIR/go" version))."
    exit 0
elif command -v go >/dev/null 2>&1; then
    echo "Go is already installed ($(go version))."
    exit 0
fi

case "$(uname -m)" in
    x86_64)  ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    armv6l)  ARCH="armv6l" ;;
    *) echo "Unsupported CPU architecture: $(uname -m)" >&2; exit 1 ;;
esac

CLEANUP_PATHS=()
cleanup() {
    for p in "${CLEANUP_PATHS[@]}"; do
        rm -rf "$p" 2>/dev/null || true
    done
}
trap cleanup EXIT

TARBALL="${GO_TARBALL:-}"

if [ -z "$TARBALL" ]; then
    echo "Checking latest stable Go release for linux-$ARCH..."
    FILENAME=""
    if command -v python3 >/dev/null 2>&1; then
        FILENAME="$(python3 -c "
import urllib.request, json, sys
try:
    req = urllib.request.Request('https://go.dev/dl/?mode=json', headers={'User-Agent': 'linux-env-setup'})
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = json.loads(resp.read().decode())
        for rel in data:
            if rel.get('stable', False):
                for f in rel.get('files', []):
                    if f.get('os') == 'linux' and f.get('arch') == '$ARCH' and f.get('kind') == 'archive':
                        print(f.get('filename', ''))
                        sys.exit(0)
except Exception:
    sys.exit(1)
" 2>/dev/null || true)"
    fi

    if [ -z "$FILENAME" ]; then
        # Fallback to web scrape via wget if JSON query fails
        FILENAME="$(wget -q -O - "https://go.dev/dl/" \
            | grep -oE "go[0-9]+(\.[0-9]+)+\.linux-${ARCH}\.tar\.gz" \
            | head -1 || true)"
    fi

    if [ -z "$FILENAME" ]; then
        echo "Could not resolve latest Go download from https://go.dev/dl/." >&2
        echo "Provide GO_TARBALL=/path/to/go.tar.gz to install manually." >&2
        exit 1
    fi

    URL="https://go.dev/dl/$FILENAME"
    TMP_TAR="$(mktemp --suffix=.tar.gz)"
    CLEANUP_PATHS+=("$TMP_TAR")

    echo "Downloading $FILENAME from $URL..."
    if [ -t 1 ]; then
        wget -q --show-progress -O "$TMP_TAR" "$URL"
    else
        wget -q -O "$TMP_TAR" "$URL"
    fi
    TARBALL="$TMP_TAR"
fi

if [ ! -f "$TARBALL" ]; then
    echo "Go tarball not found: $TARBALL" >&2
    exit 1
fi

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if [ ! -w "$INSTALL_ROOT" ] || [ ! -w "$BIN_DIR" ]; then
        SUDO="sudo"
    fi
fi

$SUDO mkdir -p "$INSTALL_ROOT" "$BIN_DIR"

TMP_DIR="$(mktemp -d)"
CLEANUP_PATHS+=("$TMP_DIR")

echo "Extracting Go archive..."
tar -xzf "$TARBALL" -C "$TMP_DIR"

if [ ! -d "$TMP_DIR/go" ] || [ ! -x "$TMP_DIR/go/bin/go" ]; then
    echo "Archive does not contain a valid Go tree." >&2
    exit 1
fi

$SUDO rm -rf "$TARGET_DIR"
$SUDO mv "$TMP_DIR/go" "$TARGET_DIR"

$SUDO ln -sf "$TARGET_DIR/bin/go" "$BIN_DIR/go"
$SUDO ln -sf "$TARGET_DIR/bin/gofmt" "$BIN_DIR/gofmt"

INSTALLED_VERSION="$("$BIN_DIR/go" version 2>/dev/null || echo "Go")"
echo "Installed $INSTALLED_VERSION to $TARGET_DIR."
echo "Binaries symlinked into $BIN_DIR (go, gofmt)."

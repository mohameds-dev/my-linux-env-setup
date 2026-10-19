#!/bin/bash
# Installs Antigravity IDE (Google's VS Code-based AI IDE) for the current
# user, from Google's official Linux tarball. No sudo needed.
#
# Google doesn't ship the IDE via apt, so this finds the current tarball URL
# on the official download page (https://antigravity.google/download?os=linux),
# unpacks it to ~/.local/share/antigravity-ide, puts the `antigravity-ide`
# command on PATH via ~/.local/bin, and adds an app-menu entry.
#
# Not to be confused with "Antigravity" 2.0 (the standalone agent desktop
# app, file name Antigravity.tar.gz). This script only installs the IDE
# ("Antigravity IDE.tar.gz").
#
# Set ANTIGRAVITY_IDE_TARBALL=/path/to/Antigravity\ IDE.tar.gz to install
# from a tarball you've already downloaded instead of downloading it.
set -euo pipefail

INSTALL_DIR="$HOME/.local/share/antigravity-ide"
BIN_LINK="$HOME/.local/bin/antigravity-ide"
DESKTOP_FILE="$HOME/.local/share/applications/antigravity-ide.desktop"
DOWNLOAD_PAGE="https://antigravity.google/download?os=linux"

if [ -x "$BIN_LINK" ]; then
    echo "Antigravity IDE is already installed ($(readlink -f "$BIN_LINK"))."
    exit 0
fi

TARBALL="${ANTIGRAVITY_IDE_TARBALL:-}"
if [ -z "$TARBALL" ]; then
    case "$(uname -m)" in
        x86_64)  ARCH=linux-x64 ;;
        aarch64) ARCH=linux-arm ;;
        *) echo "Unsupported CPU architecture: $(uname -m)" >&2; exit 1 ;;
    esac

    URL=""
    for attempt in 1 2 3 4 5; do
        URL="$(wget -q -O - "$DOWNLOAD_PAGE" \
            | grep -oE "https://[^\"' ]+/$ARCH/Antigravity%20IDE\.tar\.gz" \
            | head -1 || true)"
        [ -n "$URL" ] && break
        sleep 1
    done
    if [ -z "$URL" ]; then
        echo "Couldn't find the $ARCH Antigravity IDE download on $DOWNLOAD_PAGE." >&2
        echo "Download it manually and re-run with ANTIGRAVITY_IDE_TARBALL=/path/to/file." >&2
        exit 1
    fi

    TARBALL="$(mktemp --suffix=.tar.gz)"
    trap 'rm -f "$TARBALL"' EXIT
    echo "Downloading Antigravity IDE ($ARCH) from $URL ..."
    wget -q -O "$TARBALL" "$URL"
fi

# The tarball's top-level folder is "Antigravity IDE" (with a space); strip
# it so the install path has no spaces (simpler Exec= line in the .desktop).
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR" "$(dirname "$BIN_LINK")" "$(dirname "$DESKTOP_FILE")"
tar -xzf "$TARBALL" -C "$INSTALL_DIR" --strip-components=1

ln -sf "$INSTALL_DIR/bin/antigravity-ide" "$BIN_LINK"

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=Antigravity IDE
Comment=Google's AI-first IDE (built on VS Code)
GenericName=Text Editor
Exec=$INSTALL_DIR/antigravity-ide %F
Icon=$INSTALL_DIR/resources/app/resources/linux/code.png
Type=Application
StartupNotify=true
StartupWMClass=Antigravity IDE
Categories=Development;IDE;
MimeType=text/plain;inode/directory;x-scheme-handler/antigravity-ide;
Keywords=antigravity;vscode;code;editor;
EOF
update-desktop-database "$(dirname "$DESKTOP_FILE")" 2>/dev/null || true

echo "Installed Antigravity IDE $("$BIN_LINK" --version 2>/dev/null | head -1) to $INSTALL_DIR."
echo "Launch it from the app menu, or run 'antigravity-ide' ('antigravity-ide .' opens the current folder)."

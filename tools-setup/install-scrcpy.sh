#!/bin/bash
# Installs scrcpy + adb for mirroring an Android device (e.g. a tablet) over
# USB.
#
# adb comes from the Ubuntu/Mint universe repo (apt) — it's a stable
# protocol and the packaged version is fine.
#
# scrcpy does NOT come from apt: Ubuntu/Mint repos ship an ancient 1.25
# (2021), which crashes against modern Android versions (uses internal
# Android APIs — e.g. SurfaceControl.createDisplay — that newer Android
# releases removed). Instead this pulls the prebuilt static x86_64 Linux
# binary from scrcpy's own official GitHub Releases (the same artifact the
# project ships for every release) into /opt, and symlinks it onto PATH
# ahead of apt's copy.
set -euo pipefail

SCRCPY_VERSION="4.1"
INSTALL_ROOT=/opt
TARGET_DIR="$INSTALL_ROOT/scrcpy-$SCRCPY_VERSION"

if [ -x "$INSTALL_ROOT/scrcpy/scrcpy" ] && "$INSTALL_ROOT/scrcpy/scrcpy" --version 2>/dev/null | grep -q "scrcpy $SCRCPY_VERSION" \
    && command -v adb >/dev/null 2>&1; then
    echo "scrcpy $SCRCPY_VERSION and adb are already installed."
    exit 0
fi

sudo apt-get update -qq
sudo apt-get install -y adb

# Remove apt's broken old scrcpy if present, so it can't shadow the real one.
if dpkg -l scrcpy >/dev/null 2>&1 && dpkg -l scrcpy 2>/dev/null | grep -q '^ii'; then
    sudo apt-get remove -y scrcpy
fi

TMP_TAR="$(mktemp --suffix=.tar.gz)"
trap 'rm -f "$TMP_TAR"' EXIT

echo "Downloading scrcpy $SCRCPY_VERSION (prebuilt Linux x86_64)..."
wget -q -O "$TMP_TAR" "https://github.com/Genymobile/scrcpy/releases/download/v$SCRCPY_VERSION/scrcpy-linux-x86_64-v$SCRCPY_VERSION.tar.gz"

sudo rm -rf "$TARGET_DIR"
sudo tar -xzf "$TMP_TAR" -C "$INSTALL_ROOT"
sudo mv "$INSTALL_ROOT/scrcpy-linux-x86_64-v$SCRCPY_VERSION" "$TARGET_DIR"
sudo ln -sfn "$TARGET_DIR" "$INSTALL_ROOT/scrcpy"
sudo ln -sf "$INSTALL_ROOT/scrcpy/scrcpy" /usr/local/bin/scrcpy

echo "Installed scrcpy $SCRCPY_VERSION to $TARGET_DIR (symlinked as $INSTALL_ROOT/scrcpy and /usr/local/bin/scrcpy)."
echo "Next: enable Developer Options + USB debugging on the device, plug it"
echo "in via USB, and run 'mirror-tablet' (see ../tablet-mirror/README.md)."

#!/bin/bash
# Installs CLion (latest) from JetBrains' official download service.
#
# JetBrains doesn't ship CLion via apt, so this pulls the official tarball
# (the same URL the JetBrains Toolbox App itself uses), unpacks it under
# /opt, and symlinks the launcher onto PATH.
#
# Note: CLion still needs a JetBrains account + license (or the free 30-day
# trial) on first launch — that login step is interactive and can't be
# scripted. This script only gets the IDE onto the machine.
set -euo pipefail

if command -v clion >/dev/null 2>&1; then
    echo "CLion is already installed ($(readlink -f "$(command -v clion)"))."
    exit 0
fi

TMP_TAR="$(mktemp --suffix=.tar.gz)"
trap 'rm -f "$TMP_TAR"' EXIT

echo "Downloading latest CLion for Linux..."
wget -q -O "$TMP_TAR" "https://data.services.jetbrains.com/products/download?platform=linux&code=CL"

INSTALL_ROOT=/opt
TOP_DIR="$(tar -tzf "$TMP_TAR" | head -1 | cut -f1 -d/)"
TARGET_DIR="$INSTALL_ROOT/$TOP_DIR"

sudo rm -rf "$TARGET_DIR"
sudo tar -xzf "$TMP_TAR" -C "$INSTALL_ROOT"
sudo ln -sfn "$TARGET_DIR" "$INSTALL_ROOT/clion"
sudo ln -sf "$INSTALL_ROOT/clion/bin/clion.sh" /usr/local/bin/clion

echo "Installed CLion to $TARGET_DIR (symlinked as $INSTALL_ROOT/clion and /usr/local/bin/clion)."
echo "Launch with 'clion'. On first run: log in / start the trial, then use"
echo "Tools > Create Desktop Entry to get it in your app menu."

#!/bin/bash
# Installs Visual Studio Code from Microsoft's official .deb.
set -euo pipefail

if command -v code >/dev/null 2>&1; then
    echo "VS Code is already installed ($(code --version | head -1))."
    exit 0
fi

TMP_DEB="$(mktemp --suffix=.deb)"
trap 'rm -f "$TMP_DEB"' EXIT

wget -q -O "$TMP_DEB" "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
sudo apt-get update -qq
sudo apt-get install -y "$TMP_DEB"

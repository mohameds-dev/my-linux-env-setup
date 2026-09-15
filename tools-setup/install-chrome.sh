#!/bin/bash
# Installs Google Chrome (stable) from Google's official .deb.
set -euo pipefail

if command -v google-chrome >/dev/null 2>&1; then
    echo "Chrome is already installed ($(google-chrome --version))."
    exit 0
fi

TMP_DEB="$(mktemp --suffix=.deb)"
trap 'rm -f "$TMP_DEB"' EXIT

wget -q -O "$TMP_DEB" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt-get update -qq
sudo apt-get install -y "$TMP_DEB"

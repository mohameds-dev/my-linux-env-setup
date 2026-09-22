#!/bin/bash
# Installs Discord from Discord's official .deb.
set -euo pipefail

if command -v discord >/dev/null 2>&1; then
    echo "Discord is already installed."
    exit 0
fi

TMP_DEB="$(mktemp --suffix=.deb)"
trap 'rm -f "$TMP_DEB"' EXIT

wget -q -O "$TMP_DEB" "https://discord.com/api/download?platform=linux&format=deb"
sudo apt-get update -qq
sudo apt-get install -y "$TMP_DEB"

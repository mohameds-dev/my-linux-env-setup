#!/bin/bash
# Installs git via apt.
set -euo pipefail

if command -v git >/dev/null 2>&1; then
    echo "git is already installed ($(git --version))."
    exit 0
fi

sudo apt-get update -qq
sudo apt-get install -y git

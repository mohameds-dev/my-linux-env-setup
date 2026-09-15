#!/bin/bash
# Mounts the Windows partition (read-only) and, inside it, your WSL ext4.vhdx
# (also read-only) so you can browse/copy your WSL files from Linux Mint.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pkexec bash "$DIR/wsl-root-helper.sh" mount

echo
echo "Mounted read-only:"
echo "  Windows C: drive  -> /mnt/winc"
echo "  WSL filesystem    -> /mnt/wsldata"
echo "  Your WSL home dir -> /mnt/wsldata/home/mhmdslaptop"
echo

if command -v thunar >/dev/null 2>&1; then
    thunar /mnt/wsldata/home/mhmdslaptop >/dev/null 2>&1 &
    disown
else
    xdg-open /mnt/wsldata/home/mhmdslaptop >/dev/null 2>&1 &
    disown
fi

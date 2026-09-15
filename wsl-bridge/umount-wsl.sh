#!/bin/bash
# Cleanly unmounts the WSL filesystem, detaches the nbd device, and unmounts
# the Windows partition. Run this before shutting down / rebooting into Windows.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pkexec bash "$DIR/wsl-root-helper.sh" umount

echo "Unmounted and detached cleanly."

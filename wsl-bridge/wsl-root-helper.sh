#!/bin/bash
# Root-side actions for the WSL bridge. Not meant to be run directly —
# invoked via `pkexec bash wsl-root-helper.sh {mount|umount}` by mount-wsl.sh / umount-wsl.sh.
set -euo pipefail

WIN_PART="/dev/nvme0n1p3"
WIN_MNT="/mnt/winc"
NBD_DEV="/dev/nbd0"
WSL_MNT="/mnt/wsldata"
REAL_UID="${PKEXEC_UID:-$(id -u "${SUDO_USER:-root}")}"

do_mount() {
    if mountpoint -q "$WSL_MNT"; then
        echo "$WSL_MNT is already mounted."
        return 0
    fi

    mkdir -p "$WIN_MNT" "$WSL_MNT"

    if ! mountpoint -q "$WIN_MNT"; then
        mount -t ntfs-3g -o ro,uid="$REAL_UID",gid="$REAL_UID",umask=022 "$WIN_PART" "$WIN_MNT"
    fi

    modprobe nbd max_part=16

    NBD_SIZE=$(lsblk -ndo SIZE "$NBD_DEV" 2>/dev/null | tr -d '[:space:]')
    if [ -z "$NBD_SIZE" ] || [ "$NBD_SIZE" = "0B" ]; then
        VHDX=$(ls "$WIN_MNT"/Users/*/AppData/Local/wsl/*/ext4.vhdx 2>/dev/null | head -1)
        if [ -z "$VHDX" ]; then
            echo "Could not find an ext4.vhdx under $WIN_MNT/Users/*/AppData/Local/wsl/" >&2
            exit 1
        fi
        qemu-nbd --read-only --connect="$NBD_DEV" "$VHDX"
        sleep 1
        partprobe "$NBD_DEV" || true
    fi

    mount -o ro "$NBD_DEV" "$WSL_MNT"
}

do_umount() {
    if mountpoint -q "$WSL_MNT"; then
        umount "$WSL_MNT"
    fi
    qemu-nbd --disconnect "$NBD_DEV" >/dev/null 2>&1 || true
    if mountpoint -q "$WIN_MNT"; then
        umount "$WIN_MNT"
    fi
}

case "${1:-}" in
    mount) do_mount ;;
    umount) do_umount ;;
    *) echo "Usage: $0 {mount|umount}" >&2; exit 1 ;;
esac

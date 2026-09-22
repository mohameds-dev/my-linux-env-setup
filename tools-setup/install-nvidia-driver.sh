#!/bin/bash
# Switches an NVIDIA GPU from the open-source nouveau driver to the
# proprietary driver, and configures PRIME GPU switching if it's a hybrid
# (iGPU + NVIDIA) laptop.
#
# Hardware-aware and safe to run on any machine:
#   - No NVIDIA GPU present (PCI vendor 10de)?           -> no-op, exit 0.
#   - Not a Debian/Ubuntu system (no apt)?                -> no-op, exit 0.
#   - Proprietary driver already active?                  -> skip the install,
#                                                             but still make
#                                                             sure prime-select
#                                                             is configured.
#   - Desktop with only an NVIDIA GPU (no iGPU)?           -> installs the
#                                                             driver, skips
#                                                             prime-select
#                                                             (nothing to
#                                                             switch between).
#   - Laptop with an iGPU + NVIDIA (Optimus)?              -> installs the
#                                                             driver and sets
#                                                             prime-select to
#                                                             on-demand (iGPU
#                                                             drives the
#                                                             display by
#                                                             default, NVIDIA
#                                                             only wakes for
#                                                             apps that ask
#                                                             for it — safest
#                                                             default, best
#                                                             battery life).
#
# The actual driver package is picked by `ubuntu-drivers autoinstall`, which
# reads the GPU's modalias and installs whatever that specific chip's
# recommended driver is — so this works unmodified across different NVIDIA
# generations/models (a laptop RTX 3050 Ti, a desktop RTX 3060 Ti, etc.)
# without needing to hardcode a driver version here.
#
# A reboot is required for the new kernel module to actually take over from
# nouveau. This script does NOT reboot for you — it just tells you to.
set -euo pipefail

if ! command -v apt-get >/dev/null 2>&1; then
    echo "Not a Debian/Ubuntu-based system (no apt-get) — this script only supports those. Skipping."
    exit 0
fi

NVIDIA_PCI="$(lspci -d 10de: -k 2>/dev/null || true)"
if [ -z "$NVIDIA_PCI" ]; then
    echo "No NVIDIA GPU detected (no PCI device from vendor 10de) — nothing to do."
    exit 0
fi

GPU_NAME="$(lspci -d 10de: | head -1 | sed -E 's/^[0-9a-f:.]+ [^:]+: //')"
CURRENT_DRIVER="$(echo "$NVIDIA_PCI" | grep -i 'Kernel driver in use' | head -1 | awk -F': ' '{print $2}')"

# Any iGPU (Intel vendor 8086, AMD vendor 1002) acting as a display
# controller alongside the NVIDIA card means this is a hybrid/Optimus laptop.
IGPU_PCI="$( { lspci -d 8086:: -k 2>/dev/null; lspci -d 1002:: -k 2>/dev/null; } | grep -iE 'VGA compatible controller|Display controller' || true)"

echo "NVIDIA GPU: $GPU_NAME"
echo "Current driver: ${CURRENT_DRIVER:-none bound}"
echo "Hybrid graphics (iGPU present): $([ -n "$IGPU_PCI" ] && echo yes || echo no)"
echo

if [[ "$CURRENT_DRIVER" == nvidia* ]]; then
    echo "Proprietary NVIDIA driver is already active — skipping install."
else
    if ! command -v ubuntu-drivers >/dev/null 2>&1; then
        echo "Installing ubuntu-drivers-common..."
        sudo apt-get update -qq
        sudo apt-get install -y ubuntu-drivers-common
    fi

    echo "Drivers available for this GPU:"
    ubuntu-drivers devices 2>/dev/null | grep -i nvidia || echo "(none listed by ubuntu-drivers — is this an Ubuntu/Mint-based system with the right repos enabled?)"
    echo

    echo "Installing the recommended driver via 'ubuntu-drivers autoinstall'..."
    sudo ubuntu-drivers autoinstall

    # Belt-and-suspenders: the driver package's postinst normally blacklists
    # nouveau itself, but confirm it actually happened rather than assuming.
    if ! modprobe --showconfig 2>/dev/null | grep -q 'blacklist nouveau'; then
        echo "nouveau wasn't blacklisted automatically — adding it explicitly."
        echo -e "blacklist nouveau\noptions nouveau modeset=0" | sudo tee /etc/modprobe.d/blacklist-nouveau.conf >/dev/null
        sudo update-initramfs -u
    fi
fi

if [ -n "$IGPU_PCI" ]; then
    echo
    echo "Hybrid graphics detected — installing nvidia-prime for GPU switching..."
    sudo apt-get install -y nvidia-prime

    if command -v prime-select >/dev/null 2>&1; then
        if sudo prime-select on-demand 2>/tmp/prime-select-err.$$; then
            echo "prime-select set to 'on-demand' (iGPU drives the display by default; NVIDIA activates on-demand for apps that request it)."
        else
            echo "This system's prime-select doesn't support 'on-demand' mode:"
            cat /tmp/prime-select-err.$$
            echo "Current mode left as: $(prime-select query 2>/dev/null || echo unknown). Switch manually with 'sudo prime-select nvidia' or 'sudo prime-select intel' if needed."
        fi
        rm -f /tmp/prime-select-err.$$
    fi
else
    echo
    echo "No iGPU alongside the NVIDIA card — discrete-only setup, prime-select doesn't apply here."
fi

echo
echo "Done. A REBOOT is required before the new driver takes over from nouveau."
echo "After rebooting, verify with: nvidia-smi"
[ -n "$IGPU_PCI" ] && echo "and: prime-select query"

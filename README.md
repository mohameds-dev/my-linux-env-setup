# personal-setup-tools

Just a project to maintain tools I make for my development and personal
setup, on Linux Mint.

## Commands

| Command | What it does | Details |
|---|---|---|
| `cd tools-setup && ./run-all.sh` | Installs every dev tool below (git, Chrome, VS Code, Discord, CLion, NVIDIA driver, scrcpy/adb) in one pass, one sudo prompt. | [tools-setup/](tools-setup/) |
| `cd tools-setup && ./install-<tool>.sh` | Installs just one tool from the list above. | [tools-setup/](tools-setup/) |
| `mirror-tablet` | Mirrors the Samsung Galaxy Tab S9 FE's screen on this laptop over USB (presentations). Alias in `~/.bashrc` → `tablet-mirror/mirror-tablet`. | [tablet-mirror/](tablet-mirror/) |
| `cd keyboard-shortcuts && ./apply-shortcuts.sh` | Applies this machine's XFCE (xfwm4) keyboard shortcuts (window snap/maximize/move-to-monitor, Whisker menu on tap-Super) from `config.json`. | [keyboard-shortcuts/](keyboard-shortcuts/) |
| `cd wsl-bridge && ./mount-wsl.sh` / `./umount-wsl.sh` | Mounts/unmounts a Windows WSL install's filesystem (on an external SSD) so it's browsable from Linux Mint. | [wsl-bridge/](wsl-bridge/) |
| `cd misc && ./wifi.sh` | Adds WPA2-Enterprise (PEAP) wifi networks from `wifi.sh`'s (gitignored) `*_secrets.json` file via `nmcli`. | [misc/](misc/) |
| — (reference only, no command) | C++ single-file + stdin-redirect setup notes for DSA practice/presenting, used when CLion isn't available. | [cpp-dsa-setup/](cpp-dsa-setup/) |

Each folder's own README has the full details, troubleshooting, and why
things are built the way they are.

# Bridging WSL (Windows) → Linux Mint (external SSD)

## Quick start (do this every time)

```bash
cd ~/projects/wsl-bridge
./mount-wsl.sh      # 1 password prompt (graphical) -> opens your WSL home in Thunar
```

...browse/copy what you need...

```bash
./umount-wsl.sh     # when done
```

That's it. Everything below is background/reference — you shouldn't need it for
normal use.

## The situation

- This laptop has an internal NVMe drive (`/dev/nvme0n1`) with Windows 11 + WSL2.
- Linux Mint (this install) runs from an external USB SSD (`/dev/sda`).
- Only one OS runs at a time — there's no way to "live sync" between Windows/WSL and
  Mint while both are running, because they can't both be running at once on this
  hardware. What we *can* do: whenever you're booted into Mint, read the internal
  drive directly (Windows isn't running, so nothing has it locked) and pull whatever
  is currently on disk.
- **This means "up to date" = as of the last time you cleanly shut down Windows**,
  not live/real-time sync.

### Partition layout (as discovered)

| Device | Size | FS | Contents |
|---|---|---|---|
| `/dev/nvme0n1p1` | 100M | vfat | EFI system partition |
| `/dev/nvme0n1p2` | 16M | — | Microsoft Reserved |
| `/dev/nvme0n1p3` | 475.5G | ntfs | **Windows C: drive** (this is what we mount) |
| `/dev/nvme0n1p4` | 1.3G | ntfs | Windows Recovery |

Your WSL distro's filesystem lives inside a virtual disk file at:

```
/mnt/winc/Users/Mohamed/AppData/Local/wsl/{d74f2f30-b38a-4589-8791-0eff734db11b}/ext4.vhdx
```

This is a Hyper-V virtual disk (not a plain file), so it has to be attached as a
block device (via `qemu-nbd`) before its ext4 filesystem can be mounted. It contains
no partition table — the whole vhdx is one ext4 filesystem — and your home directory
is at `/home/mhmdslaptop` inside it (41G total; `projects/` alone is 8.1G).

## Safety notes — read this before using it

- **Everything is mounted read-only.** Neither script ever writes to the NTFS
  partition or the vhdx. There is no path by which this can corrupt or destabilize
  your Windows installation.
- **Always fully shut down Windows before booting into Mint** — not sleep, not
  hibernate. If Windows "Fast Startup" is enabled, Windows treats a shutdown like a
  partial hibernation and the NTFS filesystem is left in a "dirty"/hiberfil state,
  which can make `ntfs-3g` refuse to mount it at all (even read-only). If you hit a
  mount error mentioning hibernation, boot back into Windows, fully shut down
  (`shutdown /s /f` from an elevated prompt bypasses Fast Startup), and try again from
  Mint.
- Nothing here touches Windows' boot files, bootloader, or partition table.
- Migration is one-directional (WSL → Mint). Changes you make on the Mint side won't
  flow back to Windows/WSL automatically — that's expected, since the goal is to stop
  needing WSL day-to-day.

## One-time setup (already done on this machine)

```bash
# Package providing qemu-nbd, used to attach the .vhdx as a block device
pkexec apt-get install -y qemu-utils

# Kernel module for network block devices (used locally, no actual network involved)
pkexec modprobe nbd max_part=16
```

`qemu-utils` is now installed permanently. The `nbd` module needs to be loaded once
per boot — `mount-wsl.sh` does this automatically every time, so you don't need to
run it by hand.

## Everyday usage

From `~/projects/wsl-bridge/`:

```bash
./mount-wsl.sh      # mounts everything read-only, opens your WSL home in Thunar
...                 # browse/copy whatever you need in the file manager, or via cp/rsync
./umount-wsl.sh      # cleanly unmounts + detaches when you're done
```

After `mount-wsl.sh` runs, you have:

- `/mnt/winc` — the whole Windows C: drive (read-only)
- `/mnt/wsldata` — your WSL distro's root filesystem (read-only)
- `/mnt/wsldata/home/mhmdslaptop` — your WSL home directory — this is what opens in
  Thunar automatically

Run `umount-wsl.sh` when you're done for the session (not strictly required before a
reboot since the mounts don't persist anyway, but it's clean and releases the loop
device without leaving it dangling if you plan to remount later in the same session).

## What to migrate vs. leave behind

Do **not** copy verbatim (these bake in absolute paths / are huge and easy to
reinstall fresh instead):

- `miniconda3/` (16G) — reinstall Miniconda natively on Mint instead
- `.cache/`, `.vscode-server/`, `.vscode-remote-containers/`, `.conda/`, `.anaconda/`,
  `.nv/`, `.npm/`, `.nvm/`, `.pixi/`, `.gng/` — regenerated automatically by the
  relevant tools once reinstalled

Worth copying — your actual work:

- `projects/` (8.1G)
- `data_science_class_labs/`, `codepath_web/`, `gpu_programming_class/`,
  `SEP_workshop/`, `fall2026/`, `coding_playground/`, `utils/`, `ieee-nsm/`,
  `outlier/`, `bandit_otw/`, `camscanner_concept/`, `decoded_highlights/`
- `.gitconfig`, `.ssh/` — needed for git/GitHub access from Mint (after copying,
  run `chmod 700 ~/.ssh && chmod 600 ~/.ssh/*` since permissions don't survive
  the NTFS/ext4 round-trip cleanly)

You can just drag-and-drop what you need in Thunar once it's mounted. If you'd
rather copy everything in one shot, here's an `rsync` example with the drop list
above baked in as excludes — adjust the destination path as you like:

```bash
rsync -avh --progress \
  --exclude 'miniconda3/' \
  --exclude '.cache/' \
  --exclude '.vscode-server/' \
  --exclude '.vscode-remote-containers/' \
  --exclude '.conda/' \
  --exclude '.anaconda/' \
  --exclude '.nv/' \
  --exclude '.npm/' \
  --exclude '.nvm/' \
  --exclude '.pixi/' \
  --exclude '.gng/' \
  /mnt/wsldata/home/mhmdslaptop/ /home/the_mhmd/projects/wsl-migrated/
```

## Manual commands (what the scripts do, for reference/troubleshooting)

```bash
# 1. Mount the Windows partition read-only
pkexec mkdir -p /mnt/winc
pkexec mount -t ntfs-3g -o ro,uid=$(id -u),gid=$(id -g),umask=022 /dev/nvme0n1p3 /mnt/winc

# 2. Load the nbd kernel module
pkexec modprobe nbd max_part=16

# 3. Attach the vhdx as a read-only block device
pkexec qemu-nbd --read-only --connect=/dev/nbd0 \
  "/mnt/winc/Users/Mohamed/AppData/Local/wsl/{d74f2f30-b38a-4589-8791-0eff734db11b}/ext4.vhdx"

# 4. Mount the ext4 filesystem inside it, read-only
pkexec mkdir -p /mnt/wsldata
pkexec mount -o ro /dev/nbd0 /mnt/wsldata

# --- browse/copy files under /mnt/wsldata/home/mhmdslaptop ---

# 5. Tear down, in reverse order
pkexec umount /mnt/wsldata
pkexec qemu-nbd --disconnect /dev/nbd0
pkexec umount /mnt/winc
```

Each `pkexec` call pops a graphical password prompt (Mint/XFCE has a polkit agent
running); the scripts collapse all of this into a single prompt per run by running
one root helper script instead of five separate `pkexec` calls.

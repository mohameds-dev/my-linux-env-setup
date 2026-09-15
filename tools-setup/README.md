# tools-setup

Fresh-machine tool installer. One script per tool, plus a parent script that
runs them all.

## Quick start

```bash
cd ~/projects/linux-env-setup/tools-setup
./run-all.sh
```

You'll get **one** sudo password prompt at the very start. `run-all.sh`
caches that credential and refreshes it in the background for the rest of
the run, so none of the individual install scripts prompt again.

`sudo` needs a real terminal to read the password, so run this from your own
terminal (or Claude Code's `!` prefix) — it can't be run from a tool that has
no TTY attached.

## What's in here

| File | What it does |
|---|---|
| `run-all.sh` | Parent script. Requests sudo once, then runs every `install-*.sh` in this folder in turn. |
| `install-git.sh` | Installs `git` via `apt`. |
| `install-chrome.sh` | Installs Google Chrome (stable) from Google's official `.deb`. |
| `install-vscode.sh` | Installs VS Code from Microsoft's official `.deb`. |

## Behavior / guarantees

- **Idempotent** — each script checks if its tool is already installed and
  exits immediately (no-op) if so. Safe to re-run `run-all.sh` any time,
  e.g. after adding a new tool script.
- **Fail-safe** — if one script fails, `run-all.sh` prints its error and
  moves on to the next one instead of stopping the whole run. At the end you
  get a summary:
  ```
  ===== Summary =====
  Succeeded: install-git.sh install-chrome.sh
  Failed:    install-vscode.sh
  ```
- **Single password prompt** — only `run-all.sh` calls `sudo -v` /
  keep-alive. Individual scripts just call `sudo apt-get ...` directly and
  rely on the cached credential.
- **Trusted commands only** — every script only touches `apt`/`apt-get`
  installs from official vendor sources (Google, Microsoft) or the distro
  repos. No arbitrary remote scripts are piped into a shell.

## Adding a new tool

1. Create `install-<tool>.sh` in this directory, following the shape of the
   existing scripts:
   ```bash
   #!/bin/bash
   set -euo pipefail

   if command -v <tool-binary> >/dev/null 2>&1; then
       echo "<tool> is already installed."
       exit 0
   fi

   # ... install steps (apt-get install, or download official .deb + apt-get install) ...
   ```
2. `chmod +x install-<tool>.sh`
3. That's it — `run-all.sh` globs `install-*.sh` in this folder, so the new
   script is picked up automatically on the next run. No changes needed to
   `run-all.sh` itself.

## Running a single tool script

Each script also works standalone (it does its own `apt-get update` and
install), so you don't have to go through `run-all.sh`:

```bash
./install-git.sh
```

It will still prompt for a password if `run-all.sh` isn't already holding a
cached sudo credential.

# tablet-mirror

Mirror an Android device's screen (Samsung Galaxy Tab S9 FE) onto this
laptop over USB — for presenting from the tablet on a bigger screen without
any extra cabling or screen-sharing app on the tablet side.

Uses [scrcpy](https://github.com/Genymobile/scrcpy): USB only, no Wi-Fi/network
dependency, low latency (typically well under 100ms), no data cable other
than the USB cable itself, nothing to install on the tablet.

## Quick start

```bash
cd ~/projects/linux-env-setup/tools-setup
./install-scrcpy.sh          # one-time
```

Then, on the tablet (one-time): Settings > About tablet > tap "Build number"
7 times to unlock Developer Options, then Settings > Developer options >
enable "USB debugging".

Plug the tablet in via USB, accept the "Allow USB debugging?" prompt that
pops up on the tablet (tick "Always allow from this computer" so it doesn't
ask again), then run:

```bash
mirror-tablet
```

(`mirror-tablet` is a bash alias set up in `~/.bashrc` pointing at
`mirror-tablet` in this folder — open a new terminal, or `source ~/.bashrc`,
if it's not found right after install.)

## Useful variants

```bash
mirror-tablet --fullscreen         # go straight to fullscreen for the presentation
mirror-tablet --turn-screen-off    # blank the tablet's own screen while mirroring (saves battery, avoids glare)
mirror-tablet --help               # scrcpy's own extra options, plus this wrapper's usage
```

Once the window is open, `Ctrl+F` toggles fullscreen, and closing the window
(or `Ctrl+C` in the terminal) ends the mirror session.

## Why not apt's `scrcpy` package?

Ubuntu/Mint's repo ships scrcpy 1.25 (from 2021). It crashes on this tablet
because it calls internal Android APIs (e.g.
`SurfaceControl.createDisplay`) that newer Android versions removed:

```
java.lang.NoSuchMethodException: android.view.SurfaceControl.createDisplay
```

`install-scrcpy.sh` removes that broken apt package and instead installs the
prebuilt static Linux x86_64 binary straight from scrcpy's own GitHub
Releases into `/opt/scrcpy-<version>`, symlinked onto `PATH` via
`/usr/local/bin/scrcpy` (which resolves before apt's `/usr/bin`). `adb`
itself still comes from apt — that protocol is stable, so the packaged
version is fine.

## Troubleshooting

- **`adb devices` shows `unauthorized`**: the tablet is waiting on the
  "Allow USB debugging?" prompt — unlock the tablet screen and tap Allow.
- **`adb devices` shows nothing at all**: check the USB cable actually
  supports data (not charge-only), and that USB debugging is still enabled
  under Developer options.
- **Window is laggy**: lower `-m`/`-b` in `mirror-tablet`, or connect via a
  USB 3.0 port/cable if currently on USB 2.0.

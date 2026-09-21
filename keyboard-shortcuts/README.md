# keyboard-shortcuts

XFCE (xfwm4) keyboard shortcuts, stored as data so they can be re-applied on
any fresh XFCE install and extended later. Currently covers:

| Shortcut | Action |
|---|---|
| Tap `Super` alone (press+release, nothing else pressed) | Open the Whisker app menu |
| `Super` + `Up` | Maximize focused window |
| `Super` + `Left` / `Right` | Snap window to left/right half of screen |
| `Super` + `Shift` + `Left` / `Right` / `Up` / `Down` | Move window to the monitor on the left/right/above/below (needs 2+ monitors) |

## Quick start

```bash
cd ~/projects/linux-env-setup/keyboard-shortcuts
./apply-shortcuts.sh
```

`sudo` is used to install missing packages (`jq`, `xcape`) via `apt`, so run
this from a real terminal (or Claude Code's `!` prefix) — it needs a TTY to
read the password.

The script is idempotent: safe to re-run any time, e.g. after editing
`config.json` to add more shortcuts.

## Why this exists: the bare-Super trap

XFCE splits keyboard shortcuts across two independent grabs:

- `xfsettingsd` handles `/commands/custom/*` (launch a command) — a **plain
  key grab that fires on keydown**.
- `xfwm4` handles `/xfwm4/custom/*` (window-manager actions like maximize/tile)
  — a **modifier+key combo grab**.

If you bind the app menu directly to bare `Super_L` (the out-of-the-box
default on many XFCE setups), it fires the instant Super is pressed down —
before the WM can ever see a second key like `Up` or `Left` as part of a
combo. Every `Super+<key>` shortcut you add loses that race and just opens
the menu instead.

The fix is `xcape`: it leaves `Super_L` alone as an ordinary modifier (so
`Super+<key>` combos pass straight through, unaffected), and only if you tap
Super **alone** and release it within the configured timeout does it emit a
synthetic `Super_R` key event. The menu is bound to that synthetic key
instead of to raw `Super_L`, so it only fires on an actual standalone tap —
never as a side effect of a combo. `Super_R` doesn't need a physical key to
exist; X's default `pc105` keymap already reserves a keycode for it even on
laptops that only have a left Super key.

## What's in here

| File | What it does |
|---|---|
| `config.json` | The shortcuts themselves — data, not code. Edit this to add/change bindings. |
| `apply-shortcuts.sh` | Reads `config.json` and applies everything via `xfconf-query`; installs `jq`/`xcape` if missing; starts `xcape` for the current session; writes an autostart entry so it survives reboot/login. |

## `config.json` shape

```json
{
  "packages": ["xcape", "jq"],
  "xcape": { "mapping": "Super_L=Super_R", "timeout_ms": 200 },
  "remove": [ { "channel": "...", "property": "/commands/custom/Super_L" } ],
  "commands": [ { "keys": "Super_R", "command": "xfce4-popup-whiskermenu" } ],
  "xfwm4":    [ { "keys": "<Super>Up", "action": "maximize_window_key" } ]
}
```

- **`remove`** — xfconf properties to delete outright (used for the
  bare-`Super_L` trap above). Safe no-op if already absent.
- **`commands`** — app-launch shortcuts, written to
  `xfce4-keyboard-shortcuts` `/commands/custom/<keys>`.
- **`xfwm4`** — window-manager action shortcuts, written to
  `xfce4-keyboard-shortcuts` `/xfwm4/custom/<keys>`. `action` must be one of
  xfwm4's built-in action names (e.g. `maximize_window_key`,
  `tile_left_key`, `move_window_to_monitor_right_key`). The
  `/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml`
  default file only lists actions that ship with a default binding, so it's
  incomplete — when in doubt, check the real list by running
  `strings $(which xfwm4) | grep _key` and testing the binding actually
  fires (see the trap noted below).
- **key syntax** — `<Super>`, `<Shift>`, `<Control>`/`<Primary>`, `<Alt>`
  combine as e.g. `<Super><Shift>Left`; a bare key like `Super_L` or
  `Super_R` has no `<...>` wrapper.

## Adding a new shortcut

1. Add an entry to the `commands` or `xfwm4` array in `config.json`.
2. Re-run `./apply-shortcuts.sh`.

No changes to the script are needed for ordinary additions — it just loops
over whatever's in the JSON.

## Known limitations

- **XFCE/xfwm4 only.** This whole approach (`/xfwm4/custom`, `xfsettingsd`
  command grabs) is XFCE-specific and won't transfer to GNOME/KDE/etc.
  without a different mechanism.
- **The `move_window_left_key` / `move_window_right_key` / `move_window_up_key`
  action names are a trap.** They read as the obvious names for "move window
  to the monitor on the left/right/above", but on xfwm4 4.18 they're
  stale/dead — `xfconf-query` accepts the binding without error, and it
  shows up in `xfce4-keyboard-settings`, but xfwm4 doesn't recognize the
  action so pressing the keys does nothing. The real actions are
  `move_window_to_monitor_left_key` / `_right_key` / `_up_key` / `_down_key`
  (confirmed via `strings $(which xfwm4) | grep monitor`). This repo used to
  ship the dead names — if a binding from here isn't working, check for
  `_key` names that are missing `_to_monitor_`.
- Multi-monitor shortcuts are no-ops on a single-monitor machine — they only
  do something once a second display is actually connected.
- Monitor arrangement is physical, not logical: `left`/`right`/`up`/`down`
  are resolved from actual screen position (`xrandr --listmonitors`), not
  from any left-to-right ordering you might assume. Two monitors stacked
  vertically need the up/down bindings, not left/right, regardless of which
  one is "primary".

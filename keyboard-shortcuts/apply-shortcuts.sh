#!/bin/bash
# Applies XFCE/xfwm4 keyboard shortcuts from config.json (same directory).
#
# Fixes the classic XFCE trap where a shortcut bound directly to bare Super_L
# (e.g. to open the app menu) steals every Super+<key> combo, because
# xfsettingsd grabs it as a plain key that fires on keydown. The fix: leave
# Super_L as a normal modifier, use xcape to emit a synthetic Super_R only on
# a tap-and-release-alone, and bind the menu to that synthetic key instead.
#
# Safe to re-run: every step checks current state first (installs are
# skipped if already present, bindings are set idempotently, the removed
# property is only removed if it exists).
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$DIR/config.json"

if [ "${XDG_CURRENT_DESKTOP:-}" != "XFCE" ] || ! command -v xfconf-query >/dev/null 2>&1; then
    echo "This script targets XFCE (xfwm4 + xfconf-query). Current desktop: ${XDG_CURRENT_DESKTOP:-unknown}." >&2
    echo "Nothing was changed." >&2
    exit 1
fi

# --- 1. packages -----------------------------------------------------------

# jq itself must exist before it can be used to read config.json's package
# list, so it's bootstrapped directly rather than through that list.
if ! command -v jq >/dev/null 2>&1; then
    echo "Installing jq (needed to read config.json)"
    sudo apt-get update -qq
    sudo apt-get install -y jq
fi

mapfile -t PACKAGES < <(jq -r '.packages[]' "$CONFIG")

MISSING=()
for pkg in "${PACKAGES[@]}"; do
    command -v "$pkg" >/dev/null 2>&1 || MISSING+=("$pkg")
done

if [ "${#MISSING[@]}" -gt 0 ]; then
    echo "Installing missing packages: ${MISSING[*]}"
    sudo apt-get update -qq
    sudo apt-get install -y "${MISSING[@]}"
fi

# --- helpers -----------------------------------------------------------

# Idempotent property set: update if it exists, create it otherwise.
xfconf_set() {
    local channel="$1" prop="$2" value="$3"
    xfconf-query -c "$channel" -p "$prop" -s "$value" 2>/dev/null \
        || xfconf-query -c "$channel" -p "$prop" -n -t string -s "$value"
}

# Idempotent property removal: no error if it's already gone.
xfconf_remove() {
    local channel="$1" prop="$2"
    xfconf-query -c "$channel" -p "$prop" -r 2>/dev/null || true
}

# --- 2. remove shortcuts that must not be bound directly --------------------

jq -c '.remove[]' "$CONFIG" | while read -r row; do
    channel=$(jq -r '.channel' <<<"$row")
    prop=$(jq -r '.property' <<<"$row")
    echo "Removing $channel $prop (if present)"
    xfconf_remove "$channel" "$prop"
done

# --- 3. command shortcuts (xfce4-keyboard-shortcuts /commands/custom) -------

jq -c '.commands[]' "$CONFIG" | while read -r row; do
    keys=$(jq -r '.keys' <<<"$row")
    cmd=$(jq -r '.command' <<<"$row")
    echo "Binding $keys -> $cmd"
    xfconf_set "xfce4-keyboard-shortcuts" "/commands/custom/$keys" "$cmd"
done

# --- 4. window manager shortcuts (xfwm4 /xfwm4/custom) ----------------------

jq -c '.xfwm4[]' "$CONFIG" | while read -r row; do
    keys=$(jq -r '.keys' <<<"$row")
    action=$(jq -r '.action' <<<"$row")
    echo "Binding $keys -> $action"
    xfconf_set "xfce4-keyboard-shortcuts" "/xfwm4/custom/$keys" "$action"
done

# --- 5. xcape: run now + autostart on login ---------------------------------

MAPPING=$(jq -r '.xcape.mapping' "$CONFIG")
TIMEOUT=$(jq -r '.xcape.timeout_ms' "$CONFIG")

if [ -n "${DISPLAY:-}" ]; then
    pkill -x xcape 2>/dev/null || true
    nohup xcape -e "$MAPPING" -t "$TIMEOUT" >/tmp/xcape.log 2>&1 &
    disown
    echo "xcape running now (mapping: $MAPPING, tap timeout: ${TIMEOUT}ms)"
else
    echo "No DISPLAY in this session -- skipping live xcape start (autostart entry below still gets created)."
fi

mkdir -p ~/.config/autostart
cat > ~/.config/autostart/xcape.desktop <<EOF
[Desktop Entry]
Type=Application
Name=xcape
Comment=Tap-only modifier key emulation (see keyboard-shortcuts/config.json)
Exec=xcape -e $MAPPING -t $TIMEOUT
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF
echo "Autostart entry written to ~/.config/autostart/xcape.desktop"

echo
echo "Done. No logout/restart needed -- xfwm4 and xfsettingsd pick up xfconf changes live."

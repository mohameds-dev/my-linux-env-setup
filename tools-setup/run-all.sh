#!/bin/bash
# Runs every install-*.sh script in this directory, one at a time.
#
# Asks for sudo once up front and keeps the credential cache alive in the
# background for the whole run, so none of the individual scripts prompt for
# a password again. If a script fails, its error is shown and the run moves
# on to the next script instead of aborting.
#
# To add a new tool later: drop an install-<tool>.sh script in this same
# directory (same shape as the existing ones) and it will be picked up
# automatically next run.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Requesting sudo access up front (used for every install below)..."
sudo -v

# Refresh the sudo timestamp in the background until this script exits, so
# individual install scripts never trigger a second password prompt.
( while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done ) &
KEEPALIVE_PID=$!
trap 'kill "$KEEPALIVE_PID" 2>/dev/null' EXIT

OK=()
FAILED=()

for script in "$DIR"/install-*.sh; do
    [ -e "$script" ] || continue
    name="$(basename "$script")"
    echo
    echo "==> Running $name"
    if bash "$script"; then
        OK+=("$name")
    else
        echo "!! $name failed (see error above) — skipping it and continuing." >&2
        FAILED+=("$name")
    fi
done

echo
echo "===== Summary ====="
echo "Succeeded: ${OK[*]:-none}"
echo "Failed:    ${FAILED[*]:-none}"

[ "${#FAILED[@]}" -eq 0 ]
